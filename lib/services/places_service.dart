// Подсказки населённых пунктов и улиц (упрощение адреса, 24.09.2026).
//
// Зачем. Раньше адрес заполнялся по цепочке «область → город → улица → дом»,
// и человек застревал на первом шаге: Москва в справочнике лежит внутри
// области, посёлок свой в списке не находился, и объявление не публиковалось
// совсем. Теперь спрашиваем сразу населённый пункт, поиском по всей стране, а
// область сервер выводит из города сам.
//
//   GET /v1/addresses/places?q=мариу&size=40
//   GET /v1/addresses/search?q=лен&types[0]=street&filters[city_id]=123
//
// Наружу отдаём готовые подсказки: название, пояснение (область и район, чтобы
// отличать одноимённые села) и все нужные id.
//
// Отдельная история с Москвой, Санкт-Петербургом и Севастополем: в справочнике
// они заведены РЕГИОНАМИ, а городами внутри них лежат внутригородские округа
// («муниципальный округ Вешняки») и поселения ТиНАО. Поэтому на «Москва» поиск
// городов отдавал посёлки, а самой Москвы в списке не было. Ручка `places`
// добавляет такие города-регионы первой строкой (`isRegion`), улицы у них
// ищутся по всему региону, а округ подставляется из выбранной улицы.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/api_service.dart';

/// Одна подсказка адреса: что показать человеку и что отправить на сервер.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.name,
    this.subtitle,
    this.regionId,
    this.mainRegionId,
    this.mainRegionName,
    this.cityId,
    this.isRegion = false,
  });

  /// Номер в справочнике: города для населённого пункта, улицы для улицы.
  /// У города-региона (Москва) это номер региона, не города.
  final int id;

  /// Москва, Санкт-Петербург, Севастополь: в справочнике это регион, а не
  /// город. Улицы у него ищутся по региону, город берётся из улицы.
  final bool isRegion;

  /// Название как в справочнике: «г Мариуполь», «ул Ленина».
  final String name;

  /// Пояснение под названием: область, район. Одноимённых сёл много.
  final String? subtitle;

  /// Подрегион и область населённого пункта: уходят в адрес объявления.
  final int? regionId;
  final int? mainRegionId;

  /// Название области без района: его показываем как область в профиле.
  final String? mainRegionName;

  /// Город улицы: по нему проверяем, что улица из выбранного города.
  final int? cityId;

  @override
  bool operator ==(Object other) =>
      other is PlaceSuggestion && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class PlacesService {
  /// Сколько подсказок просить у сервера и его предел.
  static const int _size = 40;
  static const int _maxSize = 50;

  /// Населённые пункты по всей стране: города, посёлки, села, а также
  /// города-регионы (Москва, Санкт-Петербург, Севастополь) первой строкой.
  ///
  /// Область не спрашиваем и в фильтры не кладём: смысл правки в том, чтобы
  /// человек ввёл своё название и сразу увидел нужную строку.
  /// [withRegions] false отдаёт только настоящие города: так нужно там, где
  /// дальше по коду идёт одно лишь название населённого пункта (фильтры).
  static Future<List<PlaceSuggestion>> cities(
    String query, {
    bool withRegions = true,
  }) async {
    return await _places(query, withRegions: withRegions) ?? const [];
  }

  /// То же, но отличает пустую выдачу от неудачного запроса: null означает
  /// «не дозвонились». Это важно там, где по ответу принимается решение, а не
  /// просто рисуется список.
  static Future<List<PlaceSuggestion>?> _places(
    String query, {
    bool withRegions = true,
  }) async {
    final text = query.trim();

    if (text.length < 2) return const [];

    try {
      final response = await ApiService.get(
        '/addresses/places'
        '?q=${Uri.encodeQueryComponent(text)}&size=$_size',
      );

      final data = response['data'];

      if (data is! List) return [];

      final regions = <PlaceSuggestion>[];
      final cities = <PlaceSuggestion>[];

      for (final row in data) {
        if (row is! Map) continue;

        final id = (row['id'] as num?)?.toInt();
        final name = '${row['name'] ?? ''}'.trim();

        if (id == null || name.isEmpty) continue;

        final isRegion = row['place_type'] == 'region';

        if (isRegion && !withRegions) continue;

        final mainRegionId = (row['main_region_id'] as num?)?.toInt();

        final place = PlaceSuggestion(
          id: id,
          name: name,
          subtitle: _text(row['subtitle']),
          regionId: (row['region_id'] as num?)?.toInt(),
          mainRegionId: mainRegionId,
          // Только область: район («Аксайский р-н») в поле «область» не нужен.
          // У города-региона область это он сам.
          mainRegionName: isRegion ? name : _firstPart(row['subtitle']),
          isRegion: isRegion,
        );

        (isRegion ? regions : cities).add(place);
      }

      _sortByQuery(cities, text);

      // Города-регионы всегда наверху: человек, набравший «Москва», ищет
      // прежде всего саму Москву, а не поселение Внуковское.
      return [...regions, ...cities];
    } catch (e) {
      log.d('❌ PlacesService.cities: $e');
      return null;
    }
  }

  /// Улицы города-региона: ищем по всей Москве, город (округ) берём из улицы.
  static Future<List<PlaceSuggestion>> streetsInRegion(
    String query,
    int regionId,
  ) async {
    final text = query.trim();

    if (text.length < 2) return [];

    try {
      var response = await AddressService.searchAddresses(
        query: text,
        types: const ['street'],
        filters: {'main_region_id': regionId},
        size: _maxSize,
      );

      // У города-региона подрегиона нет, и в индексе он может лежать как
      // region, а не main_region. Если по области пусто, спрашиваем по району.
      if (response.data.isEmpty) {
        response = await AddressService.searchAddresses(
          query: text,
          types: const ['street'],
          filters: {'region_id': regionId},
          size: _maxSize,
        );
      }

      final byId = <int, PlaceSuggestion>{};

      for (final row in response.data) {
        final street = row.street;
        if (street == null) continue;

        byId.putIfAbsent(
          street.id,
          () => PlaceSuggestion(
            id: street.id,
            name: street.name,
            // Под улицей показываем округ: одноимённых улиц в Москве много.
            subtitle: row.city?.name ?? row.district?.name,
            regionId: row.region?.id,
            mainRegionId: row.main_region?.id ?? regionId,
            cityId: row.city?.id,
          ),
        );
      }

      final list = byId.values.toList();
      _sortByQuery(list, text);

      return list;
    } catch (e) {
      log.d('❌ PlacesService.streetsInRegion: $e');
      return [];
    }
  }

  /// Город-регион ли это: Москва, Санкт-Петербург, Севастополь.
  ///
  /// Спрашиваем сервер по названию региона. Нужно при открытии объявления на
  /// редактирование: в адресе там лежит внутригородской округ, а показать в
  /// поле надо саму Москву.
  /// null означает, что выяснить не удалось: сервер не ответил. Отличать это
  /// от «нет» обязательно — иначе одна неудачная попытка снимала бы у человека
  /// уже выбранную Москву.
  static Future<bool?> isRegionCity(int regionId, String regionName) async {
    final found = await _places(regionName);

    if (found == null) return null;

    return found.any((item) => item.isRegion && item.id == regionId);
  }

  static String? _text(dynamic value) {
    final text = '${value ?? ''}'.trim();

    return text.isEmpty ? null : text;
  }

  /// «Ростовская область, Аксайский р-н» → «Ростовская область».
  static String? _firstPart(dynamic value) {
    final text = _text(value);

    return text == null ? null : text.split(',').first.trim();
  }

  /// Улицы внутри выбранного населённого пункта.
  static Future<List<PlaceSuggestion>> streets(String query, int cityId) async {
    final text = query.trim();

    if (text.length < 2) return [];

    try {
      final response = await AddressService.searchAddresses(
        query: text,
        types: const ['street'],
        filters: {'city_id': cityId},
        size: _size,
      );

      final byId = <int, PlaceSuggestion>{};

      for (final row in response.data) {
        final street = row.street;
        if (street == null) continue;
        // Сервер фильтрует по городу, но подстрахуемся: в выдаче попадались
        // улицы соседних населённых пунктов с тем же названием.
        if (row.city != null && row.city!.id != cityId) continue;

        byId.putIfAbsent(
          street.id,
          () => PlaceSuggestion(
            id: street.id,
            name: street.name,
            subtitle: row.district?.name,
            regionId: row.region?.id,
            mainRegionId: row.main_region?.id,
            cityId: row.city?.id ?? cityId,
          ),
        );
      }

      final list = byId.values.toList();
      _sortByQuery(list, text);

      return list;
    } catch (e) {
      log.d('❌ PlacesService.streets: $e');
      return [];
    }
  }

  /// Дома на выбранной улице. Номер дома короткий («1А»), по нему сервер
  /// искать не умеет, поэтому спрашиваем по названию улицы с фильтром по ней.
  static Future<List<PlaceSuggestion>> buildings(
    String streetName,
    int streetId,
  ) async {
    final text = streetName.trim();

    if (text.length < 2) return [];

    try {
      final response = await AddressService.searchAddresses(
        query: text,
        types: const ['building'],
        filters: {'street_id': streetId},
        // Домов на улице бывает много, просим максимум, который отдаёт сервер.
        size: _maxSize,
      );

      final byId = <int, PlaceSuggestion>{};

      for (final row in response.data) {
        final building = row.building;
        if (building == null) continue;
        if (row.street != null && row.street!.id != streetId) continue;

        byId.putIfAbsent(
          building.id,
          () => PlaceSuggestion(id: building.id, name: building.name),
        );
      }

      return byId.values.toList();
    } catch (e) {
      log.d('❌ PlacesService.buildings: $e');
      return [];
    }
  }

  /// Название без типа: «г Мариуполь» → «мариуполь». Нужно и для сортировки,
  /// и чтобы человек находил посёлок, не набирая «пгт».
  static String cleanName(String name) {
    final withoutType = name.trim().replaceFirst(
      RegExp(
        r'^(г|гор|город|с|село|пгт|пос|п|посёлок|поселок|д|деревня|х|хутор|ст|станица|сл|слобода|рп|р\.п|снт|тер|ул|улица|пр-кт|пр-т|пер|б-р|ш|наб|мкр|кв-л|туп|проезд|аллея)\.?\s+',
        caseSensitive: false,
      ),
      '',
    );

    return withoutType.trim().toLowerCase();
  }

  /// Точное совпадение вперёд, потом начало названия, потом всё остальное.
  static void _sortByQuery(List<PlaceSuggestion> list, String query) {
    final needle = cleanName(query);

    int rank(PlaceSuggestion item) {
      final name = cleanName(item.name);

      if (name == needle) return 0;
      if (name.startsWith(needle)) return 1;

      return 2;
    }

    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));

      return byRank != 0 ? byRank : cleanName(a.name).compareTo(cleanName(b.name));
    });
  }
}

// Подсказки населённых пунктов и улиц (упрощение адреса, 24.09.2026).
//
// Зачем. Раньше адрес заполнялся по цепочке «область → город → улица → дом»,
// и человек застревал на первом шаге: Москва в справочнике лежит внутри
// области, посёлок свой в списке не находился, и объявление не публиковалось
// совсем. Теперь спрашиваем сразу населённый пункт, поиском по всей стране, а
// область сервер выводит из города сам.
//
//   GET /v1/addresses/search?q=мариу&types[0]=city&size=30
//   GET /v1/addresses/search?q=лен&types[0]=street&filters[city_id]=123
//
// Наружу отдаём готовые подсказки: название, пояснение (область и район, чтобы
// отличать одноимённые села) и все нужные id.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/address_service.dart';

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
  });

  /// Номер в справочнике: города для населённого пункта, улицы для улицы.
  final int id;

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

  /// Населённые пункты по всей стране: города, посёлки, села.
  ///
  /// Область не спрашиваем и в фильтры не кладём: смысл правки в том, чтобы
  /// человек ввёл своё название и сразу увидел нужную строку.
  static Future<List<PlaceSuggestion>> cities(String query) async {
    final text = query.trim();

    if (text.length < 2) return [];

    try {
      final response = await AddressService.searchAddresses(
        query: text,
        types: const ['city'],
        size: _size,
      );

      final byId = <int, PlaceSuggestion>{};

      for (final row in response.data) {
        final city = row.city;
        if (city == null) continue;

        byId.putIfAbsent(
          city.id,
          () => PlaceSuggestion(
            id: city.id,
            name: city.name,
            subtitle: _placeSubtitle(row.main_region?.name, row.region?.name),
            regionId: row.region?.id,
            mainRegionId: row.main_region?.id,
            // Только область: район («Аксайский р-н») в поле «область» не нужен.
            mainRegionName: row.main_region?.name,
          ),
        );
      }

      final list = byId.values.toList();
      _sortByQuery(list, text);

      return list;
    } catch (e) {
      log.d('❌ PlacesService.cities: $e');
      return [];
    }
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

  /// «Ростовская область, Аксайский р-н» под названием села.
  static String? _placeSubtitle(String? mainRegion, String? region) {
    final parts = <String>[];

    for (final part in [mainRegion, region]) {
      final text = (part ?? '').trim();
      if (text.isEmpty) continue;
      if (parts.contains(text)) continue;
      parts.add(text);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }
}

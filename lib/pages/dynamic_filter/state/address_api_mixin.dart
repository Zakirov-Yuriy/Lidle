part of '../dynamic_filter.dart';

/// Миксин, инкапсулирующий работу с API адресов.
///
/// Отвечает за:
///   * загрузку списка регионов ([_loadRegions]);
///   * поиск городов и улиц по пользовательскому запросу
///     ([_searchCitiesAPI], [_searchStreetsAPI]) — для диалогов выбора;
///   * автозагрузку списков городов / улиц / домов по выбранному
///     родителю ([_loadCitiesForSelectedRegion] и т.д.) — используется
///     при автозаполнении формы.
///
/// Миксин хранит у себя только «сырые» списки адресов и кеши
/// «имя → ID». Поля выбранных значений (`_selectedRegion`,
/// `_selectedCityId` и т.д.) остаются в основном State — миксин
/// только читает их через `this`.
///
/// Подключается через `part of '../dynamic_filter.dart';` и
/// `with _AddressApiMixin` в объявлении State. Приватность имён
/// (underscore) сохраняется благодаря одной library scope с главным
/// файлом.
mixin _AddressApiMixin on State<DynamicFilter> {
  // ===== Выбранные пользователем значения =====
  //
  // Эти поля физически живут в миксине (а не в State), потому что
  // Dart mixin system не позволяет обращаться к полям подкласса
  // (`_DynamicFilterState`) из методов миксина — он видит только
  // членов тип-ограничения `on State<DynamicFilter>`. Поэтому всё,
  // что нужно методам миксина, объявляется здесь же.
  //
  // Из State/UI они по-прежнему доступны напрямую благодаря
  // `with _AddressApiMixin`.

  /// Имя выбранного региона (Set для совместимости с диалогом выбора).
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedBuilding = {};

  /// ID выбранных значений — уходят в API при публикации.
  int? _selectedRegionId;
  int? _selectedCityId;
  int? _selectedStreetId;
  // ignore: unused_field
  int? _selectedBuildingId;

  /// Регион выбранного города (`region_id` = подрегион,
  /// `main_region_id` = основной регион). Используются при поиске
  /// улиц через API, чтобы сузить результаты.
  int? _selectedCityRegionId;
  int? _selectedCityMainRegionId;

  // ===== Контроллеры адресных полей =====
  //
  // Живут в миксине, потому что методы миксина (например
  // [_selectAddressFromParts]) пишут в них напрямую. Dispose вызывается
  // из State (см. `_DynamicFilterState.dispose`) — благодаря `with` он
  // видит эти поля по имени.

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();

  // ===== Списки результатов API (для UI/автозаполнения) =====

  /// Все регионы страны, полученные от API.
  List<Map<String, dynamic>> _regions = [];

  /// Города — обычно загружаются после выбора региона.
  List<Map<String, dynamic>> _cities = [];

  /// Улицы — после выбора города.
  List<Map<String, dynamic>> _streets = [];

  /// Дома — после выбора улицы.
  List<Map<String, dynamic>> _buildings = [];

  // ===== Кеши «имя → ID» для восстановления выбора =====

  /// Cache результатов поиска городов: `имя города → id`.
  /// Используется для получения ID города по имени, выбранному в
  /// [CitySelectionDialog].
  Map<String, int> _lastCitiesSearchResults = {};

  /// Cache региональной информации для каждого города:
  /// `имя города → {region_id, main_region_id}`.
  /// Нужен, чтобы правильно искать улицы после выбора города.
  Map<String, Map<String, int>> _lastCitiesRegionResults = {};

  /// Cache результатов поиска улиц: `имя улицы → id`.
  Map<String, int> _lastStreetsSearchResults = {};

  /// Cache subregion ID для каждой улицы: `имя улицы → region_id`.
  /// Используется при подаче объявления, чтобы отправить корректный
  /// region_id для адреса.
  Map<String, int?> _lastStreetsSubregionResults = {};

  // ===== Методы =====

  /// Очищает строку адреса от префиксов типа "г.", "ул.", "пр-кт", "м.о." и т.д.
  /// Используется при выборе адреса по имени (при редактировании объявления),
  /// чтобы передать в API чистое название без префикса.
  ///
  /// Примеры:
  ///   "г. Донецк" → "Донецк"
  ///   "ул. Бутовская" → "Бутовская"
  ///   "пр-кт Строителей" → "Строителей"
  ///   "Донецкая Народная респ." → "Донецкая Народная"
  static String _cleanAddressPart(String input) {
    final prefixRegex = RegExp(
      r'^(г\.|город|с\.|село|пгт\.|пгт|пос\.|посёлок|поселок|д\.|деревня|ст\.|станица|ул\.|улица|пр-кт|пр-т|пр\.|проспект|пер\.|переулок|б-р|бульвар|пл\.|площадь|ш\.|шос\.|шоссе|дорога|тракт|наб\.|набер\.|набережная|мкр\.|м-н|микрорайон|кв-л|квартал|туп\.|тупик|проезд|аллея|спуск|въезд|съезд|м\.о\.)\s+',
      caseSensitive: false,
    );
    final suffixRegex = RegExp(
      r'\s+(респ\.|область|обл\.|край|АО|округ)$',
      caseSensitive: false,
    );
    var cleaned = input.trim().replaceFirst(prefixRegex, '');
    cleaned = cleaned.replaceFirst(suffixRegex, '');
    return cleaned.trim();
  }

  /// Загружает список регионов с API при инициализации формы.
  /// При ошибке повторяет попытку через 3 секунды.
  Future<void> _loadRegions() async {
    try {
      final token = TokenService.currentToken;

      // Если нет токена, регионы все равно можно загрузить (API поддерживает без токена)
      // но если есть токен, используем его
      if (token == null) {
        log.d('ℹ️ _loadRegions: Токен не найден, загружаем без токена');
      }

      final regions = await ApiService.getRegions(token: token);

      // Логируем все регионы с их ID
      log.d('📍 Загруженные регионы:');
      for (final region in regions) {
        final regionId = region['id'];
        final regionName = region['name'];
        log.d('   ID $regionId: $regionName');
      }

      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
      log.d('✅ Loaded ${regions.length} regions');
    } catch (e) {
      log.d('❌ Error loading regions: $e');
      // Retry after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  /// 🆕 Поиск городов через API по пользовательскому вводу (для диалога).
  /// Вызывается из [CitySelectionDialog], когда пользователь вводит текст.
  ///
  /// Требования:
  ///   * выбран `_selectedRegionId`;
  ///   * длина запроса ≥ 3 символов (ограничение API).
  Future<List<String>> _searchCitiesAPI(String query) async {
    if (_selectedRegionId == null) {
      log.d('🔍 _searchCitiesAPI: regionId not selected');
      return [];
    }

    if (query.trim().length < 3) {
      log.d('🔍 _searchCitiesAPI: query too short: "$query" (need 3+)');
      return [];
    }

    try {
      final token = TokenService.currentToken;
      final cleanQuery = query.trim();

      log.d('');
      log.d('🔍 _searchCitiesAPI called:');
      log.d('   - query: "$cleanQuery"');
      log.d('   - regionId: $_selectedRegionId');

      final response = await AddressService.searchAddresses(
        query: cleanQuery,
        token: token,
        types: ['city'],
        filters: {'main_region_id': _selectedRegionId},
      );

      log.d('   - API вернула ${response.data.length} результатов');

      // Очищаем предыдущие результаты и сохраняем новые.
      _lastCitiesSearchResults.clear();
      _lastCitiesRegionResults.clear();

      final cities = <String>[];
      int filtered = 0;

      for (final result in response.data) {
        final cityName = result.city?.name ?? 'N/A';
        final cityId = result.city?.id;
        final resultRegionId = result.main_region?.id;
        final resultSubregionId = result.region?.id;

        log.d(
          '   [API] $cityName [id=$cityId, main_region.id=$resultRegionId, region.id=$resultSubregionId]',
        );

        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
          final cityName = result.city!.name;
          _lastCitiesSearchResults[cityName] = result.city!.id;
          _lastCitiesRegionResults[cityName] = {
            'region_id': result.region?.id ?? 0,
            'main_region_id': result.main_region?.id ?? 0,
          };
          // В список показа добавляем только если имя содержит запрос.
          if (cityName.toLowerCase().contains(cleanQuery.toLowerCase())) {
            cities.add(cityName);
            log.d('       ✅ СОХРАНЕНО в кеш и список');
          } else {
            log.d('       📦 СОХРАНЕНО в кеш (не совпало с запросом)');
          }
        } else {
          filtered++;
          if (result.main_region?.id != _selectedRegionId) {
            log.d(
              '       ❌ Фильтр: main_region.id=$resultRegionId != $_selectedRegionId',
            );
          } else {
            log.d('       ❌ Фильтр: city is null');
          }
        }
      }

      log.d(
        '   ✅ Возвращаем ${cities.length} городов (отфильтровано: $filtered)',
      );
      log.d('   📦 Cache содержит: ${_lastCitiesSearchResults.keys.toList()}');
      log.d('   📦 Region info cache: ${_lastCitiesRegionResults.keys.toList()}');
      log.d('');
      return cities;
    } catch (e) {
      log.d('   ❌ Error searching cities: $e');
      return [];
    }
  }

  /// 🆕 Поиск улиц через API по пользовательскому вводу (для диалога).
  /// Вызывается из [StreetSelectionDialog], когда пользователь вводит текст.
  ///
  /// В фильтры добавляются `region_id` и `main_region_id` выбранного
  /// города (из кеша [_lastCitiesRegionResults]), чтобы сузить поиск.
  Future<List<String>> _searchStreetsAPI(String query) async {
    if (_selectedCityId == null) {
      log.d('🔍 _searchStreetsAPI: cityId not selected');
      return [];
    }

    if (query.trim().length < 3) {
      log.d('🔍 _searchStreetsAPI: query too short: "$query" (need 3+)');
      return [];
    }

    try {
      final token = TokenService.currentToken;
      final cleanQuery = query.trim();

      log.d('');
      log.d('🔍 _searchStreetsAPI called:');
      log.d('   - query: "$cleanQuery"');
      log.d('   - cityId: $_selectedCityId');
      log.d('   - cityRegionId: $_selectedCityRegionId');
      log.d('   - cityMainRegionId: $_selectedCityMainRegionId');

      // Строим фильтры с информацией о регионе города.
      final filters = <String, dynamic>{'city_id': _selectedCityId};
      if (_selectedCityRegionId != null && _selectedCityRegionId != 0) {
        filters['region_id'] = _selectedCityRegionId;
      }
      if (_selectedCityMainRegionId != null && _selectedCityMainRegionId != 0) {
        filters['main_region_id'] = _selectedCityMainRegionId;
      }

      final response = await AddressService.searchAddresses(
        query: cleanQuery,
        token: token,
        types: ['street'],
        filters: filters,
      );

      log.d('   - API вернула ${response.data.length} результатов');

      _lastStreetsSearchResults.clear();

      final streets = <String>[];
      int filtered = 0;

      for (final result in response.data) {
        final streetName = result.street?.name ?? 'N/A';
        final streetId = result.street?.id;
        final resultCityId = result.city?.id;

        log.d('   [API] $streetName [id=$streetId, city.id=$resultCityId]');

        if (result.city?.id == _selectedCityId && result.street != null) {
          streets.add(result.street!.name);
          _lastStreetsSearchResults[result.street!.name] = result.street!.id;
          _lastStreetsSubregionResults[result.street!.name] = result.region?.id;
          log.d(
            '       ✅ СОХРАНЕНО в кеш (street.id=${result.street!.id}, region.id=${result.region?.id})',
          );
        } else {
          filtered++;
          if (result.city?.id != _selectedCityId) {
            log.d('       ❌ Фильтр: city.id=$resultCityId != $_selectedCityId');
          } else {
            log.d('       ❌ Фильтр: street is null');
          }
        }
      }

      log.d(
        '   ✅ Возвращаем ${streets.length} улиц (отфильтровано: $filtered)',
      );
      log.d('   📦 Cache содержит: ${_lastStreetsSearchResults.keys.toList()}');
      log.d('');
      return streets;
    } catch (e) {
      log.d('   ❌ Error searching streets: $e');
      return [];
    }
  }

  /// Загружает список городов для выбранного региона (автозаполнение).
  Future<void> _loadCitiesForSelectedRegion() async {
    if (_selectedRegionId == null) return;

    // Используем очищенное имя региона как поисковый запрос.
    // Если оно слишком короткое, не делаем запрос вообще: пользователь
    // получит пустой список в диалоге и сам введёт нужный город,
    // а API сработает через _searchCitiesAPI при вводе.
    String? searchQuery;
    if (_selectedRegion.isNotEmpty) {
      final cleaned = _cleanAddressPart(_selectedRegion.first);
      if (cleaned.length >= 3) {
        searchQuery = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
      }
    }

    if (searchQuery == null) {
      log.d('ℹ️ _loadCitiesForSelectedRegion: имя региона короткое, пропускаем предзагрузку');
      return;
    }

    try {
      final token = TokenService.currentToken;

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['city'],
        filters: _selectedRegionId != null
            ? {'main_region_id': _selectedRegionId}
            : null,
      );

      log.d(
        '🔍 [AUTO] Загрузка для области ID: $_selectedRegionId, query: "$searchQuery"',
      );
      log.d('📋 [AUTO] API вернул ${response.data.length} результатов');

      final uniqueCities = <String, int>{};
      int filtered = 0;
      for (final result in response.data) {
        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
          _lastCitiesSearchResults[result.city!.name] = result.city!.id;
          _lastCitiesRegionResults[result.city!.name] = {
            'region_id': result.region?.id ?? 0,
            'main_region_id': result.main_region?.id ?? 0,
          };
          log.d('   ✅ ${result.city!.name}');
        } else if (result.city != null) {
          filtered++;
          log.d(
            '   ❌ ${result.city!.name} - main_region.id=${result.main_region?.id}, ожидаем $_selectedRegionId',
          );
        }
      }

      if (mounted) {
        // 🔧 BUGFIX: Используем Future.microtask() чтобы гарантировать что фокус будет убран
        // ПОСЛЕ того как UI перестроится
        Future.microtask(() {
          FocusManager.instance.primaryFocus?.unfocus();
        });
        setState(() {
          _cities = uniqueCities.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
          _cities.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
        });
        log.d('✅ Auto-loaded ${_cities.length} cities');
      }
    } catch (e) {
      log.d('❌ Error auto-loading cities: $e');
    }
  }

  /// Загружает улицы для выбранного города (предзагрузка списка для диалога,
  /// по аналогии с [_loadCitiesForSelectedRegion]). Раньше метод не вызывался
  /// (был помечен unused_element), из-за чего диалог улиц открывался пустым.
  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;

    // Используем очищенное имя города как поисковый запрос.
    // Если оно короче 3 символов, ничего не делаем (диалог сам подгрузит через API).
    String? searchQuery;
    if (_selectedCity.isNotEmpty) {
      final cleaned = _cleanAddressPart(_selectedCity.first);
      if (cleaned.length >= 3) {
        searchQuery = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
      }
    }

    if (searchQuery == null) {
      log.d('ℹ️ _loadStreetsForSelectedCity: имя города короткое, пропускаем предзагрузку');
      return;
    }

    try {
      final token = TokenService.currentToken;

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['street'],
        filters: _selectedCityId != null ? {'city_id': _selectedCityId} : null,
      );

      // ВАЖНО: сохраняем не только id улицы, но и её подрегион (region.id) и
      // главный регион (main_region.id). Подрегион нужен на публикации как
      // address.region_id (бэкенд требует parent = выбранный регион). Раньше
      // предзагрузка клала только {name, id}, поэтому при выборе улицы из
      // предзагруженного списка подрегион терялся и на публикацию уходил
      // главный регион — валидация address.region_id/address.city_id падала.
      final Map<String, Map<String, dynamic>> uniqueStreets = {};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          final name = result.street!.name;
          uniqueStreets[name] = {
            'name': name,
            'id': result.street!.id,
            'region_id': result.region?.id,
            'main_region_id': result.main_region?.id,
          };
          // Кеши, из которых берутся street_id и подрегион при выборе улицы
          // (те же, что заполняет _searchStreetsAPI при ручном поиске).
          _lastStreetsSearchResults[name] = result.street!.id;
          _lastStreetsSubregionResults[name] = result.region?.id;
          log.d('   + $name (region.id=${result.region?.id})');
        } else if (result.street != null) {
          log.d(
            '   ❌ ${result.street!.name} - city.id=${result.city?.id}, ожидаем $_selectedCityId',
          );
        }
      }

      if (mounted) {
        // 🔧 BUGFIX: Используем Future.microtask() чтобы гарантировать что фокус будет убран
        // ПОСЛЕ того как UI перестроится
        Future.microtask(() {
          FocusManager.instance.primaryFocus?.unfocus();
        });
        setState(() {
          _streets = uniqueStreets.values.toList();
        });
        log.d('✅ Auto-loaded ${_streets.length} streets');
      }
    } catch (e) {
      log.d('❌ Error auto-loading streets: $e');
    }
  }

  /// Загружает номера домов для выбранной улицы.
  Future<void> _loadBuildingsForSelectedStreet() async {
    if (_selectedStreetId == null) return;

    // Используем очищенное имя улицы как поисковый запрос.
    // Если короче 3 символов, не делаем запрос.
    String? searchQuery;
    if (_selectedStreet.isNotEmpty) {
      final cleaned = _cleanAddressPart(_selectedStreet.first);
      if (cleaned.length >= 3) {
        searchQuery = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
      }
    }

    if (searchQuery == null) {
      log.d('ℹ️ _loadBuildingsForSelectedStreet: имя улицы короткое, пропускаем');
      return;
    }

    try {
      final token = TokenService.currentToken;

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['building'],
        filters: _selectedStreetId != null
            ? {'street_id': _selectedStreetId}
            : null,
      );

      final uniqueBuildings = <String, int>{};
      for (final result in response.data) {
        if (result.street?.id == _selectedStreetId && result.building != null) {
          uniqueBuildings[result.building!.name] = result.building!.id;
          log.d('   + ${result.building!.name}');
        } else if (result.building != null) {
          log.d(
            '   ❌ ${result.building!.name} - street.id=${result.street?.id}, ожидаем $_selectedStreetId',
          );
        }
      }

      if (mounted) {
        // 🔧 BUGFIX: Используем Future.microtask() чтобы гарантировать что фокус будет убран
        // ПОСЛЕ того как UI перестроится
        Future.microtask(() {
          FocusManager.instance.primaryFocus?.unfocus();
        });
        setState(() {
          _buildings = uniqueBuildings.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        log.d('✅ Auto-loaded ${_buildings.length} buildings');
      }
    } catch (e) {
      log.d('❌ Error auto-loading buildings: $e');
    }
  }

  // ===== Сеттеры адреса по имени =====
  //
  // Методы принимают имя (название региона/города/улицы/дома)
  // и асинхронно выбирают соответствующую запись, обновляя
  // `_selected*` поля. Используются в режиме редактирования
  // объявления, когда адрес приходит строкой.

  /// 🔧 Заполняет все поля адреса при редактировании объявления
  /// Парсит адрес и заполняет контроллеры: область, город, улица, номер дома
  /// Также вызывает загрузку данных для каждого уровня иерархии
  Future<void> _populateAddressFieldsFromEdit(String fullAddress) async {
    try {
      if (fullAddress.isEmpty) {
        log.d('⚠️ Empty address provided');
        return;
      }

      log.d('🔍 Populating address fields from: $fullAddress');

      // Адрес может быть в разных форматах:
      // 1. "г. Донецк, ул. Донецкая" - 2 части (город, улица)
      // 2. "г. Донецк, ул. Донецкая, д. 70" - 3 части (город, улица, дом)
      // 3. "Донецкая Народная респ., г. Донецк, ул. Донецкая, д. 70" - 4 части (область, город, улица, дом)

      final parts = fullAddress.split(',').map((p) => p.trim()).toList();

      log.d('   Parts: $parts (${parts.length} parts)');

      if (parts.isEmpty) return;

      // ✅ ВАРИАНТ 1: 4 части - полный адрес с областью
      if (parts.length == 4) {
        log.d('   📍 Full address with region detected');
        await _selectAddressFromParts(
          region: parts[0],
          city: parts[1],
          street: parts[2],
          building: parts[3],
        );
      }
      // ✅ ВАРИАНТ 2: 3 части - адрес с номером дома (без области)
      else if (parts.length == 3) {
        log.d('   📍 Address with building detected');
        await _selectAddressFromParts(
          city: parts[0],
          street: parts[1],
          building: parts[2],
        );
      }
      // ✅ ВАРИАНТ 3: 2 части - только город и улица
      else if (parts.length == 2) {
        log.d('   📍 Address without building detected');
        await _selectAddressFromParts(city: parts[0], street: parts[1]);
      }

      log.d('✅ Address fields populated successfully');
    } catch (e) {
      log.d('❌ Error populating address fields: $e');
    }
  }

  /// 🔧 Заполняет поля адреса при редактировании из СТРУКТУРНОГО ответа бэка.
  ///
  /// Бэк отдаёт в /adverts/{id} блок advert_address с id + name по уровням:
  ///   {
  ///     "main_region": {"id": .., "name": ..}, // область (верхняя выпадашка)
  ///     "region":      {"id": .., "name": ..}, // подрегион (address.region_id)
  ///     "city":        {"id": .., "name": ..},
  ///     "district":    {"id": .., "name": ..},
  ///     "street":      {"id": .., "name": ..},
  ///     "building":    {"id": .., "name": ..}
  ///   }
  ///
  /// В отличие от разбора строки, тут сразу известны id, поэтому выпадашки
  /// заполняются надёжно (в т.ч. область) и корректно уходят при сохранении.
  Future<void> _populateAddressFromStructured(
    Map<String, dynamic> address,
  ) async {
    try {
      Map<String, dynamic>? part(String key) {
        final v = address[key];
        return v is Map<String, dynamic> ? v : null;
      }

      final mainRegion = part('main_region') ?? part('region');
      final subRegion = part('region');
      final city = part('city');
      final street = part('street');
      final building = part('building');

      if (mainRegion == null && city == null && street == null) {
        log.d('ℹ️ Структурный адрес пуст, нечего заполнять');
        return;
      }

      setState(() {
        // Область. Верхняя выпадашка тянет главные регионы (parent_id = null),
        // поэтому кладём именно главный регион.
        if (mainRegion != null) {
          final name = mainRegion['name'] as String? ?? '';
          _selectedRegion
            ..clear()
            ..add(name);
          _selectedRegionId = mainRegion['id'] as int?;
          _selectedCityMainRegionId = mainRegion['id'] as int?;
          _regionController.text = name;
        }

        // Подрегион города — бэку он нужен при сохранении как address.region_id.
        if (subRegion != null) {
          _selectedCityRegionId = subRegion['id'] as int?;
        }

        // Город.
        if (city != null) {
          final name = city['name'] as String? ?? '';
          final id = city['id'] as int?;
          _selectedCity
            ..clear()
            ..add(name);
          _selectedCityId = id;
          _cityController.text = name;
          if (id != null) {
            _cities = <Map<String, dynamic>>[
              {'name': name, 'id': id},
            ];
            _lastCitiesSearchResults[name] = id;
            _lastCitiesRegionResults[name] = {
              'region_id': _selectedCityRegionId ?? 0,
              'main_region_id': _selectedCityMainRegionId ?? 0,
            };
          }
        }

        // Улица.
        if (street != null) {
          final name = street['name'] as String? ?? '';
          final id = street['id'] as int?;
          _selectedStreet
            ..clear()
            ..add(name);
          _selectedStreetId = id;
          _streetController.text = name;
          if (id != null) {
            _streets = <Map<String, dynamic>>[
              {'name': name, 'id': id},
            ];
            _lastStreetsSearchResults[name] = id;
            _lastStreetsSubregionResults[name] = _selectedCityRegionId;
          }
        }

        // Номер дома (необязательный).
        if (building != null) {
          final name = building['name']?.toString() ?? '';
          final id = building['id'] as int?;
          if (name.isNotEmpty) {
            _selectedBuilding
              ..clear()
              ..add(name);
            _buildingController.text = name;
            _selectedBuildingId = id;
            if (id != null) {
              _buildings = <Map<String, dynamic>>[
                {'name': name, 'id': id},
              ];
            }
          }
        }
      });

      log.d(
        '✅ Структурный адрес заполнен: '
        'region=$_selectedRegion($_selectedRegionId), '
        'city=$_selectedCity($_selectedCityId), '
        'street=$_selectedStreet($_selectedStreetId), '
        'building=$_selectedBuilding($_selectedBuildingId)',
      );
    } catch (e) {
      log.d('❌ Ошибка заполнения структурного адреса: $e');
    }
  }

  /// 🔧 Выбирает адрес из составляющих частей
  /// Заполняет контроллеры и _selected* переменные
  Future<void> _selectAddressFromParts({
    String? region,
    String? city,
    String? street,
    String? building,
  }) async {
    try {
      // ✅ ЗАПОЛНЯЕМ КОНТРОЛЛЕРЫ СРАЗУ
      if (region != null && region.isNotEmpty) {
        setState(() => _regionController.text = region);
        log.d('   ✅ Set _regionController = "$region"');
      }

      if (city != null && city.isNotEmpty) {
        setState(() => _cityController.text = city);
        log.d('   ✅ Set _cityController = "$city"');
      }

      if (street != null && street.isNotEmpty) {
        setState(() => _streetController.text = street);
        log.d('   ✅ Set _streetController = "$street"');
      }

      if (building != null && building.isNotEmpty) {
        setState(() => _buildingController.text = building);
        log.d('   ✅ Set _buildingController = "$building"');
      }

      // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ РЕГИОН (если он указан)
      if (region != null && region.isNotEmpty) {
        await _selectRegionByName(region);

        // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ ГОРОД (если регион выбран)
        if (city != null && city.isNotEmpty && _selectedRegionId != null) {
          await _selectCityByName(city);

          // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ УЛИЦУ (если город выбран)
          if (street != null && street.isNotEmpty && _selectedCityId != null) {
            await _selectStreetByName(street);

            // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ НОМ ЕР ДОМА (если улица выбрана)
            if (building != null &&
                building.isNotEmpty &&
                _selectedStreetId != null) {
              await _selectBuildingByName(building);
            }
          }
        }
      }
    } catch (e) {
      log.d('❌ Error selecting address from parts: $e');
    }
  }

  /// 🔍 Ищет и выбирает регион по названию
  Future<void> _selectRegionByName(String regionName) async {
    try {
      final token = TokenService.currentToken;

      // Загружаем все регионы если их нет. Используем эндпоинт /addresses/regions
      // (тот же, что и при инициализации формы) вместо поиска по букве "р" через
      // searchAddresses, который теперь не работает с короткими запросами.
      if (_regions.isEmpty) {
        final regionsResponse = await ApiService.getRegions(token: token);
        setState(() {
          _regions = regionsResponse;
        });
        log.d('   📦 Loaded ${_regions.length} regions from /addresses/regions');
      }

      // Ищем регион по названию (точное совпадение или частичное)
      final region = _regions.firstWhere(
        (r) => (r['name'] as String).toLowerCase() == regionName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _regions.firstWhere(
            (r) => (r['name'] as String).toLowerCase().contains(
              regionName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (region.isNotEmpty) {
        setState(() {
          _selectedRegionId = region['id'] as int;
          _selectedRegion.clear();
          _selectedRegion.add(region['name'] as String);
        });
        log.d('   ✅ Selected region: ${region['name']} (ID: ${region['id']})');
      } else {
        log.d('   ⚠️ Region "$regionName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting region: $e');
    }
  }

  /// 🔍 Ищет и выбирает город по названию
  Future<void> _selectCityByName(String cityName) async {
    try {
      if (_selectedRegionId == null) {
        log.d('   ⚠️ Cannot select city: no region selected');
        return;
      }

      final token = TokenService.currentToken;

      // Используем очищенное имя города как query (без префикса "г." и т.п.).
      // Если очищенное имя короче 3 символов, берём оригинал, а если и он короче 3,
      // не делаем запрос вообще.
      final cleaned = _cleanAddressPart(cityName);
      final queryStr = cleaned.length >= 3 ? cleaned : cityName.trim();
      if (queryStr.length < 3) {
        log.d('   ⚠️ Имя города слишком короткое для API: "$cityName"');
        return;
      }

      final response = await AddressService.searchAddresses(
        query: queryStr,
        token: token,
        types: ['city'],
        filters: {
          'main_region_id': _selectedRegionId, // Только города этого региона
        },
      );

      final uniqueCities = <String, int>{};
      for (final result in response.data) {
        if (result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
          // Сохраняем в кеш с информацией о регионе, чтобы потом улицы
          // искались с корректным region_id/main_region_id.
          _lastCitiesSearchResults[result.city!.name] = result.city!.id;
          _lastCitiesRegionResults[result.city!.name] = {
            'region_id': result.region?.id ?? 0,
            'main_region_id': result.main_region?.id ?? 0,
          };
        }
      }

      setState(() {
        _cities = uniqueCities.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();

        log.d(
          '✅ Loaded ${_cities.length} cities for region ID $_selectedRegionId (query: "$queryStr")',
        );
      });

      // Ищем город по названию
      final city = _cities.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == cityName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по подстроке
          return _cities.firstWhere(
            (c) => (c['name'] as String).toLowerCase().contains(
              cleaned.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (city.isNotEmpty) {
        final foundCityName = city['name'] as String;
        setState(() {
          _selectedCityId = city['id'] as int;
          _selectedCity.clear();
          _selectedCity.add(foundCityName);
          // 🆕 Сохраняем информацию о регионе города из кеша
          if (_lastCitiesRegionResults.containsKey(foundCityName)) {
            final regionInfo = _lastCitiesRegionResults[foundCityName];
            _selectedCityRegionId = regionInfo?['region_id'];
            _selectedCityMainRegionId = regionInfo?['main_region_id'];
            log.d('   ℹ️ Loaded region info: region_id=$_selectedCityRegionId, main_region_id=$_selectedCityMainRegionId');
          }
        });
        log.d('   ✅ Selected city: $foundCityName (ID: ${city['id']})');
      } else {
        log.d('   ⚠️ City "$cityName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting city: $e');
    }
  }

  /// 🔍 Ищет и выбирает улицу по названию
  Future<void> _selectStreetByName(String streetName) async {
    try {
      if (_selectedCityId == null) {
        log.d('   ⚠️ Cannot select street: no city selected');
        return;
      }

      final token = TokenService.currentToken;

      // 🆕 Строим фильтры с информацией о регионе города
      final filters = <String, dynamic>{'city_id': _selectedCityId};
      if (_selectedCityRegionId != null && _selectedCityRegionId != 0) {
        filters['region_id'] = _selectedCityRegionId;
      }
      if (_selectedCityMainRegionId != null && _selectedCityMainRegionId != 0) {
        filters['main_region_id'] = _selectedCityMainRegionId;
      }

      // Используем очищенное имя улицы как query (без префикса "ул.", "пр-кт" и т.д.).
      // Если очищенное имя короче 3 символов, пробуем оригинал.
      final cleaned = _cleanAddressPart(streetName);
      final queryStr = cleaned.length >= 3 ? cleaned : streetName.trim();
      if (queryStr.length < 3) {
        log.d('   ⚠️ Имя улицы слишком короткое для API: "$streetName"');
        return;
      }

      // Загружаем улицы для выбранного города с информацией о регионе
      final response = await AddressService.searchAddresses(
        query: queryStr,
        token: token,
        types: ['street'],
        filters: filters,
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
          // Сохраняем в кеш subregion для последующего использования при публикации
          _lastStreetsSearchResults[result.street!.name] = result.street!.id;
          _lastStreetsSubregionResults[result.street!.name] = result.region?.id;
        }
      }

      setState(() {
        _streets = uniqueStreets.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();
      });
      log.d('   📦 Loaded ${_streets.length} streets for city (query: "$queryStr")');

      // Ищем улицу по названию
      final street = _streets.firstWhere(
        (s) => (s['name'] as String).toLowerCase() == streetName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по подстроке (очищенного имени)
          return _streets.firstWhere(
            (s) => (s['name'] as String).toLowerCase().contains(
              cleaned.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (street.isNotEmpty) {
        setState(() {
          _selectedStreetId = street['id'] as int;
          _selectedStreet.clear();
          _selectedStreet.add(street['name'] as String);
        });
        log.d('   ✅ Selected street: ${street['name']} (ID: ${street['id']})');
      } else {
        log.d('   ⚠️ Street "$streetName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting street: $e');
    }
  }

  /// 🔍 Ищет и выбирает номер дома по названию
  Future<void> _selectBuildingByName(String buildingName) async {
    try {
      if (_selectedStreetId == null) {
        log.d('   ⚠️ Cannot select building: no street selected');
        return;
      }

      final token = TokenService.currentToken;

      // Для домов q обычно короткий ("1А", "5"), не пройдёт по 3 символам.
      // Используем имя улицы как query (плюс фильтр street_id), а локально
      // ищем нужный дом по имени.
      String? queryStr;
      if (_selectedStreet.isNotEmpty) {
        final cleaned = _cleanAddressPart(_selectedStreet.first);
        if (cleaned.length >= 3) queryStr = cleaned;
      }
      // Fallback: само имя дома, если оно достаточно длинное
      if (queryStr == null && buildingName.trim().length >= 3) {
        queryStr = buildingName.trim();
      }
      if (queryStr == null) {
        log.d('   ⚠️ Не могу подобрать query для поиска домов (улица и имя короткие)');
        return;
      }

      // Загружаем номера домов для выбранной улицы
      final response = await AddressService.searchAddresses(
        query: queryStr,
        token: token,
        types: ['building'],
        filters: _selectedStreetId != null
            ? {'street_id': _selectedStreetId}
            : null,
      );

      final uniqueBuildings = <String, int>{};
      for (final result in response.data) {
        if (result.street?.id == _selectedStreetId && result.building != null) {
          uniqueBuildings[result.building!.name] = result.building!.id;
        }
      }

      setState(() {
        _buildings = uniqueBuildings.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();
      });
      log.d('   📦 Loaded ${_buildings.length} buildings for street (query: "$queryStr")');

      // Ищем номер дома по названию
      final building = _buildings.firstWhere(
        (b) =>
            (b['name'] as String).toLowerCase() == buildingName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по подстроке
          return _buildings.firstWhere(
            (b) => (b['name'] as String).toLowerCase().contains(
              buildingName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (building.isNotEmpty) {
        setState(() {
          _selectedBuilding.clear();
          _selectedBuilding.add(building['name'] as String);
        });
        log.d('   ✅ Selected building: ${building['name']}');
      } else {
        log.d('   ⚠️ Building "$buildingName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting building: $e');
    }
  }

  /// 🔧 Парсит адрес из API при редактировании объявления
  /// API возвращает адрес строкой: "г. Донецк, ул. Бутовская" или "г. Донецк, ул. Бутовская, 1А"
  /// Нужно распарсить и выделить номер дома в _selectedBuilding
  void _parseAddressForEdit(String fullAddress) {
    try {
      if (fullAddress.isEmpty) return;

      // Адрес имеет формат: "город, улица[, номер_дома]"
      // Примеры:
      // "г. Донецк, ул. Бутовская" - БЕЗ номера дома
      // "г. Донецк, пр-кт 301-й Донецкой дивизии, 1А" - С номером дома

      final parts = fullAddress.split(',').map((p) => p.trim()).toList();

      log.d('🔍 Parsing address: $fullAddress');
      log.d('   Parts: $parts (${parts.length} parts)');

      if (parts.isEmpty) return;

      // Логика парсинга:
      // [0] = город (г. Донецк)
      // [1] = улица (ул. Бутовская)
      // [2] = номер дома (1А) - ОПЦИОНАЛЬНО

      String? buildingNumber;

      if (parts.length >= 3) {
        // Если 3+ части, последняя - это номер дома
        buildingNumber = parts.last;
        log.d('   ✅ Found building number: "$buildingNumber" (last part)');
      } else if (parts.length == 2) {
        // Только 2 части - нет номера дома в API
        log.d('   ⚠️ No building number in address (only 2 parts)');
        // Это нормально, может быть просто "г. Донецк, ул. Бутовская"
      }

      // Заполняем _selectedBuilding если найден номер дома
      if (buildingNumber != null && buildingNumber.isNotEmpty) {
        setState(() {
          _selectedBuilding.clear();
          _selectedBuilding.add(
            buildingNumber!,
          ); // ! для force unwrap, так как проверили что not null
        });
        log.d('   ✅ Set _selectedBuilding = {"$buildingNumber"}');
      } else {
        // Если номера дома нет, делаем _selectedBuilding пустым
        setState(() {
          _selectedBuilding.clear();
        });
        log.d('   ℹ️ _selectedBuilding cleared (no building number)');
      }
    } catch (e) {
      log.d('❌ Error parsing address: $e');
    }
  }
}
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

    try {
      final token = TokenService.currentToken;
      String searchQuery = 'по'; // Default search term

      if (_selectedRegion.isNotEmpty) {
        final regionName = _selectedRegion.first;
        if (regionName.length >= 3) {
          searchQuery = regionName.length > 50
              ? regionName.substring(0, 50)
              : regionName;
        } else {
          searchQuery = regionName + '   '; // Pad to at least 3
        }
      }

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

  /// Загружает улицы для выбранного города при автозаполнении.
  // ignore: unused_element
  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;

    try {
      final token = TokenService.currentToken;
      String searchQuery = 'у';

      if (_selectedCity.isNotEmpty) {
        final cityName = _selectedCity.first;
        if (cityName.length >= 3) {
          searchQuery = cityName.length > 50
              ? cityName.substring(0, 50)
              : cityName;
        } else {
          searchQuery = cityName + '   ';
        }
      }

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['street'],
        filters: _selectedCityId != null ? {'city_id': _selectedCityId} : null,
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
          log.d('   + ${result.street!.name}');
        } else if (result.street != null) {
          log.d(
            '   ❌ ${result.street!.name} - city.id=${result.city?.id}, ожидаем $_selectedCityId',
          );
        }
      }

      if (mounted) {
        setState(() {
          _streets = uniqueStreets.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
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

    try {
      final token = TokenService.currentToken;
      String searchQuery = '1'; // Default search term

      if (_selectedStreet.isNotEmpty) {
        final streetName = _selectedStreet.first;
        if (streetName.length >= 3) {
          searchQuery = streetName.length > 50
              ? streetName.substring(0, 50)
              : streetName;
        } else {
          searchQuery = streetName + '   ';
        }
      }

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

  /// 🔍 找ет и выбирает регион по названию
  Future<void> _selectRegionByName(String regionName) async {
    try {
      final token = TokenService.currentToken;

      // Загружаем все регионы если их нет
      if (_regions.isEmpty) {
        final response = await AddressService.searchAddresses(
          query: 'р',
          token: token,
          types: ['region'],
        );

        final uniqueRegions = <String, int>{};
        for (final result in response.data) {
          if (result.main_region != null) {
            uniqueRegions[result.main_region!.name] = result.main_region!.id;
          }
        }

        setState(() {
          _regions = uniqueRegions.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        log.d('   📦 Loaded ${_regions.length} regions from API');
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

      // Загружаем города для выбранного региона
      // Получить ВСЕ города для выбранного региона
      final response = await AddressService.searchAddresses(
        query: '   ', // Минимум 3 символа для API (пустой поиск)
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
        }
      }

      setState(() {
        _cities = uniqueCities.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();

        log.d(
          '✅ Loaded ${_cities.length} cities for region ID $_selectedRegionId',
        );
      });

      // Ищем город по названию
      final city = _cities.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == cityName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _cities.firstWhere(
            (c) => (c['name'] as String).toLowerCase().contains(
              cityName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (city.isNotEmpty) {
        final cityName = city['name'] as String;
        setState(() {
          _selectedCityId = city['id'] as int;
          _selectedCity.clear();
          _selectedCity.add(cityName);
          // 🆕 Сохраняем информацию о регионе города из кеша
          if (_lastCitiesRegionResults.containsKey(cityName)) {
            final regionInfo = _lastCitiesRegionResults[cityName];
            _selectedCityRegionId = regionInfo?['region_id'];
            _selectedCityMainRegionId = regionInfo?['main_region_id'];
            log.d('   ℹ️ Loaded region info: region_id=$_selectedCityRegionId, main_region_id=$_selectedCityMainRegionId');
          }
        });
        log.d('   ✅ Selected city: $cityName (ID: ${city['id']})');
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

      // Загружаем улицы для выбранного города с информацией о регионе
      final response = await AddressService.searchAddresses(
        query: 'у',
        token: token,
        types: ['street'],
        filters: filters,
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
        }
      }

      setState(() {
        _streets = uniqueStreets.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();
      });
      log.d('   📦 Loaded ${_streets.length} streets for city');

      // Ищем улицу по названию
      final street = _streets.firstWhere(
        (s) => (s['name'] as String).toLowerCase() == streetName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _streets.firstWhere(
            (s) => (s['name'] as String).toLowerCase().contains(
              streetName.toLowerCase(),
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

      // Загружаем номера домов для выбранной улицы
      final response = await AddressService.searchAddresses(
        query: '1',
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
      log.d('   📦 Loaded ${_buildings.length} buildings for street');

      // Ищем номер дома по названию
      final building = _buildings.firstWhere(
        (b) =>
            (b['name'] as String).toLowerCase() == buildingName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
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

/// Диалог выбора ОДНОГО города с загрузкой городов с API
/// Используется в intermediate_filters_screen
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/token_service.dart';

class _LetterHeader {
  final String letter;
  _LetterHeader(this.letter);
}

class CitySelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options; // Передаются просто для обратной совместимости
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;
  // 🆕 Callback функция для поиска через API (опционально)
  final Future<List<String>> Function(String query)? onSearchQuery;

  const CitySelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.onSearchQuery,
  });

  @override
  State<CitySelectionDialog> createState() => _CitySelectionDialogState();
}

class _CitySelectionDialogState extends State<CitySelectionDialog> {
  late Set<String> _currentSelectedOptions;
  late List<dynamic> _displayOptions;
  late List<String> _allCities;
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  Map<String, int> _citiesIdCache = {};
  
  // Для кеширования
  static const String _cacheBoxName = 'cities_cache';
  static const String _citiesCacheKey = 'all_cities';
  static const String _citiesTimestampKey = 'cities_timestamp';
  static const Duration _cacheExpiration = Duration(days: 7);

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _displayOptions = [];
    _allCities = [];
    
    _searchController.addListener(_onSearchChanged);
    
    // Если переданы опции - используем их, иначе загружаем с API
    if (widget.options.isNotEmpty) {
      _loadAllCitiesFromOptions();
    } else {
      _loadAllCities();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Загрузить города из переданных опций (для быстрой загрузки)
  void _loadAllCitiesFromOptions() {
    List<String> cities = List<String>.from(widget.options);
    cities.sort();
    
    if (mounted) {
      setState(() {
        _allCities = cities;
        _isLoading = false;
      });
      _buildDisplayOptions(_allCities, searchQuery: '');
    }
  }

  /// Сохранить города в кеш (Hive)
  Future<void> _saveCitiesToCache(List<String> cities) async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      await box.put(_citiesCacheKey, cities);
      await box.put(_citiesTimestampKey, DateTime.now().toIso8601String());
      log.d('💾 Города сохранены в кеш (${cities.length} городов)');
    } catch (e) {
      log.d('❌ Ошибка сохранения кеша: $e');
    }
  }

  /// Загрузить города из кеша (Hive)
  Future<List<String>?> _loadCitiesFromCache() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final cachedCities = box.get(_citiesCacheKey) as List<dynamic>?;
      final timestamp = box.get(_citiesTimestampKey) as String?;

      if (cachedCities == null || timestamp == null) {
        log.d('📦 Кеш пуст');
        return null;
      }

      final cacheDate = DateTime.parse(timestamp);
      final isExpired = DateTime.now().difference(cacheDate) > _cacheExpiration;

      if (isExpired) {
        log.d('⏰ Кеш устарел (${_cacheExpiration.inDays} дней)');
        return null;
      }

      final cities = cachedCities.cast<String>();
      log.d('✅ Города загружены из кеша (${cities.length} городов)');
      return cities;
    } catch (e) {
      log.d('❌ Ошибка загрузки кеша: $e');
      return null;
    }
  }

  /// Загрузить города с API (с кешированием)
  Future<void> _loadAllCities() async {
    final cachedCities = await _loadCitiesFromCache();
    if (cachedCities != null && cachedCities.isNotEmpty) {
      log.d('📥 Используем кешированные города (${cachedCities.length})');
      
      if (mounted) {
        setState(() {
          _allCities = cachedCities;
          _isLoading = false;
          _isLoadingMore = true;
          log.d('   ✅ Показаны города из кеша');
        });
        _buildDisplayOptions(_allCities, searchQuery: '');
      }

      _updateCitiesInBackground();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = TokenService.currentToken;

      log.d('📥 Загружаем города с API');

      final citiesMap = <int, String>{};
      final fastSearchQueries = ['Москва', 'Санкт', 'Новосибирск'];
      
      log.d('   ⚡ Быстрая загрузка (${fastSearchQueries.length} поисков)');
      for (final query in fastSearchQueries) {
        try {
          log.d('      🔍 Поиск: "$query"');
          final response = await AddressService.searchAddresses(
            query: query,
            token: token,
            types: ['city'],
          );

          for (final result in response.data) {
            if (result.type == 'city' && result.city != null) {
              final cityName = result.city!.name;
              final cityId = result.city!.id;
              if (_isCityNameValid(cityName)) {
                citiesMap[cityId] = cityName;
              }
            }
          }
        } catch (e) {
          log.d('      ⚠️  Ошибка: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allCities = citiesMap.values.toList();
          _citiesIdCache = {
            for (final entry in citiesMap.entries) entry.value: entry.key
          };
          _isLoading = false;
          _isLoadingMore = true;
          log.d('   ✅ Показаны первые ${_allCities.length} городов');
        });
        _buildDisplayOptions(_allCities, searchQuery: '');
      }

      _updateCitiesInBackground();
    } catch (e) {
      log.d('   ❌ Ошибка загрузки городов: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Ошибка загрузки городов: $e';
        });
      }
    }
  }

  /// Обновить города в фоне
  Future<void> _updateCitiesInBackground() async {
    try {
      final token = TokenService.currentToken;
      log.d('🔄 Обновляем города в фоне...');

      final citiesMap = <int, String>{};
      for (final city in _allCities) {
        final id = _citiesIdCache[city];
        if (id != null) {
          citiesMap[id] = city;
        }
      }

      final slowSearchQueries = ['град', 'пгт', 'село', 'краснодар', 'казань'];
      
      for (final query in slowSearchQueries) {
        try {
          final response = await AddressService.searchAddresses(
            query: query,
            token: token,
            types: ['city'],
          );

          int addedCount = 0;
          for (final result in response.data) {
            if (result.type == 'city' && result.city != null) {
              final cityName = result.city!.name;
              final cityId = result.city!.id;
              if (_isCityNameValid(cityName) && !citiesMap.containsKey(cityId)) {
                citiesMap[cityId] = cityName;
                addedCount++;
              }
            }
          }

          if (addedCount > 0 && mounted) {
            setState(() {
              _allCities = citiesMap.values.toList();
              _citiesIdCache = {
                for (final entry in citiesMap.entries) entry.value: entry.key
              };
              log.d('🔄 Добавлено $addedCount новых городов (всего ${_allCities.length})');
            });
            _buildDisplayOptions(_allCities, searchQuery: '');
          }
        } catch (e) {
          log.d('⚠️  Ошибка: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          log.d('✅ Обновление завершено. Всего ${_allCities.length} городов');
        });
      }

      await _saveCitiesToCache(_allCities);
    } catch (e) {
      log.d('❌ Ошибка обновления: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Проверить валидное ли имя города
  bool _isCityNameValid(String cityName) {
    final name = cityName.toLowerCase();
    
    if (name.contains('ул.') || 
        name.contains(' ул ') ||
        name.contains('улица') ||
        name.contains('переулок') ||
        name.contains('проспект') ||
        name.contains('пр.') ||
        name.contains('пер.') ||
        name.contains('бульвар') ||
        name.contains('бул.') ||
        name.contains('дом ') ||
        name.contains('д.')) {
      return false;
    }
    
    if (name.contains('днп') ||
        name.contains('деревня') ||
        name.contains('дер.') ||
        name.contains('хутор') ||
        name.contains('лесництво') ||
        name.contains('учебное')) {
      return false;
    }
    
    return true;
  }

  /// Обработчик изменения текста поиска с debounce
  void _onSearchChanged() {
    _debounceTimer?.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
      });
      _buildDisplayOptions(_allCities, searchQuery: '');
      return;
    }

    if (query.length < 3) {
      log.d('🔍 Локальный поиск: "$query"');
      _filterCitiesLocal(query);
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // 🆕 Если передан callback для поиска, используем его
      if (widget.onSearchQuery != null) {
        await _searchCitiesViaCallback(query);
      } else {
        // Fallback на локальный поиск
        await _searchCitiesAPI(query);
      }
    });
  }

  /// 🆕 Поиск городов через переданный callback
  Future<void> _searchCitiesViaCallback(String query) async {
    try {
      final searchResults = <String, int>{};
      
      // Вызываем переданный callback для поиска
      final cityNames = await widget.onSearchQuery!(query);
      
      log.d('🔍 Поиск API (via callback): "$query"');
      log.d('   ✅ Callback вернул ${cityNames.length} городов');

      // Нужно получить ID для каждого города
      // Если callback вернул имена городов, нам нужно их ID
      // Мы можем использовать локальный кеш или другой механизм
      
      final token = TokenService.currentToken;
      
      // Получаем полные данные городов через API
      try {
        final response = await AddressService.searchAddresses(
          query: query,
          token: token,
          types: ['city'],
        );

        for (final result in response.data) {
          if (result.type == 'city' && result.city != null) {
            final cityName = result.city!.name;
            final cityId = result.city!.id;
            
            if (_isCityNameValid(cityName) && cityNames.contains(cityName)) {
              searchResults[cityName] = cityId;
              _citiesIdCache[cityName] = cityId;
            }
          }
        }
      } catch (e) {
        log.d('   ❌ Ошибка получения полных данных: $e');
      }

      final citiesList = searchResults.keys.toList();
      log.d('   ✅ Найдено ${citiesList.length} городов');

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _buildDisplayOptions(citiesList, searchQuery: query);
      }
    } catch (e) {
      log.d('   ❌ Ошибка поиска (callback): $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Поиск городов через API
  Future<void> _searchCitiesAPI(String query) async {
    try {
      final token = TokenService.currentToken;
      log.d('🔍 Поиск API: "$query"');
      
      final searchResults = <String, int>{};

      try {
        final response = await AddressService.searchAddresses(
          query: query,
          token: token,
          types: ['city'],
        );

        for (final result in response.data) {
          if (result.type == 'city' && result.city != null) {
            final cityName = result.city!.name;
            final cityId = result.city!.id;
            
            if (_isCityNameValid(cityName)) {
              searchResults[cityName] = cityId;
              _citiesIdCache[cityName] = cityId;
            }
          }
        }
      } catch (e) {
        log.d('   ❌ Ошибка: $e');
      }

      final citiesList = searchResults.keys.toList();
      log.d('   ✅ Найдено ${citiesList.length} городов');

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _buildDisplayOptions(citiesList, searchQuery: query);
      }
    } catch (e) {
      log.d('   ❌ Ошибка поиска: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Локальный фильтр городов
  void _filterCitiesLocal(String query) {
    final queryLower = query.toLowerCase();
    
    final filtered = _allCities.where((city) {
      return city.toLowerCase().contains(queryLower);
    }).toList();

    _buildDisplayOptions(filtered, searchQuery: query);
  }

  /// Получить чистое название города
  String _getCleanCityName(String fullCityName) {
    String cleanName = fullCityName
        .replaceAll(RegExp(r'^г\.\s+'), '')
        .replaceAll(RegExp(r'^м\.о\.\s+'), '')
        .replaceAll(RegExp(r'^с\.\s+'), '')
        .replaceAll(RegExp(r'^г\.о\.\s+'), '')
        .replaceAll(RegExp(r'^пгт\.\s+'), '')
        .replaceAll(RegExp(r'^пс\.\s+'), '')
        .replaceAll(RegExp(r'^п\.\s+'), '')
        .replaceAll(RegExp(r'^р\.п\.\s+'), '')
        .trim();
    return cleanName.isNotEmpty ? cleanName : fullCityName;
  }

  /// Построить отображаемый список с разделением по буквам
  void _buildDisplayOptions(List<String> cities, {String searchQuery = ''}) {
    List<dynamic> newDisplayOptions = [];
    String? currentLetter;
    
    String? exactMatch;
    if (searchQuery.isNotEmpty) {
      final searchLower = searchQuery.toLowerCase();
      for (final city in cities) {
        final cleanName = _getCleanCityName(city).toLowerCase();
        if (cleanName == searchLower) {
          exactMatch = city;
          break;
        }
      }
    }

    if (exactMatch != null) {
      newDisplayOptions.add(exactMatch);
      newDisplayOptions.add(_LetterHeader(''));
    }

    final sortedCities = List<String>.from(cities);
    if (exactMatch != null) {
      sortedCities.removeWhere((city) => city == exactMatch);
    }

    sortedCities.sort((a, b) {
      final cleanA = _getCleanCityName(a).toLowerCase();
      final cleanB = _getCleanCityName(b).toLowerCase();
      return cleanA.compareTo(cleanB);
    });

    for (var city in sortedCities) {
      final cleanName = _getCleanCityName(city);
      final firstLetter = cleanName[0].toUpperCase();

      if (firstLetter != currentLetter) {
        newDisplayOptions.add(_LetterHeader(firstLetter));
        currentLetter = firstLetter;
      }
      newDisplayOptions.add(city);
    }

    setState(() {
      _displayOptions = newDisplayOptions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minHeight: 300,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 🔘 КНОПКА ЗАКРЫТИЯ
            IconButton(
              icon: const Icon(Icons.close, color: textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),

            // 📌 ЗАГОЛОВОК
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 23),

            // 🔍 ПОЛЕ ПОИСКА
            TextField(
              controller: _searchController,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск',
                hintStyle: const TextStyle(color: textSecondary),
                filled: true,
                fillColor: formBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(activeIconColor),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ScrollbarTheme(
                          data: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all<Color?>(
                              const Color(0xFF3C3C3C),
                            ),
                            trackColor: WidgetStateProperty.all<Color?>(
                              const Color.fromARGB(255, 43, 23, 26),
                            ),
                          ),
                          child: Scrollbar(
                            child: _displayOptions.isEmpty
                                ? Center(
                                    child: Text(
                                      _searchController.text.isEmpty
                                          ? 'Загрузка городов...'
                                          : 'Город не найден',
                                      style: const TextStyle(
                                        color: textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _displayOptions.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == _displayOptions.length && _isLoadingMore) {
                                        return Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    activeIconColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Загружаю ещё города...',
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      final item = _displayOptions[index];
                                      if (item is _LetterHeader) {
                                        if (item.letter.isEmpty) {
                                          return const SizedBox(height: 12);
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Text(
                                            item.letter,
                                            style: const TextStyle(
                                              color: textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      } else {
                                        final option = item as String;
                                        final isSelected = _currentSelectedOptions.contains(option);
                                        return GestureDetector(
                                          onTap: () {
                                            _currentSelectedOptions.clear();
                                            _currentSelectedOptions.add(option);
                                            widget.onSelectionChanged(_currentSelectedOptions);
                                            Navigator.of(context).pop();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? activeIconColor
                                                    : textPrimary,
                                                fontSize: 16,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

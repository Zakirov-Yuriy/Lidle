/// Диалог выбора города для экрана фильтров с загрузкой городов из ВСЕ РЕГИОНОВ с API
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

class CitiesFilterDialog extends StatefulWidget {
  final String title;
  final Set<String> selectedCities;
  final Function(Set<String>) onSelectionChanged;

  const CitiesFilterDialog({
    super.key,
    required this.title,
    required this.selectedCities,
    required this.onSelectionChanged,
  });

  @override
  State<CitiesFilterDialog> createState() => _CitiesFilterDialogState();
}

class _CitiesFilterDialogState extends State<CitiesFilterDialog> {
  late Set<String> _currentSelectedCities;
  late List<dynamic> _displayCities;
  late List<String> _allCities;
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;  // Загрузка остальных городов в фоне
  String? _errorMessage;
  
  Map<String, int> _citiesIdCache = {};
  
  // Для кеширования
  static const String _cacheBoxName = 'cities_cache';
  static const String _citiesCacheKey = 'all_cities';
  static const String _citiesTimestampKey = 'cities_timestamp';
  static const Duration _cacheExpiration = Duration(days: 7);  // Кеш актуален 7 дней

  @override
  void initState() {
    super.initState();
    _currentSelectedCities = Set<String>.from(widget.selectedCities);
    _displayCities = [];
    _allCities = [];
    
    _searchController.addListener(_onSearchChanged);
    _loadAllCities();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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

      // Проверяем не устарел ли кеш
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

  /// Очистить кеш городов
  Future<void> _clearCitiesCache() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      await box.delete(_citiesCacheKey);
      await box.delete(_citiesTimestampKey);
      log.d('🗑️  Кеш городов очищен');
    } catch (e) {
      log.d('❌ Ошибка очистки кеша: $e');
    }
  }

  /// Загрузить города с API (с пагинацией и кешированием)
  /// 1. Сначала пытается загрузить из кеша
  /// 2. Если кеш есть - показывает его сразу
  /// 3. Обновляет кеш в фоне со свежими данными
  Future<void> _loadAllCities() async {
    // ✅ ЭТАП 0: Проверяем кеш
    final cachedCities = await _loadCitiesFromCache();
    if (cachedCities != null && cachedCities.isNotEmpty) {
      log.d('');
      log.d('📥 _loadAllCities: используем кешированные города (${cachedCities.length})');
      
      if (mounted) {
        setState(() {
          _allCities = cachedCities;
          _isLoading = false;
          _isLoadingMore = true;  // Обновляем в фоне
          log.d('   ✅ Показаны города из кеша');
        });
        _buildDisplayCities(_allCities, searchQuery: '');
      }

      // Обновляем кеш в фоне (не блокируя UI)
      _updateCitiesInBackground();
      return;
    }

    // Кеша нет, загружаем с нуля
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = TokenService.currentToken;

      log.d('');
      log.d('📥 _loadAllCities: загружаем города из ВСЕХ РЕГИОНОВ с API');

      // ✅ ЭТАП 1: Быстрая загрузка первых городов (популярные города)
      final citiesMap = <int, String>{};
      final fastSearchQueries = ['Москва', 'Санкт', 'Новосибирск'];  // Быстрые поиски
      
      log.d('   ⚡ ЭТАП 1: Быстрая загрузка (${fastSearchQueries.length} поисков)');
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

      // ✅ Показываем первые города пользователю (снимаем экран загрузки)
      if (mounted) {
        setState(() {
          _allCities = citiesMap.values.toList();
          _citiesIdCache = {
            for (final entry in citiesMap.entries) entry.value: entry.key
          };
          _isLoading = false;  // 🔓 Показываем UI с первыми городами
          _isLoadingMore = true;  // Но продолжаем загружать в фоне
          log.d('   ✅ Показаны первые ${_allCities.length} городов');
        });
        _buildDisplayCities(_allCities, searchQuery: '');
      }

      // ✅ ЭТАП 2: Продолжаем загружать в фоне (другие города)
      final slowSearchQueries = ['град', 'пгт', 'село', 'краснодар', 'казань'];
      log.d('   🔄 ЭТАП 2: Фоновая загрузка (${slowSearchQueries.length} поисков)');
      
      for (final query in slowSearchQueries) {
        try {
          log.d('      🔍 Поиск: "$query"');
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

          // Обновляем список при добавлении новых городов
          if (addedCount > 0 && mounted) {
            setState(() {
              _allCities = citiesMap.values.toList();
              _citiesIdCache = {
                for (final entry in citiesMap.entries) entry.value: entry.key
              };
              log.d('      ✅ Добавлено $addedCount новых городов (всего ${_allCities.length})');
            });
            _buildDisplayCities(_allCities, searchQuery: '');
          }
        } catch (e) {
          log.d('      ⚠️  Ошибка: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          log.d('   ✅ Загрузка завершена. Всего ${_allCities.length} городов');
        });
      }

      // ✅ Сохраняем в кеш
      await _saveCitiesToCache(_allCities);
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

  /// Обновить города в фоне (не блокируя UI)
  Future<void> _updateCitiesInBackground() async {
    try {
      final token = TokenService.currentToken;

      log.d('🔄 Обновляем города в фоне...');

      final citiesMap = <int, String>{};
      // Сохраняем старые города
      for (final city in _allCities) {
        final id = _citiesIdCache[city];
        if (id != null) {
          citiesMap[id] = city;
        }
      }

      // Обновляем со свежими данными
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
            _buildDisplayCities(_allCities, searchQuery: '');
          }
        } catch (e) {
          log.d('⚠️  Ошибка фонового обновления: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          log.d('✅ Фоновое обновление завершено. Всего ${_allCities.length} городов');
        });
      }

      // Сохраняем обновленные данные в кеш
      await _saveCitiesToCache(_allCities);
    } catch (e) {
      log.d('❌ Ошибка фонового обновления: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
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
      _buildDisplayCities(_allCities, searchQuery: '');
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
      await _searchCitiesAPI(query);
    });
  }

  /// Поиск городов через API (по всем регионам)
  Future<void> _searchCitiesAPI(String query) async {
    try {
      final token = TokenService.currentToken;

      log.d('');
      log.d('🔍 _searchCitiesAPI: "$query" (все регионы)');
      
      final searchResults = <String, int>{};

      try {
        final response = await AddressService.searchAddresses(
          query: query,
          token: token,
          types: ['city'],
          // Без фильтра - ищем по ВСЕ регионам
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
        log.d('   ❌ Ошибка API поиска: $e');
      }

      final citiesList = searchResults.keys.toList();
      log.d('   ✅ Найдено ${citiesList.length} городов');

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _buildDisplayCities(citiesList, searchQuery: query);
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

    _buildDisplayCities(filtered, searchQuery: query);
  }

  /// Получить чистое название города (без префиксов типа г., м.о., с.)
  String _getCleanCityName(String fullCityName) {
    String cleanName = fullCityName
        .replaceAll(RegExp(r'^г\.\s+'), '')          // г. Москва → Москва
        .replaceAll(RegExp(r'^м\.о\.\s+'), '')       // м.о. → 
        .replaceAll(RegExp(r'^с\.\s+'), '')          // с. → 
        .replaceAll(RegExp(r'^г\.о\.\s+'), '')       // г.о. → 
        .replaceAll(RegExp(r'^пгт\.\s+'), '')        // пгт. → 
        .replaceAll(RegExp(r'^пс\.\s+'), '')         // пс. → 
        .replaceAll(RegExp(r'^п\.\s+'), '')          // п. → 
        .replaceAll(RegExp(r'^р\.п\.\s+'), '')       // р.п. → 
        .trim();
    return cleanName.isNotEmpty ? cleanName : fullCityName;
  }

  /// Построить отображаемый список с разделением по буквам
  /// Если есть точный поиск (searchQuery не пуст), показывает его в верху
  void _buildDisplayCities(List<String> cities, {String searchQuery = ''}) {
    List<dynamic> newDisplayCities = [];
    String? currentLetter;
    
    // Проверяем точный результат поиска
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

    // Если нашли точный результат - показываем его первым БЕЗ буквы-разделителя
    if (exactMatch != null) {
      newDisplayCities.add(exactMatch);
      newDisplayCities.add(_LetterHeader(''));  // Пустой разделитель для визуального разделения
    }

    // Остальные города выдокими по буквам
    final sortedCities = List<String>.from(cities);
    // Исключаем точный результат из остального списка
    if (exactMatch != null) {
      sortedCities.removeWhere((city) => city == exactMatch);
    }

    sortedCities.sort((a, b) {
      final cleanA = _getCleanCityName(a).toLowerCase();
      final cleanB = _getCleanCityName(b).toLowerCase();
      return cleanA.compareTo(cleanB);
    });

    for (var city in sortedCities) {
      // Определяем первую букву по ЧИСТОМУ названию
      final cleanName = _getCleanCityName(city);
      final firstLetter = cleanName[0].toUpperCase();

      if (firstLetter != currentLetter) {
        newDisplayCities.add(_LetterHeader(firstLetter));
        currentLetter = firstLetter;
      }
      newDisplayCities.add(city);
    }

    setState(() {
      _displayCities = newDisplayCities;
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
            // 🔘 КНОПКА ЗАКРЫТИЯ (справа сверху)
            IconButton(
              icon: const Icon(Icons.close, color: textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),

            // 📌 ЗАГОЛОВОК (по центру)
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
                            child: _displayCities.isEmpty
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
                                    itemCount: _displayCities.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // Если это последний элемент и идёт подгрузка в фоне
                                      if (index == _displayCities.length && _isLoadingMore) {
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

                                      final item = _displayCities[index];
                                      if (item is _LetterHeader) {
                                        // Не показывать пустой разделитель
                                        if (item.letter.isEmpty) {
                                          return const SizedBox(height: 12);
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
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
                                        final city = item as String;
                                        final isSelected =
                                            _currentSelectedCities.contains(
                                          city,
                                        );
                                        return GestureDetector(
                                          onTap: () {
                                            _currentSelectedCities.clear();
                                            _currentSelectedCities.add(city);
                                            widget.onSelectionChanged(
                                                _currentSelectedCities);
                                            Navigator.of(context).pop();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0),
                                            child: Text(
                                              city,
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

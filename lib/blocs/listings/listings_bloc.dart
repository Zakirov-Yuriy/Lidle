import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'listings_event.dart';
import 'listings_state.dart';
import '../../models/home_models.dart' as home;
import '../../models/advert_model.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../../services/loading_timer_service.dart';
import '../../services/api_request_queue.dart';
import '../../core/cache/cache_service.dart';
import '../../core/cache/cache_keys.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/data/mock/mock_listings.dart';

/// Bloc для управления состоянием данных объявлений.
/// Обрабатывает события загрузки, поиска и фильтрации объявлений.
class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  /// Задержка имитации поиска (в миллисекундах).
  static const int _searchDelayMs = 300;

  /// Задержка имитации фильтрации (в миллисекундах).
  static const int _filterDelayMs = 200;

  /// Флаг для отслеживания, уже ли загружены данные.
  /// Предотвращает ненужные повторные загрузки.
  bool _isInitialLoadComplete = false;

  /// Флаг для защиты от дублирования pull-to-refresh запросов.
  bool _isLoadingListings = false;

  /// Флаг для защиты от параллельного выполнения фазы 2 загрузки.
  /// Предотвращает множественные параллельные запросы при rate limiting.
  bool _isPhase2Loading = false;

  /// Время последнего успешного обновления через pull-to-refresh.
  DateTime? _lastRefreshTime;

  /// Минимальное время между refresh операциями (10 секунд).
  /// 🔧 УВЕЛИЧЕНО: Защита от rate limiting (429) при быстрых обновлениях.
  static const Duration _refreshDebounce = Duration(seconds: 10);

  /// 💾 Кеш полного списка объявлений для корректной работы поиска.
  /// Используется для фильтрации при вводе/удалении текста в поиск.
  /// Остается неизменным даже когда состояние меняется на ListingsSearchResults.
  List<home.Listing> _cachedAllListings = [];

  /// 💾 Кеш категорий для отображения при поиске.
  /// Загружается вместе с объявлениями и остается доступен при поиске.
  List<home.Category> _cachedCategories = [];

  /// Конструктор ListingsBloc.
  /// Инициализирует Bloc с начальным состоянием ListingsInitial.
  ListingsBloc() : super(ListingsInitial()) {
    on<LoadListingsEvent>(_onLoadListings);
    on<SearchListingsEvent>(_onSearchListings);
    on<FilterListingsByCategoryEvent>(_onFilterListingsByCategory);
    on<ResetFiltersEvent>(_onResetFilters);
    on<LoadAdvertEvent>(_onLoadAdvert);
    on<LoadNextPageEvent>(_onLoadNextPage);
    on<LoadSpecificPageEvent>(_onLoadSpecificPage);
  }

  /// Статические данные объявлений.
  /// В будущем можно заменить на загрузку из API.
  // Перемещены в lib/data/mock/mock_listings.dart

  /// Статические данные категорий.
  /// В будущем можно заменить на загрузку из API.
  /// Вспомогательный метод для преобразования Catalog из API в Category
  home.Category _catalogToCategory(dynamic catalog) {
    final colors = <Color>[
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.green,
      Colors.red,
      Colors.pink,
      Colors.cyan,
    ];

    // Используем хеш для выбора цвета на основе ID каталога
    final colorIndex = (catalog.id ?? 0) % colors.length;

    return home.Category(
      id: catalog.id,
      title: _formatCategoryTitle(catalog.name ?? ''),
      color: colors[colorIndex],
      imagePath: catalog.thumbnail ?? 'assets/home_page/image2.png',
      isCatalog: true, // Это основной каталог
    );
  }

  /// Вспомогательный метод для форматирования названия категории
  /// Добавляет перевод строки для длинных названий
  String _formatCategoryTitle(String title) {
    final words = title.split(' ');
    if (words.length > 2) {
      return '${words[0]}\n${words.sublist(1).join(' ')}';
    }
    return title;
  }

  /// Обработчик события загрузки объявлений.
  /// Использует двухэтапную загрузку для максимально быстрого первого фрейма:
  ///
  /// 🚀 ФАЗА 1 (БЫСТРО): Загружаем каталоги + первый батч (6 каталогов) параллельно
  ///   - Пользователь видит контент почти сразу (категории + 120+ объявлений)
  ///   - Skeleton исчезает через 1-2 секунды вместо 10+
  ///
  /// 🔄 ФАЗА 2 (ФОНЕ): Загружаем оставшиеся батчи объявлений (UI не блокируется)
  ///   - Продолжаем загружать остальные каталоги в фоне
  ///   - Обновляем список по завершении
  ///   - Кешируем все результаты
  ///
  /// Оптимизации:
  /// - Параллельные запросы вместо последовательных
  /// - Throttling: максимум 5 одновременных запросов в фазе 2
  /// - Парсинг JSON на фоновом потоке через compute()
  /// - Хранение в кеше для мгновенной загрузки при повторном открытии
  Future<void> _onLoadListings(
    LoadListingsEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // Защита от дублирования pull-to-refresh запросов
    if (_isLoadingListings) {
      // log.d('LoadListingsEvent уже выполняется, игнорируем дублирование');
      return;
    }

    // 🔧 Дебоунс для pull-to-refresh: минимум 10 секунд между обновлениями
    // Это защищает от rate limiting (429) при быстрых обновлениях
    if (event.forceRefresh && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _refreshDebounce) {
      // log.d('⏱️ Refresh дебоунсен: требуется ${_refreshDebounce.inSeconds}s между обновлениями ' +
            //     '(прошло ${timeSinceLastRefresh.inSeconds}s)');
        return;
      }
    }

    _isLoadingListings = true;
    if (event.forceRefresh) {
      _lastRefreshTime = DateTime.now();
    }

    const operationKey = 'listings_load';
    LoadingTimerService().startLoadingTimer(operationKey);
    
    // 🔄 Кеширование: если данные уже загружены и это не принудительная загрузка (фреш),
    // и нет ошибок, просто вернёмся к сохранённому состоянию
    if (_isInitialLoadComplete &&
        !event.forceRefresh &&
        state is ListingsLoaded &&
        state is! ListingsError) {
      LoadingTimerService().resetTimer(operationKey);
      return;
    }

    // 🔄 Проверяем кеш (L1 RAM → L2 Hive), если это не forceRefresh
    // Пропускаем при первой загрузке, когда Hive может быть не инициализирован
    if (!event.forceRefresh && state is! ListingsLoading) {
      try {
        final cachedListings = AppCacheService().get<Map>(
          CacheKeys.listingsData,
        );
        if (cachedListings != null &&
            cachedListings.containsKey('listings') &&
            cachedListings.containsKey('categories')) {
          try {
            // Каст JSON обратно в объекты
            final listings = (cachedListings['listings'] as List)
                .map((item) => _jsonToListing(item as Map<String, dynamic>))
                .toList();
            final categories = (cachedListings['categories'] as List)
                .map((item) => _jsonToCategory(item as Map<String, dynamic>))
                .toList();

            // 🔥 ТАЙМЕР: Зафиксируем время загрузки из кеша
            final cacheTimer = LoadingTimerService().stopLoadingTimer(
              operationKey,
              label: 'Listings (из кеша)',
            );

            // 💾 Обновляем кеш для корректной работы поиска
            _cachedAllListings = listings;
            _cachedCategories = categories;

            emit(
              ListingsLoaded(
                listings: listings,
                categories: categories,
                currentPage: cachedListings['currentPage'] ?? 1,
                totalPages: cachedListings['totalPages'] ?? 1,
                itemsPerPage: cachedListings['itemsPerPage'] ?? 20,
              ),
            );
            _isInitialLoadComplete = true;
            return;
          } catch (e) {
            // Игнорируем ошибку кеша и загружаем заново
          }
        }
      } catch (e) {
        // Hive еще не инициализирован, пропускаем проверку кеша
      }
    }

    emit(ListingsLoading());
    try {
      final token = TokenService.currentToken;

      //  ФАЗА 1: Загружаем каталоги один раз (НЕ дважды!)
      final catalogsResponse = await ApiService.getCatalogs(token: token);
      final allCatalogIds = catalogsResponse.data.map((c) => c.id).toList();

      final loadedCategories = catalogsResponse.data
          .map(_catalogToCategory)
          .toList();

      loadedCategories.add(
        const home.Category(
          title: 'Смотреть\nвсе',
          color: Color(0xFF00A6FF),
          imagePath: '',
        ),
      );

      // 🚀 НОВАЯ ОПТИМИЗАЦИЯ: Фазовая загрузка объявлений
      // Фаза 1: Загружаем ТОЛЬКО первые 2-3 каталога для быстрого показа
      // Это обычно содержит 12+ самых свежих объявлений
      const int initialCatalogsToLoad = 3; // Загружаем 3 первых каталога
      final firstBatchCatalogIds = allCatalogIds.take(initialCatalogsToLoad).toList();
      final remainingCatalogIds = allCatalogIds.skip(initialCatalogsToLoad).toList();

      // 🔥 Загружаем объявления из ПЕРВЫХ каталогов параллельно
      List<home.Listing> initialListings = [];
      int totalPages = 1;
      int itemsPerPage = 50;

      if (firstBatchCatalogIds.isNotEmpty) {
        // Преобразуем каталоги в список функций для queueBatch
        final requestFunctions = firstBatchCatalogIds
            .map(
              (catalogId) => () => ApiService.getAdverts(
                catalogId: catalogId,
                token: token,
                page: 1,
                limit: 50,
              ),
            )
            .toList();

        // Используем ApiRequestQueue для ограничения параллельных запросов
        // 🔧 ОПТИМИЗАЦИЯ: Уменьшена параллельность с 2 до 1 (последовательная загрузка)
        // Это уменьшает нагрузку на медленное интернет соединение
        final batchResponses = await ApiRequestQueue.instance.queueBatch(
          requestFunctions,
          batchSize: 1,
        );

        // 🔧 ИСПРАВЛЕНИЕ: Отслеживаем ID объявлений для дедупликации
        // (несколько каталогов могут содержать одно и то же объявление)
        final seenIds = <String>{};

        // Парсируем ответы
        for (final response in batchResponses) {
          if (response.data.isNotEmpty) {
            // 🔧 ОПТИМИЗАЦИЯ: Всегда переносим парсинг JSON на фоновый поток
            // Это предотвращает блокировку UI даже при небольших списках
            List<home.Listing> parsedListings = await compute<List<Advert>, List<home.Listing>>(
              (adverts) => _parseAdvertsOnBackgroundThread(adverts),
              response.data,
            );

            // 🔧 ИСПРАВЛЕНИЕ: Добавляем только уникальные объявления
            for (final listing in parsedListings) {
              if (!seenIds.contains(listing.id)) {
                seenIds.add(listing.id);
                initialListings.add(listing);
              }
            }
            
            totalPages = response.meta.lastPage;
            itemsPerPage = response.meta.perPage;
          }
        }
      }

      // Сортируем и берем ПЕРВЫЕ 12 объявлений для быстрого показа
      final allSortedListings = _sortListingsByDate(initialListings);
      final firstBatchListings = allSortedListings.take(12).toList();
      // �🚀 ФАЗА 1 ЗАВЕРШЕНА: Пользователь видит первые 12 объявлений почти сразу!
      LoadingTimerService().stopLoadingTimer(
        operationKey,
        label: 'Listings (первые 12 объявлений)',
      );
      
      // 💾 Кешируем все отсортированные объявления
      // Необходимо для корректной работы поиска при вводе/удалении текста
      _cachedAllListings = [
        ...firstBatchListings,
        ...allSortedListings.skip(12)
      ];
      _cachedCategories = loadedCategories;
      
      emit(
        ListingsLoaded(
          listings: firstBatchListings,
          categories: loadedCategories,
          currentPage: 1,
          totalPages: totalPages,
          itemsPerPage: itemsPerPage,
        ),
      );

      _isInitialLoadComplete = true;

      // 🔄 ФАЗА 2: Загружаем ОСТАЛЬНЫЕ каталоги в фоне БЕЗ блокировки UI
      // Результат придет в виде обновленного состояния с полным списком
      if (remainingCatalogIds.isNotEmpty) {
        _loadPhase2AndUpdateUI(
          remainingCatalogIds,
          token,
          loadedCategories,
          allSortedListings, // Передаем уже загруженные объявления
          operationKey,
        );
      }
    } catch (e, stackTrace) {
      // 🔥 ТАЙМЕР: Зафиксируем время загрузки перед ошибкой
      LoadingTimerService().stopLoadingTimer(
        operationKey,
        label: 'Listings (ошибка при загрузке)',
      );
      
      // 🔴 СЛОЙ 3: Преобразуем ошибку в понятное сообщение
      final errorMessage = _getErrorMessage(e);
      
      // 🔴 Логируем РЕАЛЬНУЮ ошибку для диагностики
      log.e(
        '❌ КРИТИЧЕСКАЯ ОШИБКА в LoadListingsEvent:\n'
        '   Сообщение: $errorMessage\n'
        '   Тип: ${e.runtimeType}\n'
        '   Ошибка: $e',
        error: e,
        stackTrace: stackTrace,
      );
      
      // Показываем пользователю понятное сообщение или общую ошибку
      emit(ListingsError(message: 'Unable to load listings'));
    } finally {
      _isLoadingListings = false;
    }
  }

  /// Обработчик события поиска объявлений.
  /// Выполняет поиск по заголовку и описанию объявлений.
  Future<void> _onSearchListings(
    SearchListingsEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // 🔍 Используем кеш полного списка, независимо от текущего состояния
    // Это позволяет правильно фильтровать при удалении текста из поиска
    if (_cachedAllListings.isEmpty) {
      log.w('⚠️ Кеш объявлений пуст, поиск невозможен');
      return;
    }

    emit(ListingsLoading());

    try {
      // Имитация задержки поиска
      await Future.delayed(const Duration(milliseconds: _searchDelayMs));

      final query = event.query.toLowerCase();
      
      // 📋 ЛОГИРОВАНИЕ: Показываем структуру первого объявления и ищем нужное
      if (_cachedAllListings.isNotEmpty) {
        // Показываем первое объявление
        final firstListing = _cachedAllListings.first;
        log.i('');
        log.i('═' * 80);
        log.i('📊 ПЕРВОЕ ОБЪЯВЛЕНИЕ (ID: ${firstListing.id}):');
        log.i('  Title: ${firstListing.title}');
        log.i('  Характеристик: ${firstListing.characteristics.length}');
        firstListing.characteristics.forEach((k, v) {
          log.i('    [$k] = $v (тип: ${v.runtimeType})');
          if (v is Map) {
            (v as Map).forEach((mk, mv) => log.i('      - $mk: $mv'));
          }
          if (v is List) {
            (v as List).asMap().forEach((idx, item) => 
              log.i('      [$idx] $item${item is Map ? ' ${(item as Map).toString()}' : ''}'));
          }
        });
        
        // Ищем объявление с ID 159
        try {
          final listing159 = _cachedAllListings.firstWhere((l) => l.id == '159');
          log.i('');
          log.i('═' * 80);
          log.i('🎯 ОБЪЯВЛЕНИЕ 159:');
          log.i('  ID: ${listing159.id}');
          log.i('  Title: ${listing159.title}');
          log.i('  Location: ${listing159.location}');
          log.i('  Description: ${listing159.description ?? "N/A"}');
          log.i('  Price: ${listing159.price}');
          log.i('  Характеристик: ${listing159.characteristics.length}');
          if (listing159.characteristics.isNotEmpty) {
            listing159.characteristics.forEach((k, v) {
              log.i('    [$k] = $v (тип: ${v.runtimeType})');
              if (v is Map) {
                (v as Map).forEach((mk, mv) => log.i('      - $mk: $mv'));
              }
              if (v is List) {
                for (int i = 0; i < (v as List).length; i++) {
                  final item = (v as List)[i];
                  log.i('      [$i] $item');
                  if (item is Map) {
                    (item as Map).forEach((ik, iv) => log.i('        - $ik: $iv'));
                  }
                }
              }
            });
          }
          log.i('═' * 80);
          log.i('');
        } catch (e) {
          log.w('⚠️ Объявление 159 не найдено');
        }
      }
      
      final searchResults = _cachedAllListings.where((listing) {
        return _matchesSearchQuery(listing, query);
      }).toList();

      // 📊 Логирование результатов поиска
      log.i('🔍 Поиск: "$query" | Найдено: ${searchResults.length} из ${_cachedAllListings.length} объявлений');
      if (searchResults.isEmpty && _cachedAllListings.length > 0) {
        log.w('⚠️ Результатов не найдено. Проверьте логи выше для структуры данных.');
      }

      emit(
        ListingsSearchResults(
          searchResults: searchResults,
          query: event.query,
          categories: _cachedCategories, // 🔥 Передаем кешированные категории
        ),
      );
    } catch (e) {
      log.e('❌ Ошибка при поиске: $e');
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Проверяет, соответствует ли объявление поисковому запросу.
  /// Ищет в названии, локации, городе, улице, описании и характеристиках.
  bool _matchesSearchQuery(home.Listing listing, String query) {
    // 🔍 Поиск в основных текстовых полях
    if (listing.title.toLowerCase().contains(query)) {
      log.d('  ✅ Совпадение в title: ${listing.title}');
      return true;
    }
    
    if (listing.location.toLowerCase().contains(query)) {
      log.d('  ✅ Совпадение в location: ${listing.location}');
      return true;
    }

    // 🔍 Поиск по адресным компонентам
    if (listing.city?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в city: ${listing.city}');
      return true;
    }
    if (listing.street?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в street: ${listing.street}');
      return true;
    }
    if (listing.region?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в region: ${listing.region}');
      return true;
    }
    if (listing.mainRegion?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в mainRegion: ${listing.mainRegion}');
      return true;
    }
    if (listing.subRegion?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в subRegion: ${listing.subRegion}');
      return true;
    }
    if (listing.district?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в district: ${listing.district}');
      return true;
    }

    // 🔍 Поиск в описании
    if (listing.description?.toLowerCase().contains(query) ?? false) {
      log.d('  ✅ Совпадение в description: ${listing.description}');
      return true;
    }

    // 🔍 Поиск в характеристиках (рекурсивный поиск по всем вложенным значениям)
    if (_searchInCharacteristics(listing.characteristics, query)) {
      return true;
    }

    return false;
  }

  /// Рекурсивно ищет текст в структуре характеристик.
  /// Поддерживает поиск в Map, List и простых значениях.
  bool _searchInCharacteristics(Map<String, dynamic> characteristics, String query) {
    if (characteristics.isEmpty) return false;

    for (final entry in characteristics.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // 🔍 Ищем в названии ключа характеристики
      if (key.contains(query)) {
        log.d('  ✅ Найдено совпадение в ключе: $key');
        return true;
      }

      // 🔍 Рекурсивно ищем в значении
      if (_searchInValue(value, query)) {
        log.d('  ✅ Найдено совпадение в значении для ключа: $key (значение: $value)');
        return true;
      }
    }
    return false;
  }

  /// Рекурсивно ищет текст в значении любого типа.
  /// Поддерживает Map, List, String, int, double и другие типы.
  bool _searchInValue(dynamic value, String query) {
    if (value == null) return false;

    // 🔍 Если это Map - ищем во всех значениях и ключах
    if (value is Map) {
      for (final entry in value.entries) {
        // Ищем в ключах Map (например: "label", "title", "name")
        final key = entry.key.toString().toLowerCase();
        if (key.contains(query)) return true;

        // Ищем в значениях Map (рекурсивно)
        if (_searchInValue(entry.value, query)) return true;
      }
      return false;
    }

    // 🔍 Если это List - ищем во всех элементах
    if (value is List) {
      for (final item in value) {
        if (_searchInValue(item, query)) return true;
      }
      return false;
    }

    // 🔍 Если это String - простой поиск (с удалением пробелов)
    if (value is String) {
      // Обычный поиск
      if (value.toLowerCase().contains(query)) return true;
      
      // Также ищем без пробелов и спецсимволов (если есть)
      final normalized = value.toLowerCase()
          .replaceAll(RegExp(r'[\s\-_]+'), '')  // Удаляем пробелы, дефисы, подчеркивания
          .replaceAll(RegExp(r'[ёЁ]'), 'е');     // Нормализуем ё на е
      final normalizedQuery = query.replaceAll(RegExp(r'[\s\-_]+'), '');
      if (normalized.contains(normalizedQuery)) return true;
      
      return false;
    }

    // 🔍 Если это число (int, double) - конвертируем в строку и ищем
    if (value is int || value is double) {
      if (value.toString().contains(query)) return true;
    }

    // 🔍 Если это bool - конвертируем и ищем
    if (value is bool) {
      if (value ? 'да'.contains(query) : 'нет'.contains(query)) return true;
      if (value ? 'yes'.contains(query) : 'no'.contains(query)) return true;
      if (value.toString().toLowerCase().contains(query)) return true;
    }

    return false;
  }

  /// Обработчик события фильтрации объявлений по категории.
  /// Фильтрует объявления на основе выбранной категории.
  Future<void> _onFilterListingsByCategory(
    FilterListingsByCategoryEvent event,
    Emitter<ListingsState> emit,
  ) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки фильтрации
      await Future.delayed(const Duration(milliseconds: _filterDelayMs));

      // Для демонстрации фильтрации используем простую логику
      // В будущем можно реализовать более сложную фильтрацию по API
      List<home.Listing> filteredListings;
      switch (event.categoryId) {
        case 'real-estate':
          filteredListings = currentState.listings
              .where(
                (listing) =>
                    listing.title.contains('квартира') ||
                    listing.title.contains('студия') ||
                    listing.imagePath.contains('apartment') ||
                    listing.imagePath.contains('studio'),
              )
              .toList();
          break;
        case 'auto':
          filteredListings = currentState.listings
              .where(
                (listing) =>
                    listing.title.contains('Acura') ||
                    listing.imagePath.contains('acura'),
              )
              .toList();
          break;
        default:
          filteredListings = currentState.listings;
      }

      emit(
        ListingsFiltered(
          filteredListings: filteredListings,
          categoryId: event.categoryId,
        ),
      );
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события сброса фильтров.
  /// Возвращает полный список объявлений без фильтрации.
  Future<void> _onResetFilters(
    ResetFiltersEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // 🔍 Используем кеш для восстановления полного списка
    if (_cachedAllListings.isEmpty) {
      log.w('⚠️ Кеш пуст, невозможно сбросить фильтры');
      return;
    }

    emit(ListingsLoading());

    try {
      // Имитация задержки сброса фильтров
      await Future.delayed(const Duration(milliseconds: _filterDelayMs));

      // 🔥 Используем кешированные категории вместо текущего состояния
      // Это обеспечивает корректное отображение категорий при сбросе поиска

      emit(
        ListingsLoaded(
          listings: _cachedAllListings,
          categories: _cachedCategories,
        ),
      );
    } catch (e) {
      log.e('❌ Ошибка при сбросе фильтров: $e');
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события загрузки одного объявления по ID.
  /// Загружает полные данные объявления из API.
  Future<void> _onLoadAdvert(
    LoadAdvertEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // log.d('Loading single advert for id ${event.advertId}');

    // 🔄 Проверяем кеш перед запросом к API
    final cacheKey = CacheKeys.advertKey(event.advertId);
    try {
      final cachedAdvertRaw = AppCacheService().get<dynamic>(cacheKey);
      if (cachedAdvertRaw != null && cachedAdvertRaw is Map) {
        try {
          // Безопасно преобразуем Dynamic Map в Map<String, dynamic>
          final cachedAdvert = Map<String, dynamic>.from(cachedAdvertRaw);
          // log.d('✅ ListingsBloc: Восстановили объявление из кеша');
          final listing = _jsonToListing(cachedAdvert);
          emit(AdvertLoaded(listing: listing));
          return;
        } catch (e) {
          // Если не удалось восстановить из кеша, загружаем заново
          // log.d('⚠️ ListingsBloc: Ошибка восстановления из кеша: $e');
        }
      }
    } catch (e) {
      // Игнорируем ошибки кеша и продолжаем загрузку
      // log.d('⚠️ ListingsBloc: Ошибка доступа к кешу: $e');
    }

    emit(ListingsLoading());
    try {
      // Получаем токен для аутентификации
      final token = TokenService.currentToken;

      // Загружаем полные данные объявления из API
      final advert = await ApiService.getAdvert(
        int.parse(event.advertId),
        token: token,
      );

      // log.d('Loaded advert ${advert.id} with ${advert.images.length} images');

      // Преобразуем Advert в Listing
      final listing = advert.toListing();

      // log.d('Converted to listing with ${listing.images.length} images');

      // 💾 Сохраняем в унифицированный кеш (L1 + L2 Hive)
      // Обернуто в try-catch т.к. Hive может быть не инициализирован
      try {
        final jsonToCache = _listingToJson(listing);
        // log.d('💾 Caching listing ${listing.id} with isBargain=${jsonToCache['isBargain']}');
        AppCacheService().set<Map<String, dynamic>>(
          cacheKey,
          jsonToCache,
          persist: true,
        );
      } catch (e) {
        // Ошибка кеша - продолжаем работу
      }

      emit(AdvertLoaded(listing: listing));
    } catch (e) {
      // log.d('Failed to load advert: $e');
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события загрузки следующей страницы.
  /// Добавляет объявления из следующей страницы к существующим.
  ///
  /// Загружает следующую страницу из ВСЕ каталогов параллельно.
  /// Увеличивает порцию объявлений за один раз.
  Future<void> _onLoadNextPage(
    LoadNextPageEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // Проверяем, что текущее состояние - ListingsLoaded
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;

    // Проверяем, есть ли еще объявления для загрузки
    // Предполагаем максимум 1000 объявлений в системе
    if (currentState.listings.length >= 1000) {
      return; // Не загружаем, если уже много
    }

    try {
      // Получаем токен для аутентификации
      final token = TokenService.currentToken;

      // 🚀 ИСПРАВЛЕНИЕ: Загружаем со ВСЕХ каталогов параллельно
      // Каталог 1 = все категории (главный каталог, содержит все объявления)
      // Просто берём очередную страницу из него
      final nextPage = (currentState.listings.length ~/ 50) + 1;

      // log.d('📄 Загрузка: ${currentState.listings.length} текущих, страница $nextPage...');

      final advertsResponse = await ApiService.getAdverts(
        catalogId: 1, // Главный каталог - все объявления
        token: token,
        page: nextPage,
        limit: 100, // Увеличиваем лимит с 50 до 100 для большей порции
      );

      if (advertsResponse.data.isEmpty) {
        // Нет больше объявлений
        return;
      }

      // Преобразуем Advert в Listing
      final newListings = advertsResponse.data.map((advert) {
        return advert.toListing();
      }).toList();

      // 🔧 ИСПРАВЛЕНИЕ: Дедупликация при объединении - избегаем дублей при пагинации
      // Используем Set для отслеживания уже загруженных ID
      final seenIds = currentState.listings.map((l) => l.id).toSet();
      final uniqueNewListings = newListings
          .where((listing) => !seenIds.contains(listing.id))
          .toList();

      // Объединяем существующие объявления с новыми (только с уникальными)
      final allListings = [...currentState.listings, ...uniqueNewListings];

      // 📌 НЕ пересортируем при пагинации!
      // Пользователь ожидает видеть новые объявления внизу, а не в начале
      // Сортировка происходит только при первой загрузке

      // Извлекаем информацию о пагинации
      final totalPages = advertsResponse.meta.lastPage;
      final itemsPerPage = advertsResponse.meta.perPage;

      // log.d('✅ Загружено ${newListings.length} объявлений (${uniqueNewListings.length} уникальных), всего: ${allListings.length}');

      // 💾 Обновляем кеш полного списка для корректной работы поиска
      _cachedAllListings = allListings;
      _cachedCategories = currentState.categories;

      // Испускаем новое состояние с новыми объявлениями в конце
      emit(
        ListingsLoaded(
          listings: allListings,
          categories: currentState.categories,
          currentPage: nextPage,
          totalPages: totalPages,
          itemsPerPage: itemsPerPage,
        ),
      );
    } catch (e) {
      // log.d('❌ Ошибка при загрузке следующей страницы: $e');
      // При ошибке испускаем состояние ошибки
      emit(
        ListingsError(message: 'Ошибка при загрузке следующей страницы: $e'),
      );
    }
  }

  /// Обработчик события загрузки конкретной страницы.
  /// Заменяет текущие объявления объявлениями указанной страницы.
  ///
  /// Загружает объявления из каталога 1 (все категории).
  /// Используется для прямой навигации на конкретную страницу.
  Future<void> _onLoadSpecificPage(
    LoadSpecificPageEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // Проверяем, что текущее состояние - ListingsLoaded
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;

    // Проверяем валидность номера страницы
    if (event.pageNumber < 1 || event.pageNumber > currentState.totalPages) {
      // log.d();
      return;
    }

    // log.d('📄 Загрузка конкретной страницы ${event.pageNumber}...');

    try {
      // Получаем токен для аутентификации
      final token = TokenService.currentToken;

      // Загружаем объявления конкретной страницы из каталога 1 (все категории)
      final advertsResponse = await ApiService.getAdverts(
        catalogId: 1, // Каталог 1 = все категории
        token: token,
        page: event.pageNumber,
        limit: 50,
      );

      // Преобразуем Advert в Listing
      final listings = advertsResponse.data.map((advert) {
        return advert.toListing();
      }).toList();

      // log.d();

      // Сортируем объявления по датам (новые в начале)
      final sortedListings = _sortListingsByDate(listings);

      // Извлекаем информацию о пагинации
      final totalPages = advertsResponse.meta.lastPage;
      final itemsPerPage = advertsResponse.meta.perPage;

      // 💾 Обновляем кеш полного списка для корректной работы поиска
      _cachedAllListings = sortedListings;
      _cachedCategories = currentState.categories;

      // Испускаем новое состояние с объявлениями указанной страницы
      emit(
        ListingsLoaded(
          listings: sortedListings,
          categories: currentState.categories,
          currentPage: event.pageNumber,
          totalPages: totalPages,
          itemsPerPage: itemsPerPage,
        ),
      );
    } catch (e) {
      // При ошибке испускаем состояние ошибки
      emit(ListingsError(message: 'Ошибка при загрузке страницы: $e'));
    }
  }

  /// Метод для сортировки объявлений по датам.
  /// Объявления с датой 'Сегодня' помещаются в начало.
  /// Остальные объявления сортируются от новых к старым.
  List<home.Listing> _sortListingsByDate(List<home.Listing> listings) {
    // Функция для преобразования строки даты в объект DateTime для сравнения
    DateTime? parseDate(String dateStr) {
      // Если дата 'Сегодня', возвращаем очень новую дату
      if (dateStr == 'Сегодня') {
        return DateTime.now();
      }

      try {
        // Пытаемся распарсить дату в формате DD.MM.YYYY
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (e) {
        // log.d('Ошибка при парсировании даты "$dateStr": $e');
      }
      return null;
    }

    // Разделяем объявления на две группы: 'Сегодня' и остальные
    final todayListings = <home.Listing>[];
    final otherListings = <home.Listing>[];

    for (final listing in listings) {
      if (listing.date == 'Сегодня') {
        todayListings.add(listing);
      } else {
        otherListings.add(listing);
      }
    }

    // Сортируем остальные объявления от новых к старым
    otherListings.sort((a, b) {
      final dateA = parseDate(a.date);
      final dateB = parseDate(b.date);

      if (dateA == null || dateB == null) {
        return 0; // Если не удалось распарсить, оставляем исходный порядок
      }

      // Сортируем в обратном порядке (новые сначала)
      return dateB.compareTo(dateA);
    });

    // Объединяем: сначала 'Сегодня', потом отсортированные по датам
    return [...todayListings, ...otherListings];
  }

  /// Конвертирует Listing в JSON для кеша.
  Map<String, dynamic> _listingToJson(home.Listing listing) {
    return {
      'id': listing.id,
      'imagePath': listing.imagePath,
      'images': listing.images,
      'title': listing.title,
      'price': listing.price,
      'location': listing.location,
      'date': listing.date,
      'isFavorited': listing.isFavorited,
      'isBargain': listing.isBargain,
      'sellerName': listing.sellerName,
      'sellerAvatar': listing.sellerAvatar,
      'sellerRegistrationDate': listing.sellerRegistrationDate,
      'description': listing.description,
      'characteristics': listing.characteristics,
      'userId': listing.userId,
    };
  }

  /// Конвертирует JSON обратно в Listing из кеша.
  home.Listing _jsonToListing(Map<String, dynamic> json) {
    // Безопасное преобразование characteristics из JSON
    Map<String, dynamic> characteristics = {};
    if (json['characteristics'] != null && json['characteristics'] is Map) {
      characteristics = Map<String, dynamic>.from(json['characteristics']);
    }

    return home.Listing(
      id: json['id'] ?? '',
      slug: json['slug'],
      imagePath: json['imagePath'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      title: json['title'] ?? '',
      price: json['price'] ?? '',
      location: json['location'] ?? '',
      date: json['date'] ?? '',
      isFavorited: json['isFavorited'] ?? false,
      isBargain: json['isBargain'] ?? false,
      sellerName: json['sellerName'] ?? '',
      sellerAvatar: json['sellerAvatar'] ?? '',
      sellerRegistrationDate: json['sellerRegistrationDate'] ?? '',
      description: json['description'],
      characteristics: characteristics,
      userId: json['userId']?.toString(),
    );
  }

  /// Конвертирует Category в JSON для кеша.
  Map<String, dynamic> _categoryToJson(home.Category category) {
    return {
      'id': category.id,
      'title': category.title,
      'color': category.color.toARGB32(),
      'imagePath': category.imagePath,
      'isCatalog': category.isCatalog,
    };
  }

  /// Загружает остальные каталоги в фоне БЕЗ блокировки UI и БЕЗ emit'а.
  /// Это избегает BLoC anti-pattern: "emit called after handler completed".
  /// 
  /// ФАЗА 2 работает таким образом:
  /// 1. Запускается асинхронно после возврата из _onLoadListings
  /// 2. Загружает остальные каталоги батчами (с throttling)
  /// 3. Обновляет только кеш - НЕ вызывает emit()
  /// 4. При следующей загрузке приложения, данные придут из кеша
  /// 5. Использует консервативные настройки для медленных сетей
  /// ФАЗА 2: Загружает остальные каталоги в фоне и обновляет список объявлений.
  /// Этот метод работает асинхронно и вызывает emit() когда данные готовы.
  ///
  /// Параметры:
  /// - [remainingCatalogIds] - ID каталогов для загрузки
  /// - [token] - токен авторизации
  /// - [loadedCategories] - уже загруженные категории
  /// - [initialListings] - объявления из первой фазы
  /// - [operationKey] - ключ для таймера операции
  void _loadPhase2AndUpdateUI(
    List<int> remainingCatalogIds,
    String? token,
    List<home.Category> loadedCategories,
    List<home.Listing> initialListings,
    String operationKey,
  ) {
    // 🛡️ ЗАЩИТА: Не запускаем фазу 2 если она уже выполняется
    // Предотвращает множественные параллельные загрузки при rate limiting
    if (_isPhase2Loading) {
      // log.d('⚠️ ListingsBloc ФАЗА 2: Уже выполняется, пропускаем дублирование');
      return;
    }

    _isPhase2Loading = true;

    // Запускаем в фоне, не ждём результата в основном обработчике события
    Future(() async {
      try {
        // 🚀 ТАЙМЕР: Запускаем таймер для фазы 2
        const phase2OperationKey = 'listings_load_phase2';
        LoadingTimerService().startLoadingTimer(phase2OperationKey);

        // 🔧 ИСПРАВЛЕНИЕ: Уменьшена параллельность с 2 до 1
        // Это критично для избежания rate limiting (429 ошибок)
        // При rate limiting сервер может потребовать еще больше времени между запросами
        List<home.Listing> additionalListings = [];
        const int maxConcurrentRequests = 1;  // Был 2, теперь 1
        
        // 📊 Отслеживаем успешные и неудачные батчи для graceful degradation
        int successfulBatches = 0;
        int failedBatches = 0;
        int rateLimitErrors = 0;
        
        // 📈 Exponential backoff для rate limiting ошибок
        int currentDelayMs = 500;  // Начальная задержка 500ms
        const int maxDelayMs = 5000;  // Максимальная задержка 5 сек
        
        for (int i = 0; i < remainingCatalogIds.length; i += maxConcurrentRequests) {
          final batch = remainingCatalogIds.sublist(
            i,
            (i + maxConcurrentRequests).clamp(0, remainingCatalogIds.length),
          );

          final batchFutures = batch
              .map(
                (catalogId) => ApiService.getAdverts(
                  catalogId: catalogId,
                  token: token,
                  page: 1,
                  limit: 50,
                ),
              )
              .toList();

          try {
            final batchResponses = await Future.wait(batchFutures);
            
            successfulBatches++;
            // После успешного батча сбрасываем exponential backoff
            currentDelayMs = 500;
            
            // Задержка между батчами чтобы не перегружать сервер
            if (i + maxConcurrentRequests < remainingCatalogIds.length) {
              await Future.delayed(Duration(milliseconds: currentDelayMs));
            }

            for (final response in batchResponses) {
              if (response.data.isNotEmpty) {
                // 🔧 ОПТИМИЗАЦИЯ: Всегда переносим парсинг JSON на фоновый поток
                // Это предотвращает блокировку UI даже при небольших списках
                List<home.Listing> parsedListings = await compute<List<Advert>, List<home.Listing>>(
                  (adverts) => _parseAdvertsOnBackgroundThread(adverts),
                  response.data,
                );

                additionalListings.addAll(parsedListings);
              }
            }
          } catch (e) {
            failedBatches++;
            final errorMsg = e.toString();
            
            // 🚨 Специальная обработка rate limiting (429) ошибок
            if (errorMsg.contains('429') || errorMsg.contains('RateLimitException')) {
              rateLimitErrors++;
              // log.d('⏱️ ListingsBloc ФАЗА 2: Rate limit (429), применяю exponential backoff...');
              
              // 📈 Exponential backoff: увеличиваем задержку
              currentDelayMs = (currentDelayMs * 2).clamp(500, maxDelayMs);
              
              // Если слишком много 429 ошибок - останавливаем фазу 2 и используем кеш
              if (rateLimitErrors >= 3) {
                // log.d('🛑 ListingsBloc ФАЗА 2: Слишком много rate limit ошибок (${rateLimitErrors}x 429), ' +
                //     'останавливаю фазу 2 и использую кеш...');
                break;  // Выходим из цикла батчей
              }
              
              // Ждем перед повторной попыткой
              await Future.delayed(Duration(milliseconds: currentDelayMs));
            } else {
              // Для других ошибок просто логируем и продолжаем
              // log.d('⚠️ ListingsBloc ФАЗА 2: Ошибка батча ($i-${i + maxConcurrentRequests}): $e');
            }
            
            continue;
          }
        }

        // 📊 ОБЪЕДИНЯЕМ: инициальные объявления + новые объявления
        // 🔧 Дедупликация по ID объявления
        final seenIds = <String>{};
        final deduplicatedListings = <home.Listing>[];
        
        for (final listing in [...initialListings, ...additionalListings]) {
          if (!seenIds.contains(listing.id)) {
            seenIds.add(listing.id);
            deduplicatedListings.add(listing);
          }
        }
        
        // 🔥 НОВОЕ: Загружаем атрибуты для объявлений из Фазы 2
        // (У объявлений из Фазы 1 уже есть атрибуты, поэтому пропускаем их)
        if (additionalListings.isNotEmpty) {
          log.i('⏳ Загружаем атрибуты для ${additionalListings.length} объявлений из Фазы 2...');
          try {
            // Создаем Map для быстрого обновления Listing по ID
            final listingById = <int, home.Listing>{};
            for (final listing in additionalListings) {
              listingById[int.parse(listing.id)] = listing;
            }
            
            final phase2AdvertIds = listingById.keys.toList();
            
            // Загружаем полные данные с атрибутами (параллельно, батчами)
            const batchSize = 3;
            for (int batchStart = 0; batchStart < phase2AdvertIds.length; batchStart += batchSize) {
              final batchEnd = (batchStart + batchSize > phase2AdvertIds.length) 
                ? phase2AdvertIds.length 
                : batchStart + batchSize;
              final batch = phase2AdvertIds.sublist(batchStart, batchEnd);
              
              final advertsWithAttributes = await ApiService.getAdvertsWithAttributes(
                batch,
                token: token,
              );
              
              // Обновляем только те объявления которые были в этом батче
              advertsWithAttributes.forEach((advertId, fullAdvert) {
                final listing = listingById[advertId];
                if (listing != null && fullAdvert.characteristics != null) {
                  // Создаем новый объект Listing с атрибутами
                  listingById[advertId] = home.Listing(
                    id: listing.id,
                    slug: listing.slug,
                    imagePath: listing.imagePath,
                    images: listing.images,
                    title: listing.title,
                    price: listing.price,
                    location: listing.location,
                    date: listing.date,
                    isFavorited: listing.isFavorited,
                    isBargain: listing.isBargain,
                    sellerName: listing.sellerName,
                    sellerAvatar: listing.sellerAvatar,
                    sellerRegistrationDate: listing.sellerRegistrationDate,
                    userId: listing.userId,
                    description: listing.description,
                    characteristics: fullAdvert.characteristics ?? {}, // 🔥 Атрибуты!
                    region: listing.region,
                    city: listing.city,
                    street: listing.street,
                    buildingNumber: listing.buildingNumber,
                    mainRegion: listing.mainRegion,
                    subRegion: listing.subRegion,
                    district: listing.district,
                  );
                }
              });
              
              // Задержка между батчами чтобы не перегружать API
              if (batchEnd < phase2AdvertIds.length) {
                await Future.delayed(const Duration(milliseconds: 300));
              }
            }
            
            // Обновляем additionalListings с новыми объектами с атрибутами
            additionalListings = listingById.values.toList();
            
            log.i('✅ Атрибуты загружены для ${additionalListings.length} объявлений Фазы 2');
          } catch (e) {
            // Не критично - продолжаем с объявлениями без атрибутов
            log.w('⚠️ Не удалось загрузить атрибуты для Фазы 2: $e');
          }
        }
        
        final finalSortedListings = _sortListingsByDate(deduplicatedListings);

        // 🔥 ТАЙМЕР: Фиксируем полное время загрузки (фаза 2)
        try {
          LoadingTimerService().stopLoadingTimer(
            phase2OperationKey,
            label: 'Listings (фаза 2: $successfulBatches успешно, $failedBatches ошибок)',
          );
        } catch (e) {
          // Игнорируем ошибку таймера если он не был запущен
        }

        // � Обновляем кеш полного списка для корректной работы поиска
        _cachedAllListings = finalSortedListings;
        _cachedCategories = loadedCategories;

        // �📢 GRACEFUL DEGRADATION: Всегда эмитируем успешное состояние
        // Даже если некоторые батчи 429 - показываем данные которые удалось загрузить
        // + уже загруженные данные из фазы 1
        emit(
          ListingsLoaded(
            listings: finalSortedListings,
            categories: loadedCategories,
            currentPage: 1,
            totalPages: (finalSortedListings.length / 50).ceil(),
            itemsPerPage: 50,
          ),
        );

        // 💾 Сохраняем полный список в кеш для следующего открытия
        try {
          AppCacheService().set<Map>(
            CacheKeys.listingsData,
            {
              'listings': finalSortedListings
                  .map((listing) => _listingToJson(listing))
                  .toList(),
              'categories': loadedCategories
                  .map((category) => _categoryToJson(category))
                  .toList(),
              'currentPage': 1,
              'totalPages': (finalSortedListings.length / 50).ceil(),
              'itemsPerPage': 50,
            },
            persist: true,
          );
        // log.d('✅ ListingsBloc ФАЗА 2: Данные закеширован (${finalSortedListings.length} объявлений)');
        } catch (e) {
          // log.d('⚠️ ListingsBloc ФАЗА 2: Ошибка кеширования: $e');
        }
      } catch (e) {
        // log.d('❌ ListingsBloc ФАЗА 2: Критическая ошибка: $e');
        // Даже при критической ошибке, не эмитируем ListingsError
        // Пользователь видит уже загруженные данные из фазы 1
      } finally {
        _isPhase2Loading = false;  // 🛡️ Разрешаем следующую фазу 2
      }
    });
  }

  Future<void> _loadPhase2InBackground(
    List<int> allCatalogIds,
    String? token,
    List<home.Category> loadedCategories,
    List<home.Listing> sortedListings,
    int totalPages,
    int itemsPerPage,
  ) async {
    // Запускаем в фоне, не ждём результата
    Future(() async {
      try {
        // 📌 Теперь фаза 2 просто кеширует данные
        // Так как все каталоги уже загружены в фазе 1

        // 💾 Сохраняем в кеш для быстрой загрузки при следующем открытии
        try {
          AppCacheService().set<Map>(
            CacheKeys.listingsData,
            {
              'listings': sortedListings
                  .map((listing) => _listingToJson(listing))
                  .toList(),
              'categories': loadedCategories
                  .map((category) => _categoryToJson(category))
                  .toList(),
              'currentPage': 1,
              'totalPages': totalPages,
              'itemsPerPage': itemsPerPage,
            },
            persist: true,
          );
          // log.d('✅ ListingsBloc ФАЗА 2: Данные успешно закеширован');
        } catch (e) {
          // log.d('⚠️ ListingsBloc ФАЗА 2: Ошибка кеширования: $e');
        }
      } catch (e) {
        // log.d('❌ ListingsBloc ФАЗА 2: Критическая ошибка: $e');
      }
    });
  }

  /// Конвертирует JSON обратно в Category из кеша.
  home.Category _jsonToCategory(Map<String, dynamic> json) {
    return home.Category(
      id: json['id'],
      title: json['title'] ?? '',
      color: Color(json['color'] ?? 0xFF00A6FF),
      imagePath: json['imagePath'] ?? '',
      isCatalog: json['isCatalog'] ?? true,
    );
  }

  /// � ВОССТАНОВЛЕНИЕ ИЗ КЕША: Публичный метод для восстановления данных при возврате на страницу
  /// Используется в didPopNext() для мгновенного показа кешированных данных
  /// Возвращает ListingsLoaded состояние если кеш есть, иначе null
  ListingsLoaded? restoreCachedData() {
    try {
      final cachedListings = AppCacheService().get<Map>(CacheKeys.listingsData);
      if (cachedListings != null &&
          cachedListings.containsKey('listings') &&
          cachedListings.containsKey('categories')) {
        try {
          final listings = (cachedListings['listings'] as List)
              .map((item) => _jsonToListing(item as Map<String, dynamic>))
              .toList();
          final categories = (cachedListings['categories'] as List)
              .map((item) => _jsonToCategory(item as Map<String, dynamic>))
              .toList();

          // log.d('🟢 Восстановлены данные из кеша! Объявлений: ${listings.length}, категорий: ${categories.length}');
          
          // 💾 Обновляем кеш для корректной работы поиска
          _cachedAllListings = listings;
          _cachedCategories = categories;
          
          return ListingsLoaded(
            listings: listings,
            categories: categories,
            currentPage: cachedListings['currentPage'] ?? 1,
            totalPages: cachedListings['totalPages'] ?? 1,
            itemsPerPage: cachedListings['itemsPerPage'] ?? 20,
          );
        } catch (e) {
          // log.w('⚠️ Ошибка при восстановлении из кеша: $e');
          return null;
        }
      }
    } catch (e) {
      // log.d('⚠️ Кеш недоступен: $e');
      return null;
    }
    return null;
  }

  /// �🔴 СЛОЙ 3: Преобразует ошибку в понятное для пользователя сообщение
  /// Различает TimeoutException, SocketException, 429 и другие ошибки
  String _getErrorMessage(Object error) {
    final errorStr = error.toString();
    
    if (errorStr.contains('TimeoutException')) {
      return 'Загрузка заняла слишком много времени. Проверьте интернет и попробуйте снова.';
    }
    if (errorStr.contains('SocketException')) {
      return 'Ошибка подключения. Проверьте интернет и попробуйте снова.';
    }
    if (errorStr.contains('429')) {
      return 'Слишком много запросов. Подождите немного и попробуйте снова.';
    }
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'Требуется повторная авторизация. Пожалуйста, выполните вход.';
    }
    if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
      return 'Доступ запрещен. Свяжитесь с поддержкой.';
    }
    if (errorStr.contains('500') || errorStr.contains('ServerException')) {
      return 'Ошибка сервера. Попробуйте позже.';
    }
    
    return 'Ошибка при загрузке объявлений. Попробуйте снова.';
  }
}

/// Функция для фонового парсинга объявлений на отдельном потоке.
/// Это предотвращает блокировку UI при обработке больших объемов JSON.
///
/// Используется с compute() для выполнения на изолированном потоке.
List<home.Listing> _parseAdvertsOnBackgroundThread(List<Advert> adverts) {
  return adverts.map((advert) => advert.toListing()).toList();
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'listings_event.dart';
import 'listings_state.dart';
import '../../models/home_models.dart' as home;
import '../../models/advert_model.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../../core/cache/cache_service.dart';
import '../../core/cache/cache_keys.dart';

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
  static final List<home.Listing> staticListings = [
    home.Listing(
      id: 'listing_1',
      imagePath: 'assets/home_page/apartment1.png',
      images: ['assets/home_page/apartment1.png', 'assets/home_page/image.png'],
      title: '4-к. квартира, 169,5 м²...',
      price: '78 970 000 ₽',
      location: 'Москва, ул. Кусинена, 21А',
      date: 'Сегодня',
      isFavorited: false,
    ),
    home.Listing(
      id: 'listing_2',
      imagePath: 'assets/home_page/acura_mdx.png',
      images: ['assets/home_page/acura_mdx.png'],
      title: 'Acura MDX 3.5 AT, 20...',
      price: '2 399 999 ₽',
      location: 'Брянск, Авиационная ул., 34',
      date: '29.08.2024',
      isFavorited: false,
    ),
    home.Listing(
      id: 'listing_3',
      imagePath: 'assets/home_page/acura_rdx.png',
      images: ['assets/home_page/acura_rdx.png'],
      title: 'Acura RDX 2.3 AT, 2007...',
      price: '2 780 000 ₽',
      location: 'Москва, Отрадная ул., 11',
      date: '29.08.2024',
      isFavorited: false,
    ),
    home.Listing(
      id: 'listing_4',
      imagePath: 'assets/home_page/studio.png',
      images: ['assets/home_page/studio.png', 'assets/home_page/image2.png'],
      title: 'Студия, 35,7 м², 2/6 эт...',
      price: '6 500 000 ₽',
      location: 'Москва, Варшавское ш., 125',
      date: '11.05.2024',
      isFavorited: false,
    ),
    home.Listing(
      id: 'listing_5',
      imagePath: 'assets/home_page/image.png',
      images: ['assets/home_page/image.png'],
      title: 'Студия, 35,7 м², 2/6 эт...',
      price: '6 500 000 ₽',
      location: 'Москва, Варшавское ш., 125',
      date: '11.05.2024',
      isFavorited: false,
    ),
    home.Listing(
      id: 'listing_6',
      imagePath: 'assets/home_page/image2.png',
      images: [
        'assets/home_page/image2.png',
        'assets/home_page/apartment1.png',
      ],
      title: '3-к. квартира, 125,5 м²...',
      price: '44 500 000 ₽ ',
      location: 'Москва, Истринская ул., 8к3',
      date: '09.08.2024',
      isFavorited: false,
    ),
  ];

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
    // 🔄 Кеширование: если данные уже загружены и это не принудительная загрузка (фреш),
    // и нет ошибок, просто вернёмся к сохранённому состоянию
    if (_isInitialLoadComplete &&
        !event.forceRefresh &&
        state is ListingsLoaded &&
        state is! ListingsError) {
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

      // 🚀 ФАЗА 1: Загружаем каталоги один раз (НЕ дважды!)
      final catalogsResponse = await ApiService.getCatalogs(token: token);
      final allCatalogIds = catalogsResponse.data.map((c) => c.id).toList();

      // 🚀 ОПТИМИЗАЦИЯ #2: Загружаем ВСЕ каталоги при первой загрузке
      // Это гарантирует, что все объявления (включая #142) отображаются на главной
      final firstCatalogIds = allCatalogIds;

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

      // 🔥 Загружаем объявления ИЗ ВСЕХ каталогов параллельно
      List<home.Listing> allListings = [];
      int totalPages = 1;
      int itemsPerPage = 50;

      if (firstCatalogIds.isNotEmpty) {
        // 🚀 ОПТИМИЗАЦИЯ: Уменьшиваем параллелизм с 5 на 2 для снижения пиковой нагрузки
        // и избежания RateLimitException (429 Too Many Requests)
        // При 2 параллельных запросов server восстанавливается между батчами
        const int maxConcurrentRequests = 2;
        
        for (int i = 0; i < firstCatalogIds.length; i += maxConcurrentRequests) {
          final batch = firstCatalogIds.sublist(
            i,
            (i + maxConcurrentRequests).clamp(0, firstCatalogIds.length),
          );

          final firstBatchFutures = batch
              .map(
                (catalogId) => ApiService.getAdverts(
                  catalogId: catalogId,
                  token: token,
                  page: 1,
                  limit: 50,
                ),
              )
              .toList();

          final firstBatchResponses = await Future.wait(firstBatchFutures);
          
          // ⏳ ОПТИМИЗАЦИЯ: Добавляем задержку между батчами чтобы не перегружать сервер
          // 200ms дает серверу время на восстановление между волнами запросов
          if (i + maxConcurrentRequests < firstCatalogIds.length) {
            await Future.delayed(const Duration(milliseconds: 200));
          }

          // Парсируем все ответы параллельно на фоновых потоках
          for (final response in firstBatchResponses) {
            if (response.data.isNotEmpty) {
              // 🚀 ОПТИМИЗАЦИЯ #3: Умный compute() - используем только для 50+ объявлений
              // Для малых списков синхронное парсирование быстрее
              List<home.Listing> parsedListings;

              if (response.data.length > 50) {
                // Для больших списков используем compute() на отдельном потоке
                parsedListings = await compute<List<Advert>, List<home.Listing>>(
                  (adverts) => _parseAdvertsOnBackgroundThread(adverts),
                  response.data,
                );
              } else {
                // Для малых списков синхронное парсирование (быстрее без overhead compute)
                parsedListings = _parseAdvertsOnBackgroundThread(response.data);
              }

              allListings.addAll(parsedListings);
              // Берем totalPages из последнего ответа, это обычно главный каталог
              // и наиболее точное значение
              totalPages = response.meta.lastPage;
              itemsPerPage = response.meta.perPage;
            }
          }
        }
        
        // 📌 ИСПРАВЛЕНИЕ: Если загружалось со всех каталогов, увеличиваем totalPages
        // В реальности может быть больше страниц, чем мы знаем
        if (firstCatalogIds.length > 1) {
          // Примерное увеличение для компенсации множественных каталогов
          totalPages = (totalPages * firstCatalogIds.length ~/ 2).clamp(5, 100);
          // print('📄 Расчетные страницы: $totalPages (каталогов: ${firstCatalogIds.length})');
        }
      }

      final sortedListings = _sortListingsByDate(allListings);

      // 🚀 ОПТИМИЗАЦИЯ #4: Гарантируем видимость skeleton минимум 500ms для лучшего UX
      // Это предотвращает мелькание между skeleton и контентом
      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 ФАЗА 1 ЗАВЕРШЕНА: Пользователь видит контент В ЭТОТ МОМЕНТ!
      emit(
        ListingsLoaded(
          listings: sortedListings,
          categories: loadedCategories,
          currentPage: 1,
          totalPages: totalPages,
          itemsPerPage: itemsPerPage,
        ),
      );

      _isInitialLoadComplete = true;

      // 🔄 ФАЗА 2: Загружаем остальные каталоги БЕЗ блокировки UI
      // Запускаем загрузку в фоне БЕЗ emit (только обновляем кеш)
      _loadPhase2InBackground(
        allCatalogIds,
        token,
        loadedCategories,
        sortedListings,
        totalPages,
        itemsPerPage,
      );
    } catch (e) {
      // Логируем ошибку для отладки
      // print('❌ ListingsBloc LoadListingsEvent ошибка: $e');
      // print('Stack trace: ${StackTrace.current}');
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события поиска объявлений.
  /// Выполняет поиск по заголовку и описанию объявлений.
  Future<void> _onSearchListings(
    SearchListingsEvent event,
    Emitter<ListingsState> emit,
  ) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки поиска
      await Future.delayed(const Duration(milliseconds: _searchDelayMs));

      final query = event.query.toLowerCase();
      final searchResults = currentState.listings.where((listing) {
        return listing.title.toLowerCase().contains(query) ||
            listing.location.toLowerCase().contains(query);
      }).toList();

      emit(
        ListingsSearchResults(searchResults: searchResults, query: event.query),
      );
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
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
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    emit(ListingsLoading());

    try {
      // Имитация задержки сброса фильтров
      await Future.delayed(const Duration(milliseconds: _filterDelayMs));

      emit(
        ListingsLoaded(
          listings: currentState.listings,
          categories: currentState.categories,
        ),
      );
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  /// Обработчик события загрузки одного объявления по ID.
  /// Загружает полные данные объявления из API.
  Future<void> _onLoadAdvert(
    LoadAdvertEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // print('Loading single advert for id ${event.advertId}');

    // 🔄 Проверяем кеш перед запросом к API
    final cacheKey = CacheKeys.advertKey(event.advertId);
    final cachedAdvert = AppCacheService().get<Map<String, dynamic>>(cacheKey);
    if (cachedAdvert != null) {
      try {
        // print('✅ ListingsBloc: Восстановили объявление из кеша');
        final listing = _jsonToListing(cachedAdvert);
        emit(AdvertLoaded(listing: listing));
        return;
      } catch (e) {
        // print();
      }
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

      // print('Loaded advert ${advert.id} with ${advert.images.length} images');

      // Преобразуем Advert в Listing
      final listing = advert.toListing();

      // print('Converted to listing with ${listing.images.length} images');

      // 💾 Сохраняем в унифицированный кеш (L1 + L2 Hive)
      // Обернуто в try-catch т.к. Hive может быть не инициализирован
      try {
        AppCacheService().set<Map<String, dynamic>>(
          cacheKey,
          _listingToJson(listing),
          persist: true,
        );
      } catch (e) {
        // Ошибка кеша - продолжаем работу
      }

      emit(AdvertLoaded(listing: listing));
    } catch (e) {
      // print('Failed to load advert: $e');
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

      // print('📄 Загрузка: ${currentState.listings.length} текущих, страница $nextPage...');

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

      // Объединяем существующие объявления с новыми
      final allListings = [...currentState.listings, ...newListings];

      // 📌 НЕ пересортируем при пагинации!
      // Пользователь ожидает видеть новые объявления внизу, а не в начале
      // Сортировка происходит только при первой загрузке

      // Извлекаем информацию о пагинации
      final totalPages = advertsResponse.meta.lastPage;
      final itemsPerPage = advertsResponse.meta.perPage;

      // print('✅ Загружено ${newListings.length} нов объявлений, всего: ${allListings.length}');

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
      // print('❌ Ошибка при загрузке следующей страницы: $e');
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
      // print();
      return;
    }

    // print('📄 Загрузка конкретной страницы ${event.pageNumber}...');

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

      // print();

      // Сортируем объявления по датам (новые в начале)
      final sortedListings = _sortListingsByDate(listings);

      // Извлекаем информацию о пагинации
      final totalPages = advertsResponse.meta.lastPage;
      final itemsPerPage = advertsResponse.meta.perPage;

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
        // print('Ошибка при парсировании даты "$dateStr": $e');
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
          print('✅ ListingsBloc ФАЗА 2: Данные успешно закеширован');
        } catch (e) {
          print('⚠️ ListingsBloc ФАЗА 2: Ошибка кеширования: $e');
        }
      } catch (e) {
        print('❌ ListingsBloc ФАЗА 2: Критическая ошибка: $e');
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
}

/// Функция для фонового парсинга объявлений на отдельном потоке.
/// Это предотвращает блокировку UI при обработке больших объемов JSON.
///
/// Используется с compute() для выполнения на изолированном потоке.
List<home.Listing> _parseAdvertsOnBackgroundThread(List<Advert> adverts) {
  return adverts.map((advert) => advert.toListing()).toList();
}

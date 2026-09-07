import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'listings_event.dart';
import 'listings_state.dart';
import '../../models/home_models.dart' as home;
import '../../models/advert_model.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../../services/user_service.dart';
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

  /// Сколько объявлений всего показываем на главной (задача 66).
  ///
  /// Главная это витрина, а не каталог: за полной выдачей человек уходит по
  /// кнопке «Показать больше». Двести штук это примерно десять экранов
  /// пролистывания — больше на главной никто не смотрит, а память и трафик
  /// расходуются на каждую карточку.
  static const int homeFeedLimit = 200;

  /// Размер порции при догрузке.
  ///
  /// Двенадцать: столько заказчик и обсуждал с фронтом, и столько же сервер
  /// отдаёт по умолчанию в ленте главной. Порция должна приходить быстро,
  /// иначе человек стоит у конца списка и ждёт.
  static const int homeFeedPageSize = 12;

  /// Номер последней запрошенной страницы общей ленты.
  ///
  /// Считаем сами, а не выводим из длины списка. Так было раньше:
  /// `listings.length ~/ 50 + 1`. Число 50 в этой формуле не имело отношения
  /// к тому, что реально отдавал сервер (он отдавал 30 и полностью
  /// игнорировал запрошенный размер), поэтому лента то перепрыгивала через
  /// десятки объявлений, то бесконечно перезапрашивала первую страницу.
  int _feedPage = 0;

  /// Сколько раз подряд догрузка не принесла ничего нового.
  ///
  /// Первые страницы общей ленты пересекаются с тем, что уже показано:
  /// начальная загрузка берёт объявления по каталогам. Пара пустых страниц
  /// это нормально, но если их подряд три, добирать больше нечего.
  int _emptyPages = 0;

  /// Есть ли на этом сервере лента главной (задача 70).
  ///
  /// Эндпоинт новый, и сервер может быть старее приложения: так и вышло при
  /// первой проверке, когда сборка смотрела на прод до выкладки. Тогда
  /// главная умирала целиком, вместе с лентой разделов, потому что весь экран
  /// падал в состояние ошибки. Теперь при 404 молча возвращаемся к обычному
  /// списку объявлений: он хуже (разделы снова неравномерны), но это рабочий
  /// экран вместо мёртвого.
  ///
  /// Признак сбрасывается на каждой полной загрузке, поэтому после выкладки
  /// приложение подхватит ленту само, без переустановки.
  bool _feedAvailable = true;

  /// Город, по которому лента получила приоритет, словами.
  ///
  /// Приходит с сервера вместе с лентой. Нужен, чтобы главная могла сказать
  /// человеку, почему выдача такая, и дать её сбросить: город берётся из
  /// профиля, а человек про это давно забыл.
  String? _feedCityName;

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
    on<ResetFeedCityEvent>(_onResetFeedCity);
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
    // 🔴 ИСПРАВЛЕНИЕ: Не применяем debounce если кеш был инвалидирован (он пуст)
    // Это необходимо чтобы после изменения профиля объявления перезагрузились
    if (event.forceRefresh && _lastRefreshTime != null) {
      // Проверяем: есть ли кеш? Если нет (был инвалидирован), не применяем debounce
      final hasCache = AppCacheService().get<Map>(CacheKeys.listingsData) != null;
      
      if (hasCache) {
        // Кеш есть - применяем debounce защиту
        final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
        if (timeSinceLastRefresh < _refreshDebounce) {
          // log.d('⏱️ Refresh дебоунсен: требуется ${_refreshDebounce.inSeconds}s между обновлениями ' +
              //     '(прошло ${timeSinceLastRefresh.inSeconds}s)');
          return;
        }
      } else {
        // log.d('🔄 Кеш инвалидирован - debounce НЕ применяется, загружаем свежие данные');
      }
    }

    _isLoadingListings = true;

    // Лента начинается заново: счётчик страниц догрузки тоже.
    _feedPage = 0;
    _emptyPages = 0;
    _feedAvailable = true;
    _feedCityName = null;

    if (event.forceRefresh) {
      _lastRefreshTime = DateTime.now();
      // 🔄 ВАЖНО: При forceRefresh сбрасываем флаг _isInitialLoadComplete чтобы гарантировать загрузку
      // Это особенно важно когда кеш был инвалидирован после изменения профиля
      _isInitialLoadComplete = false;
      log.d('🔄 ForceRefresh запущен - флаг _isInitialLoadComplete сброшен для гарантированной загрузки');
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
      // Каталоги нужны только для ленты разделов вверху экрана. Объявления
      // по ним больше не собираем: их отбирает сервер (задача 70).
      final catalogsResponse = await ApiService.getCatalogs(token: token);

      final loadedCategories = catalogsResponse.data
          .map(_catalogToCategory)
          .toList();

      loadedCategories.add(
        const home.Category(
          title: 'Смотреть\nвсе',
          color: Color(0xFF00A6FF),
          imagePath: '',
          isViewAll: true,
        ),
      );

      // Лента главного экрана приходит с сервера готовой (задача 70).
      //
      // Так было: приложение по очереди тянуло каталоги, склеивало их у себя
      // и сортировало по дате. Из-за этого на главной оказывалась почти одна
      // недвижимость: объявлений там больше всех, и по дате они забивали всё
      // остальное. Разложить разделы поровну на клиенте невозможно в
      // принципе, он видит только то, что успел загрузить.
      //
      // Теперь сервер сам отбирает до двухсот свежих объявлений за сутки,
      // раскладывает их равномерно по разделам и отдаёт страницами. Клиенту
      // остаётся показать первую порцию и догружать следующие при прокрутке.
      final feedPage = await _loadFeedPage(1, token);

      final firstBatchListings = feedPage.data.isEmpty
          ? <home.Listing>[]
          : await compute<List<Advert>, List<home.Listing>>(
              (adverts) => _parseAdvertsOnBackgroundThread(adverts),
              feedPage.data,
            );

      LoadingTimerService().stopLoadingTimer(
        operationKey,
        label: 'Listings (первая порция ленты)',
      );

      // Ленту НЕ пересортировываем. Порядок задал сервер: он чередует
      // разделы, чтобы первый экран не занимал один. Сортировка по дате
      // вернула бы ровно ту картину, из-за которой задачу и завели.
      _cachedAllListings = firstBatchListings;
      _cachedCategories = loadedCategories;

      _feedPage = 1;

      emit(
        ListingsLoaded(
          listings: firstBatchListings,
          categories: loadedCategories,
          currentPage: 1,
          totalPages: feedPage.meta.lastPage,
          itemsPerPage: feedPage.meta.perPage,
          hasMore: feedPage.meta.currentPage < feedPage.meta.lastPage,
          feedCityName: _feedCityName,
        ),
      );

      _isInitialLoadComplete = true;
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
    final query = event.query.trim();

    // Пустой запрос — возвращаемся к обычному списку из кеша.
    if (query.isEmpty) {
      if (_cachedAllListings.isNotEmpty) {
        emit(ListingsLoaded(
          listings: _cachedAllListings,
          categories: _cachedCategories,
        ));
      }
      return;
    }

    emit(ListingsLoading());

    try {
      // Небольшая задержка (debounce) — не дёргать бэкенд на каждый символ.
      await Future.delayed(const Duration(milliseconds: _searchDelayMs));

      final token = await TokenService.getCurrentToken();

      // 🔍 Глобальный поиск по заголовкам через бэкенд (по всем объявлениям).
      final response = await ApiService.getAdverts(
        search: query,
        token: token,
        page: 1,
        limit: 50,
      );

      // Парсим ответ в модели Listing тем же способом, что при загрузке.
      final List<home.Listing> searchResults =
          response.data.isNotEmpty
              ? await compute<List<Advert>, List<home.Listing>>(
                  (adverts) => _parseAdvertsOnBackgroundThread(adverts),
                  response.data,
                )
              : <home.Listing>[];

      log.i('🔍 Поиск на бэкенде: "$query" | Найдено: ${searchResults.length}');

      emit(
        ListingsSearchResults(
          searchResults: searchResults,
          query: event.query,
          categories: _cachedCategories,
        ),
      );
    } catch (e) {
      log.e('❌ Ошибка при поиске на бэкенде: $e');
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

  /// Догрузка следующей порции главной (задачи 66 и 70).
  ///
  /// С задачи 70 листаем ленту с сервера: он сам отобрал двести объявлений
  /// равномерно по разделам и держит их состав неизменным несколько минут,
  /// поэтому страницы не пересекаются и не пропускают.
  ///
  /// Что здесь было не так. Номер страницы считался как
  /// `listings.length ~/ 50 + 1`, а запрашивалось `limit: 100`. Ни то, ни
  /// другое не имело отношения к действительности: сервер размер страницы
  /// вообще не читал и всегда отдавал по 30. Поэтому после первой загрузки
  /// формула давала `30 ~/ 50 + 1 = 1`, то есть ту же самую первую страницу,
  /// все объявления в ней оказывались повторами, список не рос — и так каждые
  /// три секунды, пока человек стоял у конца ленты. Главная упиралась в три
  /// десятка объявлений и дальше не двигалась.
  ///
  /// Теперь размер страницы просит клиент, сервер его соблюдает, номер
  /// страницы считается честно, а лента останавливается на [homeFeedLimit].
  Future<void> _onLoadNextPage(
    LoadNextPageEvent event,
    Emitter<ListingsState> emit,
  ) async {
    // Проверяем, что текущее состояние - ListingsLoaded
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;

    // Добирать больше нечего: либо упёрлись в потолок главной, либо сервер
    // уже сказал, что страницы кончились.
    if (!currentState.hasMore ||
        currentState.listings.length >= homeFeedLimit) {
      if (currentState.hasMore) {
        emit(_withHasMore(currentState, false));
      }

      return;
    }

    try {
      // Получаем токен для аутентификации
      final token = TokenService.currentToken;

      // Ленту листаем по страницам сервера (задача 70). Номер держим сам:
      // выводить его из длины списка нельзя, там убраны повторы, и счёт
      // поедет.
      final nextPage = _feedPage + 1;

      final advertsResponse = await _loadFeedPage(nextPage, token);

      _feedPage = nextPage;

      if (advertsResponse.data.isEmpty) {
        emit(_withHasMore(currentState, false));

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

      // Страница пришла, но всё это уже показано. С серверной лентой такого
      // быть не должно: состав фиксирован и страницы не пересекаются. Счётчик
      // оставлен страховкой, чтобы лента не крутилась впустую, если состав
      // всё-таки поменяется между запросами.
      _emptyPages = uniqueNewListings.isEmpty ? _emptyPages + 1 : 0;

      // Объединяем существующие объявления с новыми (только с уникальными)
      // и обрезаем по потолку главной.
      final allListings = [
        ...currentState.listings,
        ...uniqueNewListings,
      ].take(homeFeedLimit).toList();

      // 📌 НЕ пересортируем при пагинации!
      // Пользователь ожидает видеть новые объявления внизу, а не в начале
      // Сортировка происходит только при первой загрузке

      // Извлекаем информацию о пагинации
      final totalPages = advertsResponse.meta.lastPage;
      final itemsPerPage = advertsResponse.meta.perPage;

      final hasMore = allListings.length < homeFeedLimit
          && nextPage < totalPages
          && _emptyPages < 3;

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
          hasMore: hasMore,
          feedCityName: _feedCityName,
        ),
      );
    } catch (e) {
      log.d('Не удалось догрузить страницу главной: $e');

      // Список НЕ выбрасываем.
      //
      // Так было: любая ошибка догрузки переводила экран в ListingsError, и
      // человек, долиставший до конца ленты, вместо своих объявлений видел
      // пустой экран с ошибкой. Уже показанное менять из-за неудачной
      // догрузки нельзя: оно на экране и оно верное. Просто перестаём
      // добирать.
      emit(_withHasMore(currentState, false));
    }
  }

  /// Сбросить город в профиле и перечитать ленту (задача 70).
  ///
  /// Сбрасываем на сервере, а не только у себя: приоритет считает сервер по
  /// профилю, и локальный флажок ничего бы не изменил. После сброса
  /// перечитываем главную целиком, иначе человек нажал бы кнопку и не увидел
  /// разницы.
  Future<void> _onResetFeedCity(
    ResetFeedCityEvent event,
    Emitter<ListingsState> emit,
  ) async {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) return;

    try {
      await UserService.clearAddress(token: token);
    } catch (e) {
      log.e('Не удалось сбросить город: $e');

      // Список не трогаем: он на экране и он верный. Молча оставить как есть
      // честнее, чем показать пустоту из-за неудачного сброса.
      return;
    }

    _feedCityName = null;

    add(LoadListingsEvent(forceRefresh: true));
  }

  /// Страница ленты главной, с запасным путём.
  ///
  /// Сначала спрашиваем ленту (задача 70). Если сервер про неё не знает и
  /// отвечает 404, один раз запоминаем это и дальше берём обычный список
  /// объявлений, как было до задачи. Любую другую ошибку пробрасываем: тихо
  /// подменять сломанный сервер запасным путём значит прятать поломку.
  Future<AdvertsResponse> _loadFeedPage(int page, String? token) async {
    if (_feedAvailable) {
      try {
        final feed = await ApiService.getHomeFeed(
          token: token,
          page: page,
          perPage: homeFeedPageSize,
        );

        _feedCityName = feed.cityName;

        return feed.response;
      } catch (e) {
        if (!e.toString().contains('404')) rethrow;

        log.w('Лента главной на этом сервере недоступна, беру обычный список');
        _feedAvailable = false;
        _feedCityName = null;
      }
    }

    return ApiService.getAdverts(
      catalogId: 1,
      token: token,
      page: page,
      limit: homeFeedPageSize,
    );
  }

  /// Тот же список, но с изменённым признаком «есть ещё».
  ListingsLoaded _withHasMore(ListingsLoaded state, bool hasMore) {
    return ListingsLoaded(
      listings: state.listings,
      categories: state.categories,
      filteredListings: state.filteredListings,
      currentPage: state.currentPage,
      totalPages: state.totalPages,
      itemsPerPage: state.itemsPerPage,
      hasMore: hasMore,
      feedCityName: state.feedCityName,
    );
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
  /// ВНУТРИ каждой даты объявления сортируются по ID в убывающем порядке (новые объявления с большим номером - первыми).
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

    // Функция для извлечения числового ID из строки
    int? parseIdAsInt(String idStr) {
      try {
        return int.parse(idStr);
      } catch (e) {
        return null;
      }
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

    // 🔧 Сортируем объявления "Сегодня" по ID в убывающем порядке (новые первыми)
    todayListings.sort((a, b) {
      final idA = parseIdAsInt(a.id);
      final idB = parseIdAsInt(b.id);

      if (idA == null || idB == null) {
        return 0; // Если не удалось распарсить ID, оставляем исходный порядок
      }

      // Сортируем в обратном порядке (больший ID сначала = более новые объявления)
      return idB.compareTo(idA);
    });

    // Сортируем остальные объявления от новых к старым ПО ДАТАМ,
    // а внутри каждой даты - по ID в убывающем порядке
    otherListings.sort((a, b) {
      final dateA = parseDate(a.date);
      final dateB = parseDate(b.date);

      if (dateA == null || dateB == null) {
        return 0; // Если не удалось распарсить, оставляем исходный порядок
      }

      // Сначала сравниваем по датам (новые сначала)
      final dateComparison = dateB.compareTo(dateA);
      if (dateComparison != 0) {
        return dateComparison;
      }

      // 🔧 НОВОЕ: Если даты одинаковые, сортируем по ID в убывающем порядке (новые объявления первыми)
      final idA = parseIdAsInt(a.id);
      final idB = parseIdAsInt(b.id);

      if (idA == null || idB == null) {
        return 0; // Если не удалось распарсить ID, оставляем исходный порядок
      }

      // Больший ID сначала = более новые объявления
      return idB.compareTo(idA);
    });

    // Объединяем: сначала 'Сегодня' (отсортированные по ID), потом отсортированные по датам (и внутри по ID)
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
      'isViewAll': category.isViewAll,
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
  /// БОЛЬШЕ НЕ ВЫЗЫВАЕТСЯ (задача 70).
  ///
  /// Догрузка остальных каталогов существовала, пока главную собирал сам
  /// клиент. Теперь ленту отбирает сервер, и склеивать каталоги не нужно.
  /// Метод оставлен до конца тестирования ленты: если что-то пойдёт не так,
  /// откатиться будет быстрее. Убрать вместе с _sortListingsByDate, когда
  /// лента отработает на проде.
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
        // На экран отдаём не больше потолка главной (задача 66). В кеше
        // выше список остаётся полным: по нему работает поиск, и обрезать
        // его значило бы сузить поиск заодно с лентой.
        emit(
          ListingsLoaded(
            listings: finalSortedListings.take(homeFeedLimit).toList(),
            categories: loadedCategories,
            currentPage: 1,
            totalPages: (finalSortedListings.length / 50).ceil(),
            itemsPerPage: 50,
            hasMore: finalSortedListings.length < homeFeedLimit,
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
      // Кеш от прежних версий этого поля не содержит: там опознаём служебную
      // карточку по отсутствию id, как её и создаёт блок.
      isViewAll: json['isViewAll'] ?? (json['id'] == null),
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

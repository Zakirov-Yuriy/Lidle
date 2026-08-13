import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/new_listing_notifier.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/responses_sort_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/indoor_advertising_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/outdoor_advertising_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_property_details_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/advert_qr_screen.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
// "Утилиты для форматирования"
// ============================================================
/// Форматирует цену: "1000000,00" → "1 000 000 ₽"
String _formatPriceWithRuble(String price) {
  if (price.isEmpty) return '₽';
  
  // Удаляем копейки (всё после запятой)
  final integerPart = price.contains(',') 
      ? price.split(',')[0] 
      : price.split('.')[0];
  
  // Добавляем пробелы между разрядами
  final parts = <String>[];
  for (var i = integerPart.length; i > 0; i -= 3) {
    final start = (i - 3) < 0 ? 0 : (i - 3);
    parts.insert(0, integerPart.substring(start, i));
  }
  
  final formatted = parts.join(' ');
  return '$formatted ₽';
}

// ============================================================

class MyListingsScreen extends StatefulWidget {
  static const routeName = '/my-listings';

  final int? categoryId;
  final int? tabIndex; // 0: Активные, 1: Неактивные, 2: Архив, 3: На модерации

  const MyListingsScreen({super.key, this.categoryId, this.tabIndex});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _currentTab = 0;
  int _selectedCatalogIndex = 0; // Индекс выбранного каталога (в _visibleCatalogs)
  int _selectedCategoryIndex = 0; // Индекс выбранной категории (в _advertMetaCategories)
  int? _selectedCatalogId; // ID выбранного каталога для сохранения выбора между вкладками
  int? _selectedCategoryId; // ID выбранной категории для фильтрации
  bool _selectAllChecked = false;
  bool _isSelectionMode = false; // Режим выбора
  Set<int> _selectedListingIds = {};

  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);
  static const greenColor = Color(0xFF00D084);

  List<String> _currentSort = ['По цене'];

  // Мета-данные объявлений (только каталоги и категории с объявлениями)
  List<AdvertMetaCatalog> _advertMetaCatalogs = [];
  // Каталоги, отфильтрованные под текущую вкладку: показываем только те,
  // где есть хотя бы одна категория с объявлениями в этой вкладке.
  List<AdvertMetaCatalog> _visibleCatalogs = [];
  // Категории выбранного каталога, отфильтрованные под текущую вкладку.
  List<AdvertMetaCategory> _advertMetaCategories = [];
  bool _isLoadingMetadata = false;
  String? _errorMessage;

  // Реальные объявления с API
  List<UserAdvert> _activeListings = [];
  List<UserAdvert> _inactiveListings = [];
  List<UserAdvert> _archiveListings = [];
  List<UserAdvert> _moderationListings = [];
  List<UserAdvert> _crmListings = []; // Объявления с фида на модерации (вкладка CRM)
  bool _crmLoading = false;
  List<UserAdvert> _manualListings = []; // Активные объявления, созданные вручную (вкладка «Все»)
  bool _manualLoading = false;
  // Размер страницы для ленивой подгрузки (infinite scroll).
  // Грузим по чуть-чуть и докидываем при прокрутке вниз, чтобы экран не висел
  // на аккаунтах с сотнями объявлений.
  static const int _pageSize = 20;

  // Контроллер внешнего скролла экрана: весь экран — это один ListView,
  // а вкладки внутри него нескроллируемые (shrinkWrap + NeverScrollable).
  // Поэтому «доскроллил до низа» ловим здесь, а не во вложенных списках.
  final ScrollController _outerScrollController = ScrollController();

  // Пагинация для каждого статуса
  int _activeListingsPage = 1;
  int _inactiveListingsPage = 1;
  int _archiveListingsPage = 1;
  int _moderationListingsPage = 1;
  int _manualListingsPage = 1;
  int _crmListingsPage = 1;

  // Является ли страница последней для каждого статуса
  bool _activeIsLastPage = false;
  bool _inactiveIsLastPage = false;
  bool _archiveIsLastPage = false;
  bool _moderationIsLastPage = false;
  bool _manualIsLastPage = false;
  bool _crmIsLastPage = false;

  // Полное количество объявлений в каждой вкладке (meta.total с сервера).
  // Нужно для подписей вкладок: показываем реальный тотал, а не сколько
  // уже подгрузилось на экран.
  int _activeTotal = 0;
  int _inactiveTotal = 0;
  int _archiveTotal = 0;
  int _moderationTotal = 0;
  int _manualTotal = 0;
  int _crmTotal = 0;

  bool _isLoadingMore = false;

  /// Флаг для отслеживания, загружены ли метаданные данные
  /// Предотвращает повторную загрузку при переходе между вкладками
  bool _metadataLoaded = false;

  /// Флаг для отслеживания загрузки объявлений по категориям
  /// Отдельно от _isLoadingMetadata для избежания конфликтов
  bool _listingsLoading = false;

  @override
  void initState() {
    super.initState();
    // Ленивая подгрузка: как только внешний скролл почти у дна — тянем
    // следующую страницу текущей вкладки.
    _outerScrollController.addListener(_onOuterScroll);
    _loadTabCounts(); // общие счётчики вкладок (видны всегда)
    _loadCrmListings();
    _loadManualListings();
    if (!_metadataLoaded) {
      _isLoadingMetadata = true;
      _loadAdvertMetadata().then((_) {
        // После загрузки метаданных установить категорию и вкладку из параметров
        if (widget.categoryId != null) {
          _setInitialCategoryAndTab();
        }
      });
    }
  }

  @override
  void dispose() {
    _outerScrollController.removeListener(_onOuterScroll);
    _outerScrollController.dispose();
    super.dispose();
  }

  /// Обработчик внешнего скролла: у дна экрана подгружаем следующую страницу
  /// текущей вкладки (за 300px до конца, чтобы подгрузка была плавной).
  void _onOuterScroll() {
    if (!_outerScrollController.hasClients) return;
    // Не докидываем страницы, пока идёт полная (пере)загрузка списков или
    // предыдущая подгрузка, либо если уже дошли до конца текущей вкладки.
    if (_isLoadingMore ||
        _listingsLoading ||
        _manualLoading ||
        _crmLoading ||
        _currentTabIsLastPage()) {
      return;
    }
    final position = _outerScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMoreListings();
    }
  }

  /// Достигнут ли конец списка для текущей вкладки.
  bool _currentTabIsLastPage() {
    switch (_currentTab) {
      case 0:
        return _activeIsLastPage;
      case 1:
        return _inactiveIsLastPage;
      case 2:
        return _archiveIsLastPage;
      case 3:
        return _moderationIsLastPage;
      case 4:
        return _crmIsLastPage;
      case 5:
        return _manualIsLastPage;
      default:
        return true;
    }
  }

  /// Установить начальную категорию и вкладку из параметров конструктора
  void _setInitialCategoryAndTab() {
    try {
      final categoryId = widget.categoryId;
      final tabIndex =
          widget.tabIndex ?? 3; // По умолчанию вкладка "На модерации"

      if (categoryId == null) return;

      // Найти категорию в загруженных метаданных
      for (
        int catalogIdx = 0;
        catalogIdx < _advertMetaCatalogs.length;
        catalogIdx++
      ) {
        final catalog = _advertMetaCatalogs[catalogIdx];
        for (int catIdx = 0; catIdx < catalog.categories.length; catIdx++) {
          final category = catalog.categories[catIdx];
          if (category.categoryId == categoryId) {
            // Нашли нужную категорию. Фиксируем выбор и пересчитываем видимые
            // чипсы под нужную вкладку (чтобы каталог/категория совпали с ней).
            if (mounted) {
              setState(() {
                _currentTab = tabIndex;
                _selectedCatalogId = catalog.catalogId;
                _selectedCategoryId = categoryId;
                _recomputeVisibleForTab(tabIndex);
              });
            }
            // Загрузить объявления для этой категории
            if (_selectedCategoryId != null) {
              _loadListingsByCategory(_selectedCategoryId!);
            }
            return;
          }
        }
      }
    } catch (e) {
      // log.d('Error setting initial category and tab: $e');
    }
  }

  /// Опубликовать объявление из вкладки CRM (кнопка "Опубликовать").
  Future<void> _publishFromCrm(UserAdvert advert) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.publishAdvert(
        advertId: advert.id,
        token: token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Объявление опубликовано'),
            backgroundColor: Colors.green,
          ),
        );
        // Обновляем ВСЕ списки и счётчики: объявление уходит из CRM в
        // активные/«Все», поэтому одного _loadCrmListings недостаточно.
        await _refreshAfterMutation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка публикации: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Загрузить ОПУБЛИКОВАННЫЕ объявления из фида (вкладка CRM).
  /// Это активные объявления пользователя, пришедшие из CRM-фида —
  /// сюда они попадают после нажатия «Опубликовать» на экране предпросмотра.
  /// Есть ли объявления этой категории в указанной вкладке (по флагам с бэка).
  /// Если флаг не пришёл (старый бэк) — считаем, что есть (показываем как раньше).
  bool _categoryInTab(AdvertMetaCategory c, int tab) {
    switch (tab) {
      case 0: // Активные
        return c.hasActive ?? true;
      case 1: // Неактивные
        return c.hasInactive ?? true;
      case 2: // Архив
        return c.hasArchive ?? true;
      case 3: // На модерации
        return c.hasModeration ?? true;
      case 4: // CRM
        return c.hasCrm ?? true;
      case 5: // Все
        return c.hasManual ?? true;
      default:
        return true;
    }
  }

  /// Категории каталога, доступные в текущей вкладке.
  List<AdvertMetaCategory> _categoriesInCatalogForTab(
    AdvertMetaCatalog catalog,
    int tab,
  ) => catalog.categories.where((c) => _categoryInTab(c, tab)).toList();

  /// Каталоги, у которых есть хотя бы одна категория в текущей вкладке.
  List<AdvertMetaCatalog> _catalogsForTab(int tab) => _advertMetaCatalogs
      .where((cat) => _categoriesInCatalogForTab(cat, tab).isNotEmpty)
      .toList();

  /// Пересчитать видимые каталоги/категории под вкладку [tab]. Сохраняет
  /// текущий выбор каталога/категории, если он остаётся доступным, иначе берёт
  /// первый. Меняет ТОЛЬКО поля состояния — вызывать внутри setState, без
  /// сетевых загрузок.
  void _recomputeVisibleForTab(int tab) {
    final catalogs = _catalogsForTab(tab);
    _visibleCatalogs = catalogs;

    if (catalogs.isEmpty) {
      _advertMetaCategories = const [];
      _selectedCatalogIndex = 0;
      _selectedCategoryIndex = 0;
      _selectedCatalogId = null;
      _selectedCategoryId = null;
      return;
    }

    // Сохранить выбранный каталог, если он есть в этой вкладке, иначе первый.
    int catalogIdx = 0;
    if (_selectedCatalogId != null) {
      final idx = catalogs.indexWhere((c) => c.catalogId == _selectedCatalogId);
      if (idx >= 0) catalogIdx = idx;
    }
    _selectedCatalogIndex = catalogIdx;
    _selectedCatalogId = catalogs[catalogIdx].catalogId;

    final categories = _categoriesInCatalogForTab(catalogs[catalogIdx], tab);
    _advertMetaCategories = categories;

    if (categories.isEmpty) {
      _selectedCategoryIndex = 0;
      _selectedCategoryId = null;
      return;
    }

    // Сохранить выбранную категорию, если она есть в этой вкладке, иначе первую.
    int catIdx = 0;
    if (_selectedCategoryId != null) {
      final idx = categories.indexWhere(
        (c) => c.categoryId == _selectedCategoryId,
      );
      if (idx >= 0) catIdx = idx;
    }
    _selectedCategoryIndex = catIdx;
    _selectedCategoryId = categories[catIdx].categoryId;
  }

  /// Переключение вкладки: пересчитываем чипсы под вкладку и, если выбранная
  /// категория сменилась (в новой вкладке прежней нет), перезагружаем списки.
  void _onTabChanged(int tab) {
    final int? prevCategoryId = _selectedCategoryId;
    setState(() {
      _currentTab = tab;
      _recomputeVisibleForTab(tab);
    });
    if (_selectedCategoryId != null && _selectedCategoryId != prevCategoryId) {
      _loadListingsByCategory(_selectedCategoryId!);
    }
  }

  Future<void> _loadCrmListings() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      if (mounted) setState(() => _crmLoading = true);

      final response = await MyAdvertsService.getCrmPublishedList(
        token: token,
        page: 1,
        limit: _pageSize,
        categoryId: _selectedCategoryId,
      );

      if (mounted) {
        setState(() {
          _crmListings = response.data;
          _crmListingsPage = 1;
          _crmIsLastPage = 1 >= (response.lastPage ?? 1);
          _crmLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _crmLoading = false);
    }
  }

  /// Загрузить активные объявления, созданные ВРУЧНУЮ (вкладка «Все»).
  /// Фидовые объявления сюда не попадают — их бэк исключает по manual_only=1.
  /// ВАЖНО: вкладка «Все» показывает объявления по ВСЕМ категориям и не
  /// фильтруется чипсом категории (как на сайте), поэтому categoryId не шлём.
  Future<void> _loadManualListings() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      if (mounted) setState(() => _manualLoading = true);

      final response = await MyAdvertsService.getMyAdverts(
        token: token,
        statusId: 1, // active
        manualOnly: true,
        page: 1,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _manualListings = response.data;
          _manualListingsPage = 1;
          _manualIsLastPage = 1 >= (response.lastPage ?? 1);
          _manualLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _manualLoading = false);
    }
  }

  /// Загружает ОБЩИЕ счётчики для вкладок «Активные», «Все» и «CRM» — они не
  /// зависят от выбранной категории (эти вкладки показывают объявления по всем
  /// категориям), поэтому цифры видны всегда и совпадают со списками.
  /// Счётчики «Неактивные»/«Архив»/«На модерации» считаются по выбранной
  /// категории в _loadListingsByCategory/_loadListingsByCatalog (без изменений).
  Future<void> _loadTabCounts() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      final results = await Future.wait([
        // Все активные (и ручные, и из фида).
        MyAdvertsService.getMyAdverts(statusId: 1, token: token, page: 1, limit: _pageSize),
        // CRM.
        MyAdvertsService.getCrmPublishedList(token: token, page: 1, limit: _pageSize),
        // «Все» — созданные вручную активные (statusId 1 + manual_only).
        MyAdvertsService.getMyAdverts(statusId: 1, manualOnly: true, token: token, page: 1, limit: _pageSize),
      ]);

      if (!mounted) return;
      setState(() {
        _activeTotal = results[0].meta?.total ?? results[0].data.length;
        _crmTotal = results[1].meta?.total ?? results[1].data.length;
        _manualTotal = results[2].meta?.total ?? results[2].data.length;
      });
    } catch (_) {
      // Счётчики не критичны — молча игнорируем.
    }
  }

  /// Загрузить мета-информацию объявлений (каталоги и категории с объявлениями)
  Future<void> _loadAdvertMetadata() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingMetadata = false;
            _errorMessage = 'Токен не найден';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoadingMetadata = true);
      }

      final response = await MyAdvertsService.getAdvertsMeta(token: token);

      if (response.data.isNotEmpty) {
        final metaData = response.data[0];
        if (mounted) {
          setState(() {
            _advertMetaCatalogs = metaData.catalogs;

            // Подбираем видимые каталоги/категории под текущую вкладку и
            // выбираем первую доступную категорию для фильтра. Каталоги и
            // категории показываем только те, что реально есть в этой вкладке.
            _recomputeVisibleForTab(_currentTab);

            _isLoadingMetadata = false;
            _metadataLoaded = true;
          });

          // Если на текущей вкладке объявлений нет, переключаемся на первую
          // непустую вкладку (в порядке отображения: CRM, Все, Активные,
          // Неактивные, Архив, На модерации), чтобы пользователь сразу видел
          // контент, а не пустой экран.
          if (_selectedCategoryId == null) {
            const tabOrder = [4, 5, 0, 1, 2, 3];
            for (final t in tabOrder) {
              if (_catalogsForTab(t).isNotEmpty) {
                setState(() {
                  _currentTab = t;
                  _recomputeVisibleForTab(t);
                });
                break;
              }
            }
          }

          // Грузим по ВЫБРАННОЙ категории (в UI подсвечена первая категория,
          // _selectedCategoryIndex = 0). Раньше тут грузилось по всему каталогу
          // (все категории), из-за чего счётчики «Активные»/«На модерации» были
          // завышены и «исправлялись» только после повторного выбора той же
          // категории. Теперь начальная загрузка сразу совпадает с фильтром.
          if (_selectedCategoryId != null) {
            await _loadListingsByCategory(_selectedCategoryId!);
          } else if (_selectedCatalogId != null) {
            await _loadListingsByCatalog(_selectedCatalogId!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
          _errorMessage = 'Ошибка загрузки мета-информации: $e';
          _metadataLoaded = true;
        });
      }
    }
  }

  /// Загрузить объявления по всему каталогу (все страницы)
  Future<void> _loadListingsByCatalog(int catalogId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Токен не найден';
          });
        }
        return;
      }

      // Используем отдельный флаг для загрузки объявлений
      if (mounted) {
        setState(() => _listingsLoading = true);
      }

      // Запасной путь (когда категория не определилась). Тоже грузим только
      // первую страницу по каждому статусу.
      final results = await Future.wait([
        // «Активные» — все активные (и ручные, и из фида) по ВСЕМ категориям.
        MyAdvertsService.getMyAdverts(
            statusId: 1, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 2, catalogId: catalogId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 3, catalogId: catalogId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 8, catalogId: catalogId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getCrmPublishedList(
            catalogId: catalogId, token: token, page: 1, limit: _pageSize),
        // «Все» — ручные активные по ВСЕМ категориям (без фильтра каталога).
        MyAdvertsService.getMyAdverts(
            statusId: 1, manualOnly: true, token: token, page: 1, limit: _pageSize),
      ]);

      if (mounted) {
        setState(() {
          _activeListings = results[0].data;
          _inactiveListings = results[1].data;
          _moderationListings = results[2].data;
          _archiveListings = results[3].data;
          _crmListings = results[4].data;
          _manualListings = results[5].data;

          _activeListingsPage = 1;
          _inactiveListingsPage = 1;
          _moderationListingsPage = 1;
          _archiveListingsPage = 1;
          _crmListingsPage = 1;
          _manualListingsPage = 1;

          // Активные/Все/CRM — общие счётчики (см. _loadTabCounts). А для
          // Неактивных/Модерации/Архива счётчик по выбранной категории — как
          // и раньше, чтобы совпадал с их отфильтрованным списком.
          _inactiveTotal = results[1].meta?.total ?? results[1].data.length;
          _moderationTotal = results[2].meta?.total ?? results[2].data.length;
          _archiveTotal = results[3].meta?.total ?? results[3].data.length;

          _activeIsLastPage = 1 >= (results[0].lastPage ?? 1);
          _inactiveIsLastPage = 1 >= (results[1].lastPage ?? 1);
          _moderationIsLastPage = 1 >= (results[2].lastPage ?? 1);
          _archiveIsLastPage = 1 >= (results[3].lastPage ?? 1);
          _crmIsLastPage = 1 >= (results[4].lastPage ?? 1);
          _manualIsLastPage = 1 >= (results[5].lastPage ?? 1);

          _isLoadingMore = false;
          _listingsLoading = false;
        });

        // 📢 Проверяем - может это только что созданное объявление, которое теперь активно?
        // (т.е. прошло модерацию и стало видно в списке активных)
        if (_activeListings.isNotEmpty) {
          for (final advert in _activeListings) {
            if (NewListingNotifier.instance.isLastCreatedAdvert(advert.id)) {
              // Это наше недавно созданное объявление! Показываем PublishedScreen один раз
              NewListingNotifier.instance.notify(advert);
              break;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _listingsLoading = false;
          _errorMessage = 'Ошибка загрузки объявлений: $e';
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Ошибка загрузки')),
        );
      }
    }
  }

  /// Загрузить объявления по выбранной категории (первая страница) - для фильтрации
  Future<void> _loadListingsByCategory(int categoryId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Токен не найден';
          });
        }
        return;
      }

      // Используем отдельный флаг для загрузки объявлений
      if (mounted) {
        setState(() => _listingsLoading = true);
      }

      // Грузим ТОЛЬКО первую страницу каждого статуса (по _pageSize штук).
      // Остальное подтянется лениво при прокрутке вниз (_loadMoreListings).
      // «Активные» (results[0]) и «Все» (results[5]) — по ВСЕМ категориям.
      // «Неактивные/Модерация/Архив» и «CRM» — по выбранной категории.
      final results = await Future.wait([
        // «Активные» — все активные (и ручные, и из фида) по ВСЕМ категориям.
        MyAdvertsService.getMyAdverts(
            statusId: 1, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 2, categoryId: categoryId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 3, categoryId: categoryId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getMyAdverts(
            statusId: 8, categoryId: categoryId, token: token, page: 1, limit: _pageSize),
        MyAdvertsService.getCrmPublishedList(
            categoryId: categoryId, token: token, page: 1, limit: _pageSize),
        // «Все» — ручные активные по ВСЕМ категориям (без фильтра категории).
        MyAdvertsService.getMyAdverts(
            statusId: 1, manualOnly: true, token: token, page: 1, limit: _pageSize),
      ]);

      if (mounted) {
        setState(() {
          // Порядок: [0]=1 активные, [1]=2 неактивные, [2]=3 модерация,
          // [3]=8 архив, [4]=CRM, [5]=Все (ручные активные).
          _activeListings = results[0].data;
          _inactiveListings = results[1].data;
          _moderationListings = results[2].data;
          _archiveListings = results[3].data;
          _crmListings = results[4].data;
          _manualListings = results[5].data;

          _activeListingsPage = 1;
          _inactiveListingsPage = 1;
          _moderationListingsPage = 1;
          _archiveListingsPage = 1;
          _crmListingsPage = 1;
          _manualListingsPage = 1;

          // Активные/Все/CRM — общие счётчики (см. _loadTabCounts). Для
          // Неактивных/Модерации/Архива счётчик по выбранной категории — как
          // и раньше, чтобы совпадал с их отфильтрованным списком.
          _inactiveTotal = results[1].meta?.total ?? results[1].data.length;
          _moderationTotal = results[2].meta?.total ?? results[2].data.length;
          _archiveTotal = results[3].meta?.total ?? results[3].data.length;

          _activeIsLastPage = 1 >= (results[0].lastPage ?? 1);
          _inactiveIsLastPage = 1 >= (results[1].lastPage ?? 1);
          _moderationIsLastPage = 1 >= (results[2].lastPage ?? 1);
          _archiveIsLastPage = 1 >= (results[3].lastPage ?? 1);
          _crmIsLastPage = 1 >= (results[4].lastPage ?? 1);
          _manualIsLastPage = 1 >= (results[5].lastPage ?? 1);

          _isLoadingMore = false;
          _listingsLoading = false;
        });

        // 📢 Проверяем - может это только что созданное объявление, которое теперь активно?
        // (т.е. прошло модерацию и стало видно в списке активных)
        if (_activeListings.isNotEmpty) {
          for (final advert in _activeListings) {
            if (NewListingNotifier.instance.isLastCreatedAdvert(advert.id)) {
              // Это наше недавно созданное объявление! Показываем PublishedScreen один раз
              NewListingNotifier.instance.notify(advert);
              break;
            }
          }
        }
      }
    } catch (e) {
      // log.d('=== Ошибка загрузки объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _listingsLoading = false;
          _errorMessage = 'Ошибка загрузки объявлений: $e';
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Ошибка загрузки')),
        );
      }
    }
  }

  /// id статуса объявлений для вкладок, которые фильтруются по категории.
  /// ВАЖНО: архив это 8, модерация это 3 (раньше тут было перепутано).
  int _statusIdForTab(int tab) {
    switch (tab) {
      case 0:
        return 1; // активные
      case 1:
        return 2; // неактивные
      case 2:
        return 8; // архив
      case 3:
        return 3; // модерация (бэк отдаёт статусы 3 и 4)
      default:
        return 1;
    }
  }

  /// Текущая загруженная страница вкладки.
  int _pageForTab(int tab) {
    switch (tab) {
      case 0:
        return _activeListingsPage;
      case 1:
        return _inactiveListingsPage;
      case 2:
        return _archiveListingsPage;
      case 3:
        return _moderationListingsPage;
      case 4:
        return _crmListingsPage;
      case 5:
        return _manualListingsPage;
      default:
        return 1;
    }
  }

  /// Полное количество объявлений во вкладке (meta.total с сервера).
  int _tabTotal(int tab) {
    switch (tab) {
      case 4:
        return _crmTotal;
      case 5:
        return _manualTotal;
      case 0:
        return _activeTotal;
      case 1:
        return _inactiveTotal;
      case 2:
        return _archiveTotal;
      case 3:
        return _moderationTotal;
      default:
        return 0;
    }
  }

  /// Подпись вкладки с числом (или без числа, если пусто).
  /// Число берём из meta.total, чтобы показывать реальный тотал, а не
  /// сколько строк уже подгрузилось на экран при ленивой прокрутке.
  String _tabLabel(int tab) {
    const names = {
      4: 'CRM',
      5: 'Все',
      0: 'Активные',
      1: 'Неактивные',
      2: 'Архив',
      3: 'На модерации',
    };
    final name = names[tab] ?? '';
    final total = _tabTotal(tab);
    return total > 0 ? '$name $total' : name;
  }

  /// Загрузить следующую страницу текущей вкладки (ленивая подгрузка).
  Future<void> _loadMoreListings() async {
    if (_isLoadingMore || _currentTabIsLastPage()) return;

    final int tab = _currentTab;

    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      if (mounted) {
        setState(() => _isLoadingMore = true);
      }

      final int nextPage = _pageForTab(tab) + 1;
      final MyAdvertsResponse response;

      if (tab == 4) {
        // CRM — отдельный эндпоинт, с фильтром по выбранной категории.
        response = await MyAdvertsService.getCrmPublishedList(
          token: token,
          page: nextPage,
          limit: _pageSize,
          categoryId: _selectedCategoryId,
        );
      } else if (tab == 5) {
        // «Все» — ручные активные по ВСЕМ категориям (без фильтра категории).
        response = await MyAdvertsService.getMyAdverts(
          token: token,
          statusId: 1,
          manualOnly: true,
          page: nextPage,
          limit: _pageSize,
        );
      } else if (tab == 0) {
        // «Активные» — все активные по ВСЕМ категориям (без фильтра категории).
        response = await MyAdvertsService.getMyAdverts(
          statusId: 1,
          token: token,
          page: nextPage,
          limit: _pageSize,
        );
      } else {
        // Неактивные/архив/модерация — по выбранной категории.
        response = await MyAdvertsService.getMyAdverts(
          statusId: _statusIdForTab(tab),
          categoryId: _selectedCategoryId,
          token: token,
          page: nextPage,
          limit: _pageSize,
        );
      }

      if (!mounted) return;

      final int loadedPage = response.page ?? nextPage;
      final bool isLast = loadedPage >= (response.lastPage ?? 1);
      // Для Неактивных/Архива/Модерации держим счётчик в синхроне со списком
      // (он по категории). Активные/Все/CRM — общий счётчик (_loadTabCounts).
      final int total = response.meta?.total ?? 0;

      setState(() {
        switch (tab) {
          case 0:
            _activeListings.addAll(response.data);
            _activeListingsPage = loadedPage;
            _activeIsLastPage = isLast;
            break;
          case 1:
            _inactiveListings.addAll(response.data);
            _inactiveListingsPage = loadedPage;
            _inactiveIsLastPage = isLast;
            if (total > 0) _inactiveTotal = total;
            break;
          case 2:
            _archiveListings.addAll(response.data);
            _archiveListingsPage = loadedPage;
            _archiveIsLastPage = isLast;
            if (total > 0) _archiveTotal = total;
            break;
          case 3:
            _moderationListings.addAll(response.data);
            _moderationListingsPage = loadedPage;
            _moderationIsLastPage = isLast;
            if (total > 0) _moderationTotal = total;
            break;
          case 4:
            _crmListings.addAll(response.data);
            _crmListingsPage = loadedPage;
            _crmIsLastPage = isLast;
            break;
          case 5:
            _manualListings.addAll(response.data);
            _manualListingsPage = loadedPage;
            _manualIsLastPage = isLast;
            break;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      // log.d('=== Ошибка загрузки дополнительных объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ResponsesSortDialog(
          currentSort: _currentSort,
          onSortChanged: (newSort) {
            setState(() {
              _currentSort = newSort;
            });
          },
        ),
      ),
    );
  }

  void _showDeleteMultipleDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 24),
                  const Text(
                    'Удалить публикации',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Внимание: ',
                          style: TextStyle(color: Color(0xFFE8FF00)),
                        ),
                        TextSpan(
                          text: 'если вы хотите\nудалить выбранные публикации.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Подтвердите действие',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _deleteSelected();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Подтвердить',
                        style: TextStyle(color: Color(0xFF00B7FF)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _loadAdvertMetadata();
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }

          return BlocListener<NavigationBloc, NavigationState>(
            listener: (context, state) {
              if (state is NavigationToProfile ||
                  state is NavigationToHome ||
                  state is NavigationToFavorites ||
                  state is NavigationToMessages) {
                context.read<NavigationBloc>().executeNavigation(context);
              }
            },
            listenWhen: (previous, current) =>
                current is NavigationToProfile ||
                current is NavigationToHome ||
                current is NavigationToFavorites ||
                current is NavigationToMessages,
            child: Scaffold(
              extendBody: true,
              backgroundColor: primaryBackground,
              body: SafeArea(
                bottom: false,
                child: ListView(
                  controller: _outerScrollController,
                  children: [
                    // ───── Header ─────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20, right: 25),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Header(),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),

                    // ───── Back / Cancel ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) {
                                // Если режим выбора активен - отменяем выбор
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedListingIds.clear();
                                  _selectAllChecked = false;
                                });
                              } else {
                                // Иначе возвращаемся на предыдущий экран
                                Navigator.pop(context);
                              }
                            },
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Color.fromARGB(255, 255, 255, 255),
                              size: 16,
                            ),
                          ),
                          const Text(
                            'Активные / Неактивные',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showSortDialog,
                            child: const Icon(
                              Icons.swap_vert,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───── Catalog ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Каталог',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingMetadata)
                            _buildCatalogSkeleton()
                          else if (_visibleCatalogs.isEmpty)
                            const Center(
                              child: Text(
                                'Каталоги не найдены',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  _visibleCatalogs.length,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          index < _visibleCatalogs.length - 1
                                          ? 8
                                          : 0,
                                    ),
                                    child: _catalogButton(
                                      _visibleCatalogs[index].name,
                                      _selectedCatalogIndex == index,
                                      onPressed: () {
                                        // Категории выбранного каталога под
                                        // текущую вкладку.
                                        final categories =
                                            _categoriesInCatalogForTab(
                                              _visibleCatalogs[index],
                                              _currentTab,
                                            );
                                        setState(() {
                                          _selectedCatalogIndex = index;
                                          _selectedCatalogId =
                                              _visibleCatalogs[index].catalogId;
                                          _advertMetaCategories = categories;
                                          _selectedCategoryIndex = 0;
                                          _selectedCategoryId = categories.isEmpty
                                              ? null
                                              : categories[0].categoryId;
                                        });
                                        // Загрузить объявления первой категории нового каталога
                                        if (_selectedCategoryId != null) {
                                          _loadListingsByCategory(
                                            _selectedCategoryId!,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───── Categories ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Категории',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingMetadata)
                            _buildCategoriesSkeleton()
                          else if (_advertMetaCategories.isEmpty)
                            const Center(
                              child: Text(
                                'Категории не найдены',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  _advertMetaCategories.length,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          index <
                                              _advertMetaCategories.length - 1
                                          ? 8
                                          : 0,
                                    ),
                                    child: _catalogButton(
                                      _advertMetaCategories[index].name,
                                      _selectedCategoryIndex == index,
                                      onPressed: () {
                                        final categoryId =
                                            _advertMetaCategories[index]
                                                .categoryId;
                                        setState(() {
                                          _selectedCategoryIndex = index;
                                          // Обновить ID категории для фильтрации
                                          _selectedCategoryId = categoryId;
                                        });
                                        // Загрузить объявления для выбранной категории
                                        _loadListingsByCategory(categoryId);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───── Tabs ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(4),
                                      child: Text(
                                        _tabLabel(4),
                                        style: TextStyle(
                                          color: _currentTab == 4
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(5),
                                      child: Text(
                                        _tabLabel(5),
                                        style: TextStyle(
                                          color: _currentTab == 5
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(0),
                                      child: Text(
                                        _tabLabel(0),
                                        style: TextStyle(
                                          color: _currentTab == 0
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(1),
                                      child: Text(
                                        _tabLabel(1),
                                        style: TextStyle(
                                          color: _currentTab == 1
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(2),
                                      child: Text(
                                        _tabLabel(2),
                                        style: TextStyle(
                                          color: _currentTab == 2
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          _onTabChanged(3),
                                      child: Text(
                                        _tabLabel(3),
                                        style: TextStyle(
                                          color: _currentTab == 3
                                              ? accentColor
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                Stack(
                                  children: [
                                    Container(
                                      height: 1,
                                      width: _getTabsTotalWidth(),
                                      color: Colors.white24,
                                    ),
                                    AnimatedPositioned(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      left: _getTabPosition(_currentTab),
                                      child: Container(
                                        height: 2,
                                        width: _getTabWidth(_currentTab),
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───── Select all section ─────
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Row(
                          children: [
                            CustomCheckbox(
                              value: _selectAllChecked,
                              onChanged: (value) {
                                setState(() {
                                  _selectAllChecked = value;
                                  if (_selectAllChecked) {
                                    // Select all listings from current tab
                                    final currentListings =
                                        _getCurrentTabListings();
                                    _selectedListingIds.addAll(
                                      currentListings.map((l) => l.id),
                                    );
                                  } else {
                                    _selectedListingIds.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Выбрать все',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedListingIds.isNotEmpty) ...[
                              if (_currentTab != 3) ...[
                                GestureDetector(
                                  onTap: () {
                                    _moveToArchive();
                                  },
                                  child: Text(
                                    _currentTab == 2 ? 'Из архива' : 'В архив',
                                    style: const TextStyle(
                                      color: accentColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 1,
                                  height: 19,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 10),
                              ],
                              GestureDetector(
                                onTap: () {
                                  _showDeleteMultipleDialog();
                                },
                                child: const Text(
                                  'Удалить',
                                  style: TextStyle(
                                    color: Color(0xFFFF3B30),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // ───── Content ─────
                    _buildTabContent(),
                    SizedBox(
                      height: bottomNavHeight + bottomNavPaddingBottom + 16,
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: BottomNavigation(
                onItemSelected: (index) {
                  if (index == 3) {
                    // Shopping cart icon
                    context.read<NavigationBloc>().add(
                      NavigateToMyPurchasesEvent(),
                    );
                  } else {
                    context.read<NavigationBloc>().add(
                      SelectNavigationIndexEvent(index),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVE TAB
  // ─────────────────────────────────────────────

  Widget _activeTab() {
    // Вкладка «Активные» = активные объявления выбранной категории (статус 1).
    // Бэк в этом списке уже отдаёт и ручные, и фидовые активные, поэтому
    // отдельно подмешивать CRM не нужно (иначе счётчик задваивался и не
    // совпадал с сайтом, плюс ломалась ленивая подгрузка). Опубликованные
    // из фида отдельно доступны на вкладке «CRM».
    final filteredListings = _activeListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Активные пусты',
        'У вас нет активных объявлений,\nкак только вы добавите\nобъявление оно тут появится',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels == metrics.maxScrollExtent &&
              !_activeIsLastPage &&
              !_isLoadingMore) {
            _loadMoreListings();
          }
        }
        return false;
      },
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < filteredListings.length; i++) ...[
            _listingCard(filteredListings[i], 0),
            if (i < filteredListings.length - 1) const SizedBox(height: 10),
          ],
          // Индикатор подгрузки
          if (_isLoadingMore) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // INACTIVE TAB
  // ─────────────────────────────────────────────

  Widget _inactiveTab() {
    final filteredListings = _inactiveListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Неактивные пусты',
        'У вас нет неактивных объявлений,\nкак только вы деактивируете\nобъявление оно тут появится',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels == metrics.maxScrollExtent &&
              !_inactiveIsLastPage &&
              !_isLoadingMore) {
            _loadMoreListings();
          }
        }
        return false;
      },
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < filteredListings.length; i++) ...[
            _listingCard(filteredListings[i], 1),
            if (i < filteredListings.length - 1) const SizedBox(height: 10),
          ],
          // Индикатор подгрузки
          if (_isLoadingMore) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ARCHIVE TAB
  // ─────────────────────────────────────────────

  Widget _archiveTab() {
    final filteredListings = _archiveListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Архив пуст',
        'У вас нет объявлений в архиве,\nкак только вы перенесете\nобъявления они будут тут',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels == metrics.maxScrollExtent &&
              !_archiveIsLastPage &&
              !_isLoadingMore) {
            _loadMoreListings();
          }
        }
        return false;
      },
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < filteredListings.length; i++) ...[
            _listingCard(filteredListings[i], 2),
            if (i < filteredListings.length - 1) const SizedBox(height: 10),
          ],
          // Индикатор подгрузки
          if (_isLoadingMore) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MODERATION TAB
  // ─────────────────────────────────────────────


  // ─────────────────────────────────────────────
  // CRM TAB (объявления с фида на модерации)
  // ─────────────────────────────────────────────

  Widget _crmTab() {
    if (_crmLoading) {
      return _buildTabContentSkeleton();
    }

    final filteredListings = _crmListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'CRM пусто',
        'Здесь появятся опубликованные\nобъявления из фида.\nОпубликуйте их на экране предпросмотра',
      );
    }

    // Карточки рендерим со стилем «Активные» (tabIndex 0) — те же кнопки и логика.
    // Подгрузка следующих страниц идёт через внешний скролл (_onOuterScroll).
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < filteredListings.length; i++) ...[
          _listingCard(filteredListings[i], 0),
          if (i < filteredListings.length - 1) const SizedBox(height: 10),
        ],
        if (_isLoadingMore) ..._loadingMoreIndicator(),
      ],
    );
  }

  /// Вкладка «Все» — активные объявления, созданные ВРУЧНУЮ (без фидовых).
  Widget _allTab() {
    if (_manualLoading) {
      return _buildTabContentSkeleton();
    }

    final filteredListings = _manualListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Пусто',
        'Здесь появятся активные объявления,\nсозданные вручную.',
      );
    }

    // Карточки рендерим со стилем «Активные» (tabIndex 0).
    // Подгрузка следующих страниц идёт через внешний скролл (_onOuterScroll).
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < filteredListings.length; i++) ...[
          _listingCard(filteredListings[i], 0),
          if (i < filteredListings.length - 1) const SizedBox(height: 10),
        ],
        if (_isLoadingMore) ..._loadingMoreIndicator(),
      ],
    );
  }

  /// Индикатор подгрузки следующей страницы (крутилка внизу списка).
  List<Widget> _loadingMoreIndicator() {
    return const [
      SizedBox(height: 16),
      Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
          ),
        ),
      ),
    ];
  }

  Widget _moderationTab() {
    final filteredListings = _moderationListings;

    if (filteredListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'На модерации пусто',
        'У вас нет объявлений на модерации,\nкак только вы отправите\nобъявление оно тут появится',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels == metrics.maxScrollExtent &&
              !_moderationIsLastPage &&
              !_isLoadingMore) {
            _loadMoreListings();
          }
        }
        return false;
      },
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (int i = 0; i < filteredListings.length; i++) ...[
            _listingCard(filteredListings[i], 3),
            if (i < filteredListings.length - 1) const SizedBox(height: 10),
          ],
          // Индикатор подгрузки
          if (_isLoadingMore) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B7FF)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LISTING CARD
  // ─────────────────────────────────────────────

  Widget _listingCard(UserAdvert advert, int tabIndex) {
    final isSelected = _selectedListingIds.contains(advert.id);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedListingIds.add(advert.id);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode)
                  CustomCheckbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _selectedListingIds.add(advert.id);
                        } else {
                          _selectedListingIds.remove(advert.id);
                          // Выйти из режима выбора если ничего не выбрано
                          if (_selectedListingIds.isEmpty) {
                            _isSelectionMode = false;
                            _selectAllChecked = false;
                          }
                        }
                        _selectAllChecked = false;
                      });
                    },
                  ),
                if (_isSelectionMode) const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    // Создаем базовый Listing из UserAdvert для отображения
                    final listing = Listing(
                      id: advert.id.toString(),
                      imagePath:
                          advert.thumbnail ?? "assets/home_page/image.png",
                      images: advert.thumbnail != null
                          ? [advert.thumbnail!]
                          : [],
                      title: advert.name ?? "Без названия",
                      price: advert.price ?? "0",
                      location: advert.address ?? "",
                      date: advert.createdAt ?? "",
                      isFavorited: false,
                      sellerName: "",
                      sellerAvatar: "",
                      sellerRegistrationDate: "",
                      description: "",
                      characteristics: {},
                      userId: null,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MyListingsPropertyDetailsScreen(listing: listing),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: advert.thumbnail != null
                        ? Image.network(
                            advert.thumbnail!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 72,
                                height: 72,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.image,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advert.name ?? "Без названия",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _formatPriceWithRuble(advert.price ?? "0"),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Значок «Ai» только там, где ИИ РЕАЛЬНО переписал
                          // заголовок/описание (ai_rewritten). Если у объявления
                          // сгенерировано лишь SEO (а текст оригинальный из фида
                          // или ручной), значок не показываем.
                          if (advert.aiRewritten == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: accentColor),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Ai',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        advert.address ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.white24, height: 24),

            if (tabIndex == 4) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _publishFromCrm(advert),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: const Color(0xFF00D084),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Опубликовать',
                          style: TextStyle(
                            color: Color(0xFF00D084),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DynamicFilter(
                              categoryId: _selectedCategoryId ?? 2,
                              advertId: advert.id,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: const Color(0xFF00B7FF),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Редактировать',
                          style: TextStyle(
                            color: Color(0xFF00B7FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],

            if (tabIndex == 3) ...[
              const Center(
                child: Text(
                  'Объявление находится на модерации. В течении 24 часов администрация проверит ваше объявление',
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: _actionButton('Поддержка Лидле', Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      'Редактировать',
                      accentColor,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DynamicFilter(
                              categoryId: _selectedCategoryId ?? 2,
                              advertId: advert.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ] else if (tabIndex != 4) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Просмотров: ${advert.viewsCount == 0 ? "_" : advert.viewsCount}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Переходов: ${advert.clickCount == 0 ? "_" : advert.clickCount}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Поделились: ${advert.shareCount == 0 ? "_" : advert.shareCount}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // QR код
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvertQrScreen(
                            advertId: advert.id,
                            advertTitle: advert.name ?? "Объявление",
                            advertPrice: advert.price ?? "0",
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code,
                            color: accentColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'QR код',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (tabIndex == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Деактивировать',
                        yellowColor,
                        onPressed: () {
                          _deactivateAdvert(advert.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        'Редактировать',
                        accentColor,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DynamicFilter(
                                categoryId: _selectedCategoryId ?? 2,
                                advertId: advert.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],

              if (tabIndex == 1)
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Активировать',
                        greenColor,
                        onPressed: () {
                          _activateAdvert(advert.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        'Редактировать',
                        accentColor,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DynamicFilter(
                                categoryId: _selectedCategoryId ?? 2,
                                advertId: advert.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              if (tabIndex == 2)
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Активировать',
                        greenColor,
                        onPressed: () {
                          _activateAdvert(advert.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        'Редактировать',
                        accentColor,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DynamicFilter(
                                categoryId: _selectedCategoryId ?? 2,
                                advertId: advert.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      'Наружная реклама',
                      Colors.white,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const OutdoorAdvertisingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      'Внутренняя реклама',
                      Colors.white,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const IndoorAdvertisingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUTTON
  // ─────────────────────────────────────────────

  Widget _actionButton(String title, Color color, {VoidCallback? onPressed}) {
    return SizedBox(
      height: 39,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onPressed ?? () {},
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CATALOG BUTTON
  // ─────────────────────────────────────────────

  Widget _catalogButton(
    String title,
    bool isActive, {
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isActive ? accentColor : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? accentColor : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD TAB CONTENT
  // ─────────────────────────────────────────────

  Widget _buildTabContent() {
    // Показываем skeleton при загрузке метаданных ИЛИ объявлений
    if (_isLoadingMetadata || _listingsLoading) {
      return _buildTabContentSkeleton();
    }

    switch (_currentTab) {
      case 0:
        return _activeTab();
      case 1:
        return _inactiveTab();
      case 2:
        return _archiveTab();
      case 3:
        return _moderationTab();
      case 4:
        return _crmTab();
      case 5:
        return _allTab();
      default:
        return _activeTab();
    }
  }

  // ─────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────

  double _getTextWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, fontFamily: 'SF Pro Display'),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

/// Суммарная ширина всех вкладок с отступами — для линии-фона под ними.
  double _getTabsTotalWidth() {
    double total = 0;
    for (final idx in _tabVisualOrder) {
      total += _getTabWidth(idx) + 16;
    }
    return total;
  }

  
  // Визуальный порядок вкладок слева направо (по индексам):
  // CRM(4), Все(5), Активные(0), Неактивные(1), Архив(2), На модерации(3)
  static const List<int> _tabVisualOrder = [4, 5, 0, 1, 2, 3];

  double _getTabPosition(int tabIndex) {
    double position = 0;
    for (final idx in _tabVisualOrder) {
      if (idx == tabIndex) break;
      position += _getTabWidth(idx) + 16;
    }

    // Индивидуальная подстройка каждой вкладки.
    // Отрицательное значение двигает подчёркивание ЛЕВЕЕ,
    // положительное — ПРАВЕЕ. Подбери числа под свой экран.
    switch (tabIndex) {
      case 4: // CRM
        position += 0;
        break;
      case 5: // Все
        position -= 0;
        break;
      case 0: // Активные
        position -= 0;
        break;
      case 1: // Неактивные
        position -= -5;
        break;
      case 2: // Архив
        position -= -8;
        break;
      case 3: // На модерации
        position -= -8;
        break;
    }

    return position;
  }

  double _getTabWidth(int tabIndex) {
    if (tabIndex < 0 || tabIndex > 5) return 0;
    return _getTextWidth(_tabLabel(tabIndex));
  }

  List<UserAdvert> _getCurrentTabListings() {
    switch (_currentTab) {
      case 0:
        return _activeListings;
      case 1:
        return _inactiveListings;
      case 2:
        return _archiveListings;
      case 3:
        return _moderationListings;
      case 4:
        return _crmListings;
      case 5:
        return _manualListings;
      default:
        return _activeListings;
    }
  }

  /// Перенести выбранные объявления в архив (или вернуть из архива в активные).
  ///
  /// Раньше метод только переставлял объявления между локальными списками и
  /// НЕ обращался к серверу, поэтому смена статуса не сохранялась: после любой
  /// перезагрузки списка объявления возвращались обратно, а счётчики не сходились.
  /// Теперь для каждого выбранного объявления вызываем updateAdvertStatus
  /// (статус 8 — архив; из вкладки «Архив» возвращаем в активные, статус 1),
  /// а затем перечитываем все списки с сервера через _refreshAfterMutation().
  ///
  /// ВАЖНО про id статусов (см. документацию API):
  /// 1 = active, 2 = inactive, 3 = pending_moderation, 8 = archived.
  /// Архив это 8, а НЕ 3. Отправка 3 переводила бы объявление на модерацию,
  /// такой переход бэк отклоняет (422), а клиент 422 глотает молча — из-за
  /// этого кнопка «В архив» раньше не давала видимого эффекта.
  Future<void> _moveToArchive() async {
    if (_selectedListingIds.isEmpty) return;

    final token = HiveService.getUserData('token') as String?;
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Токен не найден')));
      }
      return;
    }

    // Из вкладки «Архив» (2) возвращаем в активные (статус 1),
    // из остальных вкладок отправляем в архив (статус 8).
    final int targetStatusId = _currentTab == 2 ? 1 : 8;
    final ids = _selectedListingIds.toList();

    // Сразу выходим из режима выбора, чтобы UI не завис в выделении.
    setState(() {
      _selectedListingIds.clear();
      _selectAllChecked = false;
      _isSelectionMode = false;
    });

    try {
      // Меняем статус на сервере для каждого выбранного объявления.
      for (final id in ids) {
        await MyAdvertsService.updateAdvertStatus(
          advertId: id,
          statusId: targetStatusId,
          token: token,
        );
      }

      // Перечитываем ВСЕ списки и счётчики с сервера.
      await _refreshAfterMutation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetStatusId == 1
                  ? 'Возвращено из архива'
                  : 'Перенесено в архив',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _deleteSelected() async {
    if (_selectedListingIds.isEmpty) return;

    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Токен не найден')));
        }
        return;
      }

      // Удаляем ВСЕ выбранные объявления на сервере
      for (final advertId in _selectedListingIds) {
        await MyAdvertsService.deleteAdvert(advertId: advertId, token: token);
      }

      // После успешного удаления на сервере - обновляем ВСЕ списки и счётчики.
      await _refreshAfterMutation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявления успешно удалены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
      }
    }
  }

  /// Полностью обновить ВСЕ списки и счётчики после смены статуса объявления
  /// (актив/деактив/архив/удаление/публикация из CRM).
  ///
  /// Раньше после активации/деактивации перезагружались только вкладки по
  /// каталогу (актив/неактив/архив/модерация) через _loadListingsByCategory.
  /// А вкладки «Все» (_manualListings) и «CRM» (_crmListings) грузились только
  /// один раз в initState, поэтому их содержимое и счётчики оставались старыми
  /// до полного перезахода в аккаунт. Из-за этого объявление после включения
  /// «висело» в Активных, но не появлялось в «Все», а счётчики не сходились.
  /// Теперь обновляем всё разом.
  Future<void> _refreshAfterMutation() async {
    // Общие счётчики вкладок пересчитываем после смены статуса объявления.
    _loadTabCounts();
    // _loadListingsByCategory/_loadListingsByCatalog обновляют сразу все шесть
    // списков (включая «CRM» и «Все») с текущим фильтром по категории.
    if (_selectedCategoryId != null) {
      await _loadListingsByCategory(_selectedCategoryId!);
    } else if (_selectedCatalogId != null) {
      await _loadListingsByCatalog(_selectedCatalogId!);
    } else {
      await Future.wait([_loadManualListings(), _loadCrmListings()]);
    }
  }

  /// Активировать объявление
  void _activateAdvert(int advertId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.activateAdvert(advertId: advertId, token: token);

      // Обновляем ВСЕ списки и счётчики (включая «Все» и «CRM»).
      await _refreshAfterMutation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление активировано')),
        );
      }
    } catch (e) {
      // log.d('Ошибка активации: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  /// Деактивировать объявление
  void _deactivateAdvert(int advertId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.deactivateAdvert(advertId: advertId, token: token);

      // Обновляем ВСЕ списки и счётчики (включая «Все» и «CRM»).
      await _refreshAfterMutation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление деактивировано')),
        );
      }
    } catch (e) {
      // log.d('Ошибка деактивации: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────
  // EMPTY TAB
  // ─────────────────────────────────────────────

  Widget _emptyTab(String imagePath, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 70.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 120, fit: BoxFit.contain),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SKELETON LOADERS 💀
  // ─────────────────────────────────────────────

  /// Skeleton для каталога (горизонтальный список кнопок)
  Widget _buildCatalogSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Каталог',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(right: index < 3 ? 8 : 0),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFF374B5C),
                  highlightColor: const Color(0xFF4A5C6A),
                  child: Container(
                    height: 34,
                    width: 100 + (index * 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374B5C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Skeleton для категорий (горизонтальный список кнопок)
  Widget _buildCategoriesSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Категории',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(right: index < 3 ? 8 : 0),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFF374B5C),
                  highlightColor: const Color(0xFF4A5C6A),
                  child: Container(
                    height: 34,
                    width: 85 + (index * 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374B5C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Skeleton для карточки объявления
  Widget _buildListingCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF374B5C),
      highlightColor: const Color(0xFF4A5C6A),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + text block
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image skeleton
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                // Text skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Price
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Address
                      Container(
                        height: 12,
                        width: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Divider
            Container(height: 1, color: Colors.white24),
            const SizedBox(height: 12),
            // Stats skeleton (3 lines)
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  height: 13,
                  width: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton для содержимого вкладки (список карточек объявлений)
  Widget _buildTabContentSkeleton() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildListingCardSkeleton(),
        const SizedBox(height: 10),
        _buildListingCardSkeleton(),
        const SizedBox(height: 10),
      ],
    );
  }
}
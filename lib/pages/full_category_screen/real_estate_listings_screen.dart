import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/pages/full_category_screen/intermediate_filters_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_filters_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_filter_screen.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/add_listing/category_selection_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';

// ============================================================
// "Универсальный экран объявлений по категориям"
// ============================================================

const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';
const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class RealEstateListingsScreen extends StatefulWidget {
  final int? categoryId; // ID категории для фильтрации
  final int? catalogId; // ID каталога для фильтрации
  final String? categoryName; // Имя категории для отображения в заголовке
  final bool
  isFromFullCategory; // true если переход с full_category_screen, false если с home_page

  const RealEstateListingsScreen({
    super.key,
    this.categoryId,
    this.catalogId,
    this.categoryName,
    this.isFromFullCategory = false,
  });

  @override
  State<RealEstateListingsScreen> createState() =>
      _RealEstateListingsScreenState();
}

class _RealEstateListingsScreenState extends State<RealEstateListingsScreen> {
  static final Map<String, List<Listing>> _listingsCache = {}; // Кеш объявлений
  static final Map<String, DateTime> _cacheTimestamps =
      {}; // Время создания кеша
  static const Duration _cacheTTL = Duration(minutes: 5); // 5 минут TTL

  int _selectedIndex = 0;
  List<Listing> _listings = [];
  Set<String> _selectedSortOptions = {};
  String? _currentSort =
      'new'; // Тип сортировки: 'new', 'old', 'expensive', 'cheap'
  bool _isLoading = true;
  bool _isLoadingMore = false; // Для индикатора подгрузки
  String? _errorMessage;
  Map<String, dynamic> _appliedFilters = {}; // Применённые фильтры
  String _selectedCityName = 'Мариуполь'; // Выбранный из фильтра город
  List<Attribute> _attributes = []; // Атрибуты для отображения фильтров

  // Пагинация
  int _currentPage = 1;
  int _totalPages = 1;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedSortOptions.add('Сначала новые');
    _loadAttributes();
    _loadAdverts();
    _updateSelectedIndex();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Генерирует ключ кеша на основе параметров фильтрации
  String _getCacheKey({String? sort}) {
    final filters = _appliedFilters.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return 'listings_${widget.categoryId}_${widget.catalogId}_${sort ?? _currentSort}_$filters';
  }

  /// Проверяет является ли кеш валидным
  bool _isCacheValid(String key) {
    if (!_cacheTimestamps.containsKey(key)) return false;
    final age = DateTime.now().difference(_cacheTimestamps[key]!);
    return age < _cacheTTL;
  }

  void _updateSelectedIndex() {
    // На этом экране всегда все иконки белые, так как это подэкран
    _selectedIndex = -1;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _currentPage < _totalPages) {
      _loadNextPage();
    }
  }

  /// Загружает атрибуты фильтров для отображения
  Future<void> _loadAttributes() async {
    try {
      if (widget.categoryId == null) return;

      final token = TokenService.currentToken;
      final response = await ApiService.getListingsFilterAttributes(
        categoryId: widget.categoryId!,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> attributesData = response['data'] as List<dynamic>;
        final attributes = <Attribute>[];

        for (int i = 0; i < attributesData.length; i++) {
          try {
            final attr = Attribute.fromJson(
              attributesData[i] as Map<String, dynamic>,
            );
            attributes.add(attr);
          } catch (e) {
            print('❌ Error parsing attribute at index $i: $e');
          }
        }

        if (mounted) {
          setState(() {
            _attributes = attributes;
            print('✅ Loaded ${_attributes.length} attributes for filter display');
          });
        }
      } else {
        print('⚠️  Failed to load attributes: ${response['message']}');
      }
    } catch (e) {
      print('❌ Error loading attributes: $e');
      // Не показываем ошибку пользователю, просто продолжаем
    }
  }

  /// Получает имя атрибута по его ID
  String _getAttributeName(String attributeId) {
    try {
      final attr = _attributes.firstWhere((a) => a.id.toString() == attributeId);
      return attr.title.isNotEmpty ? attr.title : 'Атрибут $attributeId';
    } catch (e) {
      // Fallback для известных атрибутов
      final nameMap = {
        '6': 'Количество комнат',
        '12': 'Бытовая техника',
        '14': 'Комфорт',
        '17': 'Инфраструктура',
        '18': 'Ландшафт',
      };
      return nameMap[attributeId] ?? 'Фильтр $attributeId';
    }
  }

  /// Получает текст значения по ID атрибута и ID значения
  String _getAttributeValueText(String attributeId, String valueId) {
    // Очищаем valueId от возможных скобок
    String cleanValueId = valueId.replaceAll(RegExp(r'[{}]'), '');
    
    try {
      final attr = _attributes.firstWhere((a) => a.id.toString() == attributeId);
      if (attr.values.isNotEmpty) {
        final value = attr.values.firstWhere(
          (v) => v.id.toString() == cleanValueId,
          orElse: () => Value(id: 0, value: ''),
        );
        if (value.id > 0 && value.value.isNotEmpty) {
          return value.value;
        }
      }
    } catch (e) {
      print('⚠️  Error getting attribute value for $attributeId=$cleanValueId: $e');
    }

    // Fallback для известных значений
    if (attributeId == '6') {
      final rooms = {
        '40': '1 комната',
        '41': '2 комнаты',
        '42': '3 комнаты',
        '43': '4 комнаты',
        '44': '5 комнат',
        '45': '6+ комнат',
      };
      return rooms[cleanValueId] ?? cleanValueId;
    }
    
    // Fallback для ID 18 (Ландшафт)
    if (attributeId == '18') {
      final landscape = {
        '154': 'Лес',
        '155': 'Водоём',
        '156': 'Парк',
        '157': 'Луг',
        '158': 'Горы',
        '159': 'Подгорья',
        '160': 'Равнина',
        '161': 'Холмы',
        '162': 'Дюны',
        '163': 'Степь',
        '164': 'Тундра',
        '165': 'Болото',
        '166': 'Каньон',
        '167': 'Пещеры',
        '168': 'Вулканы',
        '169': 'Ледники',
        '170': 'Острова',
        '171': 'Побережье',
        '172': 'Пляж',
        '173': 'Скалы',
      };
      return landscape[cleanValueId] ?? cleanValueId;
    }

    return cleanValueId;
  }

  Future<void> _loadAdverts({
    String? sort,
    bool isNextPage = false,
    bool forceRefresh = false,
  }) async {
    try {
      if (!isNextPage) {
        print('\n🔵 ═══════════════════════════════════════');
        print('🔵 _loadAdverts() CALLED');
        print('🔵 forceRefresh: $forceRefresh');
        print('🔵 Applied filters: ${_appliedFilters.keys.toList()}');
        _appliedFilters.forEach((key, value) {
          print('   ├─ $key: ${value is Map ? "Map(${(value as Map).keys.toList()})" : value}');
        });
        print('🔵 ═══════════════════════════════════════\n');
        
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _currentPage = 1;
        });
      } else {
        setState(() {
          _isLoadingMore = true;
        });
      }

      final token = TokenService.currentToken;

      // 💾 КЕШИРОВАНИЕ: Проверяем кеш перед API запросом (только для первой страницы)
      if (!isNextPage && !forceRefresh) {
        final cacheKey = _getCacheKey(sort: sort);
        if (_isCacheValid(cacheKey)) {
          final cachedListings = _listingsCache[cacheKey] ?? [];
          print('💾 CACHE HIT: Loaded ${cachedListings.length} listings from cache');
          setState(() {
            _listings = cachedListings;
            _isLoading = false;
          });
          return;
        }
      }

      // Используем переданные параметры как есть:
      // - Если catalogId передан → используем для фильтрации по каталогу
      // - Если categoryId передан (и catalogId == null) → используем для фильтрации по подкатегории
      // - Применённые фильтры передаём в API

      var response = await ApiService.getAdverts(
        categoryId: widget.categoryId,
        catalogId: widget.catalogId,
        sort: sort,
        filters: _appliedFilters.isNotEmpty ? _appliedFilters : null,
        page: isNextPage ? _currentPage + 1 : 1,
        limit: 20,
        token: token,
        withAttributes: _appliedFilters.isNotEmpty, // 🟢 Запрашиваем атрибуты если есть фильтры для клиентской фильтрации
      );

      // ✅ ОПТИМИЗАЦИЯ: Убрали fallback загрузку 100 объявлений!
      // Если API вернул 0 результатов - просто показываем это пользователю.
      // Это предотвращает загрузку огромного количества данных и блокировку UI.

      // Если есть примененные фильтры и нет результатов, предлагаем очистить фильтры
      if (response.data.isEmpty && _appliedFilters.isNotEmpty && !isNextPage) {
        print(
          'ℹ️  No results with applied filters. User should adjust filters.',
        );
      }

      // 🔍 КЛИЕНТСКАЯ ФИЛЬТРАЦИЯ
      // Преобразуем Advert в Listing
      final listingsToFilter = response.data.map((advert) {
        return advert.toListing();
      }).toList();

      // ═══════════════════════════════════════════════════════════════
      // 🔬 ДИАГНОСТИКА: Логируем структуру характеристик для первых 3 объявлений
      // ═══════════════════════════════════════════════════════════════
      print('\n📊 LISTINGS DATA STRUCTURE (for first 3):');
      print('🔍 FULL LIST OF IDs RECEIVED:');
      print('   Total: ${listingsToFilter.length} listings');
      print('   IDs: ${listingsToFilter.map((l) => l.id).toList()}');
      
      for (int i = 0; i < listingsToFilter.take(3).length; i++) {
        final listing = listingsToFilter[i];
        print('\n   ✓ Listing #${i + 1}: ID=${listing.id}');
        print('     Title: ${listing.title}');
        print('     Characteristics keys: ${listing.characteristics.keys.toList()}');

        // Логируем КАЖДУЮ характеристику подробно
        listing.characteristics.forEach((key, value) {
          print('     ├─ ID=$key:');
          if (value is Map) {
            print('     │  (Map with ${value.length} keys)');
            value.forEach((k, v) {
              print('     │  ├─ $k: $v (${v.runtimeType})');
            });
          } else if (value is List) {
            print('     │  (List with ${value.length} items)');
            for (int j = 0; j < value.take(2).length; j++) {
              print('     │  ├─ [$j]: ${value[j]} (${value[j].runtimeType})');
            }
          } else {
            print('     │  Value: $value (${value.runtimeType})');
          }
        });
      }
      print('═══════════════════════════════════════════════════════════════\n');

      var sortedNewListings = _applyClientSideFiltering(
        listingsToFilter,
        _appliedFilters,
      );

      // 🔀 КЛИЕНТСКАЯ СОРТИРОВКА

      // 🎯 Определяем типы сортировки: поддержка МУЛЬТИСОРТИРОВКИ
      String? sortByDate = _currentSort;
      String? sortByPrice = null;

      // 🔍 Проверяем фильтры сортировки: дата И цена оба одновременно
      if (_appliedFilters.containsKey('sort_date') &&
          _appliedFilters['sort_date'] != null &&
          (_appliedFilters['sort_date'] as String).isNotEmpty) {
        sortByDate = _appliedFilters['sort_date'] as String;
        print('🔀 SORT FROM FILTERS (DATE): $sortByDate');
      }

      if (_appliedFilters.containsKey('sort_price') &&
          _appliedFilters['sort_price'] != null &&
          (_appliedFilters['sort_price'] as String).isNotEmpty) {
        sortByPrice = _appliedFilters['sort_price'] as String;
        print('🔀 SORT FROM FILTERS (PRICE): $sortByPrice');
      }

      if (sortByDate != null && sortByDate.isNotEmpty) {
        print(
          '🔀 CLIENT-SIDE SORTING: Date=$sortByDate, Price=${sortByPrice ?? "none"}',
        );
        print('🔀 BEFORE sorting: ${sortedNewListings.length} listings');

        // МУЛЬТИСОРТИРОВКА: сначала по дате, потом по цене
        sortedNewListings.sort((a, b) {
          // Первичная сортировка: ПО ДАТЕ
          final dateA = _parseDate(a.date);
          final dateB = _parseDate(b.date);

          int dateComparison = 0;
          if (sortByDate == 'new') {
            dateComparison = dateB.compareTo(dateA); // Новые сначала
          } else if (sortByDate == 'old') {
            dateComparison = dateA.compareTo(dateB); // Старые сначала
          }

          // Если даты одинаковые, сортируем ПО ЦЕНЕ
          if (dateComparison == 0 &&
              sortByPrice != null &&
              sortByPrice.isNotEmpty) {
            final priceA = double.tryParse(a.price) ?? 0;
            final priceB = double.tryParse(b.price) ?? 0;

            if (sortByPrice == 'expensive') {
              return priceB.compareTo(priceA); // Дорогие сначала
            } else if (sortByPrice == 'cheap') {
              return priceA.compareTo(priceB); // Дешевые сначала
            }
          }

          return dateComparison;
        });

        print('🔀 AFTER sorting: ${sortedNewListings.length} listings');
      } else if (sortByPrice != null && sortByPrice.isNotEmpty) {
        // Если выбрана только сортировка ПО ЦЕНЕ (без даты)
        print('🔀 CLIENT-SIDE SORTING: Price only=$sortByPrice');
        print('🔀 BEFORE sorting: ${sortedNewListings.length} listings');

        sortedNewListings.sort((a, b) {
          final priceA = double.tryParse(a.price) ?? 0;
          final priceB = double.tryParse(b.price) ?? 0;

          if (sortByPrice == 'expensive') {
            return priceB.compareTo(priceA); // Дорогие сначала
          } else if (sortByPrice == 'cheap') {
            return priceA.compareTo(priceB); // Дешевые сначала
          }

          return 0;
        });

        print('🔀 AFTER sorting: ${sortedNewListings.length} listings');
      }

      final fullListings = sortedNewListings;

      // 💾 КЕШИРОВАНИЕ: Сохраняем результаты в кеш (только первую страницу)
      if (!isNextPage) {
        final cacheKey = _getCacheKey(sort: sort);
        _listingsCache[cacheKey] = fullListings;
        _cacheTimestamps[cacheKey] = DateTime.now();
        print(
          '💾 CACHED: Saved ${fullListings.length} listings to cache (key=$cacheKey)',
        );
      }

      setState(() {
        if (isNextPage) {
          _listings.addAll(fullListings);
        } else {
          _listings = fullListings;
        }

        _currentPage = response.meta.currentPage;
        _totalPages = response.meta.lastPage;

        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('❌ Error loading listings: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadNextPage() {
    if (_currentPage < _totalPages && !_isLoadingMore) {
      _loadAdverts(isNextPage: true);
    }
  }

  /// 📅 Парсит дату формата "25.02.2026" в DateTime
  DateTime _parseDate(String dateString) {
    try {
      final parts = dateString.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('⚠️ Error parsing date "$dateString": $e');
    }
    // Возвращаем сегодняшнюю дату если парсинг не удался
    return DateTime.now();
  }

  void _sortListings(Set<String> selectedOptions) {
    String? sort;
    if (selectedOptions.contains('Сначала новые')) sort = 'new';
    if (selectedOptions.contains('Сначала старые')) sort = 'old';
    if (selectedOptions.contains('Сначала дорогие')) sort = 'expensive';
    if (selectedOptions.contains('Сначала дешевые')) sort = 'cheap';

    if (sort != null) {
      print('📊 SORT SELECTED: $sort (${selectedOptions.join(", ")})');
      _currentSort = sort; // 💾 Сохраняем текущий тип сортировки
      _loadAdverts(sort: sort);
    }
  }

  // ============================================================
  //                        BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        // Когда интернет восстановлен - перезагружаем объявления
        if (connectivityState is ConnectedState) {
          // ⏳ Добавляем задержку для стабилизации соединения
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _currentPage = 1;
              _loadAdverts(forceRefresh: true);
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          // Показываем экран отсутствия интернета
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }

          // Показываем обычный контент
          return Scaffold(
      extendBody: true,
      backgroundColor: primaryBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ---------------- FIXED HEADER (не скроллится) ----------------
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 0, bottom: 10),
              child: const Header(),
            ),
            _buildSearchField(context),
            const SizedBox(height: 10),

            _buildLocationAndFilters(),
            _buildAppliedFiltersChips(),
            // SizedBox(height: 10),

            // _buildCategoryChips(),

            // ---------------- ВСЁ НИЖЕ — СКРОЛЛИТСЯ ----------------
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ---- СКРОЛЛ СТАРТУЕТ ЗДЕСЬ ----
                  SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(child: _buildSectionHeader()),
                  SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // ------------ CONTENT ------------
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 80.0,
                            horizontal: 20.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                color: Colors.grey[500],
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока тут нет объявлений',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Попробуйте позже или измените критерии поиска',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadAdverts,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Попробовать еще'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_listings.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 80.0,
                            horizontal: 20.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_outlined,
                                color: Colors.grey[500],
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока объявлений нет',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'В этой категории пока нет объявлений',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 15,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.70,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ListingCard(listing: _listings[i]),
                          childCount: _listings.length,
                        ),
                      ),
                    ),
                  // Индикатор подгрузки
                  if (_isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: bottomNavHeight + bottomNavPaddingBottom + 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
        },
      ),
    );
  }

  // ============================================================
  //                      WIDGETS
  // ============================================================

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: textMuted),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2536),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Поиск",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/home_page/marker-pin.svg',
                color: textMuted,
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _selectedCityName,
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
              Icon(Icons.keyboard_arrow_down, color: textMuted),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              print('\n🟣 ════════════════════════════════════════');
              print('🟣 FILTERS BUTTON TAPPED on listings_screen');
              print('🟣 Current applied filters: $_appliedFilters');
              print('🟣 ════════════════════════════════════════\n');

              // Открыть динамический фильтр для листинга
              if (widget.categoryId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RealEstateListingsFilterScreen(
                      categoryId: widget.categoryId!,
                      categoryName: widget.categoryName ?? 'Недвижимость',
                      appliedFilters: _appliedFilters,
                    ),
                  ),
                ).then((filters) {
                  print('\n🟣 ════════════════════════════════════════');
                  print('🟣 RETURNED FROM FILTER SCREEN');
                  print('🟣 Filter type: ${filters?.runtimeType}');
                  print('🟣 Filter is null? ${filters == null}');
                  print('🟣 Filter is Map? ${filters is Map<String, dynamic>}');
                  print('🟣 ════════════════════════════════════════\n');

                  if (filters != null && filters is Map<String, dynamic>) {
                    // Применить фильтры и перезагрузить объявления
                    print('\n✅ ═══════════════════════════════════════');
                    print('✅ FILTERS RETURNED FROM FILTER SCREEN');
                    print('✅ ═══════════════════════════════════════');
                    print('✅ Filter count: ${filters.length}');
                    filters.forEach((key, value) {
                      print('   [$key] = ${value is Map ? "${(value as Map).keys.toList()}" : value} (type: ${value.runtimeType})');
                    });
                    print('✅ ═══════════════════════════════════════\n');

                    setState(() {
                      _appliedFilters = filters;
                      // 🟢 Обновляем выбранный город из фильтров
                      if (filters.containsKey('city_name') && filters['city_name'] is String) {
                        _selectedCityName = filters['city_name'] as String;
                        print('🌍 City updated from filters: $_selectedCityName');
                      }
                      _currentPage = 1;
                      _listings.clear();
                      // 🟢 ВАЖНО: Инвалидируем кеш при изменении фильтров
                      _cacheTimestamps.clear();
                      _listingsCache.clear();
                      print('🗑️  Cache cleared due to filter change');
                    });
                    _loadAdverts(forceRefresh: true);
                  } else {
                    print('❌ No filters returned or filters is not a Map');
                  }
                });
              } else {
                // Fallback: если нет categoryId, открыть old filter screen
                if (widget.isFromFullCategory) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RealEstateFullFiltersScreen(
                        selectedCategory: widget.categoryName ?? 'Недвижимость',
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IntermediateFiltersScreen(
                        displayTitle: widget.categoryName ?? 'Недвижимость',
                        catalogId: widget.catalogId,
                      ),
                    ),
                  );
                }
              }
            },
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/home_page/settings.svg',
                  color: Colors.white,
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  "Фильтры",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Виджет для отображения применённых фильтров как чипы
  Widget _buildAppliedFiltersChips() {
    // Если нет применённых фильтров (кроме города и сортировки), не показываем ничего
    final hasValueSelectedFilters = _appliedFilters.containsKey('value_selected') &&
        (_appliedFilters['value_selected'] as Map).isNotEmpty;
    
    final hasValuesFilters = _appliedFilters.containsKey('values') &&
        (_appliedFilters['values'] as Map).isNotEmpty;
    
    if (!hasValueSelectedFilters && !hasValuesFilters) {
      return SizedBox.shrink();
    }

    final filterChips = <Widget>[];
    
    // Отображаем value_selected фильтры (дискретные значения)
    final valueSelectedMap = _appliedFilters['value_selected'] as Map<String, dynamic>?;
    if (valueSelectedMap != null) {
      valueSelectedMap.forEach((attributeId, values) {
        // Нормализуем значения в список
        List<String> valueIdList;
        if (values is List) {
          valueIdList = List<String>.from(values.cast<String>());
        } else if (values is Set) {
          valueIdList = List<String>.from((values as Set).cast<String>());
        } else {
          valueIdList = [values.toString()];
        }
        
        for (final valueId in valueIdList) {
          final attributeName = _getAttributeName(attributeId);
          final valueName = _getAttributeValueText(attributeId, valueId.toString());
          
          filterChips.add(_buildFilterChip(
            '$attributeName: $valueName',
            () {
              setState(() {
                // Удаляем конкретное значение из списка
                final updatedValues = List<String>.from(valueIdList);
                updatedValues.remove(valueId);
                
                if (updatedValues.isEmpty) {
                  // Если это был последний фильтр этого атрибута, удаляем весь ключ
                  (_appliedFilters['value_selected'] as Map).remove(attributeId);
                  
                  // Если value_selected пуста, удаляем её
                  if ((_appliedFilters['value_selected'] as Map).isEmpty) {
                    _appliedFilters.remove('value_selected');
                  }
                } else {
                  // Иначе обновляем список значений
                  (_appliedFilters['value_selected'] as Map)[attributeId] = updatedValues;
                }
                
                // Очищаем кеш и перезагружаем список
                _currentPage = 1;
                _listings.clear();
                _cacheTimestamps.clear();
                _listingsCache.clear();
                print('🗑️  Filter removed: $attributeName = $valueName');
              });
              _loadAdverts(forceRefresh: true);
            },
          ));
        }
      });
    }
    
    // Отображаем values фильтры (диапазоны)
    final valuesMap = _appliedFilters['values'] as Map<String, dynamic>?;
    if (valuesMap != null) {
      valuesMap.forEach((attributeId, filterValue) {
        if (filterValue is Map && (filterValue.containsKey('min') || filterValue.containsKey('max'))) {
          final min = filterValue['min'];
          final max = filterValue['max'];
          final attributeName = _getAttributeName(attributeId);
          
          String displayText = attributeName;
          if (min != null && max != null) {
            displayText = '$attributeName: $min–$max';
          } else if (min != null) {
            displayText = '$attributeName: от $min';
          } else if (max != null) {
            displayText = '$attributeName: до $max';
          }
          
          filterChips.add(_buildFilterChip(
            displayText,
            () {
              setState(() {
                // Удаляем фильтр диапазона
                (_appliedFilters['values'] as Map).remove(attributeId);
                
                // Если values пуста, удаляем её
                if ((_appliedFilters['values'] as Map).isEmpty) {
                  _appliedFilters.remove('values');
                }
                
                // Очищаем кеш и перезагружаем список
                _currentPage = 1;
                _listings.clear();
                _cacheTimestamps.clear();
                _listingsCache.clear();
                print('🗑️  Range filter removed: $displayText');
              });
              _loadAdverts(forceRefresh: true);
            },
          ));
        }
      });
    }

    if (filterChips.isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...filterChips,
            const SizedBox(width: 8), // Padding в конце
          ],
        ),
      ),
    );
  }

  /// Вспомогательный метод для создания чипа фильтра
  Widget _buildFilterChip(String text, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCategoryChips() {
  //   final chipStyle = BoxDecoration(
  //     color: primaryBackground,
  //     borderRadius: BorderRadius.circular(11),
  //     border: Border.all(color: Colors.white),
  //   );

  //   Widget chip(String label, {IconData? icon}) {
  //     return Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  //       decoration: chipStyle,
  //       child: Row(
  //         children: [
  //           Text(label, style: const TextStyle(color: Colors.white)),
  //           if (icon != null) ...[
  //             const SizedBox(width: 6),
  //             Icon(icon, color: Colors.white, size: 18),
  //           ],
  //         ],
  //       ),
  //     );
  //   }

  //   return SizedBox(
  //     height: 40,
  //     child: ListView(
  //       padding: const EdgeInsets.symmetric(horizontal: 12),
  //       scrollDirection: Axis.horizontal,
  //       children: [
  //         chip("Квартиры", icon: Icons.close),
  //         const SizedBox(width: 10),
  //         chip("Новостройка", icon: Icons.keyboard_arrow_down_sharp),
  //         const SizedBox(width: 10),
  //         chip("Количество комнат", icon: Icons.apps),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSectionHeader() {
    // Форматируем заголовок из категории, удаляя переносы строк и очищая текст
    final displayTitle =
        widget.categoryName?.replaceAll('\n', ' ').trim() ?? 'Объявления';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 🔄 Кнопка refresh для очистки кеша
          // IconButton(
          //   icon: const Icon(Icons.refresh, color: Colors.white),
          //   onPressed: () => _loadAdverts(forceRefresh: true),
          //   tooltip: 'Обновить',
          // ),
          _buildFilterDropdown(
            label: _selectedSortOptions.isEmpty
                ? 'Сначала'
                : _selectedSortOptions.join(', '),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => SelectionDialog(
                  title: 'Сортировать товар',
                  options: const [
                    'Сначала новые',
                    'Сначала старые',
                    'Сначала дорогие',
                    'Сначала дешевые',
                  ],
                  selectedOptions: _selectedSortOptions,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedSortOptions = selected;
                      _sortListings(selected);
                    });
                  },
                  allowMultipleSelection: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, bottomNavPaddingBottom),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(homeIconAsset, 0, _selectedIndex),
              _buildNavItem(gridIconAsset, 1, _selectedIndex),
              _buildCenterAdd(2, _selectedIndex),
              _buildNavItem(shoppingCartAsset, 3, _selectedIndex),
              _buildNavItem(messageIconAssetLocal, 4, _selectedIndex),
              _buildNavItem(userIconAsset, 5, _selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index, int current) {
    final isSelected = index == current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          setState(() => _selectedIndex = index);
          _navigateToScreen(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(13.5),
          child: Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: isSelected ? activeIconColor : inactiveIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAdd(int index, int current) {
    final isSelected = index == current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () {
          setState(() => _selectedIndex = index);
          _navigateToScreen(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(13.5),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Image.asset(
              plusIconAsset,
              width: 28,
              height: 28,
              color: isSelected ? activeIconColor : inactiveIconColor,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(int index) {
    final String routeName;
    switch (index) {
      case 0:
        routeName = HomePage.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 1:
        routeName = FullCategoryScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 2:
        routeName = CategorySelectionScreen.routeName;
        Navigator.of(context).pushNamed(routeName);
        break;
      case 3:
        routeName = MyPurchasesScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 4:
        routeName = MessagesPage.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      case 5:
        routeName = ProfileDashboard.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
        break;
      default:
        return;
    }
  }

  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// МОЩНАЯ СИСТЕМА КЛИЕНТСКОЙ ФИЛЬТРАЦИИ
  /// Универсальный метод для всех типов фильтров
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Применяет ВСЕ типы фильтров на клиенте одновременно
  /// Поддерживает: города, value_selected, values (диапазоны), булевы, текстовые
  List<Listing> _applyClientSideFiltering(
    List<Listing> listings,
    Map<String, dynamic> filters,
  ) {
    if (filters.isEmpty || listings.isEmpty) {
      return listings;
    }

    print(
      '\n🟢 ═══════════════════════════════════════════════════════════════',
    );
    print('🟢 CLIENT-SIDE FILTERING STARTED');
    print('🟢 Initial listings: ${listings.length}');
    print('🟢 Filters to apply: ${filters.keys.toList()}');
    print(
      '🟢 ═══════════════════════════════════════════════════════════════\n',
    );

    var result = listings;

    // 🔴 ВАЖНО: Если есть value_selected API фильтры, сервер УЖЕ отфильтровал результаты!
    // Клиентская перефильтрация вернет 0, потому что объявления не содержат характеристики.
    // Пропускаем клиентскую фильтрацию при наличии API фильтров.
    final hasApiFilters = filters.containsKey('value_selected') &&
        filters['value_selected'] is Map &&
        (filters['value_selected'] as Map).isNotEmpty;

    if (hasApiFilters) {
      print('⏭️  SKIPPING CLIENT-SIDE FILTERING - API ALREADY FILTERED');
      print('   API фильтры уже применены на сервере, используем результаты как есть\n');
    } else {
      // 1️⃣ ФИЛЬТРАЦИЯ ПО ГОРОДУ
      if (filters.containsKey('city_name') &&
          filters['city_name'] != null &&
          (filters['city_name'] as String).isNotEmpty) {
        result = _filterByCity(result, filters['city_name'] as String);
      }

      // 2️⃣ ФИЛЬТРАЦИЯ ПО value_selected АТРИБУТАМ (Ландшафт, Инфраструктура и т.д.)
      if (filters.containsKey('value_selected') &&
          filters['value_selected'] is Map) {
        final valueSelectedMap = (filters['value_selected'] as Map)
            .cast<String, dynamic>();
        print('🔍 VALUE_SELECTED FILTERS:');
        print('   Full Map: $valueSelectedMap');
        valueSelectedMap.forEach((k, v) {
          print('   ├─ Key=$k, Value=$v (type=${v.runtimeType})');
          if (v is Map) {
            print('   │  └─ Map keys: ${v.keys.toList()}');
            v.forEach((mk, mv) {
              print('   │     ├─ $mk: $mv');
            });
          } else if (v is List) {
            print('   │  └─ List length: ${v.length}');
            v.forEach((item) {
              print('   │     ├─ $item (type=${item.runtimeType})');
            });
          }
        });
        result = _filterByValueSelected(result, valueSelectedMap);
      }
    }

    // 3️⃣ ФИЛЬТРАЦИЯ ПО values АТРИБУТАМ (диапазоны, цена, площадь и т.д.)
    // Только если НЕТ API фильтров
    if (!hasApiFilters &&
        filters.containsKey('values') &&
        filters['values'] is Map) {
      result = _filterByValues(
        result,
        (filters['values'] as Map).cast<String, dynamic>(),
      );
    }

    // 4️⃣ ФИЛЬТРАЦИЯ ПО БУЛЕВЫМ АТРИБУТАМ (Ипотека, Возможен торг и т.д.)
    // Только если НЕТ API фильтров
    if (!hasApiFilters &&
        filters.containsKey('boolean') &&
        filters['boolean'] is Map) {
      result = _filterByBoolean(
        result,
        (filters['boolean'] as Map).cast<String, dynamic>(),
      );
    }

    print(
      '\n🟢 ═══════════════════════════════════════════════════════════════',
    );
    print('🟢 CLIENT-SIDE FILTERING COMPLETED');
    print('🟢 Final listings: ${result.length}');
    print(
      '🟢 ═══════════════════════════════════════════════════════════════\n',
    );

    return result;
  }

  /// Фильтрует объявления по названию города
  List<Listing> _filterByCity(List<Listing> listings, String cityName) {
    print('🟢 FILTER BY CITY: "$cityName"');
    print('   BEFORE: ${listings.length} listings');

    final filtered = listings.where((listing) {
      final matches = listing.location.startsWith(cityName);
      if (!matches) {
        print('      ❌ ID=${listing.id}: ${listing.location}');
      }
      return matches;
    }).toList();

    print('   AFTER: ${filtered.length} listings\n');
    return filtered;
  }

  /// Фильтрует объявления по value_selected атрибутам (ID < 1000)
  /// Примеры: Ландшафт, Инфраструктура, тип Дома и т.д.
  List<Listing> _filterByValueSelected(
    List<Listing> listings,
    Map<String, dynamic> valueSelectedFilters,
  ) {
    if (valueSelectedFilters.isEmpty) {
      return listings;
    }

    print('🟢 FILTER BY value_selected ATTRIBUTES');
    print('   Filters: $valueSelectedFilters');

    // DEBUG: логируем структуру фильтров
    valueSelectedFilters.forEach((key, value) {
      print('   Filter key=$key, value=$value (type=${value.runtimeType})');
      if (value is List) {
        print('      List items: $value');
      } else if (value is Set) {
        print('      Set items: $value');
      }
    });

    print('   BEFORE: ${listings.length} listings');

    // ДЕБАГ: показываем характеристики для первых 5 объявлений
    print('\n📊 ХАРАКТЕРИСТИКИ ПЕРВЫХ 5 ОБЪЯВЛЕНИЙ:');
    for (int i = 0; i < listings.length && i < 5; i++) {
      final listing = listings[i];
      print('\n   📌 Объявление ID=${listing.id}:');
      if (listing.characteristics.isEmpty) {
        print('      ⚠️ БЕЗ ХАРАКТЕРИСТИК!');
      } else {
        print('      Всего своиств: ${listing.characteristics.length}');
        listing.characteristics.forEach((attrId, value) {
          print('      ├─ Атрибут $attrId: $value');
        });
      }
    }
    print('\n🟢 НАЧАЛО ФИЛЬТРАЦИИ:\n');

    final filtered = listings.where((listing) {
      // Каждый фильтр должен совпадать - логика AND между фильтрами
      for (final filterEntry in valueSelectedFilters.entries) {
        final attrIdStr = filterEntry.key;
        final selectedValueIds = filterEntry.value;

        // Получаем значение из characteristics
        final characteristic = listing.characteristics[attrIdStr];

        // DEBUG для этого конкретного объявления
        if (listing.id == 104 || listing.id == 103) {
          print('   🔍🔍 ID=${listing.id}, атрибут $attrIdStr:');
          print('      От фильтра ожидаем: $selectedValueIds (type=${selectedValueIds.runtimeType})');
          print('      В объявлении: $characteristic (type=${characteristic?.runtimeType})');
        }

        // 🔴 ВАЖНО: Если нет характеристики - ИСКЛЮЧАЕМ объявление
        // (не пропускаем фильтр, а полностью исключаем объявление)
        if (characteristic == null) {
          if (listing.id == 104 || listing.id == 103) {
            print('      ❌ БЕЗ ХАРАКТЕРИСТИКИ\n');
          }
          return false; // Объявление НЕ прходит фильтр
        }

        // Извлекаем названия из characteristic для сравнения
        // Если characteristic это Map с 'value', то это название опции (например, "Река")
        final characteristicNames = _extractCharacteristicNames(characteristic);
        final characteristicSet = _normalizeToSet(characteristicNames);

        // Также получаем ВСЕ возможные значения (для сравнения по ID, если нужно)
        final allValues = _getAllCharacteristicValuesAsSet(characteristic);

        // Нормализуем selectedValueIds в Set<String> (значения из фильтра могут быть ID или названия)
        final selectedIds = _normalizeToSet(selectedValueIds);

        if (listing.id == 104 || listing.id == 103) {
          print('      Основное значение: $characteristicSet');
          print('      Все значения: $allValues');
          print('      Ожидаемые значения (нормализованные): $selectedIds');
        }

        // ✅ ВАЖНО: Проверяем совпадение по ID/значениям
        // selectedIds содержит ID значений из фильтра (например, "154")
        // characteristicSet содержит значение из объявления (может быть ID "154" или текст)
        // allValues содержит ВСЕ значения из Map характеристики
        
        // Определяем, есть ли хотя бы одно совпадение
        bool hasMatch = false;
        
        // Проверяем основное значение
        if (characteristicSet.isNotEmpty) {
          hasMatch = characteristicSet.any((name) => selectedIds.contains(name));
        }
        
        // Если совпадение не найдено, проверяем все значения
        if (!hasMatch) {
          hasMatch = allValues.any((val) => selectedIds.contains(val));
        }

        if (listing.id == 104 || listing.id == 103) {
          print('      Результат: ${hasMatch ? '✅ СОВПАДАЕТ' : '❌ НЕ СОВПАДАЕТ'}\n');
        }

        if (!hasMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    print('   AFTER: ${filtered.length} listings\n');
    return filtered;
  }

  /// Извлекает названия/значения из характеристики для сравнения в фильтре
  /// Приводит все к единому формату (названиям опций вроде "Река", "Клубные дома" и т.д.)
  dynamic _extractCharacteristicNames(dynamic characteristic) {
    if (characteristic == null) return null;

    if (characteristic is Map) {
      // 🔑 ПРИОРИТЕТ 1: Если есть поле 'value' - это может быть ID значения (число)
      // Это первый выбор, так как это то, что хранится в атрибутах объявления
      if (characteristic.containsKey('value') &&
          characteristic['value'] != null) {
        // Возвращаем как строку для сравнения (API отправляет ID как строки)
        final value = characteristic['value'];
        print('      NAMES: extracted "value" field: $value (type=${value.runtimeType})');
        return value is int ? value.toString() : value.toString();
      }

      // 🔑 ПРИОРИТЕТ 2: Если есть поле 'title' - используем название
      if (characteristic.containsKey('title') &&
          characteristic['title'] != null) {
        print(
          '      NAMES: extracted "title" field: ${characteristic['title']}',
        );
        return characteristic['title'].toString();
      }

      // 🔑 ПРИОРИТЕТ 3: Если есть 'value_id' - это ID значения
      if (characteristic.containsKey('value_id') &&
          characteristic['value_id'] != null) {
        print(
          '      NAMES: extracted "value_id" field: ${characteristic['value_id']}',
        );
        return characteristic['value_id'].toString();
      }

      return characteristic;
    }

    // Для простых значений - возвращаем как строку
    return characteristic.toString();
  }

  /// Получает ВСЕ возможные значения из характеристики для сравнения
  /// Включает названия (value), ID (value_id, id) и т.д. для гибкого сравнения
  Set<String> _getAllCharacteristicValuesAsSet(dynamic characteristic) {
    final values = <String>{};

    if (characteristic == null) return values;

    if (characteristic is Map) {
      // Добавляем все значения из Map в виде строк
      characteristic.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          values.add(v.toString()); // Строка ("Река", "154" и т.д.)
        }
      });
      print('      VALUES: all from Map: $values');
    } else {
      // Если это не Map, добавляем само значение
      final valueStr = characteristic.toString();
      if (valueStr.isNotEmpty) {
        values.add(valueStr);
      }
      print('      VALUES: single value: $values');
    }

    return values;
  }

  /// Фильтрует объявления по values атрибутам (ID >= 1000)
  /// Примеры: Цена, Площадь, Этаж и т.д. (диапазоны)
  List<Listing> _filterByValues(
    List<Listing> listings,
    Map<String, dynamic> valuesFilters,
  ) {
    if (valuesFilters.isEmpty) {
      return listings;
    }

    print('\n🟢 ═══════════════════════════════════════════════════════════');
    print('🟢 FILTER BY values ATTRIBUTES (Range filters)');
    print('🟢 Filter count: ${valuesFilters.length}');
    
    // 📊 Логируем ПОЛНУЮ структуру валидата фильтров
    print('\n🔬 FILTER STRUCTURE DEBUG:');
    valuesFilters.forEach((key, value) {
      print('   ├─ Key="$key" (type=${key.runtimeType}):');
      if (value is Map) {
        print('   │  └─ Map (${value.length} items):');
        value.forEach((k, v) {
          print('   │     ├─ $k: $v (${v.runtimeType})');
        });
      } else if (value is List) {
        print('   │  └─ List (${value.length} items)');
      } else {
        print('   │  └─ ${value.runtimeType}: $value');
      }
    });
    print('═══════════════════════════════════════════════════════════');
    
    print('🟢 Listings BEFORE: ${listings.length}');
    print('🟢 ═══════════════════════════════════════════════════════════');

    final filtered = listings.where((listing) {
      // DEBUG: Логируем информацию о каждом объявлении
      final listingAttrs = listing.characteristics;
      
      // Каждый фильтр должен совпадать - логика AND между фильтрами
      for (final filterEntry in valuesFilters.entries) {
        final attrIdStr = filterEntry.key;
        final filterValue = filterEntry.value;

        print('\n   🔍 Checking filter: attr=$attrIdStr');
        print('      Filter value: $filterValue (type: ${filterValue.runtimeType})');
        print('      Listing characteristics keys: ${listingAttrs.keys.toList()}');
        
        // Получаем значение из characteristics
        final characteristic = listingAttrs[attrIdStr];
        print('      Characteristic for attr=$attrIdStr: $characteristic');

        // 🟢 ИЗМЕНЕННАЯ ЛОГИКА: Если нет характеристики - ПРОПУСКАЕМ этот фильтр (не исключаем объявление)
        // Это позволит показать объявления, даже если некоторые не имеют этого атрибута
        if (characteristic == null) {
          print('      ⚠️  NO CHARACTERISTIC for attr=$attrIdStr - SKIPPING THIS FILTER');
          continue;  // ← Важное изменение: continue вместо return false
        }

        // Если это Map с min/max (диапазон)
        if (filterValue is Map &&
            (filterValue.containsKey('min') ||
                filterValue.containsKey('max'))) {
          final minFilter = filterValue['min'];
          final maxFilter = filterValue['max'];

          final minNum = _parseNumber(minFilter);
          final maxNum = _parseNumber(maxFilter);

          print('      Range filter: min=$minNum, max=$maxNum');

          // Если оба пусты, пропускаем фильтр
          if (minNum == null && maxNum == null) {
            print('      ⚠️  Both min and max are empty - SKIPPING');
            continue;
          }

          // Извлекаем значение из characteristic
          dynamic advertVal = characteristic;
          if (characteristic is Map) {
            // Может быть {value: 100, max_value: 200} (диапазон) или {value: 150} (одно значение)
            if (characteristic.containsKey('value')) {
              advertVal = characteristic['value'];
              print('      Characteristic is Map with value field: $advertVal');
              
              if (characteristic.containsKey('max_value')) {
                // Это диапазон (например, этажи 1-3)
                final advertMin = _parseNumber(characteristic['value']);
                final advertMax = _parseNumber(characteristic['max_value']);

                print('      Range characteristic: $advertMin-$advertMax');

                if (advertMin != null && advertMax != null) {
                  // 🟢 УЛУЧШЕННАЯ ЛОГИКА: Проверяем пересечение диапазонов
                  // Объявление подходит если его диапазон пересекается с фильтром
                  bool intersects = true;
                  if (minNum != null) intersects = intersects && (advertMax >= minNum);
                  if (maxNum != null) intersects = intersects && (advertMin <= maxNum);

                  if (!intersects) {
                    print('      ❌ Range $advertMin-$advertMax does NOT intersect with $minNum-$maxNum');
                    return false;  // Исключаем это объявление
                  } else {
                    print('      ✅ Range $advertMin-$advertMax INTERSECTS with $minNum-$maxNum');
                    continue;  // Это объявление прошло проверку, проверим следующий фильтр
                  }
                }
              }
            } else if (characteristic.containsKey('id') && characteristic.containsKey('title')) {
              // Это может быть объект атрибута, извлекаем значение по-другому
              print('      Characteristic is attribute object');
              continue;  // Пропускаем, т.к. не можем извлечь числовое значение
            }
          }

          // Если это простое число или строка с числом - проверяем диапазон
          final advertNum = _parseNumber(advertVal);
          print('      Parsed numeric value: $advertNum');
          
          if (advertNum != null) {
            bool ok = true;
            if (minNum != null) ok = ok && (advertNum >= minNum);
            if (maxNum != null) ok = ok && (advertNum <= maxNum);

            if (!ok) {
              print('      ❌ Value $advertNum NOT in range $minNum-$maxNum');
              return false;  // Исключаем это объявление
            } else {
              print('      ✅ Value $advertNum IS in range $minNum-$maxNum');
              continue;  // Объявление прошло проверку
            }
          } else {
            print('      ⚠️  Could not parse numeric value from: $advertVal');
            continue;  // Не можем проверить, пропускаем этот фильтр
          }
        } else if (filterValue is List) {
          // Если это список значений
          print('      Filter is a list: $filterValue');
          continue;
        } else {
          // Другие типы значений
          print('      Filter type not recognized: ${filterValue.runtimeType}');
          continue;
        }
      }

      print('\n   ✅ Listing ID=${listing.id} PASSED all range filters');
      return true;
    }).toList();

    print('\n🟢 Listings AFTER: ${filtered.length}');
    print('🟢 ═══════════════════════════════════════════════════════════\n');
    return filtered;
  }

  /// Фильтрует объявления по булевым атрибутам (true/false)
  List<Listing> _filterByBoolean(
    List<Listing> listings,
    Map<String, dynamic> booleanFilters,
  ) {
    if (booleanFilters.isEmpty) {
      return listings;
    }

    print('🟢 FILTER BY BOOLEAN ATTRIBUTES');
    print('   Filters: $booleanFilters');
    print('   BEFORE: ${listings.length} listings');

    final filtered = listings.where((listing) {
      // Каждый фульгер должен совпадать - логика AND между фильтрами
      for (final filterEntry in booleanFilters.entries) {
        final attrIdStr = filterEntry.key;
        final expectedValue = filterEntry.value;

        // Получаем значение из characteristics
        final characteristic = listing.characteristics[attrIdStr];

        if (characteristic == null) {
          continue;
        }

        // Извлекаем булево значение
        bool advertBool = false;
        if (characteristic is bool) {
          advertBool = characteristic;
        } else if (characteristic is Map &&
            characteristic.containsKey('value')) {
          advertBool = characteristic['value'] == true;
        }

        // Проверяем совпадение
        bool matches = false;
        if (expectedValue == true) {
          matches = advertBool;
        } else if (expectedValue == false) {
          matches = !advertBool;
        }

        if (!matches) {
          print(
            '      ❌ ID=${listing.id}, attr=$attrIdStr: $advertBool != $expectedValue',
          );
          return false;
        }

        print(
          '      ✅ ID=${listing.id}, attr=$attrIdStr: $advertBool == $expectedValue',
        );
      }

      return true;
    }).toList();

    print('   AFTER: ${filtered.length} listings\n');
    return filtered;
  }

  /// Нормализует значение в Set<String> для сравнения
  /// Приводит всё (ID, названия, числа) к строковому формату
  Set<String> _normalizeToSet(dynamic value) {
    if (value == null) {
      print('      NORMALIZE: NULL input -> {}');
      return {};
    }

    // Если это Set - конвертируем все элементы в String
    if (value is Set) {
      final result = value
          .map((e) {
            if (e == null) return '';
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toSet();
      print('      NORMALIZE: Set (${value.length} items) -> $result');
      return result;
    }

    // Если это List - конвертируем все элементы в String
    if (value is List) {
      final result = value
          .map((e) {
            if (e == null) return '';
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toSet();
      print('      NORMALIZE: List with ${value.length} items -> $result');
      return result;
    }

    // Если это Map - обрабатываем специально
    if (value is Map) {
      print('      NORMALIZE: Map with keys=${value.keys.toSet()}');
      // Если это Map {value: X} - извлекаем X и рекурсим
      if (value.containsKey('value') && value['value'] != null) {
        print('      NORMALIZE: Found "value" key, recursing...');
        return _normalizeToSet(value['value']);
      }
      // Если это Map с числовыми или строковыми значениями
      final result = value.values
          .map((v) {
            if (v == null) return '';
            return v.toString();
          })
          .where((s) => s.isNotEmpty)
          .toSet();
      if (result.isNotEmpty) {
        print('      NORMALIZE: Map values -> $result');
        return result;
      }
      return {};
    }

    // Для всего остального - преобразуем в String
    final result = {value.toString()};
    print('      NORMALIZE: ${value.runtimeType} -> $result');
    return result;
  }

  /// Парсит число из различных форматов (string, int, double, null)
  num? _parseNumber(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

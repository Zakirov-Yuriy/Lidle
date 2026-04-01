import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';import 'package:lidle/widgets/cards/listing_card.dart';import 'package:lidle/pages/full_category_screen/filters_real_estate_rent_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/mini_property_filtered_details_screen.dart';

// Navigation
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/add_listing/add_listing_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/core/logger.dart';

const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';
const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

// ============================================================
// "Экран отфильтрованных объявлений недвижимости"
// ============================================================

class RealEstateFilteredScreen extends StatefulWidget {
  final String selectedCategory;
  final int categoryId; // ID конечной категории для фильтрации
  final String? selectedCity; // Выбранный город

  const RealEstateFilteredScreen({
    super.key,
    required this.selectedCategory,
    required this.categoryId,
    this.selectedCity,
  });

  @override
  State<RealEstateFilteredScreen> createState() => _RealEstateFilteredScreen();
}

class _RealEstateFilteredScreen extends State<RealEstateFilteredScreen> {
  int _selectedIndex = 0;
  late List<Listing> _listings;
  Set<String> _selectedSortOptions = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _listings = [];
    _selectedSortOptions.add('Сначала новые');
    _loadFilteredListings();
  }

  /// Загружает отфильтрованные объявления с API
  Future<void> _loadFilteredListings() async {
    try {
      log.d('🔍 [RealEstateFilteredScreen] initState: загружаем объявления для categoryId=${widget.categoryId}');
      
      setState(() => _isLoading = true);

      // Получаем сохраненные фильтры
      final savedFilters = HiveService.getCategoryFilters(widget.categoryId);
      log.d('� Фильтры загружены для категории ${widget.categoryId}: $savedFilters');
      log.d('📋 [API] Загруженные фильтры из Hive: $savedFilters');

      // Получаем токен
      final token = TokenService.currentToken;
      if (token == null) {
        throw Exception('Токен не найден - авторизация требуется');
      }
      log.d('🔐 [API] Токен получен, начинаем запрос');

      // ✅ СТРУКТУРИРУЕМ ФИЛЬТРЫ
      final structuredFilters = _structureFiltersForApi(savedFilters);
      
      // ИСПРАВЛЕНИЕ: Используем categoryId как параметр в API 
      // Больше НЕ загружаем весь каталог - просто используем переданный categoryId
      log.d('🔄 [API] Запрашиваем объявления для categoryId=${widget.categoryId}');
      log.d('🔄 [API] Структурированные фильтры для API: $structuredFilters');
      
      final response = await ApiService.getAdverts(
        categoryId: widget.categoryId,  // ← ИСПРАВЛЕНО: используем categoryId
        filters: structuredFilters.isNotEmpty ? structuredFilters : null,  // ← ДОБАВЛЕНО: передаём фильтры серверу
        token: token,
        page: 1,
        limit: 50,
        withAttributes: structuredFilters.isNotEmpty,  // ← Просим атрибуты если есть фильтры
      );

      log.d('✅ [API] Получено ${response.data.length} объявлений');

      if (!mounted) {
        log.d('⚠️ [Widget] mounted=false, отменяем setState');
        return;
      }

      final allAdverts = response.data;
      log.d('📦 [API] ИТОГО загружено: ${allAdverts.length} объявлений');

      // Конвертируем Advert в Listing
      final listings = <Listing>[];
      for (int i = 0; i < allAdverts.length; i++) {
        final advert = allAdverts[i];
        try {
          final listing = _convertAdvertToListing(advert);
          listings.add(listing);
        } catch (e) {
          log.d('❌ [Conversion] ОШИБКА при конвертации advert #$i: $e');
        }
      }

      log.d('✅ [Result] Успешно сконвертировано ${listings.length} объявлений из ${allAdverts.length}');

      // ✨ ПРИМЕНЯЕМ СОХРАНЕННЫЕ ФИЛЬТРЫ
      final filteredListings = _applyClientSideFiltering(listings, savedFilters);

      setState(() {
        _listings = filteredListings;
        _isLoading = false;
        _errorMessage = '';
      });
      
      log.d('✅ [UI] setState вызван, _listings.length=${_listings.length}');

    } catch (e, stackTrace) {
      log.d('❌ [ERROR] Ошибка при загрузке отфильтрованных объявлений:');
      log.d('   Error: $e');
      log.d('   StackTrace: $stackTrace');
      
      if (!mounted) {
        log.d('⚠️ [Widget] mounted=false, отменяем setState');
        return;
      }

      setState(() {
        _errorMessage = 'Ошибка загрузки: $e';
        _isLoading = false;
        _listings = [];
      });
      
      log.d('✅ [Fallback] Показываем ошибку');
    }
  }

  /// Конвертирует модель Advert в модель Listing для отображения
  Listing _convertAdvertToListing(dynamic advert) {
    try {
      log.d('   📝 advert properties:');
      log.d('      id=${advert.id}');
      log.d('      name=${advert.name}');
      log.d('      price=${advert.price}');
      log.d('      address=${advert.address}');
      log.d('      thumbnail=${advert.thumbnail}');
      log.d('      images=${advert.images}');
      log.d('      slug=${advert.slug}');
      
      final listing = Listing(
        id: advert.id.toString(),
        slug: advert.slug,
        imagePath: advert.thumbnail ?? 'assets/home_page/image.png',
        images: advert.images ?? [],
        title: advert.name ?? 'Объявление',
        price: advert.price ?? '0',
        location: advert.address ?? 'Не указано',
        date: advert.date ?? DateTime.now().toString(),
        description: advert.description,
        sellerName: advert.sellerName,
        userId: advert.sellerId,
        sellerAvatar: advert.sellerAvatar,
        sellerRegistrationDate: advert.sellerRegistrationDate,
        characteristics: advert.characteristics ?? {},
        isFavorited: false,
      );
      
      log.d('   ✅ Listing created: ${listing.title} - ${listing.price}');
      return listing;
    } catch (e, stackTrace) {
      log.d('   ❌ ОШИБКА при конвертации Advert: $e');
      log.d('   StackTrace: $stackTrace');
      log.d('   Advert object: $advert');
      
      // Возвращаем объявление с минимальной информацией
      return Listing(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: 'assets/home_page/image.png',
        title: 'Ошибка загрузки: $e',
        price: '0',
        location: 'N/A',
        date: DateTime.now().toString(),
      );
    }
  }

  List<Listing> _generateSampleListings() {
    return [
      Listing(
        id: '1',
        imagePath: 'assets/home_page/apartment1.png',
        title: '4-к. квартира, 169,5 м²',
        price: '78 970 000 ₽',
        location: 'Москва, ул. Кусищева, 21А',
        date: 'Сегодня',
        isFavorited: false,
      ),
      Listing(
        id: '2',
        imagePath: 'assets/property_details_screen/image7.png',
        title: '4-к. квартира, 169,5 м².',
        price: '80 000 000 ₽',
        location: 'Москва, ул. Казакова, 7',
        date: 'Вчера',
        isFavorited: false,
      ),
      Listing(
        id: '3',
        imagePath: 'assets/property_details_screen/image8.png',
        title: '3-к. квартира, 120 м²',
        price: '65 200 000 ₽',
        location: 'Москва, ул. Тверская, 8',
        date: '2 дня назад',
        isFavorited: false,
      ),
      Listing(
        id: '4',
        imagePath: 'assets/home_page/image.png',
        title: '2-к. квартира, 85 м²',
        price: '42 800 000 ₽',
        location: 'Москва, ул. Арбат, 5',
        date: '3 дня назад',
        isFavorited: false,
      ),
      Listing(
        id: '5',
        imagePath: 'assets/home_page/image2.png',
        title: '5-к. квартира, 200 м²',
        price: '120 000 000 ₽',
        location: 'Москва, ул. Ленинский пр., 10',
        date: 'Неделя назад',
        isFavorited: false,
      ),
      Listing(
        id: '6',
        imagePath: 'assets/home_page/studio.png',
        title: '1-к. квартира, 55 м²',
        price: '35 600 000 ₽',
        location: 'Москва, ул. Пушкинская, 3',
        date: '2 недели назад',
        isFavorited: false,
      ),
    ];
  }

  double _parsePrice(String price) {
    return double.tryParse(price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  }

  DateTime _parseDate(String date) {
    final now = DateTime.now();
    try {
      if (date.contains('Сегодня')) return now;
      if (date.contains('Вчера')) return now.subtract(const Duration(days: 1));
      if (date.contains('дня назад')) {
        final days = int.parse(date.replaceAll(RegExp(r'[^0-9]'), ''));
        return now.subtract(Duration(days: days));
      }
      if (date.contains('Неделя назад'))
        return now.subtract(const Duration(days: 7));
      if (date.contains('недели назад')) {
        final weeks = int.parse(date.replaceAll(RegExp(r'[^0-9]'), ''));
        return now.subtract(Duration(days: weeks * 7));
      }
    } catch (_) {}
    return DateTime(1970);
  }

  void _sortListings(Set<String> selectedOptions) {
    SortOption? chosenSortOption;

    if (selectedOptions.contains('Сначала новые'))
      chosenSortOption = SortOption.newest;
    if (selectedOptions.contains('Сначала старые'))
      chosenSortOption = SortOption.oldest;
    if (selectedOptions.contains('Сначала дорогие'))
      chosenSortOption = SortOption.mostExpensive;
    if (selectedOptions.contains('Сначала дешевые'))
      chosenSortOption = SortOption.cheapest;

    if (chosenSortOption != null) {
      setState(() {
        switch (chosenSortOption!) {
          case SortOption.newest:
            _listings.sort(
              (a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)),
            );
            break;
          case SortOption.oldest:
            _listings.sort(
              (a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)),
            );
            break;
          case SortOption.mostExpensive:
            _listings.sort(
              (a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)),
            );
            break;
          case SortOption.cheapest:
            _listings.sort(
              (a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)),
            );
            break;
        }
      });
    }
  }

  // ============================================================
  //                          BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,

      bottomNavigationBar: _buildBottomNavigation(),

      body: SafeArea(
        child: Column(
          children: [
            // ---------------- FIXED HEADER ----------------
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 0),
              child: const Header(),
            ),

            const SizedBox(height: 16),

            // ---------------- FIXED SEARCH FIELD ----------------
            _buildSearchField(context),

            const SizedBox(height: 3),

            // ======================================================
            // LOADING или ВСЁ НИЖЕ — СКРОЛЛИТСЯ
            // ======================================================
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Загрузка объявлений...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Начало скролла — ровно здесь
                    SliverToBoxAdapter(child: _buildSectionHeader()),
                    SliverToBoxAdapter(child: const SizedBox(height: 18)),

                    // GRID объявлений или "нет результатов"
                    if (_listings.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'Нет объявлений с выбранными фильтрами',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
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
                            (context, index) => ListingCard(
                              listing: _listings[index],
                            ),
                            childCount: _listings.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //                      UI COMPONENTS
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
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Поиск",
                        hintStyle: TextStyle(color: textMuted),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FiltersRealEstateRentListingsScreen(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/home_page/settings.svg',
                      color: textMuted,
                      width: 20,
                      height: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.selectedCategory,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                  onSelectionChanged: (Set<String> selected) {
                    setState(() {
                      _selectedSortOptions = selected;
                      _sortListings(selected);
                    });
                  },
                  allowMultipleSelection: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard({required int index, required Listing listing}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MiniPropertyDetailsScreen(listing: listing),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              child: Image.asset(
                listing.imagePath,
                height: 159,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final old = _listings[index];
                            _listings[index] = Listing(
                              id: old.id,
                              imagePath: old.imagePath,
                              images: old.images,
                              title: old.title,
                              price: old.price,
                              location: old.location,
                              date: old.date,
                              isFavorited: !old.isFavorited,
                              sellerName: old.sellerName,
                              sellerAvatar: old.sellerAvatar,
                              sellerRegistrationDate:
                                  old.sellerRegistrationDate,
                              description: old.description,
                              characteristics: old.characteristics,
                            );
                          });
                        },
                        child: Icon(
                          _listings[index].isFavorited
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _listings[index].isFavorited
                              ? Colors.red
                              : Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.location,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    listing.date,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              _buildNavItem(homeIconAsset, 0),
              _buildNavItem(gridIconAsset, 1),
              _buildCenterAdd(2),
              _buildNavItem(shoppingCartAsset, 3),
              _buildNavItem(messageIconAssetLocal, 4),
              _buildNavItem(userIconAsset, 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index) {
    final isSelected = _selectedIndex == index;

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

  Widget _buildCenterAdd(int index) {
    final isSelected = _selectedIndex == index;

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
            plusIconAsset,
            width: 28,
            height: 28,
            color: isSelected ? activeIconColor : inactiveIconColor,
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
        routeName = AddListingScreen.routeName;
        Navigator.of(context).pushReplacementNamed(routeName);
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

  // ============================================================
  // ФИЛЬТРАЦИЯ ОБЪЯВЛЕНИЙ ПО СОХРАНЕННЫМ ФИЛЬТРАМ
  // ============================================================

  /// Применяет клиентскую фильтрацию к объявлениям
  /// ВАЖНО: Если есть value_selected фильтры, они УЖЕ применены на сервере - пропускаем клиентскую фильтрацию
  List<Listing> _applyClientSideFiltering(
    List<Listing> listings,
    Map<String, dynamic> filters,
  ) {
    if (filters.isEmpty || listings.isEmpty) {
      log.d('📋 [Filter] Фильтры пусты или нет объявлений');
      return listings;
    }

    log.d('\n🟢 ═══════════════════════════════════════════════════════════════');
    log.d('🟢 ПРИМЕНЕНИЕ ФИЛЬТРОВ');
    log.d('🟢 Начальные объявления: ${listings.length}');
    log.d('🟢 Применяемые фильтры: ${filters.keys.toList()}');
    log.d('🟢 ═══════════════════════════════════════════════════════════════\n');

    var result = listings;

    // 🔴 ВАЖНО: Если есть value_selected API фильтры, сервер УЖЕ отфильтровал результаты!
    // Клиентская перефильтрация вернет 0, потому что объявления не содержат характеристики.
    // Пропускаем клиентскую фильтрацию при наличии API фильтров.
    final hasApiFilters = filters.containsKey('value_selected') &&
        filters['value_selected'] is Map &&
        (filters['value_selected'] as Map).isNotEmpty;

    if (hasApiFilters) {
      log.d('⏭️  ПРОПУСКАЕМ КЛИЕНТСКУЮ ФИЛЬТРАЦИЮ - API УЖЕ ОТФИЛЬТРОВАЛА');
      log.d('   API фильтры value_selected уже применены на сервере, используем результаты как есть\n');
    } else {
      // Фильтрация по value_selected атрибутам (Ландшафт, Инфраструктура и т.д.)
      if (filters.containsKey('value_selected') &&
          filters['value_selected'] is Map) {
        final valueSelectedMap = (filters['value_selected'] as Map)
            .cast<String, dynamic>();
        result = _filterByValueSelected(result, valueSelectedMap);
      }
    }

    // Фильтрация по values атрибутам (диапазоны, цена, площадь и т.д.)
    // Только если НЕТ API фильтров
    if (!hasApiFilters &&
        filters.containsKey('values') &&
        filters['values'] is Map) {
      result = _filterByValues(
        result,
        (filters['values'] as Map).cast<String, dynamic>(),
      );
    }

    // Фильтрация по булевым атрибутам (Ипотека, Возможен торг и т.д.)
    // Только если НЕТ API фильтров
    if (!hasApiFilters &&
        filters.containsKey('boolean') &&
        filters['boolean'] is Map) {
      result = _filterByBoolean(
        result,
        (filters['boolean'] as Map).cast<String, dynamic>(),
      );
    }

    log.d('\n🟢 ═══════════════════════════════════════════════════════════════');
    log.d('🟢 ФИЛЬТРАЦИЯ ЗАВЕРШЕНА');
    log.d('🟢 API фильтры содержат value_selected: $hasApiFilters');
    log.d('🟢 Итоговые объявления: ${result.length}');
    log.d('🟢 ═══════════════════════════════════════════════════════════════\n');

    return result;
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

    log.d('🟢 ФИЛЬТР ПО АТРИБУТАМ (value_selected)');
    log.d('   Фильтры: $valueSelectedFilters');
    log.d('   ПЕРЕД: ${listings.length} объявлений');

    final filtered = listings.where((listing) {
      // Каждый фильтр должен совпадать - логика AND между фильтрами
      for (final filterEntry in valueSelectedFilters.entries) {
        final attrIdStr = filterEntry.key;
        final selectedValueIds = filterEntry.value;

        // Получаем значение из characteristics
        final characteristic = listing.characteristics[attrIdStr];

        // ВАЖНО: Если нет характеристики - ИСКЛЮЧАЕМ объявление
        if (characteristic == null) {
          return false;
        }

        // Извлекаем названия из characteristic для сравнения
        final characteristicNames = _extractCharacteristicNames(characteristic);
        final characteristicSet = _normalizeToSet(characteristicNames);

        // Также получаем ВСЕ возможные значения
        final allValues = _getAllCharacteristicValuesAsSet(characteristic);

        // Нормализуем selectedValueIds в Set<String>
        final selectedIds = _normalizeToSet(selectedValueIds);

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

        if (!hasMatch) {
          log.d('      ❌ ID=${listing.id}: атрибут $attrIdStr не совпадает');
          return false;
        }
      }

      return true;
    }).toList();

    log.d('   ПОСЛЕ: ${filtered.length} объявлений\n');
    return filtered;
  }

  /// Фильтрует объявления по values атрибутам (диапазоны)
  List<Listing> _filterByValues(
    List<Listing> listings,
    Map<String, dynamic> valueFilters,
  ) {
    if (valueFilters.isEmpty) {
      return listings;
    }

    log.d('🟢 ФИЛЬТР ПО ДИАПАЗОНАМ (values)');
    log.d('   ПЕРЕД: ${listings.length} объявлений');

    final filtered = listings.where((listing) {
      for (final filterEntry in valueFilters.entries) {
        final attrIdStr = filterEntry.key;
        final rangeData = filterEntry.value;

        final characteristic = listing.characteristics[attrIdStr];
        if (characteristic == null) {
          return false;
        }

        // Для простоты пропускаем диапазонную фильтрацию
        // В реальном приложении нужна парсинг min/max
      }
      return true;
    }).toList();

    log.d('   ПОСЛЕ: ${filtered.length} объявлений\n');
    return filtered;
  }

  /// Фильтрует объявления по булевым атрибутам
  List<Listing> _filterByBoolean(
    List<Listing> listings,
    Map<String, dynamic> booleanFilters,
  ) {
    if (booleanFilters.isEmpty) {
      return listings;
    }

    log.d('🟢 ФИЛЬТР ПО БУЛЕВЫМ АТРИБУТАМ');
    log.d('   ПЕРЕД: ${listings.length} объявлений');

    final filtered = listings.where((listing) {
      for (final filterEntry in booleanFilters.entries) {
        final attrIdStr = filterEntry.key;
        final expectedValue = filterEntry.value;

        final characteristic = listing.characteristics[attrIdStr];
        if (characteristic == null) {
          return false;
        }

        // Сравниваем булевые значения
        final characteristicValue = characteristic is bool 
            ? characteristic
            : characteristic.toString().toLowerCase() == 'true';

        if (characteristicValue != expectedValue) {
          return false;
        }
      }
      return true;
    }).toList();

    log.d('   ПОСЛЕ: ${filtered.length} объявлений\n');
    return filtered;
  }

  /// Извлекает названия/значения из характеристики для сравнения в фильтре
  dynamic _extractCharacteristicNames(dynamic characteristic) {
    if (characteristic == null) return null;

    if (characteristic is Map) {
      // ПРИОРИТЕТ 1: Поле 'value' - это ID значения
      if (characteristic.containsKey('value') && characteristic['value'] != null) {
        final value = characteristic['value'];
        return value is int ? value.toString() : value.toString();
      }

      // ПРИОРИТЕТ 2: Поле 'title' - название
      if (characteristic.containsKey('title') && characteristic['title'] != null) {
        return characteristic['title'].toString();
      }

      // ПРИОРИТЕТ 3: Поле 'value_id' - ID значения
      if (characteristic.containsKey('value_id') && characteristic['value_id'] != null) {
        return characteristic['value_id'].toString();
      }

      return characteristic;
    }

    return characteristic?.toString() ?? '';
  }

  /// Нормализует значение в Set<String> для сравнения
  Set<String> _normalizeToSet(dynamic value) {
    final result = <String>{};

    if (value == null) return result;

    if (value is Set) {
      for (final item in value) {
        result.add(item.toString());
      }
    } else if (value is List) {
      for (final item in value) {
        result.add(item.toString());
      }
    } else if (value is Map) {
      result.add(value.toString());
    } else {
      result.add(value.toString());
    }

    return result;
  }

  /// Получает все значения из Map характеристики как Set
  Set<String> _getAllCharacteristicValuesAsSet(dynamic characteristic) {
    final result = <String>{};

    if (characteristic is Map) {
      characteristic.forEach((key, value) {
        result.add(key.toString());
        if (value != null) {
          result.add(value.toString());
        }
      });
    }

    return result;
  }

  /// Преобразует структуру фильтров из Hive (flat map) в структуру для API (categorized by type)
  /// INPUT: {18: [154], 1127: {min: 50, max: 200}}
  /// OUTPUT: {value_selected: {18: [154]}, values: {1127: {min: 50, max: 200}}}
  Map<String, dynamic> _structureFiltersForApi(Map<String, dynamic> flatFilters) {
    if (flatFilters.isEmpty) {
      return {};
    }

    log.d('\n🔵 ════════════════════════════════════════════════════════════════');
    log.d('🔵 СТРУКТУРИРОВАНИЕ ФИЛЬТРОВ ДЛЯ API');
    log.d('🔵 Входящие фильтры (flat): $flatFilters\n');

    final structured = <String, dynamic>{};
    final valueSelectedMap = <String, dynamic>{};
    final valuesMap = <String, dynamic>{};
    final booleanMap = <String, dynamic>{};

    flatFilters.forEach((keyStr, value) {
      // Конвертируем ключ в int для определения типа
      final attrId = int.tryParse(keyStr) ?? 0;

      log.d('   🔍 Обработка: key=$keyStr, attrId=$attrId, value=$value, type=${value.runtimeType}');

      // Определяем тип фильтра по ID атрибута
      if (attrId < 1000) {
        // Это value_selected фильтр (категориальный)
        log.d('      ├─ Тип: value_selected (ID < 1000)');
        valueSelectedMap[keyStr] = value;
        log.d('      └─ Добавлен в value_selected');
      } else if (attrId < 2000) {
        // Это values фильтр (диапазон или множественные значения)
        log.d('      ├─ Тип: values (ID >= 1000 и < 2000)');
        valuesMap[keyStr] = value;
        log.d('      └─ Добавлен в values');
      } else {
        // Это boolean фильтр
        log.d('      ├─ Тип: boolean (ID >= 2000)');
        booleanMap[keyStr] = value;
        log.d('      └─ Добавлен в boolean');
      }
    });

    // Добавляем только непустые категории
    if (valueSelectedMap.isNotEmpty) {
      structured['value_selected'] = valueSelectedMap;
      log.d('\n   ✅ value_selected добавлена: $valueSelectedMap');
    }

    if (valuesMap.isNotEmpty) {
      structured['values'] = valuesMap;
      log.d('   ✅ values добавлена: $valuesMap');
    }

    if (booleanMap.isNotEmpty) {
      structured['boolean'] = booleanMap;
      log.d('   ✅ boolean добавлена: $booleanMap');
    }

    log.d('\n🔵 Исходящие фильтры (structured): $structured');
    log.d('🔵 ════════════════════════════════════════════════════════════════\n');

    return structured;
  }
}

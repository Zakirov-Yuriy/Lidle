import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/pages/full_category_screen/intermediate_filters_screen.dart';

// ============================================================
// "Экран объявлений недвижимости"
// ============================================================

const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';
const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class RealEstateListingsScreen extends StatefulWidget {
  const RealEstateListingsScreen({super.key});

  @override
  State<RealEstateListingsScreen> createState() =>
      _RealEstateListingsScreenState();
}

class _RealEstateListingsScreenState extends State<RealEstateListingsScreen> {
  int _selectedIndex = 0;
  late List<Listing> _listings;
  Set<String> _selectedSortOptions = {};

  @override
  void initState() {
    super.initState();
    _listings = _generateSampleListings();
    _selectedSortOptions.add('Сначала новые');
  }

  // ---------- SAMPLE LISTINGS ----------
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
  //                        BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- FIXED HEADER (не скроллится) ----------------
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 0, bottom: 16),
              child: const Header(),
            ),
            _buildSearchField(context),
            const SizedBox(height: 10),

            _buildLocationAndFilters(),
            SizedBox(height: 10),

            _buildCategoryChips(),

            // ---------------- ВСЁ НИЖЕ — СКРОЛЛИТСЯ ----------------
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ---- СКРОЛЛ СТАРТУЕТ ЗДЕСЬ ----
                  SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(child: _buildSectionHeader()),
                  SliverToBoxAdapter(child: SizedBox(height: 13)),

                  // ------------ GRID VIEW ------------
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

                  SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      
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
                "Мариуполь",
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
              Icon(Icons.keyboard_arrow_down, color: textMuted),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IntermediateFiltersScreen(),
                ),
              );
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

  Widget _buildCategoryChips() {
    final chipStyle = BoxDecoration(
      color: primaryBackground,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white),
    );

    Widget chip(String label, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: chipStyle,
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [
          chip("Квартиры", icon: Icons.close),
          const SizedBox(width: 10),
          chip("Новостройка", icon: Icons.keyboard_arrow_down_sharp),
          const SizedBox(width: 10),
          chip("Количество комнат", icon: Icons.apps),
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
          const Text(
            "Продажа квартир",
            style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB( 25, 0, 25,  48),
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
    );
  }

  Widget _buildNavItem(String iconPath, int index, int current) {
    final isSelected = index == current;
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => setState(() => _selectedIndex = index),
      child: Image.asset(
        iconPath,
        width: 28,
        height: 28,
        color: isSelected ? activeIconColor : inactiveIconColor,
      ),
    );
  }

  Widget _buildCenterAdd(int index, int current) {
    final isSelected = index == current;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => setState(() => _selectedIndex = index),
      child: Image.asset(
        plusIconAsset,
        width: 28,
        height: 28,
        color: isSelected ? activeIconColor : inactiveIconColor,
      ),
    );
  }

  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }
}

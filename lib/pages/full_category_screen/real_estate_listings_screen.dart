import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/header.dart';
import 'package:lidle/models/home_models.dart'; // Import Listing model
import 'package:lidle/widgets/selection_dialog.dart'; // Import SelectionDialog
import 'package:lidle/widgets/listing_card.dart'; // Import ListingCard
import 'package:lidle/pages/full_category_screen/intermediate_filters_screen.dart'; // Import IntermediateFiltersScreen

// Constants for bottom navigation assets
const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';

class RealEstateListingsScreen extends StatefulWidget {
  const RealEstateListingsScreen({super.key});

  @override
  State<RealEstateListingsScreen> createState() =>
      _RealEstateListingsScreenState();
}

class _RealEstateListingsScreenState extends State<RealEstateListingsScreen> {
  int _selectedIndex = 0; // For bottom navigation
  late List<Listing> _listings; // State variable for listings
  Set<String> _selectedSortOptions = {}; // New state for selected sort options

  @override
  void initState() {
    super.initState();
    _listings =
        _generateSampleListings(); // Initialize listings with sample data
    // Initialize with a default sort option if desired, e.g., 'Сначала новые'
    _selectedSortOptions.add('Сначала новые');
  }

  // Helper method to generate sample listings
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

  // Helper function to parse price from string.
  double _parsePrice(String price) {
    try {
      // Remove all characters except digits and convert to number.
      return double.parse(price.replaceAll(RegExp(r'[^0-9]'), ''));
    } catch (e) {
      return 0.0; // Return 0 in case of error.
    }
  }

  // Helper function to parse date. Assumes format "DD.MM.YYYY".
  DateTime _parseDate(String date) {
    try {
      final now = DateTime.now();
      if (date.contains('Сегодня')) {
        return now;
      } else if (date.contains('Вчера')) {
        return now.subtract(const Duration(days: 1));
      } else if (date.contains('дня назад')) {
        final days = int.parse(date.replaceAll(RegExp(r'[^0-9]'), ''));
        return now.subtract(Duration(days: days));
      } else if (date.contains('Неделя назад')) {
        return now.subtract(const Duration(days: 7));
      } else if (date.contains('недели назад')) {
        final weeks = int.parse(date.replaceAll(RegExp(r'[^0-9]'), ''));
        return now.subtract(Duration(days: weeks * 7));
      }
    } catch (e) {
      // Error parsing, return a very old date
    }
    return DateTime(1970);
  }

  void _sortListings(Set<String> selectedOptions) {
    // Mapping string options from SelectionDialog to internal SortOption enum
    SortOption? chosenSortOption;
    if (selectedOptions.contains('Сначала новые')) {
      chosenSortOption = SortOption.newest;
    } else if (selectedOptions.contains('Сначала старые')) {
      chosenSortOption = SortOption.oldest;
    } else if (selectedOptions.contains('Сначала дорогие')) {
      chosenSortOption = SortOption.mostExpensive;
    } else if (selectedOptions.contains('Сначала дешевые')) {
      chosenSortOption = SortOption.cheapest;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // const SizedBox(height: 16),
            // _buildTopBar(context),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 25, top: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header()],
              ),
            ),
            const SizedBox(height: 16),
            _buildSearchField(context),
            const SizedBox(height: 20),
            _buildLocationAndFilters(),
            const SizedBox(height: 18),
            _buildCategoryChips(),
            const SizedBox(height: 18),
            _buildSectionHeader(),
            const SizedBox(height: 13),
            Expanded(child: _buildListingsGrid()),
            const SizedBox(height: 16),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Поле поиска
  // ============================================================

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: textMuted),
          ),
          // const SizedBox(width: 12),
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

  // ============================================================
  // Локация + Фильтры
  // ============================================================

  Widget _buildLocationAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
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
                  builder: (context) => const IntermediateFiltersScreen(),
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

  // ============================================================
  // ЧИПЫ КАТЕГОРИЙ
  // ============================================================

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
          mainAxisSize: MainAxisSize.min,
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
        padding: const EdgeInsets.symmetric(horizontal: 25),
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

  // ============================================================
  // Заголовок "Продажа квартир"
  // ============================================================

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Removed const here
          const Text(
            // Added const back to Text
            "Продажа квартир",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          // SizedBox(width: 8),
          _buildFilterDropdown(
            label: _selectedSortOptions.isEmpty
                ? 'Сначала' // Default display if nothing selected
                : _selectedSortOptions.join(', '),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SelectionDialog(
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
                        _sortListings(
                          _selectedSortOptions,
                        ); // Apply sorting immediately
                      });
                    },
                    allowMultipleSelection:
                        false, // Only one sort option at a time
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GRID обьявлений
  // ============================================================

  Widget _buildListingsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: _listings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, i) => ListingCard(listing: _listings[i]),
    );
  }



  // ============================================================
  // Нижнее меню навигации
  // ============================================================

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, bottomNavPaddingBottom),
        child: Container(
          height: bottomNavHeight,
          decoration: BoxDecoration(
            color: bottomNavBackground,
            borderRadius: BorderRadius.circular(37.5),
            boxShadow: const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(homeIconAsset, 0, _selectedIndex),
              _buildNavItem(gridIconAsset, 1, _selectedIndex),
              _buildCenterAdd(2, _selectedIndex),
              _buildNavItem(messageIconAsset, 3, _selectedIndex),
              _buildNavItem(userIconAsset, 4, _selectedIndex),
            ],
          ),
        ),
      ),
    );
  }

  /// Приватный метод для построения отдельного элемента навигации.
  Widget _buildNavItem(String iconPath, int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.all(0),
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

  /// Приватный метод для построения центрального элемента "Добавить".
  Widget _buildCenterAdd(int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _selectedIndex = index),
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
    );
  }

  // Helper widget for building dropdowns
  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }
}

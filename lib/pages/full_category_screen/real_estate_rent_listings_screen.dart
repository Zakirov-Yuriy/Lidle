import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/pages/full_category_screen/filters_real_estate_rent_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/rooms/filters_room_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/rooms/filters_room_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/houses/filters_houses_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/houses/filters_houses_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/commercial_property/filters_commercial_property_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/commercial_property/filters_office_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/commercial_property/filters_office_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/land/filters_land_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/land/filters_land_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/garages/filters_garage_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/garages/filters_garage_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_apartment_rent_screen.dart' as apartment_rent;
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_rooms_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_hotel_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_hostel_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/daily_rent/daily_hourly_tour_operator_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/foreign_real_estate/filters_foreign_apartment_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/foreign_real_estate/filters_foreign_apartment_rent_screen.dart';
import 'package:lidle/pages/full_category_screen/foreign_real_estate/filters_foreign_house_sell_screen.dart';
import 'package:lidle/pages/full_category_screen/foreign_real_estate/filters_foreign_house_rent_screen.dart';

// ============================================================
// "Экран объявлений аренды недвижимости"
// ============================================================

const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';
const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class RealEstateRentListingsScreen extends StatefulWidget {
  final String? title;
  const RealEstateRentListingsScreen({super.key, this.title});

  @override
  State<RealEstateRentListingsScreen> createState() =>
      _RealEstateRentListingsScreenState();
}

class _RealEstateRentListingsScreenState
    extends State<RealEstateRentListingsScreen> {
  
  int _selectedIndex = 0; 
  late List<Listing> _listings; 
  Set<String> _selectedSortOptions = {}; 

  @override
  void initState() {
    super.initState();
    _listings =
        _generateSampleListings(); 
    
    _selectedSortOptions.add('Сначала новые');
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
    try {
      
      return double.parse(price.replaceAll(RegExp(r'[^0-9]'), ''));
    } catch (e) {
      return 0.0; 
    }
  }

  
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
      
    }
    return DateTime(1970);
  }

  void _sortListings(Set<String> selectedOptions) {

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

  String _formatTitle(String title) {
    // Add line break only for specific long titles
    if (title == 'Продажа производственных помещений') {
      return 'Продажа производственных\nпомещений';
    } else if (title == 'Продажа помещений свободного назначения') {
      return 'Продажа помещений свободного\nназначения';
    } else if (title == 'Аренда производственных помещений') {
      return 'Аренда производственных\nпомещений';
    } else if (title == 'Аренда помещений свободного назначения') {
      return 'Аренда помещений свободного\nназначения';
    } else if (title == 'Долгосрочная аренда гаражей, парковок') {
      return 'Долгосрочная аренда гаражей,\nпарковок';
    } else if (title == 'Долгосрочная аренда квартир за рубежом') {
      return 'Долгосрочная аренда квартир за\nрубежом';
    } else if (title == 'Долгосрочная аренда домов за рубежом') {
      return 'Долгосрочная аренда домов за\nрубежом';
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            
            
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

            _buildSectionHeader(),
            const SizedBox(height: 22),
            Expanded(child: _buildListingsGrid()),
            const SizedBox(height: 16),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  
  
  

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
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
                      if (widget.title == 'Продажа комнат') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersRoomShellScreen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда комнат') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersRoomRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа домов') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersHousesShellScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда домов') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersHousesRentScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа торговых помещений') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersCommercialPropertySellScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа офисов') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersOfficeSellScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Аренда офисов') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersOfficeRentScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа гаражей, парковок') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersGarageSellScreen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа земли') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersLandSellScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда земли') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersLandRentScreenen(),
                          ),
                        );
                      } else if (widget.title == 'Комнаты посуточно, почасово') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyHourlyRoomsRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Хостелы, койко-места') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyHourlyHostelRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Предложения Туроператоров') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyHourlyTourOperatorRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Отели, базы отдыха') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyHourlyHotelRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Квартиры посуточно, почасово') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const apartment_rent.DailyHourlyApartmenRentScreen(),
                          ),
                        );
                      } else if (widget.title?.contains('посуточно') == true) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyHourlyRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда гаражей, парковок') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersGarageRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа квартир за рубежом') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersForeignApartmentSellScreen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда квартир за рубежом') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersForeignApartmentRentScreen(),
                          ),
                        );
                      } else if (widget.title == 'Продажа домов за рубежом') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersForeignHouseSellScreen(),
                          ),
                        );
                      } else if (widget.title == 'Долгосрочная аренда домов за рубежом') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FiltersForeignHouseRentScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FiltersRealEstateRentListingsScreen(),
                          ),
                        );
                      }
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
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          
          Text(

            _formatTitle(widget.title ?? "Долгосрочная аренда квартир"),
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
                        ); 
                      });
                    },
                    allowMultipleSelection:
                        false, 
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  
  
  

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
      itemBuilder: (_, i) => _buildListingCard(
        index: i,
        listing: _listings[i], 
      ),
    );
  }

  Widget _buildListingCard({
    required int index,
    required Listing listing, 
  }) {
    return Container(
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
                          
                          _listings[index].isFavorited =
                              !_listings[index].isFavorited;
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
            boxShadow: const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(homeIconAsset, 0, _selectedIndex),
            _buildNavItem(gridIconAsset, 1, _selectedIndex),
            _buildCenterAdd(2, _selectedIndex),
            _buildNavItem(shoppingCartAsset, 3, _selectedIndex),
            _buildNavItem(messageIconAsset, 4, _selectedIndex),
            _buildNavItem(userIconAsset, 5, _selectedIndex),
          ],
          ),
        ),
      ),
    );
  }

  
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

  
  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_rent_listings_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';
import 'package:lidle/pages/full_category_screen/commercial_property/full_real_estate_commercial_property_screen.dart';
import 'package:lidle/pages/full_category_screen/commercial_property/filters_coworking_screen.dart';

// ============================================================
// "Экран подкатегорий квартир в недвижимости"
// ============================================================

class FullRealEstateApartmentsScreen extends StatefulWidget {
  final Category category;
  const FullRealEstateApartmentsScreen({super.key, required this.category});

  @override
  State<FullRealEstateApartmentsScreen> createState() =>
      _FullRealEstateApartmentsScreenState();
}

class _FullRealEstateApartmentsScreenState
    extends State<FullRealEstateApartmentsScreen> {
  List<Category> _getSubcategories() {
    return widget.category.children ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 20,
                    right: 23,
                    top: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [const Header()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: activeIconColor,
                          size: 16,
                        ),
                      ),
                      const Text(
                        'Назад',
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 25.0, right: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Недвижимость: ${widget.category.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _getSubcategories().length,
                            itemBuilder: (context, index) {
                              final subcategory = _getSubcategories()[index];
                              return Column(
                                children: [
                                  _buildOptionTile(context, subcategory),
                                  if (index < (_getSubcategories().length - 1))
                                    const Divider(
                                      color: Colors.white24,
                                      height: 0.9,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25, bottom: 86),
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, MapScreen.routeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009EE2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text(
                      'Показать на карте',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, Category subcategory) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        subcategory.name,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      onTap: () {
        final subcategoryName = subcategory.name;
        // Navigation logic based on subcategory name
        if (subcategoryName.toLowerCase().contains('продажа') &&
            subcategoryName.toLowerCase().contains('коммерческ') &&
            subcategoryName.toLowerCase().contains('недвижимост')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const FullRealEstateCommercialPropertyScreen(
                    type: 'Продажа коммерческой недвижимости',
                  ),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains('аренда') &&
            subcategoryName.toLowerCase().contains('коммерческ') &&
            subcategoryName.toLowerCase().contains('недвижимост')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const FullRealEstateCommercialPropertyScreen(
                    type: 'Аренда коммерческая недвижимости',
                  ),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains('продажа комнат')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains('продажа домов')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains('продажа земли')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains('продажа гаражей')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains(
          'продажа квартир за рубежом',
        )) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        } else if (subcategoryName == 'Коворкинги') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FiltersCoworkingScreenen(),
            ),
          );
        } else if (subcategoryName.toLowerCase().contains("продажа")) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RealEstateListingsScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RealEstateRentListingsScreen(title: subcategoryName),
            ),
          );
        }
      },
    );
  }
}

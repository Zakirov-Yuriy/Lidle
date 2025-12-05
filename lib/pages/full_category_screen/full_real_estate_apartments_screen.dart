import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_rent_listings_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';

// ============================================================
// "Экран подкатегорий квартир в недвижимости"
// ============================================================

class FullRealEstateApartmentsScreen extends StatefulWidget {
  const FullRealEstateApartmentsScreen({super.key});

  @override
  State<FullRealEstateApartmentsScreen> createState() => _FullRealEstateApartmentsScreenState();
}

class _FullRealEstateApartmentsScreenState extends State<FullRealEstateApartmentsScreen> {
  bool _showAllActive = true;

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
                  padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [const Header()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10.0, right: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.lightBlueAccent, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Назад',
                        style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 16,
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
                            color: Colors.lightBlueAccent,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 25.0, right: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Недвижимость: Квартиры',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildOptionTile(context, "Продажа квартир"),
                      _buildOptionTile(context, "Долгосрочная аренда квартир"),
                    ],
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
                    onPressed: () => Navigator.pushNamed(context, MapScreen.routeName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showAllActive
                          ? const Color(0xFF009EE2)
                          : Colors.transparent,
                      side: _showAllActive
                          ? null
                          : const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text(
                      'Показать все',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showAllActive = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showAllActive
                          ? const Color(0xFF009EE2)
                          : primaryBackground,
                      side: !_showAllActive
                          ? null
                          : const BorderSide(color: Colors.white24),
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

  Widget _buildOptionTile(BuildContext context, String title) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            if (title == "Продажа квартир") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RealEstateListingsScreen()),
              );
            } else if (title == "Долгосрочная аренда квартир") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RealEstateRentListingsScreen()),
              );
            }
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}

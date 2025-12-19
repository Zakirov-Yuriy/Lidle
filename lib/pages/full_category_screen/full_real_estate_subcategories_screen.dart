import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/full_real_estate_apartments_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'map_screen.dart';

// ============================================================
// "Экран подкатегорий недвижимости"
// ============================================================

class FullRealEstateSubcategoriesScreen extends StatefulWidget {
  const FullRealEstateSubcategoriesScreen({super.key});

  @override
  State<FullRealEstateSubcategoriesScreen> createState() =>
      _FullRealEstateSubcategoriesScreenState();
}

class _FullRealEstateSubcategoriesScreenState
    extends State<FullRealEstateSubcategoriesScreen> {
  bool _showAllActive = true;

  @override
  Widget build(BuildContext context) {
    final subcategories = [
      'Квартиры',
      'Комнаты',
      'Дома',
      'Коммерческая недвижимость',
      'Земля',
      'Посуточная аренда жилья',
      'Гаражи, парковки',
      'Недвижимость за рубежом',
    ];

    return Scaffold(
      backgroundColor: primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: primaryBackground,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 25.0, right: 25),
            child: Text(
              'Категория: Недвижимость',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: ListView.builder(
                itemCount: subcategories.length + 1,
                itemBuilder: (context, index) {
                  if (index < subcategories.length) {
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            subcategories[index],
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FullRealEstateApartmentsScreen(subcategory: subcategories[index]),
                              ),
                            );
                          },
                        ),
                        if (index < subcategories.length - 1)
                          const Divider(color: Colors.white24, height: 1),
                      ],
                    );
                  } else {
                    return const Divider(color: Colors.white24, height: 1);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 57),
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 51,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showAllActive = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showAllActive
                          ? const Color(0xFF009EE2)
                          : primaryBackground,
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
                    onPressed: () {
                      setState(() {
                        _showAllActive = false;
                      });
                      Navigator.pushNamed(context, MapScreen.routeName);
                    },
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
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
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
  final String subcategory;
  const FullRealEstateApartmentsScreen({super.key, required this.subcategory});

  @override
  State<FullRealEstateApartmentsScreen> createState() => _FullRealEstateApartmentsScreenState();
}

class _FullRealEstateApartmentsScreenState extends State<FullRealEstateApartmentsScreen> {

  @override
  Widget build(BuildContext context) {
    // Определяем опции и заголовок в зависимости от подкатегории
    List<String> options;
    String titleText;
    switch (widget.subcategory) {
      case 'Квартиры':
        options = ['Продажа квартир', 'Долгосрочная аренда квартир'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Комнаты':
        options = ['Продажа комнат', 'Долгосрочная аренда комнат'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Дома':
        options = ['Продажа домов', 'Долгосрочная аренда домов'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Коммерческая недвижимость':
        options = ['Продажа коммерческой недвижимости', 'Долгосрочная аренда коммерческая недвижимость', 'Коворкинги'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;

      case 'Земля':
        options = ['Продажа земли', 'Долгосрочная аренда земли'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Посуточная аренда жилья':
        options = [
          'Дома посуточно, почасово',
          'Квартиры посуточно, почасово',
          'Комнаты посуточно, почасово',
          'Отели, базы отдыха',
          'Хостелы, койко-места',
          'Предложения Туроператоров'
        ];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Гаражи, парковки':
        options = ['Продажа гаражей, парковок', 'Долгосрочная аренда гаражей, парковок'];
        titleText = 'Недвижимость: ${widget.subcategory}';
        break;
      case 'Недвижимость за рубежом':
        options = ['Продажа квартир за рубежом', 'Долгосрочная аренда квартир за рубежом', 'Продажа домов за рубежом', 'Долгосрочная аренда домов за рубежом'];
        titleText = 'Недвижимость: За рубежом';
        break;
      default:
        options = ['Продажа ${widget.subcategory.toLowerCase()}', 'Аренда ${widget.subcategory.toLowerCase()}'];
        titleText = 'Недвижимость: ${widget.subcategory}';
    }

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
                Padding(
                  padding: const EdgeInsets.only(left: 25.0, right: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...options.map((option) => _buildOptionTile(context, option)),
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
            if (title == 'Продажа коммерческой недвижимости') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FullRealEstateCommercialPropertyScreen(type: 'Продажа коммерческая недвижимости')),
              );
            } else if (widget.subcategory == 'Комнаты' ||
                widget.subcategory == 'Дома' ||
                widget.subcategory == 'Земля' ||
                widget.subcategory == 'Посуточная аренда жилья' ||
                widget.subcategory == 'Гаражи, парковки' ||
                widget.subcategory == 'Недвижимость за рубежом') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateRentListingsScreen(title: title)),
              );
            } else if (title == 'Долгосрочная аренда коммерческая недвижимость') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FullRealEstateCommercialPropertyScreen(type: 'Аренда коммерческая недвижимости')),
              );
            } else if (title == 'Коворкинги') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FiltersCoworkingScreenen()),
              );
            } else if (title.toLowerCase().contains("продажа")) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RealEstateListingsScreen()),
              );
            } else {
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

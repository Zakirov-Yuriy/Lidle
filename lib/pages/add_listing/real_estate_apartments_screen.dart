import 'package:flutter/material.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_rent_screen.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_sell_screen.dart';
import 'package:lidle/pages/add_listing/rooms/add_room_rent_screen.dart';
import 'package:lidle/pages/add_listing/rooms/add_room_sell_screen.dart';
import 'package:lidle/widgets/components/header.dart';


// ============================================================
// "Виджет: Экран подкатегорий недвижимости (квартиры)"
// ============================================================

// Функция для получения правильной формы слова для опций продажи/аренды
String _getSubcategoryForOptions(String subcategory) {
  const Map<String, String> forms = {
    'Квартиры': 'квартир',
    'Комнаты': 'комнат',
    'Дома': 'домов',
    'Коммерческая недвижимость': 'коммерческая недвижимости',
    'Земля': 'земли',
    'Посуточная аренда жилья': 'посуточной аренды жилья',
    'Гаражи, парковки': 'гаражей, парковок',
    'Недвижимость за рубежом': 'Недвижимости за рубежом',
  };
  return forms[subcategory] ?? subcategory;
}

class RealEstateApartmentsScreen extends StatelessWidget {
  final String subcategory;

  const RealEstateApartmentsScreen({super.key, required this.subcategory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), 
      
      body: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Column(
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
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Недвижимость: ${subcategory == 'Недвижимость за рубежом' ? 'За рубежом' : subcategory}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (subcategory == 'Посуточная аренда жилья') ...[
                  _buildOptionTile(context, "Дома посуточно, почасово"),
                  _buildOptionTile(context, "Квартиры посуточно, почасово"),
                  _buildOptionTile(context, "Комнаты посуточно, почасово"),
                  _buildOptionTile(context, "Отели, базы отдыха"),
                  _buildOptionTile(context, "Хостелы, койко-места"),
                  _buildOptionTile(context, "Предложения туроператоров"),
                ] else if (subcategory == 'Недвижимость за рубежом') ...[
                  _buildOptionTile(context, "Продажа квартир за рубежом"),
                  _buildOptionTile(context, "Долгосрочная аренда квартир за рубежом"),
                  _buildOptionTile(context, "Продажа домов за рубежом"),
                  _buildOptionTile(context, "Долгосрочная аренда домов за рубежом"),
                ] else ...[
                  _buildOptionTile(context, "Продажа ${_getSubcategoryForOptions(subcategory)}"),
                  _buildOptionTile(context, subcategory == 'Коммерческая недвижимость'
                      ? "Аренда ${_getSubcategoryForOptions(subcategory)}"
                      : "Долгосрочная аренда ${_getSubcategoryForOptions(subcategory)}"),
                  if (subcategory == 'Коммерческая недвижимость')
                    _buildOptionTile(context, "Коворкинги"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// "Виджет: Построение плитки опции (продажа/аренда квартир)"
// ============================================================
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
            if (title == "Продажа комнат") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRoomSellScreen()),
              );
            } else if (title.startsWith("Продажа")) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentSellScreen()),
              );
            } else if (title == "Долгосрочная аренда комнат") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRoomRentScreen()),
              );
            } else if (title.startsWith("Аренда") || title.startsWith("Долгосрочная аренда")) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentRentScreen()),
              );
            }
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_rent_screen.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_sell_screen.dart';
import 'package:lidle/pages/add_listing/houses/add_house_rent_screen.dart';
import 'package:lidle/pages/add_listing/houses/add_house_sell_screen.dart';
import 'package:lidle/pages/add_listing/rooms/add_room_rent_screen.dart';
import 'package:lidle/pages/add_listing/rooms/add_room_sell_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/full_category_screen/real_estate_rent_listings_screen.dart';


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

// Функция для получения опций коммерческой недвижимости
List<String> _getCommercialOptions(String type) {
  const List<String> sellOptions = [
    "Продажа торговых помещений",
    "Продажа офисов",
    "Продажа ларьков",
    "Продажа складов, ангаров",
    "Продажа кофеен, кафе, ресторанов",
    "Продажа отелей, баз отдых",
    "Продажа СТО, автомоек, АЗС",
    "Продажа салонов красоты, клиник",
    "Продажа производственных помещений",
    "Продажа помещений свободного назначения",
  ];

  const List<String> rentOptions = [
    "Аренда офисов",
    "Аренда торговых помещений",
    "Аренда МАФов",
    "Аренда складов, ангаров",
    "Аренда кофеен, кафе, ресторанов",
    "Аренда отелей, баз отдых",
    "Аренда СТО, автомоек, АЗС",
    "Аренда салонов красоты, клиник",
    "Аренда производственных помещений",
    "Аренда помещений свободного назначения",
    "Аренда других помещений",
    
  ];

  if (type == "Продажа коммерческая недвижимости") {
    return sellOptions;
  } else if (type == "Аренда коммерческая недвижимости") {
    return rentOptions;
  } else {
    return [];
  }
}

class FullRealEstateCommercialPropertyScreen extends StatelessWidget {
  final String type;

  const FullRealEstateCommercialPropertyScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final String subcategory = 'Коммерческая недвижимость';
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
                  'Недвижимость: Коммерческая недвижимость: $type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._getCommercialOptions(type).map((option) => _buildOptionTile(context, option)),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          onTap: () {
            if (title == "Аренда офисов") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateRentListingsScreen(title: title)),
              );
            } else if (_getCommercialOptions("Продажа коммерческая недвижимости").contains(title)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateRentListingsScreen(title: title)),
              );
            } else if (_getCommercialOptions("Аренда коммерческая недвижимости").contains(title)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateRentListingsScreen(title: title)),
              );
            } else if (title == "Продажа комнат") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRoomSellScreen()),
              );
            } else if (title == "Продажа домов") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHouseSellScreen()),
              );
            } else if (title.startsWith("Продажа")) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentSellScreen()),
              );
            } else if (title == "Долгосрочная аренда домов") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHouseRentScreen()),
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

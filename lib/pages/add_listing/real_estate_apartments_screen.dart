import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_rent_screen.dart';
import 'package:lidle/pages/add_listing/apartments/add_apartment_sell_screen.dart';
import 'package:lidle/pages/add_listing/commercial_property/add_coworking_sell_screen.dart';
import 'package:lidle/pages/add_listing/commercial_property/real_estate_commercial_property_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_apartment_daily_rent_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_daily_share_sell_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_hostel_bed_rent_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_hotel_resort_rent_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_room_daily_rent_screen.dart';
import 'package:lidle/pages/add_listing/daily_rent/add_tour_operator_offer_screen.dart';
import 'package:lidle/pages/add_listing/houses/add_house_rent_screen.dart';
import 'package:lidle/pages/add_listing/houses/add_house_sell_screen.dart';
import 'package:lidle/pages/add_listing/land/add_land_sell_screen.dart';
import 'package:lidle/pages/add_listing/land/add_land_rent_screen.dart';
import 'package:lidle/pages/add_listing/rooms/add_room_sell_screen.dart';
import 'package:lidle/pages/add_listing/garages/add_garage_parking_sell_screen.dart';
import 'package:lidle/pages/add_listing/garages/add_garage_parking_long_rent_screen.dart';
import 'package:lidle/pages/add_listing/foreign_real_estate/add_apartment_abroad_sell_screen.dart';
import 'package:lidle/pages/add_listing/foreign_real_estate/add_apartment_abroad_long_rent_screen.dart';
import 'package:lidle/pages/add_listing/foreign_real_estate/add_house_abroad_sell_screen.dart';
import 'package:lidle/pages/add_listing/foreign_real_estate/add_house_abroad_long_rent_screen.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';
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
            padding: const EdgeInsets.only(bottom: 10, right: 23, top: 20),
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
                const SizedBox(height: 10),
                
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
            if (title == "Дома посуточно, почасово") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddDailyShareSellScreen()),
              );
            } else if (title == "Квартиры посуточно, почасово") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentDailyRentScreen()),
              );
            } else if (title == "Комнаты посуточно, почасово") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRoomDailyRentScreen()),
              );
            } else if (title == "Отели, базы отдыха") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHotelResortRentScreen()),
              );
            } else if (title == "Хостелы, койко-места") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHostelBedRentScreen()),
              );
            } else if (title == "Предложения туроператоров") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTourOperatorOfferScreen()),
              );
            } else if (title == "Коворкинги") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCoworkingSellScreen(initialCategory: title)),
              );
            } else if (title == "Продажа земли") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddLandSellScreen()),
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
            } else if (title == "Продажа коммерческая недвижимости") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateCommercialPropertyScreen(type: title)),
              );
            } else if (title == "Аренда коммерческая недвижимости") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateCommercialPropertyScreen(type: title)),
              );
            } else if (title == "Продажа гаражей, парковок") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddGarageParkingSellScreen()),
              );
            } else if (title == "Продажа квартир за рубежом") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentAbroadSellScreen()),
              );
            } else if (title == "Продажа домов за рубежом") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHouseAbroadSellScreen()),
              );
            } else if (title.startsWith("Продажа")) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentSellScreen()),
              );
            } else if (title == "Долгосрочная аренда земли") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddLandRentScreen()),
              );
            } else if (title == "Долгосрочная аренда домов") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHouseRentScreen()),
              );
            } else if (title == "Долгосрочная аренда комнат") {
              Navigator.push(
                context,
                // MaterialPageRoute(builder: (context) => const AddRoomRentScreen()),
                MaterialPageRoute(builder: (context) => const DynamicFilter()),
              );
            } else if (title == "Долгосрочная аренда гаражей, парковок") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddGarageParkingLongRentScreen()),
              );
            } else if (title == "Долгосрочная аренда квартир за рубежом") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddApartmentAbroadLongRentScreen()),
              );
            } else if (title == "Долгосрочная аренда домов за рубежом") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddHouseAbroadLongRentScreen()),
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

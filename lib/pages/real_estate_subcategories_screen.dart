import 'package:flutter/material.dart';
import 'package:lidle/widgets/header.dart';
import 'real_estate_apartments_screen.dart';

class RealEstateSubcategoriesScreen extends StatelessWidget {
  const RealEstateSubcategoriesScreen({super.key});

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
      backgroundColor: const Color(0xFF1C2834),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFF1C2834),
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
                  padding: const EdgeInsets.only(left: 10.0, right: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.lightBlueAccent,
                          size: 16,
                        ),
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
                          Navigator.pop(context); // Закрыть экран при отмене
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
          ),
          const Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25),
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
                            if (subcategories[index] == 'Квартиры') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RealEstateApartmentsScreen(),
                                ),
                              );
                            }
                            // Навигация или логика выбора подкатегории для других элементов
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
        ],
      ),
    );
  }
}

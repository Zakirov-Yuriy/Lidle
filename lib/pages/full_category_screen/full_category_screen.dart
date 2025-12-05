import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';
import 'full_real_estate_subcategories_screen.dart';

// ============================================================
// "Экран всех категорий предложений"
// ============================================================

class FullCategoryScreen extends StatefulWidget {
  static const String routeName = '/full-category';

  const FullCategoryScreen({super.key});

  @override
  State<FullCategoryScreen> createState() =>
      _FullCategoryScreenState();
}

class _FullCategoryScreenState extends State<FullCategoryScreen> {
  final Set<String> _activeCategories = {
    'Недвижимость',
    'Авто и мото',
    'Работа',
    'Подработка',
  };

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'title': 'Недвижимость', 'image': 'assets/categories/real_estate.png'},
      {'title': 'Авто и мото', 'image': 'assets/categories/auto.png'},
      {'title': 'Работа', 'image': 'assets/categories/job.png'},
      {'title': 'Подработка', 'image': 'assets/categories/part_time.png'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1D2835),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [const Header(),],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,

                  icon: const Icon(
                    Icons.arrow_back_ios,

                    size: 16,
                    color: Color(0xFF009EE2),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Назад',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF009EE2),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10, left: 25),
            child: Text(
              'Все предложения на LIDLE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 25, bottom: 106),

              itemCount: categories.length,
              itemBuilder: (context, index) {
                final item = categories[index];
                return GestureDetector(
                  onTap: () {
                    if (item['title'] == 'Недвижимость') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const FullRealEstateSubcategoriesScreen(),
                        ),
                      );
                    } else {
                      setState(() {
                        if (_activeCategories.contains(item['title']!)) {
                          _activeCategories.remove(item['title']!);
                        } else {
                          _activeCategories.add(item['title']!);
                        }
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),

                    child: Stack(
                      children: [
                        Image.asset(
                          item['image']!,
                          height: 93,
                          width: 366,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 39,
                          left: 30,
                          child: Text(
                            item['title']!,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!_activeCategories.contains(item['title']!))
                          Container(
                            height: 93,
                            width: 366,
                            color: const Color(0xFF323C49).withOpacity(0.8),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/add_listing/real_estate_apartments_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

// ============================================================
// "Виджет: Экран подкатегорий недвижимости"
// ============================================================
class RealEstateSubcategoriesScreen extends StatefulWidget {
  const RealEstateSubcategoriesScreen({super.key});

  @override
  State<RealEstateSubcategoriesScreen> createState() =>
      _RealEstateSubcategoriesScreenState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана подкатегорий недвижимости"
// ============================================================
class _RealEstateSubcategoriesScreenState
    extends State<RealEstateSubcategoriesScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await HiveService.getUserData('token');
      final catalogWithCategories = await ApiService.getCatalog(
        1,
        token: token,
      );

      print('Loaded categories: ${catalogWithCategories.categories.length}');
      catalogWithCategories.categories.forEach(
        (category) => print('Category: ${category.name}'),
      );

      setState(() {
        _categories = catalogWithCategories.categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.only(
                    bottom: 10,
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: activeIconColor),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки: $_error',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCategories,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index < _categories.length) {
                          final category = _categories[index];
                          return Column(
                            children: [
                              ListTile(
                                title: Text(
                                  category.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white70,
                                ),
                                onTap: () {
                                  // Передаем ID категории для получения её детей через API
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RealEstateApartmentsScreen(
                                            categoryId: category.id,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              if (index < _categories.length - 1)
                                const Divider(color: Colors.white24, height: 1),
                            ],
                          );
                        } else {
                          return const Divider(
                            color: Colors.white24,
                            height: 1,
                          );
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

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_apartments_screen.dart';
import 'package:lidle/widgets/components/header.dart';

// ============================================================
// "Полный экран подкатегорий недвижимости"
// ============================================================

class RealEstateFullSubcategoriesScreen extends StatefulWidget {
  final int catalogId; // ID каталога (Недвижимость=1, Работа=2 и т.д.)

  const RealEstateFullSubcategoriesScreen({super.key, this.catalogId = 1});

  @override
  State<RealEstateFullSubcategoriesScreen> createState() =>
      _RealEstateFullSubcategoriesScreenState();
}

class _RealEstateFullSubcategoriesScreenState
    extends State<RealEstateFullSubcategoriesScreen> {
  List<dynamic> apiSubcategories = [];
  bool isLoadingSubcategories = false;
  String catalogName = 'Загружаю...'; // Название каталога для отображения

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  /// Загружает подкатегории для переданного каталога с API
  Future<void> _loadSubcategories() async {
    setState(() => isLoadingSubcategories = true);
    print('🔄 Начинаем загрузку категорий из каталога ID=${widget.catalogId} с API...');
    
    try {
      // Получаем текущий токен из Hive
      final token = HiveService.getUserData('token') as String?;
      print('🔑 Токен получен: ${token != null ? "✅ YES" : "❌ NO"}');
      print('📦 Загружаем каталог ID=${widget.catalogId}');
      
      // Получаем каталог с категориями
      final catalog = await ApiService.getCatalog(widget.catalogId, token: token);
      print('✅ Каталог загружен: ${catalog.name} (ID=${catalog.id})');
      print('✅ Загружено ${catalog.categories.length} категорий для этого каталога');
      
      // Выводим названия загруженных категорий для отладки
      for (var i = 0; i < catalog.categories.length; i++) {
        print('   [$i] ${catalog.categories[i].name}');
      }
      
      if (mounted) {
        setState(() {
          catalogName = catalog.name; // Сохраняем название каталога
          apiSubcategories = catalog.categories;
          print('✅ apiSubcategories обновлены (${apiSubcategories.length} элементов)');
          print('✅ catalogName обновлено: $catalogName');
        });
      }
    } catch (e) {
      print('❌ ОШИБКА при загрузке подкатегорий: $e');
      if (mounted) {
        setState(() => apiSubcategories = []);
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingSubcategories = false);
        print('✅ Загрузка подкатегорий завершена');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25),
            child: Text(
              'Категория: $catalogName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: isLoadingSubcategories
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(activeIconColor),
                      ),
                    )
                  : apiSubcategories.isEmpty
                      ? const Center(
                          child: Text(
                            'Категории не найдены',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: apiSubcategories.length + 1,
                          itemBuilder: (context, index) {
                            if (index < apiSubcategories.length) {
                              final category = apiSubcategories[index];
                              final categoryName = category.name;
                              final hasChildren = category.children != null && category.children!.isNotEmpty;
                              
                              return Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      categoryName,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white70,
                                    ),
                                    onTap: () async {
                                      // Если у категории есть подкатегории (дети), переходим на экран выбора
                                      if (hasChildren) {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RealEstateFullApartmentsScreen(
                                              selectedCategory: categoryName,
                                              categoryChildren: category.children,
                                              parentCategoryId: category.id, // Передаём ID родительской категории
                                            ),
                                          ),
                                        );
                                        // Если получили результат, возвращаем его на intermediate_filters_screen.dart
                                        if (result != null && mounted) {
                                          Navigator.pop(context, result);
                                        }
                                      } else {
                                        // Для категорий без подкатегорий просто возвращаем название
                                        Navigator.pop(context, categoryName);
                                      }
                                    },
                                  ),
                                  if (index < apiSubcategories.length - 1)
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

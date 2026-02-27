import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_rent_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';

/// ============================================================
/// Универсальный экран для просмотра категорий и подкатегорий
/// Заменяет все специальные экраны недвижимости
/// ============================================================
class UniversalBrowseCategoryScreen extends StatefulWidget {
  /// ID каталога (если это первый уровень)
  final int? catalogId;

  /// Категория с подкатегориями (если это не первый уровень)
  final Category? category;

  /// Название каталога для отображения в заголовке
  final String? catalogName;

  /// Уровень вложенности для отладки
  final int level;

  const UniversalBrowseCategoryScreen({
    super.key,
    this.catalogId,
    this.category,
    this.catalogName,
    this.level = 0,
  }) : assert(
         (catalogId != null && catalogName != null) || category != null,
         'Необходимо указать либо catalogId с catalogName, либо category',
       );

  @override
  State<UniversalBrowseCategoryScreen> createState() =>
      _UniversalBrowseCategoryScreenState();
}

class _UniversalBrowseCategoryScreenState
    extends State<UniversalBrowseCategoryScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Загружает категории в зависимости от типа экрана
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await HiveService.getUserData('token');

      List<Category> categories = [];

      if (widget.catalogId != null) {
        // Загружаем категории каталога по ID
        // print();

        final catalogWithCategories = await ApiService.getCatalog(
          widget.catalogId!,
          token: token,
        );

        categories = catalogWithCategories.categories;

        // print();
      } else if (widget.category != null) {
        // Используем дочерние категории из переданной категории
        categories = widget.category!.children ?? [];

        // print();
      }

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      // print('❌ Browse Level ${widget.level}: ERROR LOADING CATEGORIES: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Получить название для заголовка
  String _getTitle() {
    if (widget.category != null) {
      return '${widget.catalogName ?? 'Каталог'}: ${widget.category!.name}';
    }
    return 'Категория: ${widget.catalogName}';
  }

  /// Определяет, какой экран списков открыть для данной категории
  void _navigateToListings(Category category) {
    final categoryName = category.name.toLowerCase();

    // Логика определения типа экрана на основе названия категории
    // (аналогично логике из FullRealEstateApartmentsScreen)
    if (categoryName.contains('продажа') &&
        categoryName.contains('коммерческ') &&
        categoryName.contains('недвижимост')) {
      // Для коммерческой недвижимости продажи можно создать специальный экран
      // или использовать универсальный
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealEstateListingsScreen(
            categoryId: category.id,
            categoryName: category.name,
            isFromFullCategory: true,
          ),
        ),
      );
    } else if (categoryName.contains('аренда') &&
        categoryName.contains('коммерческ') &&
        categoryName.contains('недвижимост')) {
      // Для коммерческой недвижимости аренды
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RealEstateRentListingsScreen(title: category.name),
        ),
      );
    } else if (categoryName.contains('продажа')) {
      // Для всех типов продажи используем основной экран списков
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealEstateListingsScreen(
            categoryId: category.id,
            categoryName: category.name,
            isFromFullCategory: true,
          ),
        ),
      );
    } else {
      // Для аренды и других случаев используем универсальный экран списков
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealEstateListingsScreen(
            categoryId: category.id,
            categoryName: category.name,
            isFromFullCategory: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2835),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 25, right: 23, top: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [const Header()],
            ),
          ),

          // Back button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_ios,
                        color: activeIconColor,
                        size: 16,
                      ),
                      const SizedBox(
                        width: 0,
                      ), // Небольшой отступ между иконкой и текстом
                      const Text(
                        'Назад',
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.only(
              left: 25,
              right: 25,
              top: 7,
              bottom: 5,
            ),
            child: Text(
              _getTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Content
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
                : _categories.isEmpty
                ? const Center(
                    child: Text(
                      'Категории не найдены',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 25,
                            right: 25,
                            top: 0,
                            bottom: 20,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return _CategoryTile(
                              category: category,
                              level: widget.level + 1,
                              catalogName: widget.catalogName,
                              onTap: () {
                                // print();

                                // Если есть подкатегории, переходим глубже
                                if (category.children != null &&
                                    category.children!.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          UniversalBrowseCategoryScreen(
                                            category: category,
                                            catalogName: widget.catalogName,
                                            level: widget.level + 1,
                                          ),
                                    ),
                                  );
                                } else {
                                  // Если это конечная категория, открываем экран списков
                                  // print();
                                  _navigateToListings(category);
                                }
                              },
                            );
                          },
                        ),
                      ),

                      // Кнопки внизу (Показать все / Показать на карте)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 25,
                          right: 25,
                          bottom: 86,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 51,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Показать все объявления каталога
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RealEstateListingsScreen(
                                            // Передаем catalogId для показа всех объявлений этого каталога
                                            catalogId: widget.catalogId,
                                            categoryName: widget.catalogName,
                                            isFromFullCategory: true,
                                          ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF009EE2),
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
                                  Navigator.pushNamed(
                                    context,
                                    MapScreen.routeName,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBackground,
                                  side: const BorderSide(color: Colors.white24),
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
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// Компонент: Плитка категории
/// ============================================================
class _CategoryTile extends StatelessWidget {
  final Category category;
  final int level;
  final String? catalogName;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.level,
    this.catalogName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF3A4A5F), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category name
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Arrow icon
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



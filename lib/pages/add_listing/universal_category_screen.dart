import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';

/// ============================================================
/// Виджет: Универсальный экран для отображения категорий
/// ============================================================
///
/// Этот экран динамически отображает категории любого каталога.
/// Работает для первого уровня категорий и всех подуровней.
/// При добавлении новой категории на сервер она автоматически отобразится.
class UniversalCategoryScreen extends StatefulWidget {
  /// ID каталога (если это первый уровень) или null
  final int? catalogId;

  /// Категория с подкатегориями (если это не первый уровень)
  final Category? category;

  /// Название каталога для отображения в заголовке
  final String? catalogName;

  /// Уровень вложенности для отладки
  final int level;

  const UniversalCategoryScreen({
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
  State<UniversalCategoryScreen> createState() =>
      _UniversalCategoryScreenState();
}

/// ============================================================
/// Класс состояния: Управление состоянием универсального экрана
/// ============================================================
class _UniversalCategoryScreenState extends State<UniversalCategoryScreen> {
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
      // print('❌ Level ${widget.level}: ERROR LOADING CATEGORIES: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Получить название для заголовка
  String _getTitle() {
    if (widget.category != null) {
      return widget.category!.name;
    }
    return 'Категория: ${widget.catalogName}';
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
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 25,
                      right: 25,
                      top: 0,
                      bottom: 80,
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

                          // Если есть подкатегории, переходим на экран с ними
                          if (category.children != null &&
                              category.children!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UniversalCategoryScreen(
                                  category: category,
                                  catalogName: widget.catalogName,
                                  level: widget.level + 1,
                                ),
                              ),
                            );
                          } else if (category.isEndpoint) {
                            // Если это конечная точка, открываем динамический фильтр
                            // print();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DynamicFilter(categoryId: category.id),
                              ),
                            );
                          }
                        },
                      );
                    },
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
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: const Color(0xFF3A4A5F), width: 1),
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



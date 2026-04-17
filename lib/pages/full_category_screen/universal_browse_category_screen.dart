import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_rent_listings_screen.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_listings_filter_screen.dart';
import 'package:lidle/core/logger.dart';

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

  /// Флаг: пришли ли мы с экрана filters_screen
  final bool isFromFiltersScreen;
  
  /// Предварительно выбранный город при переходе с filters_screen
  final String? preSelectedCity;
  
  /// Callback при выборе категории и подкатегории
  final Function(String categoryName, int categoryId)? onCategorySelected;
  
  /// 🔍 Текущая "родительская" категория для отслеживания уровня
  /// Используется для кнопки "Показать все" на промежуточных уровнях
  final Category? currentLevelCategory;

  const UniversalBrowseCategoryScreen({
    super.key,
    this.catalogId,
    this.category,
    this.catalogName,
    this.level = 0,
    this.isFromFiltersScreen = false,
    this.preSelectedCity,
    this.onCategorySelected,
    this.currentLevelCategory,
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
    // 🎯 ДИАГНОСТИКА: Логируем какой catalogId получил UniversalBrowseCategoryScreen
    log.d('\n🎯 ════════════════════════════════════════════════════');
    log.d('🎯 UniversalBrowseCategoryScreen OPENED');
    log.d('   Level: ${widget.level}');
    log.d('   catalogId: ${widget.catalogId}');
    log.d('   catalogName: ${widget.catalogName}');
    log.d('   category.name: ${widget.category?.name}');
    log.d('   category.children count: ${widget.category?.children?.length ?? 0}');
    
    // 🔴 ЗАЩИТА: Если level слишком высокий, не загружаем дальше
    if (widget.level > 10) {
      log.e('⚠️  РЕКУРСИЯ СЛИШКОМ ГЛУБОКАЯ (Level=${widget.level})! Останавливаем загрузку.');
      setState(() {
        _categories = [];
        _isLoading = false;
      });
      return;
    }
    
    // 🔍 Логируем дочерние категории
    if (widget.category?.children != null && widget.category!.children!.isNotEmpty) {
      log.d('   Дочерние категории (первые 5):');
      for (int i = 0; i < widget.category!.children!.length && i < 5; i++) {
        final child = widget.category!.children![i];
        log.d('      [$i] ${child.name} (ID=${child.id}, hasChildren=${child.children != null && child.children!.isNotEmpty})');
      }
    }
    
    log.d('🎯 ════════════════════════════════════════════════════\n');
    _loadCategories();
  }

  /// Загружает категории в зависимости от типа экрана
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = TokenService.currentToken;

      List<Category> categories = [];

      // 🎯 КРИТИЧЕСКИ ВАЖНО: Сначала проверяем widget.category, потом widget.catalogId!
      // Иначе при рекурсивном открытии мы загружаем весь каталог вместо детей текущей категории
      if (widget.category != null) {
        // 🔥 ПРАВИЛЬНЫЙ ПУТЬ: Используем дочерние категории из переданной категории
        log.d('   📂 Используем дочерние категории из widget.category (${widget.category!.children?.length ?? 0} элементов)');
        categories = widget.category!.children ?? [];
      } else if (widget.catalogId != null) {
        // Загружаем категории каталога по ID (только на уровне 0, когда widget.category == null)
        log.d('   📂 Загружаем все категории из каталога по ID');

        final catalogWithCategories = await ApiService.getCatalog(
          widget.catalogId!,
          token: token,
        );

        categories = catalogWithCategories.categories;
      }

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      // log.d('❌ Browse Level ${widget.level}: ERROR LOADING CATEGORIES: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 🔍 Рекурсивно собирает все листовые (конечные) categoryId из категории
  List<int> _getAllLeafCategoryIds(Category category) {
    if (category.children == null || category.children!.isEmpty) {
      // Это конечная категория
      return [category.id];
    } else {
      // Это родительская категория - собираем ID из всех подкатегорий
      List<int> allIds = [];
      for (var child in category.children!) {
        allIds.addAll(_getAllLeafCategoryIds(child));
      }
      return allIds;
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
    // 🎯 Если переход с filters_screen, используем RealEstateListingsFilterScreen
    if (widget.isFromFiltersScreen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealEstateListingsFilterScreen(
            categoryId: category.id,
            categoryName: category.name,
            preSelectedCity: widget.preSelectedCity,
          ),
        ),
      );
      return;
    }

    // ✅ Используем универсальный экран RealEstateListingsScreen для всех категорий
    // Это предотвращает краши при несовместимых экранах
    try {
      log.d('📍 _navigateToListings() - Opening RealEstateListingsScreen');
      log.d('   categoryId: ${category.id}');
      log.d('   categoryName: ${category.name}');
      log.d('   catalogId: ${widget.catalogId}'); // 🎯 Логируем какой catalogId передаём
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealEstateListingsScreen(
            categoryId: category.id,
            categoryName: category.name,
            catalogId: widget.catalogId, // 🎯 КРИТИЧЕСКИ ВАЖНО: передаём catalogId!
            isFromFullCategory: true,
            preSelectedCity: widget.preSelectedCity,
            catalogName: widget.catalogName, // 🎯 Передаём название каталога
          ),
        ),
      );
    } catch (e) {
      log.e('❌ Error navigating to listings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки категории: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        // Когда интернет восстановлен - перезагружаем категории
        if (connectivityState is ConnectedState) {
          // ⏳ Добавляем задержку для стабилизации соединения
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _loadCategories();
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          // Показываем экран отсутствия интернета
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }

          // Показываем обычный контент
          return Scaffold(
      backgroundColor: const Color(0xFF1D2835),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 23, top: 20),
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
                                // log.d();

                                // Если есть подкатегории, переходим глубже
                                if (category.children != null &&
                                    category.children!.isNotEmpty) {
                                  
                                  // 🔴 ЗАЩИТА: Проверяем что дочерние категории не содержат саму категорию (циклическая ссылка)
                                  bool hasSelfReference = false;
                                  for (var child in category.children!) {
                                    if (child.id == category.id) {
                                      hasSelfReference = true;
                                      log.e('⚠️  ЦИКЛИЧЕСКАЯ ССЫЛКА: категория "${category.name}" содержит саму себя!');
                                      break;
                                    }
                                  }
                                  
                                  if (hasSelfReference) {
                                    log.d('🛑 Прерываем открытие рекурсивного экрана из-за циклической ссылки');
                                    _navigateToListings(category);
                                    return;
                                  }
                                  
                                  // 🔴 ЗАЩИТА: Проверяем что мы открываем экран уровня +1
                                  if (widget.level >= 9) {
                                    log.e('⚠️  МАКСИМАЛЬНАЯ ГЛУБИНА РЕКУРСИИ (Level=${widget.level})! Открываем список объявлений.');
                                    _navigateToListings(category);
                                    return;
                                  }
                                  
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          UniversalBrowseCategoryScreen(
                                            category: category,
                                            catalogId: widget.catalogId, // 🎯 КРИТИЧЕСКИ ВАЖНО: передаём catalogId на все уровни!
                                            catalogName: widget.catalogName,
                                            level: widget.level + 1,
                                            // 🔍 Сохраняем текущую категорию для отслеживания уровня
                                            currentLevelCategory: category,
                                          ),
                                    ),
                                  );
                                } else {
                                  // Если это конечная категория, открываем экран списков
                                  // log.d();
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
                            const SizedBox(height: 0),
                            SizedBox(
                              width: double.infinity,
                              height: 51,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Показать все объявления в зависимости от уровня
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        log.d('📢 "Показать все" button pressed');
                                        log.d('   level: ${widget.level}');
                                        log.d('   catalogId: ${widget.catalogId}');
                                        log.d('   category: ${widget.category?.name} (ID=${widget.category?.id})');
                                        log.d('   currentLevelCategory: ${widget.currentLevelCategory?.name} (ID=${widget.currentLevelCategory?.id})');
                                        
                                        // На первом уровне (когда есть catalogId) - показываем всё из каталога
                                        if (widget.catalogId != null && widget.level == 0) {
                                          log.d('✅ Using CATALOG MODE (catalogId=${widget.catalogId})');
                                          return RealEstateListingsScreen(
                                            catalogId: widget.catalogId,
                                            categoryName: widget.catalogName,
                                            isFromFullCategory: true,
                                          );
                                        }
                                        // На промежуточных уровнях - используем currentLevelCategory или category
                                        else if (widget.currentLevelCategory != null || widget.category != null) {
                                          final currentCategory = widget.currentLevelCategory ?? widget.category;
                                          
                                          // Собираем все листовые categoryId из текущей категории
                                          final leafIds = _getAllLeafCategoryIds(currentCategory!);
                                          log.d('✅ Using MULTIPLE CATEGORY MODE');
                                          log.d('   currentCategory: ${currentCategory.name} (ID=${currentCategory.id})');
                                          log.d('   Leaf category IDs: $leafIds');
                                          
                                          return RealEstateListingsScreen(
                                            categoryIds: leafIds,
                                            categoryName: currentCategory.name,
                                            isFromFullCategory: true,
                                            catalogId: widget.catalogId, // 🎯 Передаём catalogId для правильного выбора категорий
                                            catalogName: widget.catalogName, // 🎯 Передаём название каталога
                                          );
                                        }
                                        // Fallback - не должно случиться
                                        else {
                                          log.d('⚠️  Using FALLBACK MODE (no params!)');
                                          return RealEstateListingsScreen(
                                            categoryName: widget.catalogName,
                                            isFromFullCategory: true,
                                          );
                                        }
                                      },
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
                            // const SizedBox(height: 10),
                            // SizedBox(
                            //   width: double.infinity,
                            //   height: 51,
                            //   child: ElevatedButton(
                            //     onPressed: () {
                            //       Navigator.pushNamed(
                            //         context,
                            //         MapScreen.routeName,
                            //       );
                            //     },
                            //     style: ElevatedButton.styleFrom(
                            //       backgroundColor: primaryBackground,
                            //       side: const BorderSide(color: Colors.white24),
                            //       shape: RoundedRectangleBorder(
                            //         borderRadius: BorderRadius.circular(5),
                            //       ),
                            //     ),
                            //     child: const Text(
                            //       'Показать на карте',
                            //       style: TextStyle(
                            //         color: Colors.white,
                            //         fontSize: 16,
                            //         fontWeight: FontWeight.w600,
                            //       ),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
        },
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

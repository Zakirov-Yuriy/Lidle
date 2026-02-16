import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'real_estate_subcategories_screen.dart';
import 'universal_category_screen.dart';

/// ============================================================
/// Виджет: Экран выбора категории объявления
/// ============================================================
///
/// Этот экран позволяет пользователю выбрать категорию для создания объявления.
/// Загружает список каталогов из API и отображает их в виде списка.
///
/// API документация:
/// - GET /v1/content/catalogs: Получить все каталоги
///   - Headers: Accept-Language, Accept, X-App-Client
///   - Response: {"data": [{"id": int, "name": string, "thumbnail": string, "slug": string, "type": {"id": int, "type": string, "path": string}, "order": int}, ...]}
///   - Пример: [{"id": 1, "name": "Недвижимость", ...}, {"id": 8, "name": "Работа", ...}]
///
/// Использует ApiService.getCatalogs() для загрузки данных.
/// При выборе "Недвижимость" переходит к RealEstateSubcategoriesScreen (специализированный экран).
/// Для всех остальных каталогов используется UniversalCategoryScreen (универсальный, автоматический).
class CategorySelectionScreen extends StatefulWidget {
  static const String routeName = '/category-selection';

  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

/// ============================================================
/// Класс состояния: Управление состоянием экрана выбора категории
/// ============================================================
///
/// Управляет загрузкой каталогов из API, обработкой ошибок и отображением UI.
/// Использует состояние для загрузки (_isLoading), ошибки (_error) и списка каталогов (_catalogs).
class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  List<Catalog> _catalogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  /// Загружает список каталогов из API.
  ///
  /// Выполняет GET /v1/content/catalogs (публичный эндпоинт, токен не требуется).
  /// В случае успеха обновляет _catalogs, в случае ошибки - _error.
  /// Использует ApiService.getCatalogs() для вызова API.
  Future<void> _loadCatalogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final catalogsResponse = await ApiService.getCatalogs();

      print('═══════════════════════════════════════════════════════');
      print('📦 CATALOGS LOADED');
      print('Total catalogs: ${catalogsResponse.data.length}');
      print('═══════════════════════════════════════════════════════');
      catalogsResponse.data.asMap().forEach((index, catalog) {
        print('[$index] Catalog ID: ${catalog.id}');
        print('    Name: ${catalog.name}');
        print('    Slug: ${catalog.slug}');
        print('    Thumbnail: ${catalog.thumbnail}');
        print('    Type.id: ${catalog.type.id}');
        print('    Type.type: ${catalog.type.type ?? 'null'}');
        print('    Type.path: ${catalog.type.path ?? 'null'}');
        print('    Type.slug: ${catalog.type.slug ?? 'null'}');
        print('    Order: ${catalog.order}');
        print('---');
      });
      print('═══════════════════════════════════════════════════════');

      setState(() {
        _catalogs = catalogsResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ ERROR LOADING CATALOGS: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2835),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 25, right: 23, top: 20),
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 25, right: 25, top: 7),
            child: Text(
              'Выберите категории публикации',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                        // const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCatalogs,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(
                      left: 25,
                      right: 25,
                      bottom: 0,
                      top: 12,
                    ),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 120 / 83,
                          ),
                      itemCount: _catalogs.length,
                      itemBuilder: (context, index) {
                        final catalog = _catalogs[index];
                        print(
                          '🎨 Rendering catalog [$index/${_catalogs.length}]: ${catalog.name} (ID: ${catalog.id})',
                        );

                        return GestureDetector(
                          onTap: () {
                            print('👆 Tapped on catalog: ${catalog.name}');
                            if (catalog.name == 'Недвижимость') {
                              // Специализированный экран для Недвижимости
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RealEstateSubcategoriesScreen(),
                                ),
                              );
                            } else {
                              // Универсальный экран для всех остальных каталогов
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UniversalCategoryScreen(
                                    catalogId: catalog.id,
                                    catalogName: catalog.name,
                                  ),
                                ),
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                catalog.thumbnail != null &&
                                        catalog.thumbnail!.isNotEmpty &&
                                        catalog.thumbnail!.startsWith('http')
                                    ? Image.network(
                                        catalog.thumbnail!,
                                        height: 83,
                                        width: 120,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 83,
                                                width: 120,
                                                color: Colors.grey[700],
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                            Colors.white,
                                                          ),
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                        errorBuilder: (context, error, stackTrace) {
                                          print(
                                            '❌ Error loading thumbnail for ${catalog.name}: $error',
                                          );
                                          return Container(
                                            height: 83,
                                            width: 120,
                                            color: const Color(0xFF2A3A4F),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.white70,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    catalog.name,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        height: 83,
                                        width: 120,
                                        color: const Color(0xFF2A3A4F),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.category,
                                                color: Colors.white70,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                catalog.name,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

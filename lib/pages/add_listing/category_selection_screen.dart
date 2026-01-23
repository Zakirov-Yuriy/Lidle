import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'real_estate_subcategories_screen.dart';

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
///   - Response: {"data": [{"id": int, "name": string, "thumbnail": string, "slug": string, "type": {"id": int, "slug": string}, "order": int}, ...]}
///   - Пример: [{"id": 1, "name": "Недвижимость", ...}, {"id": 8, "name": "Работа", ...}]
///
/// Использует ApiService.getCatalogs() для загрузки данных.
/// При выборе "Недвижимость" переходит к RealEstateSubcategoriesScreen.
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

      print('Loaded catalogs: ${catalogsResponse.data.length}');
      catalogsResponse.data.forEach(
        (catalog) => print('Catalog: ${catalog.name}'),
      );

      setState(() {
        _catalogs = catalogsResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Функция для получения изображения категории по умолчанию
  String _getCategoryImage(String catalogName) {
    switch (catalogName.toLowerCase()) {
      case 'недвижимость':
        return 'assets/categories/real_estate.png';
      case 'работа':
        return 'assets/categories/job.png';
      default:
        return 'assets/categories/real_estate.png'; // fallback
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10, left: 25, right: 25, top: 7),
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
                          onPressed: _loadCatalogs,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 25, bottom: 106),
                    itemCount: _catalogs.length,
                    itemBuilder: (context, index) {
                      final catalog = _catalogs[index];
                      return GestureDetector(
                        onTap: () {
                          if (catalog.name == 'Недвижимость') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RealEstateSubcategoriesScreen(),
                              ),
                            );
                          }
                          // Для других каталогов можно добавить логику позже
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10, right: 25),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                catalog.thumbnail != null &&
                                        catalog.thumbnail!.startsWith('http')
                                    ? Image.network(
                                        catalog.thumbnail!,
                                        height: 93,
                                        width: 366,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Image.asset(
                                                _getCategoryImage(catalog.name),
                                                height: 93,
                                                width: 366,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                      )
                                    : Image.asset(
                                        _getCategoryImage(catalog.name),
                                        height: 93,
                                        width: 366,
                                        fit: BoxFit.cover,
                                      ),
                                // Временно убрал текст для диагностики дублирования
                                // Positioned(
                                //   top: 39,
                                //   left: 30,
                                //   child: Text(
                                //     catalog.name,
                                //     style: const TextStyle(
                                //       color: Colors.black,
                                //       fontSize: 18,
                                //       fontWeight: FontWeight.w500,
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
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

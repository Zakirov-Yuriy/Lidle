import 'package:lidle/models/catalog_category_model.dart';
import 'package:lidle/services/api_service.dart';

/// Сервис для работы с каталогами и категориями
class CatalogService {
  /// Получить все каталоги
  static Future<CatalogsResponse> getCatalogs({String? token}) async {
    try {
      final response = await ApiService.get('/content/catalogs', token: token);
      return CatalogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог по ID с категориями
  static Future<Catalog> getCatalog(int catalogId, {String? token}) async {
    try {
      final response = await ApiService.get(
        '/content/catalogs/$catalogId',
        token: token,
      );
      // API возвращает массив, берём первый элемент
      final List<dynamic> dataList = response['data'] ?? [];
      if (dataList.isEmpty) {
        throw Exception('Catalog not found');
      }
      return Catalog.fromJson(dataList[0] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load catalog: $e');
    }
  }

  /// Получить категорию по ID
  static Future<Category> getCategory(int categoryId, {String? token}) async {
    try {
      final response = await ApiService.get(
        '/content/categories/$categoryId',
        token: token,
      );
      // API возвращает массив в data
      final List<dynamic> dataList = response['data'] ?? [];
      if (dataList.isEmpty) {
        throw Exception('Category not found');
      }
      return Category.fromJson(dataList[0] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Поиск категорий по названию
  static Future<CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await ApiService.getWithQuery(
        '/content/categories/search',
        {'catalog_id': catalogId, 'q': query},
        token: token,
      );
      return CategoriesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }
}

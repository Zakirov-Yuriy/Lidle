// ============================================================
// "API методы для работы с каталогами и категориями"
// ============================================================

import 'package:lidle/models/catalog_model.dart' as catalog_models;
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/network/http_client.dart';

/// Remote класс для всех операций с каталогами и категориями.
///
/// Включает методы для:
/// - Получения списка каталогов
/// - Получения категорий в каталоге
/// - Поиска категорий
/// - Получения мета-фильтров
class CatalogRemote {
  /// Получить все каталоги
  static Future<catalog_models.CatalogsResponse> getCatalogs({
    String? token,
  }) async {
    try {
      final response = await HttpClient.get('/content/catalogs', token: token);
      return catalog_models.CatalogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог с категориями по ID
  static Future<catalog_models.CatalogWithCategories> getCatalog(
    int catalogId, {
    String? token,
  }) async {
    try {
      final response =
          await HttpClient.get('/content/catalogs/$catalogId', token: token);

      // Проверяем наличие data и что это не null
      if (response['data'] == null || response['data'] is! List) {
        throw Exception('Invalid catalog response: data is null or not a list');
      }

      final dataList = response['data'] as List<dynamic>;
      if (dataList.isEmpty) {
        throw Exception('Catalog not found');
      }

      return catalog_models.CatalogWithCategories.fromJson(
        dataList[0] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to load catalog: $e');
    }
  }

  /// Получить категорию по ID
  static Future<catalog_models.Category> getCategory(
    int categoryId, {
    String? token,
  }) async {
    try {
      final response = await HttpClient.get(
        '/content/categories/$categoryId',
        token: token,
      );

      // Проверяем наличие data и что это не null
      if (response['data'] == null || response['data'] is! List) {
        throw Exception(
          'Invalid category response: data is null or not a list',
        );
      }

      final dataList = response['data'] as List<dynamic>;
      if (dataList.isEmpty) {
        throw Exception('Category not found');
      }

      return catalog_models.Category.fromJson(
        dataList[0] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Поиск категорий по запросу
  static Future<catalog_models.CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await HttpClient.getWithQuery(
        '/content/categories/search',
        {
          'catalog_id': catalogId,
          'q': query,
        },
        token: token,
      );
      return catalog_models.CategoriesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }

  /// Получить мета-фильтры (sort options и filters) для категории
  static Future<MetaFiltersResponse> getMetaFilters({
    int? categoryId,
    int? catalogId,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await HttpClient.getWithQuery(
        '/meta/filters',
        queryParams,
        token: token,
      );

      // API returns { "success": true, "data": {"sort": [...], "filters": [...]} }
      // Extract the data object which contains sort and filters
      final data = response['data'] ?? response;

      // Логирование структуры фильтров для отладки
      if (data['filters'] is List) {
        final filtersList = data['filters'] as List;
        log.d('📊 CatalogRemote.getMetaFilters: loaded ${filtersList.length} filters');

        // Поиск специального фильтра "Вам предложат цену"
        bool found = false;
        for (final filter in filtersList) {
          final title = filter['title']?.toString() ?? '';
          if (title.contains('предложат') ||
              title.contains('цену') ||
              title.contains('offer') ||
              title.contains('price')) {
            log.d('   ✅ Found price offer filter: ID=${filter['id']}, Title=$title');
            found = true;
          }
        }
        if (!found) {
          log.d('   ℹ️ Price offer filter not found in API response');
        }
      }

      try {
        return MetaFiltersResponse.fromJson(data);
      } catch (parseError) {
        log.d('🔴 ERROR parsing MetaFiltersResponse: $parseError');
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to load meta filters: $e');
    }
  }
}

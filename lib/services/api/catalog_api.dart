// ============================================================
// Catalog API — работа с каталогами, категориями и meta-фильтрами.
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 1113–1282).
// Логика идентична оригиналу; изменён только путь модуля.
//
// Методы:
//   - getCatalogs()
//   - getCatalog(catalogId)
//   - getCategory(categoryId)
//   - searchCategories({catalogId, query})
//   - getMetaFilters({categoryId, catalogId})
//
// Низкоуровневые HTTP-вызовы по-прежнему идут через ApiService.get/getWithQuery,
// потому что у фасада уже есть встроенный retry + refresh token.
// Когда все feature-клиенты будут готовы, ApiService.get/post/... станут
// прокси к HttpClient из core/network/http_client.dart.

import 'package:lidle/core/logger.dart';
import 'package:lidle/models/catalog_model.dart' as catalog_models;
import 'package:lidle/services/api_service.dart';

class CatalogApi {
  /// Получить все каталоги.
  static Future<catalog_models.CatalogsResponse> getCatalogs({
    String? token,
  }) async {
    try {
      final response = await ApiService.get('/content/catalogs', token: token);

      // 🔍 DEBUG: Логируем сырой ответ для диагностики
      log.i('📦 API getCatalogs() response keys: ${response.keys.toList()}');
      if (response.containsKey('data')) {
        log.i('   - data type: ${response['data'].runtimeType}');
        if (response['data'] is List) {
          log.i('   - data length: ${(response['data'] as List).length}');
        }
      } else {
        log.w('⚠️  ВНИМАНИЕ: API response НЕ содержит поле "data"!');
        log.w('   - Полный ответ: $response');
      }

      return catalog_models.CatalogsResponse.fromJson(response);
    } catch (e, stackTrace) {
      log.e(
        '❌ ОШИБКА при загрузке каталогов: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог с категориями по ID.
  static Future<catalog_models.CatalogWithCategories> getCatalog(
    int catalogId, {
    String? token,
  }) async {
    try {
      final response =
          await ApiService.get('/content/catalogs/$catalogId', token: token);

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

  /// Получить категорию по ID.
  static Future<catalog_models.Category> getCategory(
    int categoryId, {
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
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

  /// Поиск категорий.
  static Future<catalog_models.CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await ApiService.getWithQuery(
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
}

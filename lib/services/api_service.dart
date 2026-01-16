import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/models/filter_models.dart'; // Import the new model
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/hive_service.dart';

/// Базовый класс для работы с API.
/// Обрабатывает общие заголовки и базовый URL.
class ApiService {
  static String get baseUrl =>
      dotenv.get('BASE_URL', fallback: 'https://dev-api.lidle.io/v1');
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    'Content-Type': 'application/json',
  };

  /// Выполняет GET запрос.
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Выполняет POST запрос.
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Выполняет GET запрос с query параметрами.
  static Future<Map<String, dynamic>> getWithQuery(
    String endpoint,
    Map<String, dynamic> queryParams, {
    String? token,
  }) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      if (e.toString().contains('Token expired')) {
        rethrow; // Пропустить Token expired
      }
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Обрабатывает ответ от сервера.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('API Response status: ${response.statusCode}');
    // Оптимизированное логирование: не логируем весь body для производительности
    // print('API Response body: ${response.body}'); // Закомментировано для производительности
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    // print('API Response parsed: $data'); // Закомментировано для производительности

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else if (response.statusCode == 401) {
      // Попытка обновить токен при 401
      print('Error response: ${data['message'] ?? 'Token expired'}');
      throw Exception('Token expired');
    } else {
      print('Error response: ${data['message'] ?? 'Ошибка сервера'}');
      throw Exception(data['message'] ?? 'Ошибка сервера');
    }
  }

  static Future<List<Attribute>> getAdvertCreationAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/adverts/create', {
        'category_id': categoryId,
      }, token: token);
      final List<dynamic> attributesJson = response['data']['attributes'];
      return attributesJson
          .map((json) => Attribute.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return getAdvertCreationAttributes(
            categoryId: categoryId,
            token: newToken,
          );
        }
      }
      throw Exception('Failed to load advert creation attributes: $e');
    }
  }

  /// Получить список объявлений.
  static Future<AdvertsResponse> getAdverts({
    int? categoryId,
    int? catalogId,
    String? sort,
    Map<String, dynamic>? filters,
    int? page,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;
      if (sort != null) queryParams['sort'] = sort;
      if (page != null) queryParams['page'] = page;

      // Добавляем фильтры
      if (filters != null) {
        filters.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            value.forEach((subKey, subValue) {
              queryParams['filters[$key][$subKey]'] = subValue.toString();
            });
          } else {
            queryParams['filters[$key]'] = value.toString();
          }
        });
      }

      final response = await getWithQuery(
        '/adverts',
        queryParams,
        token: token,
      );
      return AdvertsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load adverts: $e');
    }
  }

  /// Получить все каталоги.
  static Future<CatalogsResponse> getCatalogs({String? token}) async {
    try {
      final response = await get('/content/catalogs', token: token);
      return CatalogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог с категориями по ID.
  static Future<CatalogWithCategories> getCatalog(
    int catalogId, {
    String? token,
  }) async {
    try {
      final response = await get('/content/catalogs/$catalogId', token: token);
      return CatalogWithCategories.fromJson(response['data'][0]);
    } catch (e) {
      throw Exception('Failed to load catalog: $e');
    }
  }

  /// Получить категорию по ID.
  static Future<Category> getCategory(int categoryId, {String? token}) async {
    try {
      final response = await get(
        '/content/categories/$categoryId',
        token: token,
      );
      return Category.fromJson(response['data'][0]);
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Поиск категорий.
  static Future<CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/content/categories/search', {
        'catalog_id': catalogId,
        'q': query,
      }, token: token);
      return CategoriesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }

  /// Получить фильтры для категории.
  static Future<MetaFiltersResponse> getMetaFilters({
    int? categoryId,
    int? catalogId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await getWithQuery('/meta/filters', queryParams);
      return MetaFiltersResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load meta filters: $e');
    }
  }

  /// Обновить токен доступа.
  static Future<String?> refreshToken(String currentToken) async {
    try {
      final response = await post(
        '/auth/refresh-token',
        {},
        token: currentToken,
      );
      final newToken = response['access_token'] as String?;
      if (newToken != null) {
        await HiveService.saveUserData('token', newToken);
      }
      return newToken;
    } catch (e) {
      // Если refresh не удался, вернуть null
      return null;
    }
  }
}

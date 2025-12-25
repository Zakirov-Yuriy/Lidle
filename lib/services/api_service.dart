import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/models/filter_models.dart'; // Import the new model

/// Базовый класс для работы с API.
/// Обрабатывает общие заголовки и базовый URL.
class ApiService {
  static String get baseUrl => dotenv.get('BASE_URL', fallback: 'https://dev-api.lidle.io/v1');
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    'Content-Type': 'application/json',
  };

  /// Выполняет GET запрос.
  static Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

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

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

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

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Обрабатывает ответ от сервера.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('API Response status: ${response.statusCode}');
    print('API Response body: ${response.body}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print('API Response parsed: $data');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      print('Error response: $data');
      throw Exception(data['message'] ?? 'Ошибка сервера');
    }
  }

  static Future<List<Attribute>> getAdvertCreationAttributes(
      {required int categoryId, String? token}) async {
    try {
      final response = await getWithQuery(
        '/adverts/create',
        {'category_id': categoryId},
        token: token,
      );
      final List<dynamic> attributesJson = response['data']['attributes'];
      return attributesJson
          .map((json) => Attribute.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load advert creation attributes: $e');
    }
  }
}

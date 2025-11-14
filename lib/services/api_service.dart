import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Базовый класс для работы с API.
/// Обрабатывает общие заголовки и базовый URL.
class ApiService {
  static const String baseUrl = 'https://dev-api.lidle.io/v1';
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

  /// Обрабатывает ответ от сервера.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print('API Response: ${response.statusCode} - $data');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Ошибка сервера');
    }
  }
}

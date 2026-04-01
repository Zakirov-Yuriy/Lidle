// ============================================================
// "API методы для работы с профилем пользователя"
// ============================================================

import 'package:lidle/core/network/http_client.dart';

/// Remote класс для всех операций с профилем и данными пользователя.
///
/// Включает методы для:
/// - Получения профиля пользователя
/// - Получения телефонов пользователя
/// - Получения главной страницы контента
class UserRemote {
  /// Получить профиль текущего пользователя или другого по ID
  static Future<Map<String, dynamic>> getUserProfile({
    int? userId,
    String? token,
  }) async {
    try {
      final endpoint = userId != null ? '/user/profile/$userId' : '/user/profile';
      final response = await HttpClient.get(endpoint, token: token);
      return response;
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }

  /// Получить телефоны пользователя
  static Future<List<String>> getUserPhones({
    String? token,
  }) async {
    try {
      final response = await HttpClient.get('/user/phones', token: token);
      final data = response['data'];

      if (data is List) {
        // Преобразуем каждый элемент в строку
        return data.map((phone) => phone.toString()).toList();
      } else if (data is Map) {
        // Если вернулся Map, извлекаем values
        return (data as Map).values.map((v) => v.toString()).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Failed to load user phones: $e');
    }
  }

  /// Получить главную страницу с контентом (каталоги, рекомендации, и т.д.)
  static Future<Map<String, dynamic>> getMainContent({String? token}) async {
    try {
      return await HttpClient.get('/content/main', token: token);
    } catch (e) {
      throw Exception('Failed to load main content: $e');
    }
  }
}

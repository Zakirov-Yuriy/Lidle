// ============================================================
// "Сервис: Аутентификация пользователей"
// ============================================================

import 'dart:convert';
import 'api_service.dart';

class AuthService {
  /// Отправка кода подтверждения.
  /// Отправляет код на email для верификации.
  static Future<Map<String, dynamic>> sendCode({required String email}) async {
    final body = {'email': email};

    return await ApiService.post('/auth/resend-verification-email-code', body);
  }

  /// Регистрация нового пользователя.
  /// Отправляет данные пользователя на сервер для создания аккаунта.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = {
      'name': name,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };

    return await ApiService.post('/auth/register', body);
  }

  /// Верификация кода подтверждения.
  /// Отправляет код для подтверждения email.
  static Future<Map<String, dynamic>> verify({
    required String email,
    required String code,
  }) async {
    final body = {'email': email, 'code': code};

    return await ApiService.post('/auth/verify-email', body);
  }

  /// Вход в систему.
  /// Аутентифицирует пользователя и возвращает токен.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final body = {'email': email, 'password': password, 'remember': remember};

    return await ApiService.post('/auth/login', body);
  }

  /// Забыли пароль.
  /// Отправляет запрос на сброс пароля по email.
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final body = {'email': email};

    return await ApiService.post('/auth/forgot-password', body);
  }

  /// Сброс пароля.
  /// Устанавливает новый пароль по коду восстановления.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String token,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'token': token,
    };

    return await ApiService.post('/auth/password/reset', body);
  }

  /// Выход из системы.
  /// Здесь можно добавить логику для инвалидации токена на сервере.
  static Future<void> logout() async {
    // TODO: Реализовать выход, если нужно отправить запрос на сервер
  }

  /// Декодирует JWT токен и извлекает userId из claim 'sub'
  /// JWT структура: header.payload.signature
  /// Payload содержит claim "sub" с ID пользователя
  ///
  /// Пример JWT payload:
  /// {
  ///   "iss": "https://dev-api.lidle.io/v1/auth/login",
  ///   "sub": "1",  <-- это userId
  ///   "iat": 1751103872,
  ///   ...
  /// }
  static String extractUserIdFromToken(String token) {
    try {
      // Разбираем токен на три части: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        print('❌ AuthService: Неверный формат токена (ожидается 3 части)');
        return '0';
      }

      // Берем payload (вторая часть) и добавляем padding если нужно
      String payload = parts[1];
      // JWT использует URL-safe Base64, нужно добавить padding для стандартного Base64
      switch (payload.length % 4) {
        case 1:
          payload += '===';
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      // Декодируем Base64
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      // Извлекаем claim 'sub' - это ID пользователя
      final userId = json['sub']?.toString() ?? '0';
      print('✅ AuthService: userId из токена = $userId');
      return userId;
    } catch (e) {
      print('❌ AuthService: Ошибка при декодировании токена: $e');
      return '0';
    }
  }
}

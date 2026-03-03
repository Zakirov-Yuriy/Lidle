// ============================================================
// "Сервис: Аутентификация пользователей"
// ============================================================

import 'dart:convert';
import 'api_service.dart';
import '../hive_service.dart';

class AuthService {
  /// Отправка кода подтверждения.
  /// Отправляет код на email для верификации.
  static Future<Map<String, dynamic>> sendCode({required String email}) async {
    final body = {'email': email};

    // skipTokenRefresh: true — 401 здесь не означает истёкший токен, не запускаем refresh
    return await ApiService.post(
      '/auth/resend-verification-email-code',
      body,
      skipTokenRefresh: true,
    );
  }

  /// Регистрация нового пользователя.
  /// Отправляет данные пользователя на сервер для создания аккаунта.
  ///
  /// API v1.3.3+: поля device_name и app_version НЕ используются при регистрации.
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

    // skipTokenRefresh: true — auth-эндпоинт, 401 = неверные данные, не обновлять токен
    return await ApiService.post(
      '/auth/register',
      body,
      skipTokenRefresh: true,
    );
  }

  /// Верификация кода подтверждения.
  /// Отправляет код для подтверждения email.
  static Future<Map<String, dynamic>> verify({
    required String email,
    required String code,
  }) async {
    final body = {'email': email, 'code': code};

    // skipTokenRefresh: true — auth-эндпоинт, 401 = неверные данные
    return await ApiService.post(
      '/auth/verify-email',
      body,
      skipTokenRefresh: true,
    );
  }

  /// Вход в систему.
  /// Аутентифицирует пользователя и возвращает access_token + refresh_token.
  ///
  /// API v1.4+: device_name обязателен, app_version необязателен.
  /// Ответ: { access_token, refresh_token, token_type, expires_in: 900 }
  /// 401 = неверные учётные данные
  /// 422 = ошибка валидации (не заполненообязательное поле)
  /// 423 = email не подтверждён (email_not_verified) или аккаунт заблокирован (account_locked)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'device_name': 'Lidle Mobile App', // обязательное поле (API v1.4+)
      'app_version': '1.4.1',
    };

    // skipTokenRefresh: true — при 401 (неверные данные) не пытаемся refresh токена,
    // иначе login зависает на 15с ожидая refresh.
    return await ApiService.post('/auth/login', body, skipTokenRefresh: true);
  }

  /// Забыли пароль.
  /// Отправляет запрос на сброс пароля по email.
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final body = {'email': email};

    // skipTokenRefresh: true — auth-эндпоинт
    return await ApiService.post(
      '/auth/forgot-password',
      body,
      skipTokenRefresh: true,
    );
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

    // skipTokenRefresh: true — auth-эндпоинт
    return await ApiService.post(
      '/auth/password/reset',
      body,
      skipTokenRefresh: true,
    );
  }

  /// Выход из системы.
  /// Отправляет запрос на сервер для инвалидации токена,
  /// затем очищает оба токена из локального хранилища.
  static Future<void> logout() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token != null && token.isNotEmpty) {
        // Инвалидируем токен на сервере
        await ApiService.post('/auth/logout', {}, token: token);
        // print('✅ AuthService: logout на сервере выполнен');
      }
    } catch (e) {
      // Игнорируем ошибки сервера — токены всё равно удалим локально
      // print('⚠️ AuthService: ошибка logout на сервере (игнорируем): $e');
    } finally {
      // Всегда удаляем оба токена локально
      await HiveService.deleteUserData('token');
      await HiveService.deleteUserData('refresh_token');
    }
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
        // print('❌ AuthService: Неверный формат токена (ожидается 3 части)');
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
      // print('✅ AuthService: userId из токена = $userId');
      return userId;
    } catch (e) {
      // print('❌ AuthService: Ошибка при декодировании токена: $e');
      return '0';
    }
  }
}

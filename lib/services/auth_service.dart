import 'api_service.dart';

/// Сервис для аутентификации пользователей.
/// Обрабатывает регистрацию, верификацию и вход.
class AuthService {
  /// Отправка кода подтверждения.
  /// Отправляет код на email для верификации.
  static Future<Map<String, dynamic>> sendCode({
    required String email,
  }) async {
    final body = {
      'email': email,
    };

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
    final body = {
      'email': email,
      'code': code,
    };

    return await ApiService.post('/auth/verify-email', body);
  }

  /// Вход в систему.
  /// Аутентифицирует пользователя и возвращает токен.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'remember': remember,
    };

    return await ApiService.post('/auth/login', body);
  }

  /// Забыли пароль.
  /// Отправляет запрос на сброс пароля по email.
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final body = {
      'email': email,
    };

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
    // TODO: реализовать выход, если нужно отправить запрос на сервер
  }
}

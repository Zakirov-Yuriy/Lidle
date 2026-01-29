import 'package:lidle/models/user_profile_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

class UserService {
  /// Получить профиль текущего пользователя
  static Future<UserProfile> getProfile({required String token}) async {
    try {
      final response = await ApiService.get('/me', token: token);

      final profileResponse = UserProfileResponse.fromJson(response);
      return profileResponse.data;
    } catch (e) {
      throw Exception('Ошибка при загрузке профиля: $e');
    }
  }

  /// Обновить профиль пользователя
  static Future<UserProfile> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? about,
    String? avatar,
    required String token,
  }) async {
    try {
      final request = UpdateProfileRequest(
        name: name,
        email: email,
        phone: phone,
        about: about,
        avatar: avatar,
      );

      final response = await ApiService.put(
        '/me',
        request.toJson(),
        token: token,
      );

      final profileResponse = UserProfileResponse.fromJson(response);
      return profileResponse.data;
    } catch (e) {
      throw Exception('Ошибка при обновлении профиля: $e');
    }
  }

  /// Выход из аккаунта (если требуется на сервере)
  static Future<void> logout({required String token}) async {
    try {
      await ApiService.post('/auth/logout', {}, token: token);
    } catch (e) {
      throw Exception('Ошибка при выходе: $e');
    }
  }

  /// Изменить пароль
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
    required String token,
  }) async {
    try {
      final data = {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPasswordConfirmation,
      };

      await ApiService.post('/me/password', data, token: token);
    } catch (e) {
      throw Exception('Ошибка при изменении пароля: $e');
    }
  }

  /// Удалить аккаунт с подтверждением паролем
  ///
  /// Для тестируемости можно подменить:
  /// - `deleteFn` — вызов API (по умолчанию `ApiService.delete`, теперь поддерживает тело)
  /// - `deleteUserDataFn` — очистка локального хранилища (по умолчанию `HiveService.deleteUserData`)
  static Future<void> deleteAccount({
    required String token,
    required String password,
    Future<dynamic> Function(
      String endpoint, {
      String? token,
      Map<String, dynamic>? body,
    })?
    deleteFn,
    Future<void> Function(String key)? deleteUserDataFn,
    Future<void> Function()? clearAllFn,
  }) async {
    try {
      final callDelete =
          deleteFn ??
          ((String endpoint, {String? token, Map<String, dynamic>? body}) =>
              ApiService.delete(endpoint, token: token, body: body));

      // Выполнить удаление на сервере с подтверждением пароля
      await callDelete(
        '/me/settings/account',
        token: token,
        body: {'password': password},
      );

      // Очистить локальные данные (по умолчанию через HiveService)
      final clearFn =
          deleteUserDataFn ?? ((String key) => HiveService.deleteUserData(key));

      await clearFn('token');
      await clearFn('name');
      await clearFn('email');
      await clearFn('phone');
      await clearFn('userId');

      // На всякий случай — очистим полностью все боксы Hive (можно заменить через clearAllFn в тестах)
      final performClearAll = clearAllFn ?? (() => HiveService.clearAllData());
      await performClearAll();
    } catch (e) {
      throw Exception('Ошибка при удалении аккаунта: $e');
    }
  }
}

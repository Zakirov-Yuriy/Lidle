import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lidle/models/user_profile_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

class UserService {
  /// Получить профиль текущего пользователя
  static Future<UserProfile> getProfile({required String token}) async {
    try {
      print('🔐 UserService: Запрашиваем профиль с токеном...');
      final response = await ApiService.get('/me', token: token);

      print('📦 UserService: Ответ от API получен');
      print('📦 UserService: Тип response: ${response.runtimeType}');
      print('📦 UserService: Ключи response: ${response.keys.toList()}');
      print('📦 UserService: Полный ответ: ${jsonEncode(response)}');

      final profileResponse = UserProfileResponse.fromJson(response);
      print('✅ UserService: Профиль распарсен');
      print(
        '✅ UserService: profileResponse.data.length = ${profileResponse.data.length}',
      );

      if (profileResponse.data.isEmpty) {
        throw Exception('Список профилей пуст');
      }

      final profile = profileResponse.data[0];
      print(
        '👤 UserService: Возвращаем профиль: ${profile.name} ${profile.lastName}',
      );
      return profile;
    } catch (e) {
      print('❌ UserService: Ошибка при загрузке профиля: $e');
      print('❌ UserService: Type: ${e.runtimeType}');
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
      return profileResponse.data[0];
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

  /// Загрузить аватарку профиля
  static Future<bool> uploadAvatar({
    required String filePath,
    required String token,
  }) async {
    try {
      print('🖼️ UserService: Загружаем аватарку...');
      print('📍 Путь файла: $filePath');

      final response = await ApiService.uploadFile(
        '/me/settings/avatar',
        filePath: filePath,
        fieldName: 'image',
        token: token,
      );

      print('✅ UserService: Аватарка успешно загружена');
      print('📦 Ответ: $response');

      if (response['success'] == true) {
        print('✅ UserService: success = true');
        return true;
      } else {
        print('❌ UserService: success = false');
        throw Exception('API вернул success: false');
      }
    } catch (e) {
      print('❌ UserService: Ошибка при загрузке аватарки: $e');
      throw Exception('Ошибка при загрузке аватарки: $e');
    }
  }

  /// Удалить аватарку профиля
  static Future<bool> deleteAvatar({required String token}) async {
    try {
      print('🖼️ UserService: Удаляем аватарку...');

      // API требует отправку как multipart с delete_image=true
      final headers = {'X-App-Client': 'mobile'};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('═══════════════════════════════════════════════════════');
      print('📤 DELETE AVATAR REQUEST');
      print('URL: ${ApiService.baseUrl}/me/settings/avatar');
      print('Token provided: true');
      print('═══════════════════════════════════════════════════════');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/me/settings/avatar'),
      );

      request.headers.addAll(headers);
      request.fields['delete_image'] = 'true';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final httpResponse = await http.Response.fromStream(streamedResponse);

      print('✅ Response status: ${httpResponse.statusCode}');
      print('📋 Response: ${httpResponse.body}');

      if (httpResponse.statusCode == 200) {
        final response = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        if (response['success'] == true) {
          print('✅ UserService: Аватарка успешно удалена');
          return true;
        }
      }

      throw Exception('Failed to delete avatar');
    } catch (e) {
      print('❌ UserService: Ошибка при удалении аватарки: $e');
      throw Exception('Ошибка при удалении аватарки: $e');
    }
  }
}

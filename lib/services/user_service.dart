import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lidle/models/user_profile_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';

class UserService {
  /// Получить профиль текущего пользователя
  static Future<UserProfile> getProfile({required String token}) async {
    try {
      final response = await ApiService.get('/me', token: token);

      final profileResponse = UserProfileResponse.fromJson(response);
      // print('✅ UserService: Профиль распарсен');
      // print();

      if (profileResponse.data.isEmpty) {
        throw Exception('Список профилей пуст');
      }

      final profile = profileResponse.data[0];

      // DEBUG: Детальное логирование полей
      // print('🔍 DEBUG UserService.getProfile() BEFORE FIX:');
      // print('   - profile.name = "${profile.name}"');
      // print('   - profile.lastName = "${profile.lastName}"');

      // FIX: API иногда возвращает скомбинированное имя вместо отдельных полей
      // Если nameполучилось как "Имя Фамилия Фамилия", нужно вычистить
      String firstName = profile.name;
      String lastName = profile.lastName;

      // Если lastName не пустой и name кончается на lastName - удаляем это
      if (lastName.isNotEmpty && firstName.endsWith(lastName)) {
        // Убираем фамилию из конца имени
        firstName = firstName
            .substring(0, firstName.length - lastName.length)
            .trim();
        // print('   ✏️ FIXED: Removed trailing lastName from name');
      }

      // Если в конце первого имени есть пробел - убираем его
      if (firstName.contains(' ${lastName}')) {
        firstName = firstName.replaceAll(' ${lastName}', '').trim();
        // print('   ✏️ FIXED: Removed space-separated lastName');
      }

      // Проверяем если уже нет дублирования
      final parts = firstName.split(' ');
      // print('   - Parts in name: $parts');

      // Если есть дублирование (например "Юрий Зак Зак"), оставляем только "Юрий"
      // Ищем повторение слов в конце
      if (parts.length > 1) {
        for (int i = 1; i < parts.length - 1; i++) {
          if (parts[i] == parts[parts.length - 1]) {
            // Нашли повторение - берем только первое имя
            firstName = parts.first;
            // print();
            break;
          }
        }
      }

      // print('🔍 DEBUG UserService.getProfile() AFTER FIX:');
      // print('   - firstName = "$firstName"');
      // print('   - lastName = "$lastName"');

      // Создаем новый профиль с исправленными значениями
      final correctedProfile = UserProfile(
        id: profile.id,
        name: firstName,
        lastName: lastName,
        email: profile.email,
        phone: profile.phone,
        nickname: profile.nickname,
        avatar: profile.avatar,
        about: profile.about,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
        emailVerifiedAt: profile.emailVerifiedAt,
        phoneVerifiedAt: profile.phoneVerifiedAt,
        offersCount: profile.offersCount,
        newOffersCount: profile.newOffersCount,
        contacts: profile.contacts,
        qrCode: profile.qrCode,
      );

      return correctedProfile;
    } catch (e) {
      if (e.toString().contains('Token expired')) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getProfile(token: newToken);
        }
      }
      // print('❌ UserService: Ошибка при загрузке профиля: $e');
      // print('❌ UserService: Type: ${e.runtimeType}');
      rethrow;
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
      if (e.toString().contains('Token expired')) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return updateProfile(
            name: name,
            email: email,
            phone: phone,
            about: about,
            avatar: avatar,
            token: newToken,
          );
        }
      }
      rethrow;
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
      // print('🖼️ UserService: Загружаем аватарку...');
      // print('📍 Путь файла: $filePath');

      final response = await ApiService.uploadFile(
        '/me/settings/avatar',
        filePath: filePath,
        fieldName: 'image',
        token: token,
      );

      // print('✅ UserService: Аватарка успешно загружена');
      // print('📦 Ответ: $response');

      if (response['success'] == true) {
        // print('✅ UserService: success = true');
        return true;
      } else {
        // print('❌ UserService: success = false');
        throw Exception('API вернул success: false');
      }
    } catch (e) {
      // print('❌ UserService: Ошибка при загрузке аватарки: $e');
      throw Exception('Ошибка при загрузке аватарки: $e');
    }
  }

  /// Удалить аватарку профиля
  static Future<bool> deleteAvatar({required String token}) async {
    try {
      // print('🖼️ UserService: Удаляем аватарку...');

      // API требует отправку как multipart с delete_image=true
      final headers = {'X-App-Client': 'mobile'};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // print('═══════════════════════════════════════════════════════');
      // print('📤 DELETE AVATAR REQUEST');
      // print('URL: ${ApiService.baseUrl}/me/settings/avatar');
      // print('Token provided: true');
      // print('═══════════════════════════════════════════════════════');

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

      // print('✅ Response status: ${httpResponse.statusCode}');
      // print('📋 Response: ${httpResponse.body}');

      if (httpResponse.statusCode == 200) {
        final response = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        if (response['success'] == true) {
          // print('✅ UserService: Аватарка успешно удалена');
          return true;
        }
      }

      throw Exception('Failed to delete avatar');
    } catch (e) {
      // print('❌ UserService: Ошибка при удалении аватарки: $e');
      throw Exception('Ошибка при удалении аватарки: $e');
    }
  }

  /// Обновить информацию "О себе"
  static Future<Map<String, dynamic>> updateAbout({
    required String about,
    required String token,
  }) async {
    try {
      // print('📝 UserService: Обновляем информацию "О себе"...');

      final data = {'about': about};

      final response = await ApiService.put(
        '/me/settings/about',
        data,
        token: token,
      );

      // print('✅ UserService: Информация "О себе" успешно обновлена');
      // print('📦 Ответ: $response');

      return response;
    } catch (e) {
      // print('❌ UserService: Ошибка при обновлении "О себе": $e');
      throw Exception('Ошибка при обновлении информации о себе: $e');
    }
  }

  /// Изменить язык системы (локаль)
  static Future<Map<String, dynamic>> changeLocale({
    required String locale,
    required String token,
  }) async {
    try {
      // print('🌐 UserService: Меняем язык на "$locale"...');

      final data = {'locale': locale};

      final response = await ApiService.put(
        '/me/settings/locale',
        data,
        token: token,
      );

      // print('✅ UserService: Язык успешно изменен на "$locale"');
      // print('📦 Ответ: $response');

      // Сохраняем текущий язык локально
      await HiveService.saveUserData('currentLocale', locale);

      return response;
    } catch (e) {
      // print('❌ UserService: Ошибка при изменении языка: $e');
      throw Exception('Ошибка при изменении языка: $e');
    }
  }

  /// Обновить имя и фамилию пользователя
  static Future<Map<String, dynamic>> updateName({
    required String name,
    required String lastName,
    String? nickname,
    required String token,
  }) async {
    try {
      // print();

      final data = {
        'name': name,
        'last_name': lastName,
        if (nickname != null) 'nickname': nickname,
      };

      final response = await ApiService.put(
        '/me/settings/name',
        data,
        token: token,
      );

      // print('✅ UserService: Имя успешно обновлено');
      // print('📦 Ответ: $response');

      return response;
    } catch (e) {
      // print('❌ UserService: Ошибка при обновлении имени: $e');
      throw Exception('Ошибка при обновлении имени: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Локальное хранилище: тонкая обёртка над HiveService для UI-слоя.
  // Страницы и виджеты импортируют UserService, а не HiveService напрямую.
  // ─────────────────────────────────────────────────────────────────────────

  /// Синхронно читает значение из локального хранилища по [key].
  static dynamic getLocal(String key) => HiveService.getUserData(key);

  /// Асинхронно сохраняет [value] в локальное хранилище по [key].
  static Future<void> saveLocal(String key, dynamic value) =>
      HiveService.saveUserData(key, value);

  /// Асинхронно удаляет значение из локального хранилища по [key].
  static Future<void> deleteLocal(String key) =>
      HiveService.deleteUserData(key);

  /// Полностью очищает данные профиля текущего пользователя:
  /// удаляет все поля из Hive и инвалидирует L1/L2-кеш.
  ///
  /// Вызывать при logout и перед сохранением данных нового пользователя при login,
  /// чтобы исключить показ данных предыдущей сессии.
  static Future<void> clearLocalProfileData() async {
    // Удаляем все поля профиля из Hive
    const profileKeys = [
      'name',
      'lastName',
      'email',
      'phone',
      'userId',
      'profileImage',
      'username',
      'about',
      'qrCode',
    ];
    for (final key in profileKeys) {
      await HiveService.deleteUserData(key);
    }

    // Инвалидируем все кеши профиля (L1 + L2)
    AppCacheService().invalidate(CacheKeys.profileData);
    AppCacheService().invalidate(CacheKeys.profileListingsCounts);
    AppCacheService().invalidate(CacheKeys.profilePriceOffersCount);
  }
}

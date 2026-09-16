// ============================================================
// "Сервис: Аутентификация пользователей"
// ============================================================

import 'dart:convert';
import 'api_service.dart';
import '../hive_service.dart';
import 'user_service.dart';
import 'device_info_service.dart';
import 'package:lidle/core/logger.dart';

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

  /// Исправить почту НЕПОДТВЕРЖДЁННОГО аккаунта (16.09.2026).
  ///
  /// Человек ошибся в своём адресе при регистрации: письмо ушло в никуда,
  /// войти он не может (вход требует подтверждённой почты), а поменять адрес
  /// было нечем. Раньше единственным выходом была регистрация заново, и в базе
  /// оставался мёртвый аккаунт.
  ///
  /// Пароль обязателен: без него любой, знающий чужой неподтверждённый адрес,
  /// увёл бы регистрацию на свою почту. Человек набирал его на предыдущем
  /// экране пару минут назад.
  static Future<Map<String, dynamic>> changePendingEmail({
    required String email,
    required String password,
    required String newEmail,
  }) async {
    return await ApiService.post(
      '/auth/change-email',
      {
        'email': email.trim(),
        'password': password,
        'new_email': newEmail.trim(),
      },
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
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };

    // Фамилию шлём, только если она есть (16.09.2026). В форме регистрации
    // поля больше нет, человек вписывает фамилию на экране контактных данных.
    // Пустая строка не прошла бы проверку сервера (минимум две буквы), поэтому
    // не отправляем ключ вовсе.
    if (lastName.trim().isNotEmpty) {
      body['last_name'] = lastName.trim();
    }

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
  ///
  /// ОБНОВЛЕНО: device_name теперь получается динамически из DeviceInfoService
  /// вместо жесткого значения, чтобы каждое устройство было уникально идентифицировано.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email,
      'password': password,
      // Уникальное имя устройства (модель + стабильный id установки), чтобы вход
      // на одном устройстве не вытеснял токены других устройств пользователя.
      'device_name': await DeviceInfoService.getDeviceNameForApiAsync(),
      'app_version': '1.4.1',
    };

    // skipTokenRefresh: true — при 401 (неверные данные) не пытаемся refresh токена,
    // иначе login зависает на 15с ожидая refresh.
    return await ApiService.post('/auth/login', body, skipTokenRefresh: true);
  }

  /// Быстрый вход/регистрация через соцсеть (VK, Одноклассники).
  /// Отправляет authorization code от провайдера на бэк; бэк меняет код на
  /// данные пользователя и отдаёт те же токены, что обычный логин, плюс is_new.
  /// Ответ: { access_token, refresh_token, token_type, expires_in, is_new }
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String code,
    String? codeVerifier,
    String? deviceId,
    String? redirectUri,
  }) async {
    final body = <String, dynamic>{
      'provider': provider,
      'code': code,
      // То же уникальное имя устройства, что и при обычном логине.
      'device_name': await DeviceInfoService.getDeviceNameForApiAsync(),
      'app_version': '1.4.1',
    };
    // PKCE и device_id для VK ID.
    if (codeVerifier != null && codeVerifier.isNotEmpty) {
      body['code_verifier'] = codeVerifier;
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      body['device_id'] = deviceId;
    }
    if (redirectUri != null && redirectUri.isNotEmpty) {
      body['redirect_uri'] = redirectUri;
    }
    return await ApiService.post('/auth/social', body, skipTokenRefresh: true);
  }

  /// Нужна ли этому человеку настоящая почта (16.09.2026).
  ///
  /// ВК не всегда отдаёт почту, и тогда аккаунт заводится со служебным
  /// адресом вида `vk_123@social.lidle.io`. Человек уже внутри приложения, но
  /// письма ему не дойдут, покупателю такой адрес не покажешь, и объявление
  /// он опубликовать не сможет.
  ///
  /// Признак приходит и в ответе соцвхода, и в профиле: вход бывает один раз,
  /// а приложение перезапускают каждый день, и без второго источника человек,
  /// закрывший экран, больше никогда бы его не увидел.
  static bool needsEmail = false;

  /// Шаг 1: человек указал почту, сервер шлёт на неё код.
  static Future<Map<String, dynamic>> claimSocialEmail({
    required String email,
  }) async {
    return await ApiService.post('/auth/social/claim-email', {
      'email': email.trim(),
    });
  }

  /// Шаг 2: человек ввёл код.
  ///
  /// Сервер на этом шаге может не просто поставить почту, а ОБЪЕДИНИТЬ
  /// аккаунты: если такая почта уже есть у кого-то, соцвход переезжает на тот
  /// аккаунт, а пустой новый удаляется. Тогда в ответе приезжают новые токены,
  /// и их надо сохранить, иначе человек останется с токеном удалённого
  /// аккаунта.
  static Future<Map<String, dynamic>> confirmSocialEmail({
    required String email,
    required String code,
  }) async {
    final response = await ApiService.post('/auth/social/confirm-email', {
      'email': email.trim(),
      'code': code.trim(),
    });

    if (response['success'] == true) {
      await _saveMergedTokens(response);

      needsEmail = false;
    }

    return response;
  }

  /// Сохранить токены, приехавшие после объединения аккаунтов.
  ///
  /// Обычный вход сохраняет токены в блоке авторизации, но сюда человек
  /// попадает уже вошедшим, минуя его. Пишем те же ключи, что и там: разойдись
  /// они, приложение после объединения осталось бы с токеном удалённого
  /// аккаунта и вылетело бы при первом же запросе.
  static Future<void> _saveMergedTokens(Map<String, dynamic> response) async {
    final token = response['access_token'] ?? response['data']?['access_token'];

    if (token == null) return;

    await UserService.saveLocal('token', token);

    final refresh =
        response['refresh_token'] ?? response['data']?['refresh_token'];

    if (refresh != null) {
      await UserService.saveLocal('refresh_token', refresh);
    }

    final expiresIn =
        ((response['expires_in'] ?? response['data']?['expires_in']) as num?)
            ?.toInt() ??
        900;

    await UserService.saveLocal(
      'token_expires_at',
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );

    final refreshExpiresIn =
        ((response['refresh_expires_in'] ??
                response['data']?['refresh_expires_in']) as num?)
            ?.toInt() ??
        1209600;

    await UserService.saveLocal(
      'refresh_token_expires_at',
      DateTime.now()
          .add(Duration(seconds: refreshExpiresIn))
          .millisecondsSinceEpoch,
    );
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

  /// Проверить код восстановления, ничего не меняя.
  ///
  /// Отдельный шаг нужен, чтобы человек узнал об ошибке в коде сразу на
  /// экране ввода кода, а не после того, как дважды наберёт новый пароль.
  /// Код при этом не гасится: его гасит только сама смена пароля.
  static Future<Map<String, dynamic>> checkRecoveryCode({
    required String email,
    required String code,
  }) async {
    return await ApiService.post(
      '/auth/password/check-code',
      {'email': email, 'code': code},
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
  /// затем очищает оба токена из локального хранилища (Hive + secure storage).
  static Future<void> logout() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token != null && token.isNotEmpty) {
        // Инвалидируем токен на сервере
        await ApiService.post('/auth/logout', {}, token: token);
        // log.d('✅ AuthService: logout на сервере выполнен');
      }
    } catch (e) {
      // Игнорируем ошибки сервера — токены всё равно удалим локально
      // log.d('⚠️ AuthService: ошибка logout на сервере (игнорируем): $e');
    } finally {
      // Всегда удаляем оба токена локально (из Hive И из secure storage)
      await UserService.deleteAllTokens();
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
        // log.d('❌ AuthService: Неверный формат токена (ожидается 3 части)');
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
      // log.d('✅ AuthService: userId из токена = $userId');
      return userId;
    } catch (e) {
      // log.d('❌ AuthService: Ошибка при декодировании токена: $e');
      return '0';
    }
  }
}

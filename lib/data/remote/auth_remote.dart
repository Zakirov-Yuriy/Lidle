// ============================================================
// "API методы для авторизации и управления токенами"
// ============================================================

import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/network/http_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Remote класс для всех операций с авторизацией и управлением токенами.
///
/// Включает методы для:
/// - Обновления access_token через refresh_token
class AuthRemote {
  static const String _baseUrl = 'https://dev-api.lidle.io/v1';
  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    'Content-Type': 'application/json',
  };

  /// Обновляет access_token используя refresh_token согласно API документации v1.4+
  ///
  /// Параметры (согласно POST /auth/refresh-token):
  /// - device_name: String (обязателен) — название устройства
  /// - app_version: String (опционален) — версия приложения из pubspec.yaml
  ///
  /// Возвращает новый access_token или null если refresh_token истёк/невалиден.
  ///
  /// Обновления (согласно последней документации):
  /// - Обрабатывает refresh_expires_in для проактивного обновления refresh_token
  /// - Сохраняет оба время истечения: token_expires_at и refresh_token_expires_at
  /// - Динамически читает device_name и app_version
  /// - 401/403 → null (нужна повторная авторизация)
  ///
  /// КРИТИЧНО: Метод ИГНОРИРУЕТ параметр currentToken и используем ТОЛЬКО refresh_token из Hive.
  /// Передача access_token вместо refresh_token приведет к 401 от сервера!
  static Future<String?> refreshToken(String currentToken) async {
    try {
      // POST /auth/refresh-token  (документация API v1.4+)
      // Authorization: Bearer {refresh_token}  ← refresh_token в заголовке
      // Body: {"device_name": "...", "app_version": "..."}

      // ИСПРАВЛЕНИЕ: Используем ТОЛЬКО refresh_token из Hive, никогда не используем currentToken
      final refreshTokenValue =
          HiveService.getUserData('refresh_token') as String?;

      // Если refresh_token не найден - это критическая ошибка
      if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
        log.d(
          '❌ AuthRemote.refreshToken: refresh_token не найден в Hive, невозможно обновить токен',
        );
        return null;
      }

      final headers = {..._defaultHeaders};
      // Передаём REFRESH_TOKEN (не access_token) как Bearer в Authorization
      headers['Authorization'] = 'Bearer $refreshTokenValue';

      // ОБНОВЛЕНО: Получаем device_name и app_version динамически
      final deviceName = await _getDeviceName();
      final appVersion = _getAppVersion(); // из pubspec.yaml: 1.0.0

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh-token'),
            headers: headers,
            // device_name обязателен согласно API документации — API отклонит запрос без него
            // app_version опционален, но рекомендуется отправлять для аналитики сервера
            body: jsonEncode({
              'device_name': deviceName,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 15));

      // 401 = токен истёк, 403 = токен невалиден.
      // Оба случая означают что нужна повторная авторизация (нет автоматического рефреша).
      if (response.statusCode == 401 || response.statusCode == 403) {
        log.d(
          '🔒 AuthRemote.refreshToken: токен истёк/невалиден (${response.statusCode})',
        );
        return null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        log.d(
          '❌ AuthRemote.refreshToken: сервер вернул ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Проверяем флаг success
      if (data['success'] != true) {
        log.d('❌ AuthRemote.refreshToken: success=false');
        return null;
      }

      // Сохраняем новый access_token
      final newAccessToken = data['access_token'] as String?;
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await HiveService.saveUserData('token', newAccessToken);
        log.d('✅ AuthRemote.refreshToken: новый access_token сохранён');
      } else {
        log.d('❌ AuthRemote.refreshToken: access_token не найден в ответе');
        return null;
      }

      // API v1.4+: обновлённый refresh_token ротируется при каждом refresh
      // Без сохранения следующее обновление завершится 401 (старый refresh_token истёк).
      final newRefreshToken = data['refresh_token'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await HiveService.saveUserData('refresh_token', newRefreshToken);
        log.d('✅ AuthRemote.refreshToken: новый refresh_token сохранён (ротация)');
      } else {
        log.d('❌ AuthRemote.refreshToken: refresh_token не найден в ответе');
        return null;
      }

      // ОБНОВЛЕНО: Сохраняем время истечения access_token для TokenService
      // Sanctum opaque токены (формат "153|abc...") НЕ являются JWT —
      // нельзя декодировать поле exp. Используем expires_in из ответа сервера.
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 900;
      final expiresAtMs = DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch;
      await HiveService.saveUserData('token_expires_at', expiresAtMs);
      log.d(
        '✅ AuthRemote.refreshToken: access_token expires_in=$expiresIn сек',
      );

      // ОБНОВЛЕНО: Сохраняем время истечения refresh_token для проактивного обновления
      final refreshExpiresIn =
          (data['refresh_expires_in'] as num?)?.toInt() ?? 1209600;
      final refreshExpiresAtMs = DateTime.now()
          .add(Duration(seconds: refreshExpiresIn))
          .millisecondsSinceEpoch;
      await HiveService.saveUserData(
        'refresh_token_expires_at',
        refreshExpiresAtMs,
      );
      log.d(
        '✅ AuthRemote.refreshToken: refresh_token expires_in=$refreshExpiresIn сек (14 дней)',
      );

      // КРИТИЧНО: Перед возвратом проверяем что токен действительно сохранен в Hive
      final savedToken = HiveService.getUserData('token') as String?;
      if (savedToken == null || savedToken.isEmpty) {
        log.d('❌ AuthRemote.refreshToken: токен не был сохранен в Hive!');
        return null;
      }

      log.d('✅ AuthRemote.refreshToken: токен успешно сохранен');
      return newAccessToken;
    } catch (e) {
      log.d('❌ AuthRemote.refreshToken exception: $e');
      return null;
    }
  }

  /// Получает название устройства для отправки на сервер
  static Future<String> _getDeviceName() async {
    try {
      return 'Lidle Mobile App';
    } catch (_) {
      return 'Unknown Device';
    }
  }

  /// Получает версию приложения из pubspec.yaml (формат: 1.0.0)
  static String _getAppVersion() {
    // В реальном приложении используйте package_info_plus для получения версии во время выполнения
    return '1.0.0'; // version: 1.0.0+1 из pubspec.yaml
  }
}

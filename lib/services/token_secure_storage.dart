// ============================================================
// "Сервис: Безопасное хранилище токенов"
//
// Отвечает за:
// 1. Сохранение токенов в flutter_secure_storage (шифрованное хранилище)
// 2. Чтение токенов из secure storage
// 3. Удаление токенов при logout
// 4. Миграция старых токенов из Hive в secure storage при первом запуске
// ============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lidle/core/logger.dart';

/// Сервис для безопасного хранения токенов в зашифрованном хранилище.
///
/// ВАЖНО: На iOS используется Keychain, на Android используется EncryptedSharedPreferences.
/// Токены недоступны для других приложений или файловой системы.
class TokenSecureStorage {
  /// Ключи для хранения
  static const String _accessTokenKey = 'access_token_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';
  static const String _tokenExpiresAtKey = 'token_expires_at_secure';
  static const String _refreshTokenExpiresAtKey =
      'refresh_token_expires_at_secure';

  /// Миграция завершена флаг
  static const String _migrationCompleteKey = 'token_migration_complete';

  /// flutter_secure_storage instance
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Используем EncryptedSharedPreferences по умолчанию (безопаснее)
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm:
          StorageCipherAlgorithm.AES_GCM_NoPadding, // AES-256-GCM
    ),
    // На iOS используется Keychain (встроенное хранилище Apple) по умолчанию
  );

  /// Singleton pattern
  static final TokenSecureStorage _instance =
      TokenSecureStorage._internal();

  factory TokenSecureStorage() {
    return _instance;
  }

  TokenSecureStorage._internal();

  /// Сохраняет access_token в secure storage
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: token,
      );
      log.d('✅ TokenSecureStorage: access_token сохранён в secure storage');
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при сохранении access_token: $e');
      rethrow;
    }
  }

  /// Сохраняет refresh_token в secure storage
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: token,
      );
      log.d('✅ TokenSecureStorage: refresh_token сохранён в secure storage');
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при сохранении refresh_token: $e');
      rethrow;
    }
  }

  /// Сохраняет timestamp истечения access_token
  Future<void> saveTokenExpiresAt(String expiresAt) async {
    try {
      await _secureStorage.write(
        key: _tokenExpiresAtKey,
        value: expiresAt,
      );
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при сохранении token_expires_at: $e');
      rethrow;
    }
  }

  /// Сохраняет timestamp истечения refresh_token
  Future<void> saveRefreshTokenExpiresAt(String expiresAt) async {
    try {
      await _secureStorage.write(
        key: _refreshTokenExpiresAtKey,
        value: expiresAt,
      );
    } catch (e) {
      log.e(
        '❌ TokenSecureStorage: Ошибка при сохранении refresh_token_expires_at: $e',
      );
      rethrow;
    }
  }

  /// Читает access_token из secure storage
  ///
  /// Возвращает null если токен не найден
  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token != null) {
        log.d(
          '✅ TokenSecureStorage: access_token прочитан из secure storage',
        );
      }
      return token;
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при чтении access_token: $e');
      return null;
    }
  }

  /// Читает refresh_token из secure storage
  ///
  /// Возвращает null если токен не найден
  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: _refreshTokenKey);
      if (token != null) {
        log.d(
          '✅ TokenSecureStorage: refresh_token прочитан из secure storage',
        );
      }
      return token;
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при чтении refresh_token: $e');
      return null;
    }
  }

  /// Читает timestamp истечения access_token
  Future<String?> getTokenExpiresAt() async {
    try {
      return await _secureStorage.read(key: _tokenExpiresAtKey);
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при чтении token_expires_at: $e');
      return null;
    }
  }

  /// Читает timestamp истечения refresh_token
  Future<String?> getRefreshTokenExpiresAt() async {
    try {
      return await _secureStorage.read(key: _refreshTokenExpiresAtKey);
    } catch (e) {
      log.e(
        '❌ TokenSecureStorage: Ошибка при чтении refresh_token_expires_at: $e',
      );
      return null;
    }
  }

  /// Удаляет все токены (logout)
  Future<void> clearAllTokens() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _accessTokenKey),
        _secureStorage.delete(key: _refreshTokenKey),
        _secureStorage.delete(key: _tokenExpiresAtKey),
        _secureStorage.delete(key: _refreshTokenExpiresAtKey),
      ]);
      log.d('✅ TokenSecureStorage: Все токены удалены');
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при удалении токенов: $e');
      rethrow;
    }
  }

  /// Проверяет была ли миграция старых токенов завершена
  Future<bool> isMigrationComplete() async {
    try {
      final value = await _secureStorage.read(key: _migrationCompleteKey);
      return value == 'true';
    } catch (e) {
      log.e(
        '❌ TokenSecureStorage: Ошибка при проверке миграции: $e',
      );
      return false;
    }
  }

  /// Отмечает миграцию как завершённую
  Future<void> markMigrationComplete() async {
    try {
      await _secureStorage.write(
        key: _migrationCompleteKey,
        value: 'true',
      );
      log.d(
        '✅ TokenSecureStorage: Миграция отмечена как завершённая',
      );
    } catch (e) {
      log.e('❌ TokenSecureStorage: Ошибка при отметке миграции: $e');
      rethrow;
    }
  }
}

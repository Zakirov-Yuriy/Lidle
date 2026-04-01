import 'dart:async';
import 'package:lidle/core/logger.dart';
import 'package:lidle/data/remote/auth_remote.dart';
import 'package:lidle/hive_service.dart';

/// Interceptor для логики refresh токена.
/// 
/// Обеспечивает:
/// - Синхронизацию параллельных refresh запросов (Completer lock)
/// - Предотвращение race condition при одновременном получении 401
/// - Интеграцию с AuthRemote для обновления токена
/// - Управление состоянием refresh операции
class TokenInterceptor {
  /// Lock для синхронизации параллельных refresh-попыток
  static Completer<String?>? _tokenRefreshCompleter;

  /// Возвращает true если прямо сейчас выполняется refresh токена
  static bool get isRefreshingToken => _tokenRefreshCompleter != null;

  /// Ожидает завершения текущего refresh-запроса, если он выполняется
  /// 
  /// Возвращает новый access_token если refresh успешен, иначе null.
  /// Используется для синхронизации при одновременном получении 401 несколькими запросами.
  static Future<String?> waitForPendingRefresh() async {
    final completer = _tokenRefreshCompleter;
    if (completer == null) return null;
    try {
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  /// Выполняет refresh токена с синхронизацией через Completer
  /// 
  /// Логика:
  /// 1. Если уже выполняется refresh - ждём его завершения (не запускаем новый)
  /// 2. Если нет - создаём новый Completer и начинаем refresh
  /// 3. Все параллельные запросы ждут первого refresh'а
  /// 4. После завершения - очищаем Completer для следующего цикла
  /// 
  /// Параметр currentToken - текущий access_token (для логирования/отладки)
  static Future<String?> refreshToken(String currentToken) async {
    try {
      // Если уже идёт refresh - ждём его завершения
      final existingCompleter = _tokenRefreshCompleter;
      if (existingCompleter != null) {
        log.d('🔔 TokenInterceptor: refresh уже в процессе, ждём завершения');
        return await existingCompleter.future;
      }

      // Создаём новый Completer для синхронизации других запросов
      final completer = Completer<String?>();
      _tokenRefreshCompleter = completer;

      log.d('🔄 TokenInterceptor: начинаем refresh токена');

      // Читаем refresh_token из Hive для использования в AuthRemote
      final refreshToken = HiveService.getUserData('refresh_token') as String?;
      if (refreshToken == null) {
        log.e('❌ TokenInterceptor: refresh_token не найден в Hive');
        completer.completeError('refresh_token not found');
        return null;
      }

      // Вызываем AuthRemote для обновления токена
      // currentToken используется как параметр согласно контракту, но AuthRemote
      // всё равно использует только refresh_token из Hive
      final newAccessToken = await AuthRemote.refreshToken(refreshToken);

      if (newAccessToken != null) {
        log.i('✅ TokenInterceptor: успешно получен новый access_token');
        // Сохраняем новый токен в Hive (делает AuthRemote)
        // Здесь просто подтверждаем успех
      } else {
        log.e('❌ TokenInterceptor: refresh_token истёк или невалиден (401/403)');
      }

      // Завершаем Completer с результатом
      completer.complete(newAccessToken);
      return newAccessToken;
    } catch (e, st) {
      // Если произошла ошибка - должны очистить Completer
      log.e('❌ TokenInterceptor error: $e\n$st');
      _tokenRefreshCompleter?.completeError(e);
      return null;
    } finally {
      // Очищаем Completer если он был создан в этом методе
      if (_tokenRefreshCompleter != null) {
        _tokenRefreshCompleter = null;
      }
    }
  }

  /// Проверяет нужен ли refresh на основе времени истечения
  /// 
  /// Используется TokenService для проактивного обновления перед истечением
  static bool shouldRefreshToken() {
    final expiresAt = HiveService.getUserData('token_expires_at') as int?;
    if (expiresAt == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Пороговое значение: обновляем за 5 минут до истечения (300000 мс)
    return now >= (expiresAt - 300000);
  }

  /// Устанавливает Completer вручную (для HttpClient интеграции)
  /// 
  /// Используется HttpClient для заполнения Completer'а снаружи
  static void setTokenRefreshCompleter(Completer<String?>? completer) {
    _tokenRefreshCompleter = completer;
  }
}

// ============================================================
// "Этап 3: foreground-сервис, удерживающий WebSocket (Android)"
// ============================================================
//
// Держит подключение к Reverb ЖИВЫМ даже когда приложение полностью закрыто
// (убрано из недавних). Для этого соединение живёт не в main-изоляте, а в
// изоляте Android foreground-сервиса (пакет flutter_foreground_task) — Android
// не убивает такой процесс, пока висит постоянное уведомление сервиса.
//
// Архитектура:
//   • main-изолят (WsForegroundService.start) — определяет userId, кладёт
//     параметры подключения и токен в общее хранилище (FlutterForegroundTask),
//     запрашивает разрешения и стартует сервис;
//   • изолят сервиса (WsTaskHandler) — читает параметры, поднимает
//     ReverbConnection и на событие `moderation.ai.done` показывает локальное
//     уведомление своим экземпляром flutter_local_notifications.
//
// Токен: кладётся при старте. Пока соединение живо (heartbeat), Reverb не
// перезапрашивает токен, поэтому долгая сессия работает и со «старым» токеном.
// При переоткрытии приложения start() кладёт свежий токен. Для проактивного
// обновления есть WsForegroundService.updateToken() (можно повесить на refresh).
//
// iOS: полноценного аналога foreground-сервиса нет — там используется
// WebSocketService (main-изолят). Этот сервис — Android-only.
//
// ВНИМАНИЕ: требует пакета flutter_foreground_task (см. pubspec) и правок
// AndroidManifest (разрешения + объявление сервиса). API пакета версии 8.x;
// при иной версии сигнатуры TaskHandler/Options могут отличаться.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/reverb_connection.dart';

// Ключи общего хранилища (main-изолят пишет → изолят сервиса читает).
const String _kToken = 'ws_token';
const String _kUserId = 'ws_user_id';
const String _kHost = 'ws_host';
const String _kKey = 'ws_key';
const String _kTls = 'ws_tls';
const String _kAuthUrl = 'ws_auth_url';

const int _aiNotificationId = 90031;
const int _feedNotificationId = 90032;
const int _serviceId = 90030;

/// Точка входа изолята foreground-сервиса. ДОЛЖНА быть top-level и помечена
/// vm:entry-point (иначе tree-shaking её выкинет).
@pragma('vm:entry-point')
void startWsForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(WsTaskHandler());
}

/// Обработчик, живущий в изоляте сервиса.
class WsTaskHandler extends TaskHandler {
  ReverbConnection? _conn;
  FlutterLocalNotificationsPlugin? _fln;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _initNotifications();

    final userId = await FlutterForegroundTask.getData<int>(key: _kUserId);
    final host = await FlutterForegroundTask.getData<String>(key: _kHost);
    final appKey = await FlutterForegroundTask.getData<String>(key: _kKey);
    final tls = await FlutterForegroundTask.getData<bool>(key: _kTls) ?? true;
    final authUrl = await FlutterForegroundTask.getData<String>(key: _kAuthUrl);

    if (userId == null || host == null || appKey == null || authUrl == null) {
      if (kDebugMode) debugPrint('[WS-FG] нет параметров подключения, стоп');
      return;
    }

    _conn = ReverbConnection(
      host: host,
      appKey: appKey,
      tls: tls,
      authUrl: authUrl,
      userId: userId,
      // Токен читаем из общего хранилища — при реконнекте подхватится свежий,
      // если main-изолят его обновил через updateToken().
      tokenProvider: () async =>
          FlutterForegroundTask.getData<String>(key: _kToken),
      onAiEvent: _showAi,
      onFeedEvent: _showFeed,
      log: (m) {
        if (kDebugMode) debugPrint('[WS-FG] $m');
      },
    );
    await _conn!.start();
  }

  // Периодический тик сервиса (по eventAction). Соединение держится своим
  // heartbeat, поэтому тут ничего делать не нужно — оставлено для наглядности.
  @override
  void onRepeatEvent(DateTime timestamp) {}

  // Данные из main-изолята (если понадобится присылать свежий токен «вживую»).
  @override
  void onReceiveData(Object data) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _conn?.stop();
    _conn = null;
  }

  Future<void> _initNotifications() async {
    _fln = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _fln!.initialize(settings);
  }

  Future<void> _showAi(String title, String body) async {
    final fln = _fln;
    if (fln == null) return;
    // Тот же канал, что у NotificationService.showNotification, чтобы вид был
    // единым.
    const android = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await fln.show(
      _aiNotificationId,
      title,
      body,
      details,
      payload: 'ai_moderation_done',
    );
  }

  // Уведомление о завершении импорта фида (пункты №3/№4). Отдельный id, чтобы
  // не затирать уведомление о завершении ИИ.
  Future<void> _showFeed(String title, String body) async {
    final fln = _fln;
    if (fln == null) return;
    const android = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await fln.show(
      _feedNotificationId,
      title,
      body,
      details,
      payload: 'feed_import_done',
    );
  }
}

/// Публичный API (вызывается из main-изолята).
class WsForegroundService {
  WsForegroundService._();

  static bool _inited = false;

  static void _ensureInit() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ws_foreground',
        channelName: 'Связь с сервером',
        channelDescription:
            'Держит соединение для мгновенных уведомлений о завершении ИИ.',
        onlyAlertOnce: true,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _inited = true;
  }

  /// Запустить сервис (после логина, пока приложение на переднем плане).
  static Future<void> start() async {
    _ensureInit();

    // Разрешение на уведомления (Android 13+).
    final np = await FlutterForegroundTask.checkNotificationPermission();
    if (np != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // Снятие ограничений энергосбережения (иначе Doze/агрессивные прошивки
    // могут душить сервис).
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Токен и userId (определяем в main-изоляте — тут доступны ApiService и т.п.).
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) return;
    final userId = await _resolveUserId(token);
    if (userId == null) return;

    final cfg = AppConfig();
    await FlutterForegroundTask.saveData(key: _kToken, value: token);
    await FlutterForegroundTask.saveData(key: _kUserId, value: userId);
    await FlutterForegroundTask.saveData(key: _kHost, value: cfg.reverbHost);
    await FlutterForegroundTask.saveData(key: _kKey, value: cfg.reverbKey);
    await FlutterForegroundTask.saveData(key: _kTls, value: cfg.reverbTls);
    await FlutterForegroundTask.saveData(
        key: _kAuthUrl, value: cfg.broadcastAuthUrl);

    if (await FlutterForegroundTask.isRunningService) {
      // Уже запущен — просто освежили сохранённый токен/параметры.
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'ЛИДЛ',
      notificationText: 'Слежу за завершением ИИ-обработки',
      callback: startWsForegroundCallback,
    );
  }

  /// Обновить сохранённый токен (например, после refresh) — чтобы переподписка
  /// в изоляте прошла со свежим токеном. Best-effort.
  static Future<void> updateToken(String token) async {
    if (token.isEmpty) return;
    try {
      await FlutterForegroundTask.saveData(key: _kToken, value: token);
    } catch (_) {}
  }

  /// Остановить сервис (логаут).
  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  static Future<int?> _resolveUserId(String token) async {
    try {
      final resp = await ApiService.get('/me', token: token);
      final data = resp['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        final id = (data.first as Map)['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
        if (id is num) return id.toInt();
      }
    } catch (_) {}
    return null;
  }
}

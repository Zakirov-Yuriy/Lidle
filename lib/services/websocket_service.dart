// ============================================================
// "WebSocket сервис (Reverb) — main-изолят / fallback"
// ============================================================
//
// Держит подключение к Reverb, пока приложение открыто или свёрнуто, но процесс
// жив (main-изолят). Вся протокольная логика вынесена в ReverbConnection
// (reverb_connection.dart) — этот класс лишь связывает её с сервисами
// приложения (токен, userId через /me, показ уведомления).
//
// На Android для доставки при ПОЛНОСТЬЮ закрытом приложении используется
// WsForegroundService (этап 3, отдельный изолят). Этот сервис остаётся как
// путь для iOS и как fallback.
//
// Запуск: WebSocketService().start();  Стоп: WebSocketService().stop();

import 'dart:async';

import 'package:logger/logger.dart';

import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/reverb_connection.dart';

final _logger = Logger();

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  static const int _aiNotificationId = 90031;
  static const int _feedNotificationId = 90032;

  // DEBUG: показать одно тестовое уведомление сразу после успешной подписки,
  // чтобы проверить, что слой уведомлений вообще работает (без broadcast).
  // Перед релизом поставить false.
  static const bool _debugSelfTest = true;
  bool _selfTested = false;

  ReverbConnection? _conn;
  bool _started = false;
  int? _userId;

  /// Запустить: определить userId и подключиться.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      _started = false;
      return;
    }

    _userId ??= await _resolveUserId(token);
    if (_userId == null) {
      _logger.w('WebSocketService: не удалось определить userId');
      _started = false;
      return;
    }

    final cfg = AppConfig();
    _conn = ReverbConnection(
      host: cfg.reverbHost,
      appKey: cfg.reverbKey,
      tls: cfg.reverbTls,
      authUrl: cfg.broadcastAuthUrl,
      userId: _userId!,
      tokenProvider: () async => TokenService.currentToken,
      onAiEvent: _showAi,
      onFeedEvent: _showFeed,
      onSubscribed: () {
        if (_debugSelfTest && !_selfTested) {
          _selfTested = true;
          _showAi('Тест WebSocket',
              'Соединение установлено — уведомления работают ✅');
        }
      },
      log: (m) => _logger.i(m),
    );
    await _conn!.start();
  }

  /// Остановить (логаут).
  Future<void> stop() async {
    _started = false;
    await _conn?.stop();
    _conn = null;
  }

  void _showAi(String title, String body) {
    NotificationService().showNotification(
      id: _aiNotificationId,
      title: title,
      body: body,
      payload: 'ai_moderation_done',
    );
  }

  // Уведомление о завершении импорта фида (пункты №3/№4). Отдельный id, чтобы
  // не затирать уведомление о завершении ИИ.
  void _showFeed(String title, String body) {
    NotificationService().showNotification(
      id: _feedNotificationId,
      title: title,
      body: body,
      payload: 'feed_import_done',
    );
  }

  Future<int?> _resolveUserId(String token) async {
    try {
      final resp = await ApiService.get('/me', token: token);
      final data = resp['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        final id = (data.first as Map)['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
        if (id is num) return id.toInt();
      }
    } catch (e) {
      _logger.w('WebSocketService: /me ошибка: $e');
    }
    return null;
  }
}

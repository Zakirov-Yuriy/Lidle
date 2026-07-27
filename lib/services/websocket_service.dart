// ============================================================
// "WebSocket сервис (Reverb) для мгновенных уведомлений"
// ============================================================
//
// Подключается к Laravel Reverb напрямую по протоколу Pusher (через
// web_socket_channel — без внешнего Pusher-SDK, чтобы не зависеть от его
// версий). Слушает приватный канал `private-user.{id}` и на событие
// `moderation.ai.done` показывает локальное уведомление — мгновенно, пока
// приложение подключено (открыто или свёрнуто, но процесс жив).
//
// Протокол Pusher (кратко):
//  1. Подключаемся к wss://<host>/app/<key>?protocol=7...
//  2. Сервер шлёт pusher:connection_established с socket_id.
//  3. Для приватного канала берём подпись на /v1/broadcasting/auth
//     (Bearer-токен) и шлём pusher:subscribe { channel, auth }.
//  4. Ловим события; на pusher:ping отвечаем pusher:pong.
//
// Запуск: WebSocketService().start();  Стоп: WebSocketService().stop();
//
// Для доставки при полностью закрытом приложении соединение нужно удерживать
// foreground-сервисом — отдельный слой (этап 3).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/notification_service.dart';

final _logger = Logger();

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  static const int _aiNotificationId = 90031;
  static const String _aiEventName = 'moderation.ai.done';
  // Reverb закрывает «тихое» соединение (activity_timeout ~120с). Шлём ping
  // раньше — каждые ~25с, чтобы держать канал живым.
  static const Duration _heartbeatInterval = Duration(seconds: 25);

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _started = false;
  bool _stopping = false;
  int? _userId;
  String? _channelName;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  /// Запустить: определить userId и подключиться.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopping = false;
    await _connect();
  }

  /// Остановить (логаут).
  Future<void> stop() async {
    _stopping = true;
    _started = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _channelName = null;
  }

  Future<void> _connect() async {
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      _started = false;
      return;
    }

    // Чистим прошлое соединение, чтобы не плодить «висящие» каналы/подписки.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;

    try {
      _userId ??= await _resolveUserId(token);
      if (_userId == null) {
        _logger.w('WebSocketService: не удалось определить userId');
        _scheduleReconnect();
        return;
      }
      _channelName = 'private-user.$_userId';

      final cfg = AppConfig();
      final scheme = cfg.reverbTls ? 'wss' : 'ws';
      // nginx проксирует /app/ на Reverb; порт 443 (по умолчанию для wss).
      final url =
          '$scheme://${cfg.reverbHost}/app/${cfg.reverbKey}?protocol=7&client=flutter&version=1.0';

      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          _logger.w('WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          _logger.i('WS закрыт (${_channel?.closeCode})');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      _logger.i('🔌 WS: подключение к $scheme://${cfg.reverbHost}/app/***');
    } catch (e) {
      _logger.w('WebSocketService._connect ошибка: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_stopping || !_started) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (_started && !_stopping) _connect();
    });
  }

  /// Периодический ping, чтобы Reverb не закрывал «тихое» соединение (1006).
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  Future<void> _onMessage(dynamic raw) async {
    try {
      final msg = jsonDecode(raw as String);
      if (msg is! Map) return;
      final event = msg['event']?.toString();

      switch (event) {
        case 'pusher:connection_established':
          _startHeartbeat();
          final data = _decodeData(msg['data']);
          final socketId = data?['socket_id']?.toString();
          if (socketId != null && _channelName != null) {
            await _subscribePrivate(socketId, _channelName!);
          }
          break;

        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          break;

        case 'pusher:pong':
          // сервер жив — ничего не делаем
          break;

        case 'pusher_internal:subscription_succeeded':
          _logger.i('✅ WS: подписка на $_channelName');
          break;

        case _aiEventName:
          _handleAiEvent(_decodeData(msg['data']));
          break;

        default:
          // прочие события игнорируем
          break;
      }
    } catch (e) {
      _logger.w('WS: ошибка разбора сообщения: $e');
    }
  }

  /// Авторизует приватный канал и отправляет pusher:subscribe.
  Future<void> _subscribePrivate(String socketId, String channelName) async {
    try {
      final token = TokenService.currentToken ?? '';
      final resp = await http.post(
        Uri.parse(AppConfig().broadcastAuthUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'socket_id': socketId, 'channel_name': channelName},
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _logger.w('WS auth не удалась: ${resp.statusCode} ${resp.body}');
        return;
      }
      final authData = jsonDecode(resp.body);
      final auth = (authData is Map) ? authData['auth']?.toString() : null;
      if (auth == null) {
        _logger.w('WS auth: нет поля auth в ответе');
        return;
      }

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });
    } catch (e) {
      _logger.w('WS _subscribePrivate ошибка: $e');
    }
  }

  void _handleAiEvent(Map<String, dynamic>? data) {
    final title = data?['title']?.toString() ?? 'ИИ завершил обработку';
    final body = data?['body']?.toString() ??
        'Все объявления из фида обработаны. Зайдите и опубликуйте их.';
    NotificationService().showNotification(
      id: _aiNotificationId,
      title: title,
      body: body,
      payload: 'ai_moderation_done',
    );
    _logger.i('📬 WS: уведомление о завершении ИИ показано');
  }

  /// data в протоколе Pusher приходит строкой с JSON — декодируем в Map.
  Map<String, dynamic>? _decodeData(dynamic data) {
    try {
      if (data is String && data.isNotEmpty) {
        final d = jsonDecode(data);
        if (d is Map<String, dynamic>) return d;
      } else if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      _logger.w('WS send ошибка: $e');
    }
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
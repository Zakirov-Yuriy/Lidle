// ============================================================
// "Общее подключение к Laravel Reverb (протокол Pusher)"
// ============================================================
//
// Чистая, переиспользуемая логика WebSocket-подключения к Reverb по протоколу
// Pusher (через web_socket_channel, без внешнего Pusher-SDK). НЕ зависит от
// Flutter-виджетов и сервисов приложения — все параметры и колбэки передаются
// снаружи. Благодаря этому один и тот же код работает:
//   • в main-изоляте (см. websocket_service.dart) — пока приложение открыто;
//   • в изоляте foreground-сервиса (см. ws_foreground_service.dart) — чтобы
//     соединение держалось и когда приложение полностью закрыто (этап 3).
//
// Протокол Pusher (кратко):
//  1. Подключаемся к wss://<host>/app/<key>?protocol=7...
//  2. Сервер шлёт pusher:connection_established с socket_id.
//  3. Для приватного канала берём подпись на <authUrl> (Bearer-токен) и шлём
//     pusher:subscribe { channel, auth }.
//  4. Ловим события; на pusher:ping отвечаем pusher:pong; сами шлём ping,
//     чтобы Reverb не рвал «тихое» соединение по activity_timeout.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Колбэк события завершения ИИ-обработки: (title, body) для показа уведомления.
typedef ReverbAiEventCallback = void Function(String title, String body);

/// Простой лог-колбэк (в main-изоляте — Logger, в сервисе — debugPrint).
typedef ReverbLog = void Function(String message);

class ReverbConnection {
  ReverbConnection({
    required this.host,
    required this.appKey,
    required this.tls,
    required this.authUrl,
    required this.userId,
    required this.tokenProvider,
    required this.onAiEvent,
    this.onSubscribed,
    this.log,
  });

  /// Домен WS (nginx проксирует `/app/` на Reverb).
  final String host;

  /// Публичный REVERB_APP_KEY.
  final String appKey;

  /// true → wss, false → ws.
  final bool tls;

  /// URL авторизации приватных каналов (Bearer Sanctum).
  final String authUrl;

  /// ID пользователя для канала `private-user.{id}`.
  final int userId;

  /// Провайдер актуального токена (читается перед каждой авторизацией канала,
  /// чтобы при реконнекте использовать свежий токен).
  final Future<String?> Function() tokenProvider;

  /// Показать уведомление о завершении ИИ-обработки.
  final ReverbAiEventCallback onAiEvent;

  /// Вызывается один раз при успешной подписке на канал (для self-test и т.п.).
  final void Function()? onSubscribed;

  /// Необязательный лог.
  final ReverbLog? log;

  // Reverb закрывает «тихое» соединение (activity_timeout ~120с). Шлём ping
  // раньше — каждые ~25с, чтобы держать канал живым.
  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const String _aiEventName = 'moderation.ai.done';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _started = false;
  bool _stopping = false;
  String? _channelName;

  /// Запустить подключение.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopping = false;
    await _connect();
  }

  /// Остановить и всё почистить.
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
    final token = await tokenProvider();
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
      _channelName = 'private-user.$userId';
      final scheme = tls ? 'wss' : 'ws';
      final url =
          '$scheme://$host/app/$appKey?protocol=7&client=flutter&version=1.0';

      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          log?.call('WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          log?.call(
              'WS закрыт (code=${_channel?.closeCode} reason=${_channel?.closeReason})');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      log?.call('🔌 WS: подключение к $scheme://$host/app/***');
    } catch (e) {
      log?.call('ReverbConnection._connect ошибка: $e');
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

  /// Периодический ping, чтобы Reverb не закрывал «тихое» соединение.
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

        case 'pusher:error':
          // Reverb шлёт это ПЕРЕД тем как закрыть сокет (часто перед 1002).
          final err = _decodeData(msg['data']);
          log?.call(
              '⚠️ WS pusher:error code=${err?['code']} message=${err?['message']}');
          break;

        case 'pusher_internal:subscription_succeeded':
          log?.call('✅ WS: подписка на $_channelName');
          onSubscribed?.call();
          break;

        case _aiEventName:
          final data = _decodeData(msg['data']);
          final title = data?['title']?.toString() ?? 'ИИ завершил обработку';
          final body = data?['body']?.toString() ??
              'Все объявления из фида обработаны. Зайдите и опубликуйте их.';
          onAiEvent(title, body);
          log?.call('📬 WS: уведомление о завершении ИИ показано');
          break;

        default:
          break;
      }
    } catch (e) {
      log?.call('WS: ошибка разбора сообщения: $e');
    }
  }

  /// Авторизует приватный канал и отправляет pusher:subscribe.
  Future<void> _subscribePrivate(String socketId, String channelName) async {
    try {
      final token = await tokenProvider() ?? '';
      final resp = await http.post(
        Uri.parse(authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'socket_id': socketId, 'channel_name': channelName},
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        log?.call('WS auth не удалась: ${resp.statusCode} ${resp.body}');
        return;
      }
      final authData = jsonDecode(resp.body);
      final auth = (authData is Map) ? authData['auth']?.toString() : null;
      if (auth == null) {
        log?.call('WS auth: нет поля auth в ответе');
        return;
      }

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });
    } catch (e) {
      log?.call('WS _subscribePrivate ошибка: $e');
    }
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
      log?.call('WS send ошибка: $e');
    }
  }
}

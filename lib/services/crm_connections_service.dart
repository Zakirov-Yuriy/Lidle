// Подключение CRM компании (задача 88, 28.10.2026).
//
// Компания подключает свою систему сама: события площадки, звонки, заявки,
// брони и переписка, уходят к ней и ложатся в её CRM. Ручки те же, что у
// сайта: /v1/me/crm-connections.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Подключение в том виде, в каком его показывают человеку.
class CrmConnection {
  const CrmConnection({
    required this.id,
    required this.kind,
    this.name,
    this.url,
    this.events,
    this.isActive = true,
    this.lastOkAt,
    this.lastError,
  });

  factory CrmConnection.fromJson(Map<String, dynamic> json) {
    final events = json['events'];

    return CrmConnection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] as String?) ?? 'webhook',
      name: json['name'] as String?,
      url: json['url'] as String?,
      events: events is List ? events.whereType<String>().toList() : null,
      isActive: json['is_active'] != false,
      lastOkAt: json['last_ok_at'] as String?,
      lastError: json['last_error'] as String?,
    );
  }

  final int id;
  final String kind;
  final String? name;
  final String? url;

  /// Пусто означает «все события».
  final List<String>? events;

  final bool isActive;
  final String? lastOkAt;
  final String? lastError;

  String get title => (name == null || name!.trim().isEmpty) ? 'Подключение' : name!.trim();

  /// Строка состояния под названием.
  String get subtitle {
    if (lastError != null && lastError!.trim().isNotEmpty) {
      return 'последняя ошибка: ${lastError!.trim()}';
    }

    if (lastOkAt != null) {
      return 'последняя удачная отправка $lastOkAt';
    }

    return 'пока ничего не отправлялось';
  }
}

/// Строка журнала доставок.
class CrmDelivery {
  const CrmDelivery({
    required this.id,
    required this.event,
    required this.status,
    this.httpCode,
    this.error,
    this.createdAt,
  });

  factory CrmDelivery.fromJson(Map<String, dynamic> json) {
    return CrmDelivery(
      id: (json['id'] as num?)?.toInt() ?? 0,
      event: (json['event'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      httpCode: (json['http_code'] as num?)?.toInt(),
      error: json['error'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String event;
  final String status;
  final int? httpCode;
  final String? error;
  final String? createdAt;

  /// Понятное человеку название события.
  String get title {
    switch (event) {
      case 'call':
        return 'Нажали «Позвонить»';
      case 'contact':
        return 'Открыли контакты';
      case 'offer':
        return 'Предложили цену';
      case 'response':
        return 'Отклик';
      case 'booking':
        return 'Запись или бронь';
      case 'chat_message':
        return 'Сообщение в переписке';
      case 'test':
        return 'Пробное событие';
      default:
        return event;
    }
  }

  String get stateLine {
    final parts = <String>[];

    parts.add(switch (status) {
      'ok' => 'доставлено',
      'failed' => 'не доставлено',
      _ => 'отправляется',
    });

    if (httpCode != null) parts.add('ответ $httpCode');
    if (createdAt != null) parts.add(createdAt!);

    return parts.join(' · ');
  }
}

/// Созданное подключение: секрет показывается один раз.
class CreatedCrmConnection {
  const CreatedCrmConnection({required this.secret, required this.connection});

  final String secret;
  final CrmConnection connection;
}

class CrmConnectionsService {
  static const String _path = '/me/crm-connections';

  /// Какие события умеет отдавать сервер. Приходит вместе со списком, чтобы
  /// приложение не держало свой список, который разойдётся с сервером.
  static List<String> knownEvents = const [
    'call', 'contact', 'offer', 'response', 'booking', 'chat_message',
  ];

  static int limit = 3;

  static Future<List<CrmConnection>> all() async {
    final response = await ApiService.get(_path);

    final meta = response['meta'];

    if (meta is Map) {
      final events = meta['events'];
      if (events is List && events.isNotEmpty) {
        knownEvents = events.whereType<String>().toList();
      }

      if (meta['limit'] is num) {
        limit = (meta['limit'] as num).toInt();
      }
    }

    final data = response['data'];

    if (data is! List) return const [];

    return data.whereType<Map<String, dynamic>>().map(CrmConnection.fromJson).toList();
  }

  static Future<CreatedCrmConnection> create({
    required String url,
    String? name,
    String kind = 'webhook',
    String? token,
    List<String>? events,
  }) async {
    final body = <String, dynamic>{'url': url.trim(), 'kind': kind};

    // Токен нужен только amoCRM: туда мы ходим сами, а не она к нам.
    if (token != null && token.trim().isNotEmpty) {
      body['token'] = token.trim();
    }

    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }

    if (events != null && events.isNotEmpty) {
      body['events'] = events;
    }

    final response = await ApiService.post(_path, body);

    final card = response['data'];

    log.d('🔌 Подключение CRM создано');

    return CreatedCrmConnection(
      secret: (response['secret'] as String?) ?? '',
      connection: card is Map<String, dynamic>
          ? CrmConnection.fromJson(card)
          : const CrmConnection(id: 0, kind: 'webhook'),
    );
  }

  static Future<void> remove(int id) async {
    await ApiService.delete('$_path/$id');
  }

  /// Отправить пробное событие: иначе настройку не проверить.
  static Future<void> test(int id) async {
    await ApiService.post('$_path/$id/test', const {});
  }

  static Future<List<CrmDelivery>> deliveries(int id) async {
    final response = await ApiService.get('$_path/$id/deliveries');

    final data = response['data'];

    if (data is! List) return const [];

    return data.whereType<Map<String, dynamic>>().map(CrmDelivery.fromJson).toList();
  }
}

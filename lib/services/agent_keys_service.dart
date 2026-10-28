// Ключи ИИ-агентов в кабинете человека (задача 55, 27.10.2026).
//
// Раньше ключ выписывал администратор в админке, куда обычному человеку хода
// нет. Теперь он выпускает его сам и вставляет в своего агента: Клода, GPT,
// Алису, любого.
//
// Ручки те же, что у сайта: /v1/me/agent-keys.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Ключ агента в том виде, в каком его показывают человеку.
///
/// САМОГО КЛЮЧА ЗДЕСЬ НЕТ. Сервер хранит только отпечаток и отдаёт ключ один
/// раз, в ответ на выпуск, см. [AgentKeysService.issue].
class AgentKey {
  const AgentKey({
    required this.id,
    required this.name,
    this.trusted = false,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
    this.expired = false,
  });

  factory AgentKey.fromJson(Map<String, dynamic> json) {
    return AgentKey(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Ключ ИИ-агента',
      trusted: json['trusted'] == true,
      createdAt: json['created_at'] as String?,
      lastUsedAt: json['last_used_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      expired: json['expired'] == true,
    );
  }

  final int id;
  final String name;

  /// Повышенные лимиты. Ставит только администратор, из кабинета не выдаётся.
  final bool trusted;

  final String? createdAt;
  final String? lastUsedAt;
  final String? expiresAt;
  final bool expired;

  /// Строка под названием ключа: когда им пользовались и до какого числа он
  /// живёт.
  String get subtitle {
    final parts = <String>[];

    parts.add(lastUsedAt == null ? 'ни разу не использован' : 'последний раз $lastUsedAt');
    parts.add(expiresAt == null ? 'бессрочно' : (expired ? 'срок истёк $expiresAt' : 'до $expiresAt'));

    return parts.join(' · ');
  }
}

/// Ответ на выпуск ключа: сам ключ и его карточка.
class IssuedAgentKey {
  const IssuedAgentKey({required this.key, required this.card});

  final String key;
  final AgentKey card;
}

class AgentKeysService {
  static const String _path = '/me/agent-keys';

  /// Сколько ключей человеку оставили выпустить. Нужно, чтобы не предлагать
  /// кнопку, которая всё равно ответит отказом.
  static int lastLeft = 0;

  /// Адрес, который человек вставляет в настройки своего помощника.
  ///
  /// ПРИХОДИТ С СЕРВЕРА, а не зашит здесь (28.10.2026): на деве и на проде он
  /// разный, и правильный знает только сервер. Пока не загрузили, пусто, и
  /// экран ничего не показывает, чтобы не соврать.
  static String mcpUrl = '';

  /// Имя заголовка, в который кладут ключ.
  static String headerName = 'Authorization';

  /// Список ключей человека.
  static Future<List<AgentKey>> all() async {
    final response = await ApiService.get(_path);

    final meta = response['meta'];

    if (meta is Map) {
      if (meta['left'] is num) {
        lastLeft = (meta['left'] as num).toInt();
      }

      final url = meta['mcp_url'];
      if (url is String && url.trim().isNotEmpty) {
        mcpUrl = url.trim();
      }

      final header = meta['header_name'];
      if (header is String && header.trim().isNotEmpty) {
        headerName = header.trim();
      }
    }

    final data = response['data'];

    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(AgentKey.fromJson)
        .toList();
  }

  /// Выпустить ключ. Сам ключ приходит ОДИН раз, показать его повторно
  /// невозможно: сервер хранит только отпечаток.
  static Future<IssuedAgentKey> issue({
    String? name,
    int? days,
    bool trusted = false,
  }) async {
    final body = <String, dynamic>{};

    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }

    if (days != null && days > 0) {
      body['days'] = days;
    }

    if (trusted) {
      body['trusted'] = true;
    }

    final response = await ApiService.post(_path, body);

    final key = (response['key'] as String?) ?? '';
    final card = response['data'];

    log.d('🔑 Ключ агента выпущен, длина ${key.length}');

    return IssuedAgentKey(
      key: key,
      card: card is Map<String, dynamic>
          ? AgentKey.fromJson(card)
          : const AgentKey(id: 0, name: 'Ключ ИИ-агента'),
    );
  }

  /// Отозвать ключ. Агент с ним сразу перестаёт заходить.
  static Future<void> revoke(int id) async {
    await ApiService.delete('$_path/$id');
  }
}

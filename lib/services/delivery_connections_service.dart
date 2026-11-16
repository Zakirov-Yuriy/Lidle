// Подключения служб доставки (задача 53, 16.11.2026).
//
// Решение Саши 16.11.2026: договор компания заключает со службой напрямую, а
// ключи вставляет у нас. Мы даём функционал, деньги идут мимо нас.
//
// СПИСОК СЛУЖБ И ПОЛЯ КЛЮЧЕЙ ПРИХОДЯТ С СЕРВЕРА. Экран строится по ним,
// поэтому следующая служба, Яндекс или Озон, появится без новой сборки
// приложения и без новой версии в магазине.
//
// Ручки: /v1/me/delivery-connections.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Поле, которое нужно спросить у компании: ключ, название, подсказка.
class DeliveryField {
  const DeliveryField({
    required this.key,
    required this.label,
    this.hint,
    this.required_ = false,
    this.secret = false,
  });

  factory DeliveryField.fromJson(Map<String, dynamic> json) {
    return DeliveryField(
      key: (json['key'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      hint: json['hint'] as String?,
      required_: json['required'] == true,
      secret: json['secret'] == true,
    );
  }

  final String key;
  final String label;
  final String? hint;

  /// Имя с подчёркиванием: `required` занято ключевым словом Dart.
  final bool required_;

  /// Секретные поля показываем звёздочками и никогда не заполняем обратно:
  /// сервер их не отдаёт.
  final bool secret;
}

/// Служба доставки, которую мы умеем подключать.
class DeliveryProviderInfo {
  const DeliveryProviderInfo({
    required this.key,
    required this.title,
    this.about = '',
    this.fields = const [],
  });

  factory DeliveryProviderInfo.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];

    return DeliveryProviderInfo(
      key: (json['key'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      about: (json['about'] as String?) ?? '',
      fields: fields is List
          ? fields
              .whereType<Map<String, dynamic>>()
              .map(DeliveryField.fromJson)
              .toList()
          : const [],
    );
  }

  final String key;
  final String title;
  final String about;
  final List<DeliveryField> fields;
}

/// Подключение компании к службе.
class DeliveryConnection {
  const DeliveryConnection({
    required this.id,
    required this.provider,
    required this.title,
    this.name,
    this.isTest = false,
    this.isActive = true,
    this.ready = false,
    this.state = '',
    this.filled = const {},
    this.lastOkAt,
    this.lastError,
  });

  factory DeliveryConnection.fromJson(Map<String, dynamic> json) {
    final filled = json['filled'];

    return DeliveryConnection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      provider: (json['provider'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      name: json['name'] as String?,
      isTest: json['is_test'] == true,
      isActive: json['is_active'] == true,
      ready: json['ready'] == true,
      state: (json['state'] as String?) ?? '',
      filled: filled is Map
          ? filled.map((k, v) => MapEntry(k.toString(), v == true))
          : const {},
      lastOkAt: json['last_ok_at'] as String?,
      lastError: json['last_error'] as String?,
    );
  }

  final int id;
  final String provider;
  final String title;
  final String? name;
  final bool isTest;
  final bool isActive;

  /// Все обязательные ключи заполнены.
  final bool ready;

  /// Готовая строка состояния с сервера: выключено, не хватает ключей,
  /// служба ответила ошибкой, не проверено, работает.
  final String state;

  /// Какие ключи уже сохранены. Сами значения сервер не отдаёт никогда.
  final Map<String, bool> filled;

  final String? lastOkAt;
  final String? lastError;
}

class DeliveryConnectionsService {
  static const String _path = '/me/delivery-connections';

  /// Службы, которые мы умеем. Приходят вместе со списком подключений.
  static List<DeliveryProviderInfo> providers = const [];

  static Future<List<DeliveryConnection>> all() async {
    final response = await ApiService.get(_path);

    final meta = response['meta'];

    if (meta is Map && meta['providers'] is List) {
      providers = (meta['providers'] as List)
          .whereType<Map<String, dynamic>>()
          .map(DeliveryProviderInfo.fromJson)
          .toList();
    }

    final data = response['data'];

    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(DeliveryConnection.fromJson)
        .toList();
  }

  /// Подключить службу или переписать ключи.
  ///
  /// Пустые поля не отправляем: сервер дописывает ключи поверх прежних, и
  /// пустая строка стёрла бы сохранённый секрет.
  static Future<String?> save({
    required String provider,
    required Map<String, String> credentials,
    bool isTest = false,
    String? name,
  }) async {
    try {
      final body = <String, dynamic>{
        'provider': provider,
        'is_test': isTest,
        'credentials': Map<String, String>.fromEntries(
          credentials.entries.where((e) => e.value.trim().isNotEmpty),
        ),
      };

      if (name != null && name.trim().isNotEmpty) {
        body['name'] = name.trim();
      }

      final response = await ApiService.post(_path, body);

      return response['success'] == true ? null : _message(response);
    } catch (e) {
      log.w('DeliveryConnectionsService.save: $e');

      return 'Не удалось сохранить, попробуйте ещё раз';
    }
  }

  /// Проверить связь со службой. Пусто означает, что всё хорошо.
  static Future<String?> check(int id) async {
    try {
      final response = await ApiService.post('$_path/$id/check', {});

      return response['success'] == true ? null : _message(response);
    } catch (e) {
      log.w('DeliveryConnectionsService.check: $e');

      return 'Служба не ответила, попробуйте ещё раз';
    }
  }

  static Future<String?> toggle(int id) async {
    try {
      final response = await ApiService.post('$_path/$id/toggle', {});

      return response['success'] == true ? null : _message(response);
    } catch (e) {
      log.w('DeliveryConnectionsService.toggle: $e');

      return 'Не удалось переключить';
    }
  }

  static Future<String?> remove(int id) async {
    try {
      final response = await ApiService.delete('$_path/$id');

      return response['success'] == true ? null : _message(response);
    } catch (e) {
      log.w('DeliveryConnectionsService.remove: $e');

      return 'Не удалось отключить';
    }
  }

  static String _message(Map<String, dynamic> response) {
    final message = response['message'];

    return message is String && message.trim().isNotEmpty
        ? message
        : 'Что-то пошло не так';
  }
}

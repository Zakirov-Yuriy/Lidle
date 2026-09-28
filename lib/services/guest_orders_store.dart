import 'dart:convert';

import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

/// Заказы, оформленные без учётной записи (28.09.2026).
///
/// ЗАЧЕМ. Гость оформляет заказ, получает код получения и… больше нигде его не
/// видит: список покупок есть только у вошедшего, а сервер опознаёт покупателя
/// по учётной записи. Человек не может ни вспомнить код, ни узнать, принял ли
/// продавец заказ. Со стороны это выглядит так, будто заказ пропал.
///
/// Поэтому оформленные заказы приложение помнит у себя на телефоне, а их
/// состояние обновляет с сервера по номеру и коду получения
/// (`GET /orders/guest/{number}?code=...`).
///
/// Границы решения, о них честно сказано и на экране: это память ОДНОГО
/// телефона. На другом устройстве и после переустановки заказов не будет.
/// Настоящее место для покупок — учётная запись: при регистрации на ту же
/// почту гостевые заказы привязываются к ней сами.
///
/// Хранение в `settingsBox`, а не в пользовательском: гостевые заказы не
/// принадлежат никакому входу.
class GuestOrdersStore {
  const GuestOrdersStore._();

  static const String _key = 'guest_orders';

  /// Сколько заказов помним. Больше полусотни на одном телефоне это уже не
  /// история покупок, а балласт: самые старые вытесняются.
  static const int _limit = 50;

  /// Всё, что помним, самые свежие первыми.
  static List<OrderModel> all() {
    final orders = <OrderModel>[];

    for (final row in _raw()) {
      try {
        orders.add(OrderModel.fromJson(row));
      } catch (e) {
        // Одна битая запись не должна прятать остальные.
        log.d('Гостевой заказ не разобрался: $e');
      }
    }

    return orders;
  }

  static bool get hasAny => _raw().isNotEmpty;

  /// Запомнить только что оформленные заказы.
  ///
  /// [raw] — те самые объекты заказов, что прислал сервер: храним их как
  /// есть, чтобы не заводить второй, свой формат заказа, который однажды
  /// разойдётся с настоящим.
  static Future<void> remember(List<Map<String, dynamic>> raw) async {
    if (raw.isEmpty) return;

    final stored = _raw();

    // Свои заказы кладём в начало, а прежние записи с теми же номерами
    // убираем: повторное оформление того же номера должно заменить старое.
    final numbers = raw.map((row) => '${row['number'] ?? ''}').toSet();

    stored.removeWhere((row) => numbers.contains('${row['number'] ?? ''}'));

    final next = [...raw, ...stored];

    await _write(next.length > _limit ? next.sublist(0, _limit) : next);
  }

  /// Спросить сервер о состоянии каждого запомненного заказа.
  ///
  /// Обновляем по месту: заказ мог быть принят, собран или отменён, и человеку
  /// важно видеть это, а не свою запись недельной давности.
  ///
  /// Заказ, которого сервер больше не отдаёт, из памяти НЕ выбрасываем: это
  /// чаще всего значит, что человек зарегистрировался и заказ стал его. Тогда
  /// он виден в «Покупках» обычным путём, а наша запись просто перестаёт
  /// обновляться.
  static Future<List<OrderModel>> refresh() async {
    final stored = _raw();

    if (stored.isEmpty) return const [];

    final updated = <Map<String, dynamic>>[];

    for (final row in stored) {
      final number = '${row['number'] ?? ''}'.trim();
      final code = '${row['pickup_code'] ?? ''}'.trim();

      if (number.isEmpty || code.isEmpty) {
        updated.add(row);

        continue;
      }

      final fresh = await _fetch(number, code);

      updated.add(fresh ?? row);
    }

    await _write(updated);

    return all();
  }

  /// Забыть заказ (человек убрал его из списка).
  static Future<void> forget(String number) async {
    final stored = _raw()
      ..removeWhere((row) => '${row['number'] ?? ''}' == number);

    await _write(stored);
  }

  /// Забыть всё. Зовётся после регистрации: заказы уехали в учётную запись.
  static Future<void> clear() async {
    await HiveService.saveSetting(_key, '[]');
  }

  /// Один заказ с сервера. null — не ответил или уже не отдаёт.
  static Future<Map<String, dynamic>?> _fetch(String number, String code) async {
    try {
      final response = await ApiService.getWithQuery(
        '/orders/guest/$number',
        {'code': code},
      );

      final data = response['data'];

      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      log.d('Гостевой заказ $number не обновился: $e');

      return null;
    }
  }

  /// Хранится строкой JSON: Hive умеет списки и карты, но вложенные карты
  /// возвращает как `Map<dynamic, dynamic>`, и каждый разбор пришлось бы
  /// приводить к типам вручную.
  static List<Map<String, dynamic>> _raw() {
    final stored = HiveService.getSetting(_key, defaultValue: '');

    if (stored is! String || stored.isEmpty) return [];

    try {
      final decoded = jsonDecode(stored);

      if (decoded is! List) return [];

      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e) {
      log.d('Список гостевых заказов не прочитался: $e');

      return [];
    }
  }

  static Future<void> _write(List<Map<String, dynamic>> rows) async {
    try {
      await HiveService.saveSetting(_key, jsonEncode(rows));
    } catch (e) {
      log.d('Список гостевых заказов не сохранился: $e');
    }
  }
}

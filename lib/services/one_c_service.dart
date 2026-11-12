// Обмен с 1С: кабинет компании (задача 54, 10.11.2026).
//
// Компания подключает обмен сама и сама видит, что происходит: когда последний
// раз приезжал каталог, когда цены, что сломалось. Раньше ключ выдавала наша
// команда на сервере, и это годилось только для проверки.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Состояние обмена для одной точки продаж.
class OneCState {
  const OneCState({
    required this.shopId,
    required this.shopName,
    required this.connected,
    required this.isActive,
    required this.name,
    required this.pingUrl,
    required this.catalogUrl,
    required this.pricesUrl,
    required this.processorUrl,
    required this.processorReady,
    required this.docsUrl,
    required this.docsReady,
    required this.catalogLastAt,
    required this.catalogItems,
    required this.pricesLastAt,
    required this.pricesItems,
    required this.lastError,
    required this.productsCount,
    required this.hiddenByBilling,
    required this.billingEnabled,
    required this.paid,
    required this.firstTime,
    required this.feeConnection,
    required this.feeProducts,
    required this.feeMonthly,
    required this.feeTotal,
    required this.subscriptionStatus,
    required this.endsAt,
  });

  final int shopId;
  final String shopName;

  final bool connected;
  final bool isActive;
  final String name;

  /// Адреса целиком, с ключом внутри: их вставляют в настройки обмена.
  final String pingUrl;
  final String catalogUrl;
  final String pricesUrl;

  /// Готовый файл обработки для 1С.
  ///
  /// `processorReady` отличает «файла пока нет» от «ссылка не приехала». Пока
  /// он false, кнопку не рисуем вовсе: ведущая в никуда кнопка хуже, чем её
  /// отсутствие.
  final String processorUrl;
  final bool processorReady;

  /// Инструкция для программиста компании, файлом.
  ///
  /// Лежит рядом с адресами, под той же раскрывашкой: кому нужны адреса, тому
  /// нужна и она. Своей выгрузке мало ключа, нужны ещё названия полей, формат
  /// и признак полной выгрузки.
  final String docsUrl;
  final bool docsReady;

  /// Состояние каналов ПОРОЗНЬ: каталог ходит раз в сутки, цены каждые
  /// четверть часа, и общее «последний обмен» врало бы про оба.
  final String catalogLastAt;
  final int catalogItems;
  final String pricesLastAt;
  final int pricesItems;

  final String lastError;

  final int productsCount;
  final int hiddenByBilling;

  final bool billingEnabled;
  final bool paid;
  final bool firstTime;
  final double feeConnection;
  final double feeProducts;
  final double feeMonthly;
  final double feeTotal;
  final String subscriptionStatus;
  final String endsAt;

  /// Имя сервера без схемы и пути: ровно то, что вставляют в поле «Сервер»
  /// готовой обработки.
  ///
  /// Берём его ИЗ АДРЕСА, который уже пришёл с сервера, а не из настроек
  /// сборки. Так в приложении, собранном на дев, покажется дев, а на проде
  /// прод, и расходиться им негде.
  String get serverHost {
    final uri = Uri.tryParse(pingUrl);

    return uri == null ? '' : uri.host;
  }

  /// Ключ обмена, вынутый из адреса `/v1/1c/{ключ}/ping`.
  ///
  /// Отдельным полем сервер его не отдаёт, и заводить это поле ради экрана
  /// незачем: ключ и так стоит в каждом адресе.
  String get token {
    final uri = Uri.tryParse(pingUrl);

    if (uri == null) return '';

    final parts = uri.pathSegments;
    final at = parts.indexOf('1c');

    return (at >= 0 && at + 1 < parts.length) ? parts[at + 1] : '';
  }

  static OneCState fromJson(Map<String, dynamic> data) {
    final shop = (data['shop'] as Map?) ?? const {};
    final urls = (data['urls'] as Map?) ?? const {};
    final catalog = (data['catalog'] as Map?) ?? const {};
    final prices = (data['prices'] as Map?) ?? const {};
    final billing = (data['billing'] as Map?) ?? const {};
    final processor = (data['processor'] as Map?) ?? const {};
    final docs = (data['docs'] as Map?) ?? const {};

    return OneCState(
      shopId: _int(shop['id']),
      shopName: '${shop['name'] ?? ''}',
      connected: data['connected'] == true,
      isActive: data['is_active'] == true,
      name: '${data['name'] ?? ''}',
      pingUrl: '${urls['ping'] ?? ''}',
      catalogUrl: '${urls['catalog'] ?? ''}',
      pricesUrl: '${urls['prices'] ?? ''}',
      processorUrl: '${processor['url'] ?? ''}',
      processorReady: processor['ready'] == true,
      docsUrl: '${docs['url'] ?? ''}',
      docsReady: docs['ready'] == true,
      catalogLastAt: '${catalog['last_at'] ?? ''}',
      catalogItems: _int(catalog['items']),
      pricesLastAt: '${prices['last_at'] ?? ''}',
      pricesItems: _int(prices['items']),
      lastError: '${data['last_error'] ?? ''}',
      productsCount: _int(data['products_count']),
      hiddenByBilling: _int(data['hidden_by_billing']),
      billingEnabled: billing['enabled'] == true,
      paid: billing['paid'] == true,
      firstTime: billing['first_time'] == true,
      feeConnection: _double(billing['connection']),
      feeProducts: _double(billing['products']),
      feeMonthly: _double(billing['monthly']),
      feeTotal: _double(billing['total']),
      subscriptionStatus: '${billing['status'] ?? ''}',
      endsAt: '${billing['ends_at'] ?? ''}',
    );
  }

  static int _int(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class OneCService {
  static const _path = '/me/one-c';

  static Future<OneCState?> state() async {
    try {
      final response = await ApiService.get(_path);
      final data = response['data'];

      return data is Map<String, dynamic> ? OneCState.fromJson(data) : null;
    } catch (e) {
      log.d('Состояние обмена с 1С не загрузилось: $e');

      return null;
    }
  }

  /// Подключить обмен и получить ключ.
  static Future<Map<String, dynamic>> connect() async {
    return await ApiService.post(_path, {});
  }

  /// Включить или выключить обмен.
  static Future<Map<String, dynamic>> setActive(bool active) async {
    return await ApiService.put(_path, {'is_active': active});
  }

  /// Новый ключ взамен прежнего.
  static Future<Map<String, dynamic>> newKey() async {
    return await ApiService.post('$_path/key', {});
  }

  /// Отключить обмен. Товары остаются на витрине.
  static Future<Map<String, dynamic>> disconnect() async {
    return await ApiService.delete(_path);
  }
}

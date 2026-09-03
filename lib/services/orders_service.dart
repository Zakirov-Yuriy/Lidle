import 'package:lidle/core/logger.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/services/api_service.dart';

/// Заказы: оформление и жизнь заказа у обеих сторон.
///
/// Оплаты здесь нет и не будет в этой версии: деньги идут напрямую продавцу,
/// мы их не проводим. Поэтому оформление заканчивается кодом получения, а не
/// платежом.
class OrdersService {
  /// Оформить корзину.
  ///
  /// Работает и без входа. Гостю имя, телефон и почта обязательны: без них его
  /// нечем найти и некуда прислать код.
  ///
  /// Возвращает НЕСКОЛЬКО заказов, если в корзине были товары разных точек:
  /// каждая точка выдаёт своё и по своему коду.
  static Future<CheckoutResult> place({
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? comment,
    List<int>? shopIds,
  }) async {
    final body = <String, dynamic>{};

    if (contactName != null && contactName.isNotEmpty) {
      body['contact_name'] = contactName;
    }
    if (contactPhone != null && contactPhone.isNotEmpty) {
      body['contact_phone'] = contactPhone;
    }
    if (contactEmail != null && contactEmail.isNotEmpty) {
      body['contact_email'] = contactEmail;
    }
    if (comment != null && comment.isNotEmpty) body['comment'] = comment;
    if (shopIds != null && shopIds.isNotEmpty) body['shop_ids'] = shopIds;

    try {
      final response = await ApiService.post('/orders', body);

      if (response['success'] != true) {
        // Текст ответа написан для показа человеку: «товар разобрали, пока вы
        // оформляли». Придумывать свой нельзя, он будет менее точным.
        return CheckoutResult.failure(
          '${response['message'] ?? 'Не получилось оформить заказ'}',
        );
      }

      final data = response['data'];

      return CheckoutResult.success(
        data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(OrderModel.fromJson)
                  .toList()
            : const [],
        message: response['message']?.toString(),
      );
    } catch (e) {
      log.d('Ошибка оформления заказа: $e');

      return CheckoutResult.failure('Не получилось связаться с сервером');
    }
  }

  /// Мои покупки. По умолчанию живые: разбирают обычно то, что ещё не
  /// закончилось. За прошлым идём с `all: true`.
  static Future<List<OrderModel>> myOrders({String? status, bool all = false}) =>
      _list('/me/orders', status: status, all: all);

  /// Заказы в моих точках, для продавца.
  static Future<List<OrderModel>> incoming({String? status, bool all = false}) =>
      _list('/me/orders/incoming', status: status, all: all);

  static Future<OrderModel?> details(int orderId) async {
    try {
      final response = await ApiService.get('/me/orders/$orderId');
      final data = response['data'];

      if (data is Map<String, dynamic>) return OrderModel.fromJson(data);

      return null;
    } catch (e) {
      log.d('Не удалось загрузить заказ $orderId: $e');

      return null;
    }
  }

  static Future<OrderActionResult> accept(int orderId) =>
      _action('/me/orders/$orderId/accept', {});

  static Future<OrderActionResult> ready(int orderId) =>
      _action('/me/orders/$orderId/ready', {});

  /// Выдать заказ. Код стоит присылать: это единственное место, где сверка
  /// кода что-то проверяет. Без него продавец отмечает выдачу на свой страх.
  static Future<OrderActionResult> complete(int orderId, {String? pickupCode}) =>
      _action('/me/orders/$orderId/complete', {
        if (pickupCode != null && pickupCode.isNotEmpty) 'pickup_code': pickupCode,
      });

  /// Отменить. Товар вернётся на остаток: заказ его занимал.
  static Future<OrderActionResult> cancel(int orderId, {String? reason}) =>
      _action('/me/orders/$orderId/cancel', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  static Future<List<OrderModel>> _list(
    String path, {
    String? status,
    bool all = false,
  }) async {
    final query = <String>[];

    if (status != null && status.isNotEmpty) query.add('status=$status');
    if (all) query.add('scope=all');

    final url = query.isEmpty ? path : '$path?${query.join('&')}';

    try {
      final response = await ApiService.get(url);
      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } catch (e) {
      log.d('Не удалось загрузить заказы ($path): $e');

      return const [];
    }
  }

  static Future<OrderActionResult> _action(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await ApiService.post(path, body);

      if (response['success'] != true) {
        return OrderActionResult(
          isOk: false,
          message: '${response['message'] ?? 'Не получилось'}',
        );
      }

      final data = response['data'];

      return OrderActionResult(
        isOk: true,
        message: '${response['message'] ?? ''}',
        order: data is Map<String, dynamic> ? OrderModel.fromJson(data) : null,
      );
    } catch (e) {
      log.d('Ошибка действия с заказом: $e');

      return const OrderActionResult(
        isOk: false,
        message: 'Не получилось связаться с сервером',
      );
    }
  }
}

class CheckoutResult {
  final bool isOk;
  final List<OrderModel> orders;
  final String? message;
  final String? error;

  const CheckoutResult._({
    required this.isOk,
    this.orders = const [],
    this.message,
    this.error,
  });

  factory CheckoutResult.success(List<OrderModel> orders, {String? message}) =>
      CheckoutResult._(isOk: true, orders: orders, message: message);

  factory CheckoutResult.failure(String error) =>
      CheckoutResult._(isOk: false, error: error);
}

class OrderActionResult {
  final bool isOk;
  final String message;
  final OrderModel? order;

  const OrderActionResult({
    required this.isOk,
    required this.message,
    this.order,
  });
}

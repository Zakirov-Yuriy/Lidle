import 'package:lidle/core/logger.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/models/orders/order_payment.dart';
import 'package:lidle/services/api_service.dart';

/// Заказы: оформление и жизнь заказа у обеих сторон.
///
/// Оплаты здесь нет и не будет в этой версии: деньги идут напрямую продавцу,
/// мы их не проводим. Поэтому оформление заканчивается кодом получения, а не
/// платежом.
class OrdersService {
  /// Отправить гостю код подтверждения почты (21.09.2026).
  ///
  /// Возвращает, через сколько секунд можно просить новый код: сервер
  /// отвечает так и тогда, когда письмо не отправлял, потому что прошлое ушло
  /// меньше минуты назад. Экран просто показывает этот таймер.
  static Future<GuestCodeResult> sendGuestCode(String email) async {
    try {
      final response = await ApiService.post(
        '/orders/guest-code',
        {'email': email.trim()},
      );

      if (response['success'] != true) {
        return GuestCodeResult.failure(
          '${response['message'] ?? 'Не получилось отправить код'}',
        );
      }

      final wait = response['resend_in'];

      return GuestCodeResult.sent(
        wait is num ? wait.toInt() : int.tryParse('$wait') ?? 60,
      );
    } catch (e) {
      return GuestCodeResult.failure(
        _serverText(e) ?? 'Не получилось отправить код. Проверьте почту и связь.',
      );
    }
  }

  /// Проверить код из письма. Верный — токен для оформления.
  static Future<GuestCodeResult> verifyGuestCode(
    String email,
    String code,
  ) async {
    try {
      final response = await ApiService.post(
        '/orders/guest-code/verify',
        {'email': email.trim(), 'code': code.trim()},
      );

      final token = response['token'];

      if (response['success'] == true && token is String && token.isNotEmpty) {
        return GuestCodeResult.verified(token);
      }

      return GuestCodeResult.failure(
        '${response['message'] ?? 'Код не подошёл'}',
      );
    } catch (e) {
      return GuestCodeResult.failure(
        _serverText(e) ??
            'Код не подошёл. Проверьте письмо или запросите новый код.',
      );
    }
  }

  /// Текст ошибки сервера из исключения ApiService, если он там есть.
  static String? _serverText(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();

    if (text.isEmpty || text.contains('Exception') || text.length > 200) {
      return null;
    }

    return text;
  }

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

    /// Номера товаров, отмеченных галочками в корзине (14.09.2026).
    ///
    /// Пусто — заказывается вся корзина. Список — только отмеченное,
    /// остальное остаётся лежать.
    List<int>? productIds,
    bool paymentAcknowledged = false,

    /// Чем покупатель платит, по способу на точку: номер точки — ключ
    /// способа (15.09.2026). Точек в заказе бывает несколько, и принимают
    /// они разное, поэтому выбор именно по точкам, а не один на весь заказ.
    Map<int, String>? paymentMethods,

    /// Как получать заказ, по каждой точке (16.09.2026). Цену доставки сюда
    /// НЕ кладём: её подставляет сервер по номеру способа, и присланной он не
    /// верит. Иначе цену доставки можно было бы назначить себе самому.
    Map<int, OrderDeliveryChoice>? deliveries,

    /// Токен подтверждённой почты гостя (21.09.2026), из [verifyGuestCode].
    String? emailToken,

    /// `individual` или `company`; у компании название и ИНН (21.09.2026).
    String buyerType = 'individual',
    String? companyName,
    String? companyInn,

    /// Онлайн-оплата (22.09.2026): какой способ YooKassa открыть сразу
    /// (`bank_card`, `sberbank`, `tinkoff_bank`, `sbp`). Пусто — человек
    /// выбирает на странице оплаты сам.
    String? paymentChannel,
  }) async {
    final body = <String, dynamic>{
      // Приложение умеет платить формой карты SDK YooKassa (22.09.2026):
      // сервер только заводит платёж, а в YooKassa он уходит с токеном.
      'payment_sdk': true,
    };

    if (paymentChannel != null && paymentChannel.isNotEmpty) {
      body['payment_channel'] = paymentChannel;
    }

    if (emailToken != null && emailToken.isNotEmpty) {
      body['email_token'] = emailToken;
    }

    body['buyer_type'] = buyerType;

    if (buyerType == 'company') {
      body['company_name'] = companyName ?? '';
      body['company_inn'] = companyInn ?? '';
    }

    // Подтверждение, что человек понял, кому и куда платит. Сервер требует
    // его обязательно: деньги идут продавцу напрямую, мимо площадки, и
    // вернуть их мы не сможем. Без галочки оформление отвечает 422 с
    // понятным текстом, его и показываем.
    body['payment_acknowledged'] = paymentAcknowledged;

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
    if (productIds != null && productIds.isNotEmpty) {
      body['product_ids'] = productIds;
    }

    // Ключи отправляем строками: номер точки в JSON-объекте всё равно станет
    // строкой, и лучше сделать это здесь, чем полагаться на кодировщик.
    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      body['payment_methods'] = paymentMethods.map(
        (shopId, method) => MapEntry('$shopId', method),
      );
    }

    if (deliveries != null && deliveries.isNotEmpty) {
      body['deliveries'] = deliveries.map(
        (shopId, choice) => MapEntry('$shopId', choice.toJson()),
      );
    }

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
        payment: response['payment'] is Map<String, dynamic>
            ? OrderPaymentInfo.fromJson(response['payment'])
            : null,
      );
    } catch (e) {
      log.d('Ошибка оформления заказа: $e');

      return CheckoutResult.failure('Не получилось связаться с сервером');
    }
  }

  // ── Онлайн-оплата заказа (22.09.2026) ─────────────────────────────

  /// Чем кончилась оплата. Сервер сам переспрашивает YooKassa, если исход
  /// ещё не известен. null — не удалось связаться.
  static Future<OrderPaymentInfo?> paymentStatus(String token) async {
    try {
      final response = await ApiService.get('/orders/payments/$token');
      final data = response['data'];

      return data is Map<String, dynamic>
          ? OrderPaymentInfo.fromJson(data)
          : null;
    } catch (e) {
      log.d('Ошибка статуса оплаты: $e');

      return null;
    }
  }

  /// Заплатить ещё раз: другой картой ([cardId]) или другим способом
  /// YooKassa ([channel]). Возвращает НОВЫЙ платёж со своей ссылкой.
  static Future<PaymentActionResult> retryPayment(
    String token, {
    String? channel,
    int? cardId,
  }) async {
    try {
      final response = await ApiService.post('/orders/payments/$token/retry', {
        if (channel != null) 'channel': channel,
        if (cardId != null) 'card_id': cardId,
      });

      final data = response['data'];

      return PaymentActionResult(
        isOk: response['success'] == true,
        message: response['message']?.toString(),
        payment: data is Map<String, dynamic>
            ? OrderPaymentInfo.fromJson(data)
            : null,
      );
    } catch (e) {
      return PaymentActionResult(
        isOk: false,
        message: _serverText(e) ?? 'Не получилось связаться с сервером',
      );
    }
  }

  /// Заплатить токеном из формы SDK YooKassa. Отказ банка приходит в
  /// ответе сразу: `status = canceled` и причина.
  static Future<OrderPaymentInfo?> chargePayment(
    String token, {
    required String paymentToken,
    required String methodType,
    bool save = false,
  }) async {
    try {
      final response = await ApiService.post('/orders/payments/$token/charge', {
        'payment_token': paymentToken,
        'method_type': methodType,
        'save': save,
      });

      final data = response['data'];

      return data is Map<String, dynamic>
          ? OrderPaymentInfo.fromJson(data)
          : null;
    } catch (e) {
      log.d('Ошибка оплаты токеном: $e');

      return null;
    }
  }

  /// Перейти на оплату наличными при получении.
  static Future<PaymentActionResult> payInCash(String token) async {
    try {
      final response = await ApiService.post(
        '/orders/payments/$token/cash',
        const {},
      );

      final data = response['data'];

      return PaymentActionResult(
        isOk: response['success'] == true,
        message: response['message']?.toString(),
        orders: data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(OrderModel.fromJson)
                  .toList()
            : const [],
      );
    } catch (e) {
      return PaymentActionResult(
        isOk: false,
        message: _serverText(e) ?? 'Не получилось связаться с сервером',
      );
    }
  }

  /// Отменить неоплаченный заказ.
  static Future<PaymentActionResult> cancelUnpaid(String token) async {
    try {
      final response = await ApiService.post(
        '/orders/payments/$token/cancel',
        const {},
      );

      return PaymentActionResult(
        isOk: response['success'] == true,
        message: response['message']?.toString(),
      );
    } catch (e) {
      return PaymentActionResult(
        isOk: false,
        message: _serverText(e) ?? 'Не получилось связаться с сервером',
      );
    }
  }

  /// Мои покупки. По умолчанию живые: разбирают обычно то, что ещё не
  /// закончилось. За прошлым идём с `all: true`.
  static Future<List<OrderModel>> myOrders({String? status, bool all = false}) =>
      _list('/me/orders', status: status, all: all);

  /// Заказы в моих точках, для продавца.
  ///
  /// `tab` это вкладка экрана продавца: `new`, `in_work`, `done`, `rejected`.
  /// Вкладка важнее отбора по одному статусу: на «Исполняемых» лежат сразу
  /// два статуса, а на «Отклонённых» отмены обеих сторон (16.09.2026).
  static Future<List<OrderModel>> incoming({
    String? status,
    bool all = false,
    String? tab,
    int? year,
    int? month,
  }) => _list(
    '/me/orders/incoming',
    status: status,
    all: all,
    tab: tab,
    year: year,
    month: month,
  );

  /// Сколько заказов на каждой вкладке. Отдельным запросом: числа нужны сразу
  /// на всех вкладках, а список приходит по одной.
  static Future<OrderCounts> counts() async {
    try {
      final response = await ApiService.get('/me/orders/counts');
      final data = response['data'];

      if (data is Map<String, dynamic>) return OrderCounts.fromJson(data);

      return const OrderCounts();
    } catch (e) {
      log.d('Не удалось загрузить счётчики заказов: $e');

      return const OrderCounts();
    }
  }

  /// Курьеры продавца: сотрудники его публикаций с должностью курьера.
  static Future<List<CourierBrief>> couriers() async {
    try {
      final response = await ApiService.get('/me/couriers');
      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(CourierBrief.fromJson)
          .toList();
    } catch (e) {
      log.d('Не удалось загрузить курьеров: $e');

      return const [];
    }
  }

  /// Принять ОДИН товар из заказа (16.09.2026).
  ///
  /// Продавец решает по каждому отдельно: одного товара может не оказаться, а
  /// остальное он соберёт.
  static Future<OrderActionResult> acceptItem(int orderId, int itemId) =>
      _action('/me/orders/$orderId/items/$itemId/accept', {});

  /// Отклонить ОДИН товар. Он вернётся в продажу и уйдёт из суммы заказа.
  /// Когда отклонили всё, заказ отменяется целиком.
  static Future<OrderActionResult> rejectItem(
    int orderId,
    int itemId, {
    String? reason,
  }) =>
      _action('/me/orders/$orderId/items/$itemId/reject', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  /// Назначить курьера на заказ. Пустой номер снимает назначение.
  static Future<OrderActionResult> assignCourier(int orderId, int? staffId) =>
      _action('/me/orders/$orderId/courier', {'staff_id': staffId});

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

  /// Оценить курьера по своему заказу (18.09.2026).
  ///
  /// Оценивает покупатель и только после получения заказа: оценивают
  /// доставку, а пока её не было, оценивать нечего. Проверяет это сервер, а
  /// экран прячет кнопку по признаку `can_review`.
  ///
  /// Возвращает `null` при успехе, иначе текст ошибки с сервера: он объясняет
  /// причину точнее, чем общее «не получилось».
  static Future<String?> reviewCourier(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    try {
      final response = await ApiService.post(
        '/me/orders/$orderId/courier/review',
        {
          'rating': rating,
          if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        },
      );

      if (response['success'] == true) return null;

      return '${response['message'] ?? 'Не получилось сохранить оценку'}';
    } catch (e) {
      log.d('Оценка курьера не сохранилась: $e');

      return 'Не получилось связаться с сервером';
    }
  }

  /// Отменить. Товар вернётся на остаток: заказ его занимал.
  static Future<OrderActionResult> cancel(int orderId, {String? reason}) =>
      _action('/me/orders/$orderId/cancel', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  static Future<List<OrderModel>> _list(
    String path, {
    String? status,
    bool all = false,
    String? tab,
    int? year,
    int? month,
  }) async {
    final query = <String>[];

    if (status != null && status.isNotEmpty) query.add('status=$status');
    if (all) query.add('scope=all');
    if (tab != null && tab.isNotEmpty) query.add('tab=$tab');
    if (year != null) query.add('year=$year');
    if (month != null) query.add('month=$month');

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

  /// Онлайн-платёж, если хотя бы один заказ оплачивается онлайн.
  final OrderPaymentInfo? payment;

  const CheckoutResult._({
    required this.isOk,
    this.orders = const [],
    this.message,
    this.error,
    this.payment,
  });

  factory CheckoutResult.success(
    List<OrderModel> orders, {
    String? message,
    OrderPaymentInfo? payment,
  }) => CheckoutResult._(
    isOk: true,
    orders: orders,
    message: message,
    payment: payment,
  );

  factory CheckoutResult.failure(String error) =>
      CheckoutResult._(isOk: false, error: error);
}

class PaymentActionResult {
  final bool isOk;
  final String? message;
  final OrderPaymentInfo? payment;
  final List<OrderModel> orders;

  const PaymentActionResult({
    required this.isOk,
    this.message,
    this.payment,
    this.orders = const [],
  });
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


/// Выбор способа получения по одной точке (16.09.2026).
///
/// Цены здесь нет намеренно: её подставляет сервер по номеру способа.
class OrderDeliveryChoice {
  final String type;
  final int? optionId;
  final String? address;
  final String? comment;

  const OrderDeliveryChoice.pickup()
      : type = 'pickup',
        optionId = null,
        address = null,
        comment = null;

  const OrderDeliveryChoice.courier({
    required this.optionId,
    required this.address,
    this.comment,
  }) : type = 'courier';

  bool get isCourier => type == 'courier';

  Map<String, dynamic> toJson() => {
        'type': type,
        if (optionId != null) 'option_id': optionId,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };
}

/// Числа на вкладках экрана заказов продавца.
class OrderCounts {
  final int newOrders;
  final int inWork;
  final int done;
  final int rejected;

  const OrderCounts({
    this.newOrders = 0,
    this.inWork = 0,
    this.done = 0,
    this.rejected = 0,
  });

  factory OrderCounts.fromJson(Map<String, dynamic> data) => OrderCounts(
        newOrders: _num(data['new']),
        inWork: _num(data['in_work']),
        done: _num(data['done']),
        rejected: _num(data['rejected']),
      );

  static int _num(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Курьер продавца. Учётной записи у него нет: это сотрудник из справочника,
/// в приложение он не входит.
class CourierBrief {
  final int id;
  final String name;
  final String? position;
  final String? image;

  const CourierBrief({
    required this.id,
    required this.name,
    this.position,
    this.image,
  });

  factory CourierBrief.fromJson(Map<String, dynamic> data) => CourierBrief(
        id: OrderCounts._num(data['id']),
        name: '${data['name'] ?? ''}',
        position: data['position']?.toString(),
        image: data['image']?.toString(),
      );
}

/// Итог работы с кодом подтверждения почты гостя (21.09.2026).
class GuestCodeResult {
  const GuestCodeResult._({this.resendIn, this.token, this.error});

  const GuestCodeResult.sent(int resendIn) : this._(resendIn: resendIn);

  const GuestCodeResult.verified(String token) : this._(token: token);

  const GuestCodeResult.failure(String error) : this._(error: error);

  /// Через сколько секунд можно просить новый код.
  final int? resendIn;

  /// Токен подтверждённой почты: уходит в оформление.
  final String? token;

  final String? error;

  bool get isOk => error == null;
}

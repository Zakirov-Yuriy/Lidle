/// Онлайн-оплата заказа через YooKassa (22.09.2026).
///
/// Приходит в ответе оформления (`payment`) и из
/// `GET /orders/payments/{token}`. По [token] приложение спрашивает исход и
/// платит повторно, в том числе у гостя без входа.
class OrderPaymentInfo {
  final String token;

  /// `pending`, `succeeded`, `canceled` или `failed` (YooKassa не ответила).
  final String status;
  final bool paid;
  final double amount;

  /// Ссылка на страницу оплаты. Есть только сразу после создания платежа.
  final String? confirmationUrl;

  /// Причина отказа YooKassa, например `insufficient_funds`, и готовые
  /// тексты для экрана «Заказ не оплачен».
  final String? reason;
  final String? reasonTitle;
  final String? reasonHint;

  final List<SavedPaymentCard> cards;

  /// Настройки формы оплаты в приложении (мобильный SDK YooKassa). null —
  /// на сервере SDK не настроен, платим через страницу оплаты.
  final OrderPaymentSdk? sdk;

  const OrderPaymentInfo({
    required this.token,
    required this.status,
    required this.paid,
    required this.amount,
    this.confirmationUrl,
    this.reason,
    this.reasonTitle,
    this.reasonHint,
    this.cards = const [],
    this.sdk,
  });

  bool get isPending => status == 'pending';
  bool get isFailed => status == 'canceled' || status == 'failed';

  factory OrderPaymentInfo.fromJson(Map<String, dynamic> json) {
    final url = json['confirmation_url']?.toString();
    final cards = json['cards'];
    final sdk = json['sdk'];

    return OrderPaymentInfo(
      token: '${json['token'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
      paid: json['paid'] == true,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      confirmationUrl: url == null || url.isEmpty ? null : url,
      reason: json['reason']?.toString(),
      reasonTitle: json['reason_title']?.toString(),
      reasonHint: json['reason_hint']?.toString(),
      cards: cards is List
          ? cards
                .whereType<Map<String, dynamic>>()
                .map(SavedPaymentCard.fromJson)
                .toList()
          : const [],
      sdk: sdk is Map<String, dynamic> ? OrderPaymentSdk.fromJson(sdk) : null,
    );
  }

  /// Тот же платёж с другой причиной для экрана «Заказ не оплачен».
  OrderPaymentInfo withReason(String title, String hint) => OrderPaymentInfo(
    token: token,
    status: status,
    paid: false,
    amount: amount,
    reason: 'unfinished',
    reasonTitle: title,
    reasonHint: hint,
    cards: cards,
    sdk: sdk,
  );
}

/// Что нужно форме оплаты SDK YooKassa. Ключ не секретный: он только
/// открывает форму и выдаёт одноразовый токен карты.
class OrderPaymentSdk {
  final String clientKey;
  final String shopId;
  final String title;
  final String subtitle;

  /// Сумма строкой, как её ждёт SDK: `2350.00`.
  final String amount;
  final bool canSave;
  final String? customerId;

  const OrderPaymentSdk({
    required this.clientKey,
    required this.shopId,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.canSave = false,
    this.customerId,
  });

  factory OrderPaymentSdk.fromJson(Map<String, dynamic> json) =>
      OrderPaymentSdk(
        clientKey: '${json['client_key'] ?? ''}',
        shopId: '${json['shop_id'] ?? ''}',
        title: '${json['title'] ?? 'LIDLE'}',
        subtitle: '${json['subtitle'] ?? ''}',
        amount: '${json['amount'] ?? '0'}',
        canSave: json['can_save'] == true,
        customerId: json['customer_id']?.toString(),
      );
}

/// Сохранённая карта. Номера нет, только последние цифры: `**5434 МИР`.
class SavedPaymentCard {
  final int id;
  final String title;
  final String? last4;
  final String? cardType;

  /// id способа оплаты в YooKassa: по нему SDK платит этой картой, спросив
  /// только CVC.
  final String? methodId;

  const SavedPaymentCard({
    required this.id,
    required this.title,
    this.last4,
    this.cardType,
    this.methodId,
  });

  factory SavedPaymentCard.fromJson(Map<String, dynamic> json) =>
      SavedPaymentCard(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: '${json['title'] ?? ''}',
        last4: json['last4']?.toString(),
        cardType: json['card_type']?.toString(),
        methodId: json['method_id']?.toString(),
      );
}

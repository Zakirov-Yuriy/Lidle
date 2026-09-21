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
  });

  bool get isPending => status == 'pending';
  bool get isFailed => status == 'canceled' || status == 'failed';

  factory OrderPaymentInfo.fromJson(Map<String, dynamic> json) {
    final url = json['confirmation_url']?.toString();
    final cards = json['cards'];

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
    );
  }
}

/// Сохранённая карта. Номера нет, только последние цифры: `**5434 МИР`.
class SavedPaymentCard {
  final int id;
  final String title;
  final String? last4;
  final String? cardType;

  const SavedPaymentCard({
    required this.id,
    required this.title,
    this.last4,
    this.cardType,
  });

  factory SavedPaymentCard.fromJson(Map<String, dynamic> json) =>
      SavedPaymentCard(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: '${json['title'] ?? ''}',
        last4: json['last4']?.toString(),
        cardType: json['card_type']?.toString(),
      );
}

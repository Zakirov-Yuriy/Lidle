import 'package:lidle/models/products/product_item.dart';

/// Заказ. Одна модель для покупателя и для продавца.
///
/// Так же, как у броней: заказ это один и тот же предмет разговора, и
/// расхождения между «моей покупкой» и «моим заказом» приводят к спорам на
/// ровном месте. Что показывать, решают экраны.
class OrderModel {
  final int id;
  final String number;

  /// `new`, `accepted`, `ready`, `completed`, `cancelled_by_buyer`,
  /// `cancelled_by_seller`.
  final String status;

  /// Подпись состояния приходит готовой: переводить на клиенте нельзя, иначе
  /// приложение и админка однажды назовут одно и то же по-разному.
  final String statusTitle;

  /// Код получения. Покупатель называет его в точке, продавец сверяет.
  final String? pickupCode;

  final String total;
  final int? cookingTimeMinutes;

  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? comment;
  final String? cancelReason;

  final ShopBrief? shop;
  final List<OrderLine> items;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;

  const OrderModel({
    required this.id,
    required this.number,
    required this.status,
    required this.statusTitle,
    required this.total,
    required this.items,
    this.pickupCode,
    this.cookingTimeMinutes,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.comment,
    this.cancelReason,
    this.shop,
    this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.pickedUpAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> data) {
    final items = data['items'];

    return OrderModel(
      id: _int(data['id']) ?? 0,
      number: '${data['number'] ?? ''}',
      status: '${data['status'] ?? ''}',
      statusTitle: '${data['status_title'] ?? ''}',
      pickupCode: data['pickup_code']?.toString(),
      total: '${data['total'] ?? '0'}',
      cookingTimeMinutes: _int(data['cooking_time_minutes']),
      contactName: data['contact_name']?.toString(),
      contactPhone: data['contact_phone']?.toString(),
      contactEmail: data['contact_email']?.toString(),
      comment: data['comment']?.toString(),
      cancelReason: data['cancel_reason']?.toString(),
      shop: ShopBrief.tryParse(data['shop']),
      items: items is List
          ? items.whereType<Map<String, dynamic>>().map(OrderLine.fromJson).toList()
          : const [],
      createdAt: _date(data['created_at']),
      acceptedAt: _date(data['accepted_at']),
      readyAt: _date(data['ready_at']),
      pickedUpAt: _date(data['picked_up_at']),
    );
  }

  /// Живой заказ: его ещё разбирают, он занимает товар.
  bool get isAlive =>
      status == 'new' || status == 'accepted' || status == 'ready';

  bool get isCancelled =>
      status == 'cancelled_by_buyer' || status == 'cancelled_by_seller';

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Дату разбираем без приведения к поясу устройства: сервер отдаёт момент
  /// со смещением, и `DateTime.parse` уводит его в UTC. Для подписи «когда
  /// заказали» этого достаточно, но для времени выдачи пришлось бы держать
  /// строку, как мы делаем в бронировании.
  static DateTime? _date(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse('$value');
  }
}

double? _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class OrderLine {
  final int? productId;
  final String name;
  final String? sku;
  final String price;
  final int quantity;
  final double sum;

  const OrderLine({
    required this.name,
    required this.price,
    required this.quantity,
    required this.sum,
    this.productId,
    this.sku,
  });

  factory OrderLine.fromJson(Map<String, dynamic> data) {
    return OrderLine(
      productId: OrderModel._int(data['product_id']),
      name: '${data['name'] ?? ''}',
      sku: data['sku']?.toString(),
      price: '${data['price'] ?? '0'}',
      quantity: OrderModel._int(data['quantity']) ?? 1,
      sum: _double(data['sum']) ?? 0,
    );
  }
}

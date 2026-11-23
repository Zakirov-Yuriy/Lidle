// Отправления продавца (задача 53, этап 5, 19.11.2026).
//
// ПОСЫЛКУ СОЗДАЁТ ТОТ, КТО ЕЁ ОТПРАВЛЯЕТ. Покупатель видит номер для
// отслеживания в своём заказе, но создать или напечатать ничего не может.
//
// ЧТО ПЕРЕДАЁМ СЛУЖБЕ, РЕШАЕТ ЗАКАЗ. Если покупатель при оформлении выбрал
// службу, тариф и пункт выдачи, всё это уже лежит в заказе, и продавцу
// остаётся нажать кнопку. Поэтому создание ничего не требует на входе.
//
// Ручки: /v1/me/orders/{id}/shipments, /v1/me/shipments/{id}/refresh и label.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Посылка в службе глазами продавца.
class Shipment {
  const Shipment({
    required this.id,
    required this.number,
    this.provider = '',
    this.trackingNumber,
    this.status = '',
    this.statusTitle = '',
    this.statusText,
    this.statusAt,
    this.pointCode,
    this.toAddress,
    this.price,
    this.lastError,
  });

  factory Shipment.fromJson(Map<String, dynamic> data) {
    return Shipment(
      id: data['id'] is int ? data['id'] as int : int.tryParse('${data['id']}') ?? 0,
      number: '${data['number'] ?? ''}',
      provider: '${data['provider'] ?? ''}',
      trackingNumber: data['tracking_number']?.toString(),
      status: '${data['status'] ?? ''}',
      statusTitle: '${data['status_title'] ?? ''}',
      statusText: data['status_text']?.toString(),
      statusAt: data['status_at'] == null
          ? null
          : DateTime.tryParse('${data['status_at']}'),
      pointCode: data['point_code']?.toString(),
      toAddress: data['to_address']?.toString(),
      price: data['price'] is num ? (data['price'] as num).toDouble() : null,
      lastError: data['last_error']?.toString(),
    );
  }

  final int id;
  final String number;
  final String provider;
  final String? trackingNumber;
  final String status;
  final String statusTitle;
  final String? statusText;
  final DateTime? statusAt;
  final String? pointCode;
  final String? toAddress;
  final double? price;

  /// Что служба ответила, когда отказала. Продавцу это видно, покупателю нет.
  final String? lastError;

  String get providerTitle => switch (provider) {
        'cdek' => 'СДЭК',
        'yandex' => 'Яндекс.Доставка',
        'ozon' => 'Озон',
        'dellin' => 'Деловые линии',
        _ => provider,
      };

  bool get failed => status == 'failed';
}

/// Ответ на попытку создать посылку: вышло или нет и что сказать человеку.
class ShipmentResult {
  const ShipmentResult({required this.ok, this.message, this.shipment});

  final bool ok;
  final String? message;
  final Shipment? shipment;
}

/// Ответ на запрос печатной формы: ссылка или причина отказа.
class LabelResult {
  const LabelResult({this.url, this.message});

  final String? url;
  final String? message;

  bool get ok => url != null;
}

class ShipmentsService {
  /// Посылки по заказу.
  static Future<List<Shipment>> forOrder(int orderId) async {
    try {
      final response = await ApiService.get('/me/orders/$orderId/shipments');

      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(Shipment.fromJson)
          .toList();
    } catch (e) {
      log.e('Посылки заказа не загрузились: $e');

      return const [];
    }
  }

  /// Передать посылку службе.
  ///
  /// Службу, тариф и пункт сервер берёт из заказа, если покупатель выбрал их
  /// при оформлении. Габариты можно уточнить: коробка известна продавцу, а
  /// не покупателю.
  static Future<ShipmentResult> create(
    int orderId, {
    int? weight,
    int? length,
    int? width,
    int? height,
  }) async {
    try {
      final response = await ApiService.post('/me/orders/$orderId/shipments', {
        if (weight != null) 'weight': weight,
        if (length != null) 'length': length,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      });

      final data = response['data'];

      return ShipmentResult(
        ok: response['success'] == true,
        message: response['message']?.toString(),
        shipment: data is Map<String, dynamic> ? Shipment.fromJson(data) : null,
      );
    } catch (e) {
      log.e('Посылка не создалась: $e');

      return const ShipmentResult(
        ok: false,
        message: 'Не удалось передать посылку службе. Попробуйте ещё раз.',
      );
    }
  }

  /// Спросить службу, что с посылкой.
  ///
  /// Кнопкой, а не только по расписанию: у СДЭК номер появляется через
  /// несколько секунд после создания, и человек хочет увидеть его сейчас.
  static Future<Shipment?> refresh(int shipmentId) async {
    try {
      final response = await ApiService.post('/me/shipments/$shipmentId/refresh', {});

      final data = response['data'];

      return data is Map<String, dynamic> ? Shipment.fromJson(data) : null;
    } catch (e) {
      log.e('Состояние посылки не обновилось: $e');

      return null;
    }
  }

  /// Ссылка на печатную форму.
  ///
  /// ДВА ВИДА. `waybill` это накладная или квитанция, бумага для водителя.
  /// `barcode` это наклейка на коробку.
  ///
  /// ВОЗВРАЩАЕМ И ПРИЧИНУ ОТКАЗА. Служба нередко отвечает не «нельзя», а
  /// «подождите, документ формируется», и человеку надо это прочитать, а
  /// не гадать над молчащей кнопкой.
  static Future<LabelResult> label(int shipmentId, {String kind = 'waybill'}) async {
    try {
      final response = await ApiService.get('/me/shipments/$shipmentId/label?kind=$kind');

      final data = response['data'];
      final url = data is Map ? data['url']?.toString() : null;

      return LabelResult(
        url: url == null || url.isEmpty ? null : url,
        message: response['message']?.toString(),
      );
    } catch (e) {
      log.e('Печатная форма не получена: $e');

      return const LabelResult(
        message: 'Не удалось получить документ. Попробуйте ещё раз.',
      );
    }
  }
}

import 'package:lidle/models/bookings/booking_availability.dart';

/// Одна бронь в списке.
///
/// Повторяет ответ сервера один в один, см. вики `back/api/booking-api.md`.
///
/// Правила «кто и до какого часа может отменить» здесь НЕ вычисляются.
/// Сервер присылает готовые флаги `can_confirm`, `can_reject`, `can_cancel`,
/// и это осознанно: те же правила действуют на сайте и в админке, и если
/// каждый посчитает их сам, однажды они разойдутся. Кнопки рисуем по флагам,
/// а последнее слово всё равно за сервером.
class BookingItem {
  final int id;
  final int advertId;
  final String status;
  final String statusTitle;

  /// Время по часам мастера, для показа.
  final DateTime? startsAt;
  final DateTime? endsAt;

  final int? guestsCount;
  final String? comment;
  final String? cancelReason;

  /// 'owner' — это заявка ко мне, 'guest' — моя бронь.
  final String? role;

  final BookingAdvertBrief? advert;
  final BookingParty? counterparty;

  final bool canConfirm;
  final bool canReject;
  final bool canCancel;

  const BookingItem({
    required this.id,
    required this.advertId,
    required this.status,
    required this.statusTitle,
    required this.startsAt,
    required this.endsAt,
    required this.guestsCount,
    required this.comment,
    required this.cancelReason,
    required this.role,
    required this.advert,
    required this.counterparty,
    required this.canConfirm,
    required this.canReject,
    required this.canCancel,
  });

  bool get isOwnerView => role == 'owner';
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  /// Живая ли бронь. От этого зависит цвет плашки состояния: отменённые и
  /// отклонённые не должны выглядеть так же, как предстоящие.
  bool get isActive => status == 'pending' || status == 'confirmed';

  static BookingItem? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = _asInt(raw['id']);
    if (id == null) return null;

    return BookingItem(
      id: id,
      advertId: _asInt(raw['advert_id']) ?? 0,
      status: '${raw['status'] ?? ''}',
      statusTitle: '${raw['status_title'] ?? ''}',
      startsAt: parseBookingWallClock(raw['starts_at']),
      endsAt: parseBookingWallClock(raw['ends_at']),
      guestsCount: _asInt(raw['guests_count']),
      comment: _asString(raw['comment']),
      cancelReason: _asString(raw['cancel_reason']),
      role: _asString(raw['role']),
      advert: BookingAdvertBrief.tryParse(raw['advert']),
      counterparty: BookingParty.tryParse(raw['counterparty']),
      canConfirm: raw['can_confirm'] == true,
      canReject: raw['can_reject'] == true,
      canCancel: raw['can_cancel'] == true,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}

/// Краткое объявление внутри брони: название, картинка, цена.
class BookingAdvertBrief {
  final int id;
  final String name;
  final String? thumbnail;
  final String? price;

  const BookingAdvertBrief({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.price,
  });

  static BookingAdvertBrief? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = BookingItem._asInt(raw['id']);
    if (id == null) return null;

    return BookingAdvertBrief(
      id: id,
      name: '${raw['name'] ?? 'Объявление $id'}',
      thumbnail: BookingItem._asString(raw['thumbnail']),
      price: BookingItem._asString(raw['price']),
    );
  }
}

/// Вторая сторона брони: гостю приходит владелец, владельцу гость.
class BookingParty {
  final int id;
  final String name;
  final String? phone;

  const BookingParty({
    required this.id,
    required this.name,
    required this.phone,
  });

  static BookingParty? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = BookingItem._asInt(raw['id']);
    if (id == null) return null;

    return BookingParty(
      id: id,
      name: '${raw['name'] ?? ''}'.trim(),
      phone: BookingItem._asString(raw['phone']),
    );
  }
}

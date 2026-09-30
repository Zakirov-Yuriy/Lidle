import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/bookings/preorder.dart';

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

  /// Где сидят: «Основной зал, столик на 2 места» или «Веранда, весь зал»
  /// (22.09.2026). Пусто у броней без зала.
  final String? place;
  final String? comment;
  final String? cancelReason;

  /// 'owner' — это заявка ко мне, 'guest' — моя бронь.
  final String? role;

  final BookingAdvertBrief? advert;
  final BookingParty? counterparty;

  final bool canConfirm;
  final bool canReject;
  final bool canCancel;

  /// Заказ навынос (30.09.2026): столика нет, человек заберёт сам.
  final bool isTakeaway;

  /// Что человек заказал к брони: блюда, товары, услуги, доставка.
  ///
  /// Владельцу это нужнее, чем гостю: по этому списку он готовит. Раньше
  /// сервер его отдавал, а приложение не читало, и в заявке был только
  /// столик.
  final List<PreorderLine> items;

  /// Счёт: предзаказ, депозит, услуга бронирования и итог.
  final PreorderTotals totals;

  /// Выбранное место: номер, вместимость, депозит, примечание заведения.
  final BookingSeat? seat;

  /// Чем платить заведению (30.09.2026): способы и реквизиты. Деньги идут
  /// заведению напрямую, мимо площадки, поэтому здесь реквизиты, а не кнопка
  /// оплаты. Владельцу список не приходит: свои реквизиты он знает.
  final List<BookingPayment> payment;

  const BookingItem({
    required this.id,
    required this.advertId,
    required this.status,
    required this.statusTitle,
    required this.startsAt,
    required this.endsAt,
    required this.guestsCount,
    this.place,
    required this.comment,
    required this.cancelReason,
    required this.role,
    required this.advert,
    required this.counterparty,
    required this.canConfirm,
    required this.canReject,
    required this.canCancel,
    this.isTakeaway = false,
    this.items = const [],
    this.totals = const PreorderTotals(),
    this.seat,
    this.payment = const [],
  });

  /// Есть ли что показывать в счёте: предзаказ или депозит.
  bool get hasBill => items.isNotEmpty || totals.total > 0;

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
      place: _asString(raw['place']),
      comment: _asString(raw['comment']),
      cancelReason: _asString(raw['cancel_reason']),
      role: _asString(raw['role']),
      advert: BookingAdvertBrief.tryParse(raw['advert']),
      counterparty: BookingParty.tryParse(raw['counterparty']),
      canConfirm: raw['can_confirm'] == true,
      canReject: raw['can_reject'] == true,
      canCancel: raw['can_cancel'] == true,
      isTakeaway: raw['is_takeaway'] == true,
      items: PreorderCart.fromJson({'items': raw['items']}).items,
      totals: PreorderTotals.fromJson(raw['totals']),
      seat: BookingSeat.tryParse(raw['table']),
      payment: [
        for (final row in (raw['payment'] is List ? raw['payment'] as List : const []))
          if (BookingPayment.tryParse(row) != null) BookingPayment.tryParse(row)!,
      ],
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

/// Способ оплаты заведения с реквизитами (30.09.2026).
class BookingPayment {
  final String key;
  final String title;
  final String? hint;

  /// Реквизиты строками «подпись: значение», уже готовые к показу.
  final List<MapEntry<String, String>> fields;

  /// Ссылка на оплату из банка заведения, если продавец её завёл.
  final String? link;

  const BookingPayment({
    required this.key,
    required this.title,
    this.hint,
    this.fields = const [],
    this.link,
  });

  static BookingPayment? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final key = '${raw['key'] ?? ''}'.trim();

    if (key.isEmpty) return null;

    final fields = <MapEntry<String, String>>[];

    for (final row in (raw['fields'] is List ? raw['fields'] as List : const [])) {
      if (row is! Map) continue;

      final label = '${row['label'] ?? ''}'.trim();
      final value = '${row['value'] ?? ''}'.trim();

      if (label.isNotEmpty && value.isNotEmpty) {
        fields.add(MapEntry(label, value));
      }
    }

    return BookingPayment(
      key: key,
      title: '${raw['title'] ?? ''}'.trim(),
      hint: BookingItem._asString(raw['hint']),
      fields: fields,
      link: BookingItem._asString(raw['link']),
    );
  }
}

/// Выбранное место брони: столик, кресло или кровать (30.09.2026).
class BookingSeat {
  final String key;
  final String number;
  final int seats;
  final double deposit;
  final String note;

  const BookingSeat({
    required this.key,
    required this.number,
    required this.seats,
    required this.deposit,
    required this.note,
  });

  static BookingSeat? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final key = '${raw['key'] ?? ''}'.trim();

    if (key.isEmpty) return null;

    double money(dynamic v) {
      if (v is num) return v.toDouble();

      return double.tryParse('${v ?? ''}') ?? 0;
    }

    return BookingSeat(
      key: key,
      number: '${raw['number'] ?? ''}'.trim(),
      seats: BookingItem._asInt(raw['seats']) ?? 0,
      deposit: money(raw['deposit']),
      note: '${raw['note'] ?? ''}'.trim(),
    );
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

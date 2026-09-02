/// Модели ответа календаря занятости.
///
/// Контракт описан в вики: back/api/booking-api.md.
///
/// Главное, что стоит держать в голове при чтении этого файла: занятость
/// считается сервером по РЕСУРСУ, а не по объявлению. У врача три услуги
/// могут делить одно расписание, и тогда занятый слот придёт из-за брони по
/// соседнему объявлению. Клиенту считать занятость самому нельзя, он только
/// показывает то, что прислал сервер.
library;

/// Режим бронирования: запись на услуги или посуточное жильё.
enum BookingMode { slots, daily }

/// Разбирает время так, как его имел в виду сервер, без пересчёта поясов.
///
/// Сервер присылает строки вида `2026-09-02T09:00:00+03:00`, где 09:00 это
/// время по часам мастера. `DateTime.parse` у такой строки переводит момент
/// в UTC, и час превращается в 06. Показывать это человеку нельзя: он
/// нажмёт «06:00» и придёт на три часа раньше.
///
/// Поэтому отрезаем смещение и читаем оставшееся как есть. Получается
/// «настенное время» ресурса: ровно то, что человек увидит у мастера на
/// часах. Обратно на сервер уходит исходная строка целиком, вместе со
/// смещением, так что момент времени не искажается ни на одном шаге.
DateTime? parseBookingWallClock(dynamic raw) {
  if (raw == null) return null;

  final text = '$raw'.trim();
  if (text.isEmpty) return null;

  // Отрезаем хвост: Z, +03:00, -0500 и подобное. Дату вида 2026-09-02 без
  // времени это не трогает.
  final withoutOffset = text.replaceFirst(
    RegExp(r'(Z|[+-]\d{2}:?\d{2})$'),
    '',
  );

  return DateTime.tryParse(withoutOffset);
}

/// Один слот в режиме записи на услуги.
class BookingSlot {
  /// Время по часам мастера, для показа на экране.
  final DateTime startsAt;
  final DateTime endsAt;

  /// Исходные строки сервера со смещением. Именно они уходят обратно при
  /// создании брони: так момент времени не зависит ни от часов телефона,
  /// ни от наших пересчётов.
  final String startsAtRaw;
  final String endsAtRaw;

  final bool isFree;

  const BookingSlot({
    required this.startsAt,
    required this.endsAt,
    required this.startsAtRaw,
    required this.endsAtRaw,
    required this.isFree,
  });

  static BookingSlot? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final startsRaw = '${raw['starts_at']}';
    final endsRaw = '${raw['ends_at']}';

    final starts = parseBookingWallClock(startsRaw);
    final ends = parseBookingWallClock(endsRaw);
    if (starts == null || ends == null) return null;

    return BookingSlot(
      startsAt: starts,
      endsAt: ends,
      startsAtRaw: startsRaw,
      endsAtRaw: endsRaw,
      // Отсутствующий флаг считаем занятым: лучше не показать свободное
      // время, чем предложить занятое и получить отказ на отправке.
      isFree: raw['is_free'] == true,
    );
  }
}

/// Один день в режиме записи на услуги.
class BookingDay {
  final DateTime date;
  final bool isWorking;
  final List<BookingSlot> slots;

  const BookingDay({
    required this.date,
    required this.isWorking,
    required this.slots,
  });

  bool get hasFreeSlots => slots.any((s) => s.isFree);

  static BookingDay? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final date = parseBookingWallClock(raw['date']);
    if (date == null) return null;

    final slots = <BookingSlot>[];
    if (raw['slots'] is List) {
      for (final item in raw['slots'] as List) {
        final slot = BookingSlot.tryParse(item);
        if (slot != null) slots.add(slot);
      }
    }

    return BookingDay(
      date: date,
      isWorking: raw['is_working'] != false,
      slots: slots,
    );
  }
}

/// Одна ночь в посуточном режиме.
class BookingNight {
  final DateTime date;
  final DateTime startsAt;
  final DateTime endsAt;
  final String startsAtRaw;
  final String endsAtRaw;
  final bool isFree;

  const BookingNight({
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.startsAtRaw,
    required this.endsAtRaw,
    required this.isFree,
  });

  static BookingNight? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final startsRaw = '${raw['starts_at']}';
    final endsRaw = '${raw['ends_at']}';

    final date = parseBookingWallClock(raw['date']);
    final starts = parseBookingWallClock(startsRaw);
    final ends = parseBookingWallClock(endsRaw);
    if (date == null || starts == null || ends == null) return null;

    return BookingNight(
      date: date,
      startsAt: starts,
      endsAt: ends,
      startsAtRaw: startsRaw,
      endsAtRaw: endsRaw,
      isFree: raw['is_free'] == true,
    );
  }
}

/// Ответ `GET /v1/adverts/{id}/availability` целиком.
class BookingAvailability {
  final BookingMode mode;
  final String timezone;
  final int slotMinutes;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;
  final int? maxGuests;

  /// Нужно ли подтверждение владельцем.
  ///
  /// Умолчание на сервере `false`: заказчик выбрал мгновенную бронь. Но
  /// читать флаг всё равно надо, а не считать его константой: у отдельных
  /// объявлений подтверждение включают, и тогда экраны говорят «заявка
  /// отправлена» вместо «время забронировано».
  final bool needsConfirmation;

  final List<BookingDay> days;
  final List<BookingNight> nights;

  const BookingAvailability({
    required this.mode,
    required this.timezone,
    required this.slotMinutes,
    required this.minDurationMinutes,
    required this.maxDurationMinutes,
    required this.maxGuests,
    required this.needsConfirmation,
    required this.days,
    required this.nights,
  });

  factory BookingAvailability.fromJson(Map<String, dynamic> data) {
    final days = <BookingDay>[];
    if (data['days'] is List) {
      for (final item in data['days'] as List) {
        final day = BookingDay.tryParse(item);
        if (day != null) days.add(day);
      }
    }

    final nights = <BookingNight>[];
    if (data['nights'] is List) {
      for (final item in data['nights'] as List) {
        final night = BookingNight.tryParse(item);
        if (night != null) nights.add(night);
      }
    }

    return BookingAvailability(
      mode: '${data['mode']}' == 'daily' ? BookingMode.daily : BookingMode.slots,
      timezone: '${data['timezone'] ?? 'Europe/Moscow'}',
      slotMinutes: _asInt(data['slot_minutes']) ?? 60,
      minDurationMinutes: _asInt(data['min_duration_minutes']),
      maxDurationMinutes: _asInt(data['max_duration_minutes']),
      maxGuests: _asInt(data['max_guests']),
      needsConfirmation: data['needs_confirmation'] == true,
      days: days,
      nights: nights,
    );
  }

  /// Есть ли вообще что предлагать. Если свободного времени нет во всём
  /// присланном промежутке, блок в карточке показывать бессмысленно.
  bool get hasAnythingFree =>
      days.any((d) => d.isWorking && d.hasFreeSlots) ||
      nights.any((n) => n.isFree);

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

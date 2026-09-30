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

import 'package:lidle/models/bookings/booking_labels.dart';
import 'package:lidle/models/hall_table.dart';

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

/// Столики одного размера в зале: «на 4 места — 3 шт.».
class BookingTableGroup {
  final int seats;
  final int count;

  const BookingTableGroup({required this.seats, required this.count});
}

/// Стол на плане зала (28.09.2026).
///
/// Ключ постоянный: номер продавец меняет, а бронь должна указывать на тот же
/// стол и после переименования. Координаты в тех же единицах, в которых их
/// расставлял продавец, поэтому схема рисуется той же сеткой.
class BookingHallTable {
  final String key;
  final String number;
  final int seats;
  final double x;
  final double y;

  /// Свободен ли стол на выбранное время. В списке залов приходит без этого
  /// признака: занятость считается на конкретный слот.
  final bool isFree;

  /// Депозит за этот стол, рубли (29.09.2026). Ноль значит «без депозита»:
  /// строку в счёте тогда не показываем.
  final int deposit;

  /// «Важно!» от заведения: с чем объединяется стол, чем отличается.
  final String note;

  /// Размер стола долями плана и поворот в градусах (30.09.2026).
  ///
  /// Схемы залов у всех разные: длинный стол на восемь человек и круглый на
  /// двоих, да ещё под углом. Метка одного размера ложилась мимо, поэтому
  /// размер и поворот задаёт заведение, а схема рисует стол как он есть.
  final double width;
  final double height;
  final double angle;

  const BookingHallTable({
    required this.key,
    required this.number,
    required this.seats,
    required this.x,
    required this.y,
    this.isFree = true,
    this.deposit = 0,
    this.note = '',
    this.width = kTableMarkWidth,
    this.height = kTableMarkHeight,
    this.angle = 0,
  });

  static List<BookingHallTable> listOf(dynamic raw) {
    final tables = <BookingHallTable>[];

    if (raw is! List) return tables;

    for (final item in raw) {
      if (item is! Map) continue;

      final key = '${item['key'] ?? ''}'.trim();

      if (key.isEmpty) continue;

      tables.add(BookingHallTable(
        key: key,
        number: '${item['number'] ?? ''}'.trim(),
        seats: (item['seats'] is num) ? (item['seats'] as num).toInt() : 0,
        x: (item['x'] is num) ? (item['x'] as num).toDouble() : 0,
        y: (item['y'] is num) ? (item['y'] as num).toDouble() : 0,
        // Ключа нет — считаем стол свободным: список залов занятость не
        // считает, её отдаёт отдельный запрос на выбранное время.
        isFree: item['is_free'] == null || item['is_free'] == true,
        deposit: (item['deposit'] is num) ? (item['deposit'] as num).toInt() : 0,
        note: '${item['note'] ?? ''}'.trim(),
        // Столы, расставленные до 30.09.2026, размера не имеют: берём
        // прежний, чтобы схема не переехала.
        width: (item['w'] is num)
            ? (item['w'] as num).toDouble().clamp(kTableMarkMin, kTableMarkMax)
            : kTableMarkWidth,
        height: (item['h'] is num)
            ? (item['h'] as num).toDouble().clamp(kTableMarkMin, kTableMarkMax)
            : kTableMarkHeight,
        angle: (item['angle'] is num) ? (item['angle'] as num).toDouble() % 360 : 0,
      ));
    }

    return tables;
  }
}

/// Строка под названием зала: «Этаж зала: 1».
class BookingHallLine {
  final String title;
  final String value;

  const BookingHallLine({required this.title, required this.value});

  static List<BookingHallLine> listOf(dynamic raw) {
    final lines = <BookingHallLine>[];

    if (raw is! List) return lines;

    for (final item in raw) {
      if (item is! Map) continue;

      final title = '${item['title'] ?? ''}'.trim();
      final value = '${item['value'] ?? ''}'.trim();

      if (title.isEmpty || value.isEmpty) continue;

      lines.add(BookingHallLine(title: title, value: value));
    }

    return lines;
  }
}

/// Зал ресторана, где можно бронировать (22.09.2026).
///
/// Приходит в свободном времени объявления полем `halls`, если ресторан
/// описал столики хотя бы в одном зале или разрешил банкет. Тогда гость
/// сначала выбирает зал, а свободное время считается по его столикам.
class BookingHall {
  final int id;
  final String name;
  final List<BookingTableGroup> tables;
  final int totalSeats;

  /// Самый большой столик: больше гостей за столик не посадить.
  final int maxTable;

  /// Можно ли забронировать зал целиком (банкет).
  final bool banquetEnabled;
  final int banquetMinGuests;

  /// Жёсткая длительность брони целиком, часов. Ноль — длительность обычная
  /// (25.09.2026): у ресторанного банкета она есть, у переговорной нет.
  final int banquetHours;

  /// Сколько человек помещается, если брать целиком (25.09.2026). Ноль —
  /// ограничения нет, действует общий предел объявления.
  final int capacity;

  /// План зала, который загрузил продавец: по нему рисуется схема со
  /// столиками, он же показывается на карточке выбора зала (28.09.2026).
  /// `fileKind` бывает `image` и `pdf`: PDF картинкой не нарисовать.
  final String? fileUrl;
  final String? fileKind;

  /// Столы, расставленные на плане: место, номер и вместимость.
  final List<BookingHallTable> layout;

  /// Поля экрана зала как их заполнил продавец: «Этаж зала: 1»,
  /// «Время работы зала: 9:00 - 18:00». Какие это поля, решает админка.
  final List<BookingHallLine> lines;

  const BookingHall({
    required this.id,
    required this.name,
    required this.tables,
    required this.totalSeats,
    required this.maxTable,
    required this.banquetEnabled,
    required this.banquetMinGuests,
    required this.banquetHours,
    this.capacity = 0,
    this.fileUrl,
    this.fileKind,
    this.layout = const [],
    this.lines = const [],
  });

  bool get hasTables => tables.isNotEmpty;

  /// Есть ли схема со столиками: без неё гостю нечего выбирать пальцем.
  bool get hasLayout => layout.isNotEmpty;

  /// Картинка плана, которую можно показать. У PDF её нет.
  String? get planImageUrl =>
      (fileKind == 'image' && (fileUrl ?? '').isNotEmpty) ? fileUrl : null;

  static BookingHall? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = _int(raw['id']);
    if (id == null) return null;

    final tables = <BookingTableGroup>[];
    if (raw['tables'] is List) {
      for (final t in raw['tables'] as List) {
        if (t is! Map) continue;
        final seats = _int(t['seats']) ?? 0;
        final count = _int(t['count']) ?? 0;
        if (seats > 0 && count > 0) {
          tables.add(BookingTableGroup(seats: seats, count: count));
        }
      }
    }

    final banquet = raw['banquet'] is Map ? raw['banquet'] as Map : const {};

    return BookingHall(
      id: id,
      name: '${raw['name'] ?? 'Зал'}',
      tables: tables,
      totalSeats: _int(raw['total_seats']) ?? 0,
      maxTable: _int(raw['max_table']) ?? 0,
      banquetEnabled: banquet['enabled'] == true,
      banquetMinGuests: _int(banquet['min_guests']) ?? 1,
      banquetHours: _int(banquet['hours']) ?? 0,
      capacity: _int(raw['capacity']) ?? 0,
      fileUrl: '${raw['file_url'] ?? ''}'.isEmpty ? null : '${raw['file_url']}',
      fileKind: '${raw['file_kind'] ?? ''}'.isEmpty ? null : '${raw['file_kind']}',
      layout: BookingHallTable.listOf(raw['layout']),
      lines: BookingHallLine.listOf(raw['lines']),
    );
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Что сервер посчитал для залов: какой зал, сколько гостей, столик или
/// банкет. Сервер мог поправить выбор (например, поднять число гостей до
/// минимума банкета), поэтому экран берёт значения отсюда.
class BookingHallSelection {
  final int hallId;
  final int guests;
  final bool wholeHall;
  final int durationMinutes;

  const BookingHallSelection({
    required this.hallId,
    required this.guests,
    required this.wholeHall,
    required this.durationMinutes,
  });

  static BookingHallSelection? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final hallId = BookingHall._int(raw['hall_id']);
    if (hallId == null) return null;

    return BookingHallSelection(
      hallId: hallId,
      guests: BookingHall._int(raw['guests']) ?? 2,
      wholeHall: raw['whole_hall'] == true,
      durationMinutes: BookingHall._int(raw['duration_minutes']) ?? 120,
    );
  }
}

/// Ответ `GET /v1/adverts/{id}/availability` целиком.
class BookingAvailability {
  /// Залы ресторана (22.09.2026). Пусто — бронь без залов, как раньше.
  final List<BookingHall> halls;

  /// Выбор, для которого посчитано время. Есть, только если есть залы.
  final BookingHallSelection? selection;

  /// Тексты под категорию (22.09.2026), см. [BookingLabels].
  final BookingLabels labels;

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

  /// Часы заезда и выезда, только для посуточного режима. Именно они делают
  /// возможным выезд и заезд в один день: предыдущий гость съезжает утром,
  /// следующий заезжает днём, и ночь при этом занята ровно одним.
  final String? checkInTime;
  final String? checkOutTime;

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
    required this.checkInTime,
    required this.checkOutTime,
    this.labels = BookingLabels.standard,
    this.halls = const [],
    this.selection,
  });

  bool get hasHalls => halls.isNotEmpty;

  BookingHall? get selectedHall {
    final id = selection?.hallId;
    for (final hall in halls) {
      if (hall.id == id) return hall;
    }
    return halls.isEmpty ? null : halls.first;
  }

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
      checkInTime: _timeOrNull(data['check_in_time']),
      checkOutTime: _timeOrNull(data['check_out_time']),
      labels: BookingLabels.fromJson(data['labels']),
      halls: [
        if (data['halls'] is List)
          for (final raw in data['halls'] as List)
            if (BookingHall.tryParse(raw) != null) BookingHall.tryParse(raw)!,
      ],
      selection: BookingHallSelection.tryParse(data['selection']),
    );
  }

  /// Сервер отдаёт время как `14:00:00`, человеку нужны часы и минуты.
  static String? _timeOrNull(dynamic value) {
    if (value == null) return null;

    final text = '$value'.trim();
    if (text.isEmpty) return null;

    return text.length >= 5 ? text.substring(0, 5) : text;
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

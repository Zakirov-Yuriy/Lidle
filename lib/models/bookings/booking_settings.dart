/// Настройки брони объявления — то, что видит и меняет владелец.
///
/// Ресурс здесь не техническая подробность, а важная для владельца вещь:
/// расписание висит на исполнителе, а не на объявлении. Если у мастера три
/// услуги на одном ресурсе, запись на одну закроет время в остальных.
/// `sharedAdvertsCount` нужен, чтобы сказать ему об этом прямо, иначе
/// поведение выглядит как ошибка.
class BookingSettings {
  final int advertId;
  final bool isEnabled;

  final BookingResourceBrief? resource;

  final bool needsConfirmation;
  final int confirmTtlMinutes;
  final int slotMinutes;
  final int bufferMinutes;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;
  final int leadTimeMinutes;
  final int horizonDays;
  final int cancelBeforeHours;
  final int? maxGuests;

  /// Часы заезда и выезда, только для посуточного режима. Именно они задают
  /// границы ночи, и по ним же закрываются даты: закрыть «сутки с 00:00 до
  /// 23:59» у жилья означало бы задеть две ночи, а не одну.
  final String? checkInTime;
  final String? checkOutTime;

  final List<BookingWorkingHour> workingHours;

  const BookingSettings({
    required this.advertId,
    required this.isEnabled,
    required this.resource,
    required this.needsConfirmation,
    required this.confirmTtlMinutes,
    required this.slotMinutes,
    required this.bufferMinutes,
    required this.minDurationMinutes,
    required this.maxDurationMinutes,
    required this.leadTimeMinutes,
    required this.horizonDays,
    required this.cancelBeforeHours,
    required this.maxGuests,
    required this.checkInTime,
    required this.checkOutTime,
    required this.workingHours,
  });

  /// Бронь ни разу не включали. Сервер отдаёт это обычным ответом, а не 404:
  /// для экрана настроек «ещё не настроено» нормальное состояние.
  factory BookingSettings.notConfigured(int advertId) => BookingSettings(
        advertId: advertId,
        isEnabled: false,
        resource: null,
        needsConfirmation: false,
        confirmTtlMinutes: 10,
        slotMinutes: 60,
        bufferMinutes: 0,
        minDurationMinutes: null,
        maxDurationMinutes: null,
        leadTimeMinutes: 0,
        horizonDays: 90,
        cancelBeforeHours: 24,
        maxGuests: null,
        checkInTime: null,
        checkOutTime: null,
        workingHours: const [],
      );

  factory BookingSettings.fromJson(Map<String, dynamic> data) {
    final hours = <BookingWorkingHour>[];
    if (data['working_hours'] is List) {
      for (final row in data['working_hours'] as List) {
        final hour = BookingWorkingHour.tryParse(row);
        if (hour != null) hours.add(hour);
      }
    }

    return BookingSettings(
      advertId: _int(data['advert_id']) ?? 0,
      isEnabled: data['is_enabled'] == true,
      resource: BookingResourceBrief.tryParse(data['resource']),
      needsConfirmation: data['needs_confirmation'] == true,
      confirmTtlMinutes: _int(data['confirm_ttl_minutes']) ?? 10,
      slotMinutes: _int(data['slot_minutes']) ?? 60,
      bufferMinutes: _int(data['buffer_minutes']) ?? 0,
      minDurationMinutes: _int(data['min_duration_minutes']),
      maxDurationMinutes: _int(data['max_duration_minutes']),
      leadTimeMinutes: _int(data['lead_time_minutes']) ?? 0,
      horizonDays: _int(data['horizon_days']) ?? 90,
      cancelBeforeHours: _int(data['cancel_before_hours']) ?? 24,
      maxGuests: _int(data['max_guests']),
      checkInTime: _time(data['check_in_time']),
      checkOutTime: _time(data['check_out_time']),
      workingHours: hours,
    );
  }

  BookingSettings copyWith({
    bool? isEnabled,
    bool? needsConfirmation,
    int? confirmTtlMinutes,
    int? slotMinutes,
    int? bufferMinutes,
    int? cancelBeforeHours,
    int? leadTimeMinutes,
    List<BookingWorkingHour>? workingHours,
  }) {
    return BookingSettings(
      advertId: advertId,
      isEnabled: isEnabled ?? this.isEnabled,
      resource: resource,
      needsConfirmation: needsConfirmation ?? this.needsConfirmation,
      confirmTtlMinutes: confirmTtlMinutes ?? this.confirmTtlMinutes,
      slotMinutes: slotMinutes ?? this.slotMinutes,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      minDurationMinutes: minDurationMinutes,
      maxDurationMinutes: maxDurationMinutes,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
      horizonDays: horizonDays,
      cancelBeforeHours: cancelBeforeHours ?? this.cancelBeforeHours,
      maxGuests: maxGuests,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      workingHours: workingHours ?? this.workingHours,
    );
  }

  /// Посуточный режим: у него закрывается ночь, а не календарные сутки.
  bool get isDaily => resource?.mode == 'daily';

  /// Сервер отдаёт `14:00:00`, человеку нужны часы и минуты.
  static String? _time(dynamic value) {
    if (value == null) return null;

    final text = '$value'.trim();
    if (text.isEmpty) return null;

    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class BookingResourceBrief {
  final int id;
  final String name;

  /// `slots` — запись на услуги, `daily` — посуточно.
  final String mode;
  final String timezone;

  /// Сколько объявлений делят это расписание. Если больше одного, запись на
  /// одно закроет время в остальных, и владелец должен это знать заранее.
  final int sharedAdvertsCount;

  const BookingResourceBrief({
    required this.id,
    required this.name,
    required this.mode,
    required this.timezone,
    required this.sharedAdvertsCount,
  });

  bool get isShared => sharedAdvertsCount > 1;

  static BookingResourceBrief? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = BookingSettings._int(raw['id']);
    if (id == null) return null;

    return BookingResourceBrief(
      id: id,
      name: '${raw['name'] ?? ''}',
      mode: '${raw['mode'] ?? 'slots'}',
      timezone: '${raw['timezone'] ?? ''}',
      sharedAdvertsCount: BookingSettings._int(raw['shared_adverts_count']) ?? 1,
    );
  }
}

/// Рабочий промежуток в конкретный день недели.
///
/// Строк на день может быть несколько: обед делит день на две. Выходной — это
/// день, для которого строк нет вовсе.
class BookingWorkingHour {
  /// 1 понедельник, 7 воскресенье.
  final int weekday;
  final String startsAt;
  final String endsAt;

  const BookingWorkingHour({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
  });

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'starts_at': startsAt,
        'ends_at': endsAt,
      };

  static BookingWorkingHour? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final weekday = BookingSettings._int(raw['weekday']);
    if (weekday == null) return null;

    return BookingWorkingHour(
      weekday: weekday,
      startsAt: '${raw['starts_at'] ?? '09:00'}',
      endsAt: '${raw['ends_at'] ?? '18:00'}',
    );
  }
}

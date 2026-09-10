// ============================================================
// Сотрудники публикации: группы и карточки (макет 10.09.2026).
// ============================================================
//
// Устроены как группы товара и доставки: папка с обложкой, внутри карточки.
//
// Карточка сотрудника это памятка продавца, а не учётная запись: сотрудник в
// приложение не входит, и отмеченные доступы пока ничего не открывают.

/// Пункт доступа: ключ и название. Список приходит с сервера, чтобы
/// приложение не держало вторую копию названий.
class StaffAccessItem {
  const StaffAccessItem({required this.key, required this.title});

  final String key;
  final String title;

  factory StaffAccessItem.fromJson(Map<String, dynamic> data) => StaffAccessItem(
    key: '${data['key'] ?? ''}',
    title: '${data['title'] ?? ''}',
  );
}

/// Справочники доступов: заведение и аккаунт.
class StaffAccessDictionary {
  const StaffAccessDictionary({this.venue = const [], this.account = const []});

  final List<StaffAccessItem> venue;
  final List<StaffAccessItem> account;

  factory StaffAccessDictionary.fromJson(Map<String, dynamic> data) {
    List<StaffAccessItem> read(dynamic raw) => raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(StaffAccessItem.fromJson)
              .toList()
        : const <StaffAccessItem>[];

    return StaffAccessDictionary(
      venue: read(data['venue']),
      account: read(data['account']),
    );
  }
}


/// Как устроен график работы сотрудника.
///
/// `weeks` — одни и те же дни недели каждую неделю;
/// `rotation` — чередование: столько-то рабочих, столько-то выходных;
/// `days` — человек отмечает дни в календаре руками.
enum StaffScheduleMode { weeks, rotation, days }

/// Рабочее время: одно на весь график.
///
/// Разное время по дням макет не просит, и заводить его на будущее значит
/// показать продавцу поле, которое он не понимает, зачем заполнять.
class StaffWorkTime {
  const StaffWorkTime({
    this.allDay = false,
    this.start = '09:00',
    this.end = '18:00',
    this.breakStart,
    this.breakEnd,
  });

  /// Круглосуточно: тогда «с» и «до» не показываем.
  final bool allDay;

  final String start;
  final String end;

  /// Перерыв. Пусто — перерыв не задавали.
  final String? breakStart;
  final String? breakEnd;

  bool get hasBreak => breakStart != null && breakEnd != null;

  StaffWorkTime copyWith({
    bool? allDay,
    String? start,
    String? end,
    String? breakStart,
    String? breakEnd,
    bool dropBreak = false,
  }) {
    return StaffWorkTime(
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      breakStart: dropBreak ? null : (breakStart ?? this.breakStart),
      breakEnd: dropBreak ? null : (breakEnd ?? this.breakEnd),
    );
  }

  Map<String, dynamic> toJson() => {
        'all_day': allDay,
        'start': start,
        'end': end,
        'break_start': breakStart,
        'break_end': breakEnd,
      };

  factory StaffWorkTime.fromJson(Map<String, dynamic> data) {
    String? time(dynamic value) {
      final text = value?.toString().trim() ?? '';

      return text.isEmpty ? null : text;
    }

    return StaffWorkTime(
      allDay: data['all_day'] == true,
      start: time(data['start']) ?? '09:00',
      end: time(data['end']) ?? '18:00',
      breakStart: time(data['break_start']),
      breakEnd: time(data['break_end']),
    );
  }
}

/// График работы сотрудника.
///
/// Сервер его только хранит. Какие дни рабочие, считает приложение: правило
/// живёт рядом с экраном, который его показывает, и вторая такая же
/// арифметика на сервере однажды разойдётся с первой.
class StaffSchedule {
  const StaffSchedule({
    this.mode = StaffScheduleMode.days,
    this.weekdays = const [],
    this.rotationWork = 2,
    this.rotationRest = 2,
    this.rotationFrom,
    this.days = const [],
    this.time = const StaffWorkTime(),
  });

  final StaffScheduleMode mode;

  /// Дни недели, где 1 — понедельник, 7 — воскресенье.
  final List<int> weekdays;

  final int rotationWork;
  final int rotationRest;

  /// С какого дня считать чередование. Пусто — с первого дня календаря.
  final DateTime? rotationFrom;

  /// Дни, отмеченные руками, в виде `2026-12-01`.
  final List<String> days;

  final StaffWorkTime time;

  bool get isEmpty =>
      (mode == StaffScheduleMode.days && days.isEmpty) ||
      (mode == StaffScheduleMode.weeks && weekdays.isEmpty);

  StaffSchedule copyWith({
    StaffScheduleMode? mode,
    List<int>? weekdays,
    int? rotationWork,
    int? rotationRest,
    DateTime? rotationFrom,
    List<String>? days,
    StaffWorkTime? time,
  }) {
    return StaffSchedule(
      mode: mode ?? this.mode,
      weekdays: weekdays ?? this.weekdays,
      rotationWork: rotationWork ?? this.rotationWork,
      rotationRest: rotationRest ?? this.rotationRest,
      rotationFrom: rotationFrom ?? this.rotationFrom,
      days: days ?? this.days,
      time: time ?? this.time,
    );
  }

  /// Рабочий ли этот день по правилу графика.
  bool isWorkingDay(DateTime day) {
    switch (mode) {
      case StaffScheduleMode.weeks:
        return weekdays.contains(day.weekday);

      case StaffScheduleMode.rotation:
        final length = rotationWork + rotationRest;

        if (rotationWork <= 0 || length <= 0) return false;

        final from = rotationFrom ?? DateTime(day.year, day.month, 1);
        final shift = DateTime(day.year, day.month, day.day)
            .difference(DateTime(from.year, from.month, from.day))
            .inDays;

        if (shift < 0) return false;

        return shift % length < rotationWork;

      case StaffScheduleMode.days:
        return days.contains(dayKey(day));
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'weekdays': weekdays,
        'rotation': {
          'work': rotationWork,
          'rest': rotationRest,
          'from': rotationFrom == null ? null : dayKey(rotationFrom!),
        },
        'days': days,
        'time': time.toJson(),
      };

  factory StaffSchedule.fromJson(Map<String, dynamic> data) {
    final rotation = data['rotation'];
    final rotationMap = rotation is Map
        ? Map<String, dynamic>.from(rotation)
        : const <String, dynamic>{};

    final time = data['time'];

    return StaffSchedule(
      mode: StaffScheduleMode.values.firstWhere(
        (item) => item.name == '${data['mode']}',
        orElse: () => StaffScheduleMode.days,
      ),
      weekdays: data['weekdays'] is List
          ? (data['weekdays'] as List)
              .map(_int)
              .whereType<int>()
              .where((item) => item >= 1 && item <= 7)
              .toList()
          : const [],
      rotationWork: _int(rotationMap['work']) ?? 2,
      rotationRest: _int(rotationMap['rest']) ?? 2,
      rotationFrom: DateTime.tryParse('${rotationMap['from']}'),
      days: data['days'] is List
          ? (data['days'] as List).map((item) => '$item').toList()
          : const [],
      time: time is Map
          ? StaffWorkTime.fromJson(Map<String, dynamic>.from(time))
          : const StaffWorkTime(),
    );
  }
}

/// Дата в тот вид, в котором она ездит на сервер: `2026-12-01`.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Сотрудник.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    this.position,
    this.number,
    this.salary,
    this.venueAccess = const [],
    this.accountAccess = const [],
    this.schedule,
    this.description = '',
    this.image,
    this.groupId,
    this.order = 0,
  });

  final int id;
  final String name;

  /// Должность словом. Список ведёт администратор характеристикой раздела,
  /// поэтому здесь название, а не номер значения: справочник могут
  /// переписать, а должность сотрудника от этого пропадать не должна.
  final String? position;

  final int? number;
  final num? salary;

  final List<String> venueAccess;
  final List<String> accountAccess;

  /// График работы. Пусто — его не задавали.
  final StaffSchedule? schedule;

  final String description;
  final String? image;
  final int? groupId;
  final int order;

  factory StaffMember.fromJson(Map<String, dynamic> data) {
    List<String> keys(dynamic raw) => raw is List
        ? raw.map((item) => '$item').where((item) => item.isNotEmpty).toList()
        : const <String>[];

    return StaffMember(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      position: data['position']?.toString(),
      number: _int(data['number']),
      salary: _num(data['salary']),
      venueAccess: keys(data['venue_access']),
      accountAccess: keys(data['account_access']),
      schedule: data['schedule'] is Map
          ? StaffSchedule.fromJson(
              Map<String, dynamic>.from(data['schedule'] as Map))
          : null,
      description: '${data['description'] ?? ''}',
      image: data['image']?.toString(),
      groupId: _int(data['group_id']),
      order: _int(data['order']) ?? 0,
    );
  }
}

/// Группа сотрудников.
class StaffGroup {
  const StaffGroup({
    required this.id,
    required this.name,
    this.image,
    this.order = 0,
    this.membersCount = 0,
    this.members = const [],
  });

  final int id;
  final String name;
  final String? image;
  final int order;
  final int membersCount;
  final List<StaffMember> members;

  factory StaffGroup.fromJson(Map<String, dynamic> data) {
    final raw = data['members'];

    return StaffGroup(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      image: data['image']?.toString(),
      order: _int(data['order']) ?? 0,
      membersCount: _int(data['members_count']) ?? 0,
      members: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(StaffMember.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Все сотрудники публикации.
class PublicationStaff {
  const PublicationStaff({this.groups = const [], this.ungrouped = const []});

  final List<StaffGroup> groups;
  final List<StaffMember> ungrouped;

  bool get isEmpty => groups.isEmpty && ungrouped.isEmpty;

  /// Сколько сотрудников заведено всего, включая тех, кто вне групп.
  int get total =>
      ungrouped.length +
      groups.fold<int>(0, (sum, group) => sum + group.members.length);

  factory PublicationStaff.fromJson(Map<String, dynamic> data) {
    final groups = data['groups'];
    final loose = data['ungrouped'];

    return PublicationStaff(
      groups: groups is List
          ? groups
                .whereType<Map<String, dynamic>>()
                .map(StaffGroup.fromJson)
                .toList()
          : const [],
      ungrouped: loose is List
          ? loose
                .whereType<Map<String, dynamic>>()
                .map(StaffMember.fromJson)
                .toList()
          : const [],
    );
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse('${value ?? ''}');
}

num? _num(dynamic value) {
  if (value is num) return value;

  return num.tryParse('${value ?? ''}');
}

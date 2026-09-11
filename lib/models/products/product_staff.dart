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
enum StaffScheduleMode { weeks, rotation, days, hours }

/// Часы одного дня недели.
///
/// Отдельно от [StaffWorkTime]: там время всего графика с перерывом, здесь
/// только «с» и «до» одного дня. Складывать это в один класс значит показать
/// на экране «Дни и часы» перерыв, которого макет там не просит.
class StaffDayHours {
  const StaffDayHours({required this.weekday, this.start, this.end});

  /// Номер дня недели, 1 — понедельник.
  ///
  /// Обычным полем, а не ключом объекта: объект с числовыми ключами PHP на
  /// сервере переиндексирует, и «понедельник и суббота» превращаются в
  /// «первый и второй». Поймали это проверкой 10.09.2026.
  final int weekday;

  final String? start;
  final String? end;

  bool get isEmpty => start == null && end == null;

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'start': start, 'end': end};

  factory StaffDayHours.fromJson(Map<String, dynamic> data, {int? weekday}) {
    String? time(dynamic value) {
      final text = value?.toString().trim() ?? '';

      return text.isEmpty || text == 'null' ? null : text;
    }

    return StaffDayHours(
      weekday: _int(data['weekday']) ?? weekday ?? 1,
      start: time(data['start']),
      end: time(data['end']),
    );
  }
}

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
    this.weeksPreset,
    this.rotationWork = 2,
    this.rotationRest = 2,
    this.rotationFrom,
    this.rotationTo,
    this.days = const [],
    this.weekdayHours = const {},
    this.time = const StaffWorkTime(),
  });

  final StaffScheduleMode mode;

  /// Дни недели, где 1 — понедельник, 7 — воскресенье.
  ///
  /// Осталось от первой версии экрана и сейчас не заполняется: рабочие недели
  /// задаются готовым набором (`weeksPreset`). Поле оставлено, чтобы графики,
  /// заведённые до 10.09.2026, не пропали.
  final List<int> weekdays;

  /// Готовый набор рабочих недель: `all`, `workdays`, `even`, `odd`.
  /// Пусто — «По неделям» ещё не настроили.
  final String? weeksPreset;

  final int rotationWork;
  final int rotationRest;

  /// Начало и конец периода чередования. Пусто — период не задан, и рабочих
  /// дней по этому правилу нет.
  final DateTime? rotationFrom;
  final DateTime? rotationTo;

  /// Дни, отмеченные руками, в виде `2026-12-01`.
  final List<String> days;

  /// Часы по дням недели: ключ — номер дня, 1 понедельник. Заполняется на
  /// экране «Дни и часы»; день, которого здесь нет, нерабочий.
  final Map<int, StaffDayHours> weekdayHours;

  final StaffWorkTime time;

  bool get isEmpty =>
      (mode == StaffScheduleMode.days && days.isEmpty) ||
      (mode == StaffScheduleMode.weeks &&
          weeksPreset == null &&
          weekdays.isEmpty) ||
      (mode == StaffScheduleMode.rotation &&
          (rotationFrom == null || weekdays.isEmpty)) ||
      (mode == StaffScheduleMode.hours && weekdayHours.isEmpty);

  /// Короткие названия дней недели, где 1 — понедельник.
  static const List<String> weekdayShort = [
    'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс',
  ];

  static const List<String> weekdayFull = [
    'Понедельник', 'Вторник', 'Среда', 'Четверг',
    'Пятница', 'Суббота', 'Воскресенье',
  ];

  /// Как набор рабочих недель называется на экране.
  static String weeksPresetTitle(String? preset) {
    switch (preset) {
      case 'all':
        return 'Все дни';
      case 'workdays':
        return 'Будни';
      case 'even':
        return 'Чётные';
      case 'odd':
        return 'Нечётные';
      default:
        return 'Не настроено';
    }
  }

  StaffSchedule copyWith({
    StaffScheduleMode? mode,
    List<int>? weekdays,
    String? weeksPreset,
    bool clearWeeksPreset = false,
    int? rotationWork,
    int? rotationRest,
    DateTime? rotationFrom,
    DateTime? rotationTo,
    bool clearRotationDates = false,
    List<String>? days,
    Map<int, StaffDayHours>? weekdayHours,
    StaffWorkTime? time,
  }) {
    return StaffSchedule(
      mode: mode ?? this.mode,
      weekdays: weekdays ?? this.weekdays,
      weeksPreset: clearWeeksPreset ? null : (weeksPreset ?? this.weeksPreset),
      rotationWork: rotationWork ?? this.rotationWork,
      rotationRest: rotationRest ?? this.rotationRest,
      rotationFrom:
          clearRotationDates ? null : (rotationFrom ?? this.rotationFrom),
      rotationTo: clearRotationDates ? null : (rotationTo ?? this.rotationTo),
      days: days ?? this.days,
      weekdayHours: weekdayHours ?? this.weekdayHours,
      time: time ?? this.time,
    );
  }

  /// Как настроен график, в пару слов: для карточки сотрудника.
  ///
  /// Живёт рядом с моделью, а не в экране: та же строка понадобится на
  /// сводке, и вторая такая же сборка разойдётся с первой.
  ///
  /// Карточка узкая, поэтому здесь именно правило и время, а не пересказ
  /// всех отмеченных дней: подробности человек смотрит в самом графике.
  String get shortTitle {
    final hours = time.allDay ? 'круглосуточно' : '${time.start}–${time.end}';

    switch (mode) {
      case StaffScheduleMode.weeks:
        final preset = weeksPreset;

        return preset == null
            ? hours
            : '${weeksPresetTitle(preset)}, $hours';

      case StaffScheduleMode.rotation:
        return '$rotationWork/$rotationRest, $hours';

      case StaffScheduleMode.days:
        return '${days.length} ${daysWord(days.length)}, $hours';

      case StaffScheduleMode.hours:
        return 'По часам: ${weekdayHours.length} ${daysWord(weekdayHours.length)}';
    }
  }

  /// «день», «дня», «дней» по числу.
  static String daysWord(int count) {
    final tail = count % 100;

    if (tail >= 11 && tail <= 14) return 'дней';

    switch (count % 10) {
      case 1:
        return 'день';
      case 2:
      case 3:
      case 4:
        return 'дня';
      default:
        return 'дней';
    }
  }

  /// Рабочий ли этот день по правилу графика.
  bool isWorkingDay(DateTime day) {
    switch (mode) {
      case StaffScheduleMode.weeks:
        switch (weeksPreset) {
          case 'all':
            return true;
          case 'workdays':
            return day.weekday <= 5;

          // «Чётные» и «нечётные» это числа месяца, как о них и говорят:
          // «работаю по чётным». Недели тут ни при чём, хотя блок на макете
          // называется «Рабочие недели».
          case 'even':
            return day.day.isEven;
          case 'odd':
            return day.day.isOdd;
        }

        return weekdays.contains(day.weekday);

      case StaffScheduleMode.rotation:
        // Чередование это «вот эти дни недели, вот в этот период». Так его
        // задаёт экран, и считать иначе значит показать в календаре не то,
        // что человек только что отметил галочками.
        final from = rotationFrom;
        final to = rotationTo;

        if (from == null || to == null || weekdays.isEmpty) return false;

        final current = DateTime(day.year, day.month, day.day);
        final start = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);

        if (current.isBefore(start) || current.isAfter(end)) return false;

        return weekdays.contains(current.weekday);

      case StaffScheduleMode.days:
        return days.contains(dayKey(day));

      case StaffScheduleMode.hours:
        return weekdayHours.containsKey(day.weekday);
    }
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'weekdays': weekdays,
        'weeks': {'preset': weeksPreset},
        'rotation': {
          'work': rotationWork,
          'rest': rotationRest,
          'from': rotationFrom == null ? null : dayKey(rotationFrom!),
          'to': rotationTo == null ? null : dayKey(rotationTo!),
        },
        'days': days,
        'hours': (weekdayHours.keys.toList()..sort())
            .map((weekday) => weekdayHours[weekday]!.toJson())
            .toList(),
        'time': time.toJson(),
      };

  factory StaffSchedule.fromJson(Map<String, dynamic> data) {
    final weeks = data['weeks'];
    final weeksMap =
        weeks is Map ? Map<String, dynamic>.from(weeks) : const <String, dynamic>{};

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
      weeksPreset: weeksMap['preset'] == null
          ? null
          : '${weeksMap['preset']}',
      rotationWork: _int(rotationMap['work']) ?? 2,
      rotationRest: _int(rotationMap['rest']) ?? 2,
      rotationFrom: DateTime.tryParse('${rotationMap['from']}'),
      rotationTo: DateTime.tryParse('${rotationMap['to']}'),
      days: data['days'] is List
          ? (data['days'] as List).map((item) => '$item').toList()
          : const [],
      weekdayHours: _hours(data['hours']),
      time: time is Map
          ? StaffWorkTime.fromJson(Map<String, dynamic>.from(time))
          : const StaffWorkTime(),
    );
  }
}

/// Часы по дням недели из ответа сервера.
///
/// Разбираем и список, и старый вид «номер дня → часы»: графики, заведённые
/// до перехода на список, должны открываться.
Map<int, StaffDayHours> _hours(dynamic raw) {
  final result = <int, StaffDayHours>{};

  void add(Map<String, dynamic> data, {int? weekday}) {
    final hours = StaffDayHours.fromJson(data, weekday: weekday);

    if (hours.weekday < 1 || hours.weekday > 7) return;

    result[hours.weekday] = hours;
  }

  if (raw is List) {
    for (final item in raw) {
      if (item is Map) add(Map<String, dynamic>.from(item));
    }

    return result;
  }

  if (raw is Map) {
    raw.forEach((key, value) {
      if (value is! Map) return;

      add(Map<String, dynamic>.from(value), weekday: int.tryParse('$key'));
    });
  }

  return result;
}

/// Дата так, как её читает человек: `13.12.2025`.
String dayLabel(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.'
    '${day.month.toString().padLeft(2, '0')}.'
    '${day.year}';

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

  /// Зарплата так, как её читают: «40 000 ₽». Пусто — не указана.
  ///
  /// Разряды разделяем пробелами: без них «40000» на карточке приходится
  /// пересчитывать глазами, а карточка нужна для беглого взгляда.
  String get salaryShort {
    final value = salary;

    if (value == null) return '';

    final whole = value.floor();
    final digits = whole.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');

      buffer.write(digits[i]);
    }

    return '$buffer ₽';
  }

  /// Есть ли у графика что показывать. Пустой график это «не настроен».
  bool get hasSchedule => schedule != null && !schedule!.isEmpty;

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

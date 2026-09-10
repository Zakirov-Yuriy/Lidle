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

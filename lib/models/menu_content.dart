import 'dart:math';

/// Группа меню: «Завтраки», «Салаты» (23.09.2026). У группы своя картинка.
class MenuGroup {
  final String key;
  String name;

  /// Порядок группы в списке. Ставится сам, меняется руками (23.09.2026).
  int position;

  /// Имя уже сохранённой картинки на сервере.
  String? image;

  /// Ссылка на сохранённую картинку.
  String? imageUrl;

  /// Картинка, выбранная на телефоне и ещё не отправленная.
  String? localPath;

  MenuGroup({
    required this.key,
    this.name = '',
    this.position = 1,
    this.image,
    this.imageUrl,
    this.localPath,
  });

  MenuGroup copy() => MenuGroup(
        key: key,
        name: name,
        position: position,
        image: image,
        imageUrl: imageUrl,
        localPath: localPath,
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'name': name, 'position': position, 'image': image ?? ''};

  static MenuGroup? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = '${raw['key'] ?? ''}';
    if (key.isEmpty) return null;

    int number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 1;

    return MenuGroup(
      key: key,
      name: '${raw['name'] ?? ''}',
      position: number(raw['position']) < 1 ? 1 : number(raw['position']),
      image: '${raw['image'] ?? ''}'.isEmpty ? null : '${raw['image']}',
      imageUrl: raw['image_url']?.toString(),
    );
  }
}

/// Позиция меню: блюдо (23.09.2026).
class MenuItem {
  final String key;

  /// Ключ группы, в которой лежит блюдо.
  String group;

  String name;
  List<String> cuisines;
  int price;
  int weight;
  String description;

  /// Порядок в группе. Ставится сам, но его можно поменять руками.
  int position;

  String? image;
  String? imageUrl;
  String? localPath;

  MenuItem({
    required this.key,
    required this.group,
    this.name = '',
    List<String>? cuisines,
    this.price = 0,
    this.weight = 0,
    this.description = '',
    this.position = 1,
    this.image,
    this.imageUrl,
    this.localPath,
  }) : cuisines = cuisines ?? [];

  bool get hasImage => localPath != null || imageUrl != null;

  MenuItem copy() => MenuItem(
        key: key,
        group: group,
        name: name,
        cuisines: List.of(cuisines),
        price: price,
        weight: weight,
        description: description,
        position: position,
        image: image,
        imageUrl: imageUrl,
        localPath: localPath,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'group': group,
        'name': name,
        'cuisines': cuisines,
        'price': price,
        'weight': weight,
        'description': description,
        'position': position,
        'image': image ?? '',
      };

  static MenuItem? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = '${raw['key'] ?? ''}';
    final group = '${raw['group'] ?? ''}';
    if (key.isEmpty || group.isEmpty) return null;

    int number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return MenuItem(
      key: key,
      group: group,
      name: '${raw['name'] ?? ''}',
      cuisines: [
        if (raw['cuisines'] is List)
          for (final c in raw['cuisines'] as List) '$c',
      ],
      price: number(raw['price']),
      weight: number(raw['weight']),
      description: '${raw['description'] ?? ''}',
      position: number(raw['position']) < 1 ? 1 : number(raw['position']),
      image: '${raw['image'] ?? ''}'.isEmpty ? null : '${raw['image']}',
      imageUrl: raw['image_url']?.toString(),
    );
  }
}

/// Меню целиком: группы и позиции (23.09.2026).
class MenuContent {
  final List<MenuGroup> groups;
  final List<MenuItem> items;

  MenuContent({List<MenuGroup>? groups, List<MenuItem>? items})
      : groups = groups ?? [],
        items = items ?? [];

  static final Random _random = Random();

  static String newKey(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  bool get isEmpty => groups.isEmpty && items.isEmpty;

  /// Группы по порядку.
  List<MenuGroup> get sortedGroups {
    final list = List<MenuGroup>.of(groups)
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Блюда группы по порядку.
  List<MenuItem> ofGroup(String groupKey) {
    final list = items.where((i) => i.group == groupKey).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Добавить сюда чужие группы и позиции (23.09.2026): так доставку из
  /// другого объявления переносят целиком. Ключи выдаются новые, чтобы не
  /// столкнуться с теми, что уже есть, а номера продолжают нумерацию.
  /// Картинки не перезаливаются: у сохранённых уже есть имя файла на сервере.
  void merge(MenuContent other) {
    var position = groups.fold<int>(0, (max, g) => g.position > max ? g.position : max);
    final keys = <String, String>{};

    for (final group in other.sortedGroups) {
      final key = newKey('g');
      keys[group.key] = key;

      groups.add(MenuGroup(
        key: key,
        name: group.name,
        position: ++position,
        image: group.image,
        imageUrl: group.imageUrl,
      ));
    }

    for (final item in other.items) {
      final group = keys[item.group];
      if (group == null) continue;

      items.add(MenuItem(
        key: newKey('i'),
        group: group,
        name: item.name,
        cuisines: List.of(item.cuisines),
        price: item.price,
        weight: item.weight,
        description: item.description,
        position: item.position,
        image: item.image,
        imageUrl: item.imageUrl,
      ));
    }
  }

  MenuContent copy() => MenuContent(
        groups: groups.map((g) => g.copy()).toList(),
        items: items.map((i) => i.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  static MenuContent fromJson(dynamic raw) {
    if (raw is! Map) return MenuContent();

    return MenuContent(
      groups: [
        if (raw['groups'] is List)
          for (final g in raw['groups'] as List)
            if (MenuGroup.tryParse(g) != null) MenuGroup.tryParse(g)!,
      ],
      items: [
        if (raw['items'] is List)
          for (final i in raw['items'] as List)
            if (MenuItem.tryParse(i) != null) MenuItem.tryParse(i)!,
      ],
    );
  }
}

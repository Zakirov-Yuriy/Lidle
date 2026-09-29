/// Предзаказ к брони (29.09.2026).
///
/// Гость выбрал стол и добавляет к нему блюда из меню, товары, услуги и
/// доставку. Витрину отдаёт сервер одним ответом, корзина тоже живёт на
/// сервере: человек набрал с телефона, а подтвердил с планшета.
library;

/// Группа на витрине: «Завтраки», «Салаты», «Горячие закуски».
class PreorderGroup {
  final String key;
  final String name;
  final String? imageUrl;

  const PreorderGroup({required this.key, required this.name, this.imageUrl});

  static PreorderGroup? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final key = '${raw['key'] ?? ''}'.trim();

    if (key.isEmpty) return null;

    return PreorderGroup(
      key: key,
      name: '${raw['name'] ?? ''}'.trim(),
      imageUrl: _url(raw['image_url']),
    );
  }
}

/// Позиция на витрине: блюдо, товар, услуга или способ доставки.
class PreorderPosition {
  final String key;
  final String group;
  final String name;
  final double price;
  final int weight;
  final String description;
  final String? imageUrl;

  /// Порядок, заданный заведением. Сортировка «старое» идёт по нему.
  final int position;

  const PreorderPosition({
    required this.key,
    required this.group,
    required this.name,
    required this.price,
    required this.weight,
    required this.description,
    required this.position,
    this.imageUrl,
  });

  static PreorderPosition? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final key = '${raw['key'] ?? ''}'.trim();

    if (key.isEmpty) return null;

    return PreorderPosition(
      key: key,
      group: '${raw['group'] ?? ''}'.trim(),
      name: '${raw['name'] ?? ''}'.trim(),
      price: _num(raw['price']),
      weight: _num(raw['weight']).toInt(),
      description: '${raw['description'] ?? ''}'.trim(),
      position: _num(raw['position']).toInt(),
      imageUrl: _url(raw['image_url']),
    );
  }
}

/// Блок витрины: один экран «Меню», «Товары», «Услуги» или «Доставка».
///
/// Экранов у блока может быть несколько, и каждый приходит отдельно со своими
/// группами. На витрине они показываются одной полосой.
class PreorderBlock {
  /// menu | product | service | delivery
  final String kind;
  final String title;
  final int blockItemId;
  final List<PreorderGroup> groups;
  final List<PreorderPosition> items;

  const PreorderBlock({
    required this.kind,
    required this.title,
    required this.blockItemId,
    required this.groups,
    required this.items,
  });

  static PreorderBlock? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final kind = '${raw['kind'] ?? ''}'.trim();
    final id = _num(raw['block_item_id']).toInt();

    if (kind.isEmpty || id <= 0) return null;

    return PreorderBlock(
      kind: kind,
      title: '${raw['title'] ?? ''}'.trim(),
      blockItemId: id,
      groups: _list(raw['groups'], PreorderGroup.tryParse),
      items: _list(raw['items'], PreorderPosition.tryParse),
    );
  }

  List<PreorderPosition> ofGroup(String groupKey) =>
      items.where((i) => i.group == groupKey).toList();
}

/// Строка корзины или состава брони.
class PreorderLine {
  final int id;
  final String kind;
  final int blockItemId;
  final String itemKey;
  final String name;
  final String? groupName;
  final String? imageUrl;
  final int weight;
  final double price;
  final int quantity;
  final double sum;

  const PreorderLine({
    required this.id,
    required this.kind,
    required this.blockItemId,
    required this.itemKey,
    required this.name,
    required this.weight,
    required this.price,
    required this.quantity,
    required this.sum,
    this.groupName,
    this.imageUrl,
  });

  /// Ключ позиции на витрине: экран блока плюс ключ внутри него.
  String get slot => '$blockItemId:$itemKey';

  static PreorderLine? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = _num(raw['id']).toInt();

    if (id <= 0) return null;

    return PreorderLine(
      id: id,
      kind: '${raw['kind'] ?? ''}'.trim(),
      blockItemId: _num(raw['block_item_id']).toInt(),
      itemKey: '${raw['item_key'] ?? ''}'.trim(),
      name: '${raw['name'] ?? ''}'.trim(),
      groupName: '${raw['group_name'] ?? ''}'.trim().isEmpty
          ? null
          : '${raw['group_name']}'.trim(),
      imageUrl: _url(raw['image_url']),
      weight: _num(raw['weight']).toInt(),
      price: _num(raw['price']),
      quantity: _num(raw['quantity']).toInt(),
      sum: _num(raw['sum']),
    );
  }
}

/// Счёт: предзаказ, депозит за стол, услуга бронирования.
class PreorderTotals {
  final double itemsTotal;
  final double depositAmount;
  final double feeAmount;
  final double total;
  final int itemsCount;

  const PreorderTotals({
    this.itemsTotal = 0,
    this.depositAmount = 0,
    this.feeAmount = 0,
    this.total = 0,
    this.itemsCount = 0,
  });

  static PreorderTotals fromJson(dynamic raw) {
    if (raw is! Map) return const PreorderTotals();

    return PreorderTotals(
      itemsTotal: _num(raw['items_total']),
      depositAmount: _num(raw['deposit_amount']),
      feeAmount: _num(raw['fee_amount']),
      total: _num(raw['total']),
      itemsCount: _num(raw['items_count']).toInt(),
    );
  }
}

/// Корзина целиком: состав и счёт. Сервер отдаёт её после любого действия,
/// поэтому отдельного запроса за состоянием нет.
class PreorderCart {
  final List<PreorderLine> items;
  final PreorderTotals totals;

  const PreorderCart({this.items = const [], this.totals = const PreorderTotals()});

  bool get isEmpty => items.isEmpty;

  /// Сколько штук этой позиции уже в корзине.
  int quantityOf(int blockItemId, String itemKey) {
    for (final line in items) {
      if (line.blockItemId == blockItemId && line.itemKey == itemKey) {
        return line.quantity;
      }
    }

    return 0;
  }

  /// Строки одного рода: меню отдельно, товары отдельно.
  List<PreorderLine> ofKind(String kind) =>
      items.where((i) => i.kind == kind).toList();

  static PreorderCart fromJson(dynamic raw) {
    if (raw is! Map) return const PreorderCart();

    return PreorderCart(
      items: _list(raw['items'], PreorderLine.tryParse),
      totals: PreorderTotals.fromJson(raw['totals']),
    );
  }
}

/// Разобрать список, выбросив то, что разобрать не удалось: испорченная
/// строка не должна ронять весь экран.
List<T> _list<T>(dynamic raw, T? Function(dynamic) parse) {
  // Не const: в обобщённой функции константный пустой список со свободным
  // типом компилятор не пропускает.
  if (raw is! List) return <T>[];

  final out = <T>[];

  for (final row in raw) {
    final parsed = parse(row);

    if (parsed != null) out.add(parsed);
  }

  return out;
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();

  return double.tryParse('${value ?? ''}') ?? 0;
}

String? _url(dynamic value) {
  final text = '${value ?? ''}'.trim();

  return text.isEmpty ? null : text;
}

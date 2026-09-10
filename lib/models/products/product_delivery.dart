// ============================================================
// Доставка публикации: группы и способы (макет 10.09.2026).
// ============================================================
//
// Устроена так же, как товарные группы и позиции: папка с обложкой, внутри
// карточки. Модели ручные, без кодогенерации, по той же причине, что и у
// публикации: полей мало, а макет пока меняется каждый день.

/// Способ доставки: «Доставка на авто», «от 400 ₽».
class DeliveryOption {
  const DeliveryOption({
    required this.id,
    required this.name,
    this.description = '',
    this.priceFrom,
    this.image,
    this.groupId,
    this.order = 0,
  });

  final int id;
  final String name;

  /// Условия доставки словами: сроки, зона, ограничения по весу.
  final String description;

  /// «от 400 ₽». Пусто означает, что цену продавец не называл: доставка
  /// бывает бесплатной, и выдуманный ноль там хуже пустоты.
  final num? priceFrom;

  final String? image;
  final int? groupId;
  final int order;

  factory DeliveryOption.fromJson(Map<String, dynamic> data) => DeliveryOption(
    id: _int(data['id']) ?? 0,
    name: '${data['name'] ?? ''}',
    description: '${data['description'] ?? ''}',
    priceFrom: _num(data['price_from']),
    image: data['image']?.toString(),
    groupId: _int(data['group_id']),
    order: _int(data['order']) ?? 0,
  );

  /// Строка стоимости для карточки.
  String get priceLabel =>
      priceFrom == null ? 'Стоимость не указана' : 'Стоимость: от ${_money(priceFrom!)} ₽';
}

/// Группа доставки: «Курьер», «Самовывоз».
class DeliveryGroup {
  const DeliveryGroup({
    required this.id,
    required this.name,
    this.image,
    this.order = 0,
    this.optionsCount = 0,
    this.options = const [],
  });

  final int id;
  final String name;
  final String? image;
  final int order;
  final int optionsCount;
  final List<DeliveryOption> options;

  factory DeliveryGroup.fromJson(Map<String, dynamic> data) {
    final raw = data['options'];

    return DeliveryGroup(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      image: data['image']?.toString(),
      order: _int(data['order']) ?? 0,
      optionsCount: _int(data['options_count']) ?? 0,
      options: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(DeliveryOption.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Вся доставка публикации.
///
/// Способы вне групп приходят отдельным списком: группу можно удалить, а
/// способы остаются, и потерять их из виду человек не должен.
class PublicationDelivery {
  const PublicationDelivery({this.groups = const [], this.ungrouped = const []});

  final List<DeliveryGroup> groups;
  final List<DeliveryOption> ungrouped;

  bool get isEmpty => groups.isEmpty && ungrouped.isEmpty;

  int get total =>
      ungrouped.length +
      groups.fold<int>(0, (sum, group) => sum + group.options.length);

  factory PublicationDelivery.fromJson(Map<String, dynamic> data) {
    final groups = data['groups'];
    final loose = data['ungrouped'];

    return PublicationDelivery(
      groups: groups is List
          ? groups
                .whereType<Map<String, dynamic>>()
                .map(DeliveryGroup.fromJson)
                .toList()
          : const [],
      ungrouped: loose is List
          ? loose
                .whereType<Map<String, dynamic>>()
                .map(DeliveryOption.fromJson)
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

/// Цена без хвоста «.0» и с пробелами по три знака.
String _money(num value) {
  final whole = value % 1 == 0 ? value.toInt().toString() : '$value';
  final digits = whole.split('').reversed.toList();
  final grouped = <String>[];

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add(' ');

    grouped.add(digits[i]);
  }

  return grouped.reversed.join();
}

// ============================================================
// "Фильтр витрины продавца"
// ============================================================
//
// Состав панели и выбор человека это две разные вещи, и они здесь разделены
// намеренно (17.09.2026).
//
// [StoreFilterOptions] — что вообще можно выбрать у ЭТОГО продавца: его точки,
// его разделы, его бренды, вилка его цен. Приходит с сервера целиком, потому
// что собрать это на клиенте значит выкачать всю витрину ради списка брендов.
//
// [StoreFilterSelection] — что человек отметил. Переводится в параметры запроса
// одним местом, чтобы товары и объявления спрашивались согласованно и не
// разошлись при первой же правке.

import 'package:flutter/foundation.dart';

/// Пункт списка: точка, раздел или бренд.
@immutable
class StoreFilterOption {
  final int id;
  final String name;

  const StoreFilterOption({required this.id, required this.name});

  factory StoreFilterOption.fromJson(Map<String, dynamic> json) {
    return StoreFilterOption(
      id: int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
    );
  }
}

/// Значение характеристики: «46», «красный», «с принтом».
@immutable
class StoreAttributeValue {
  final int id;
  final String value;

  const StoreAttributeValue({required this.id, required this.value});

  factory StoreAttributeValue.fromJson(Map<String, dynamic> json) {
    return StoreAttributeValue(
      id: int.tryParse('${json['id']}') ?? 0,
      value: '${json['value'] ?? ''}'.trim(),
    );
  }
}

/// Характеристика раздела: размер, цвет, принт и всё прочее.
@immutable
class StoreAttribute {
  final int id;
  final String title;
  final bool isRange;

  /// Можно ли отметить несколько значений сразу.
  ///
  /// У «Размера» и «С принтом» сервер говорит «нет», и панель это соблюдает:
  /// «да» и «нет» разом бессмысленны.
  final bool isMultiple;

  final List<StoreAttributeValue> values;

  const StoreAttribute({
    required this.id,
    required this.title,
    required this.isRange,
    required this.isMultiple,
    required this.values,
  });

  factory StoreAttribute.fromJson(Map<String, dynamic> json) {
    final raw = (json['values'] as List?) ?? const [];

    return StoreAttribute(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}'.trim(),
      isRange: json['is_range'] == true,
      isMultiple: json['is_multiple'] == true,
      values: raw
          .whereType<Map<String, dynamic>>()
          .map(StoreAttributeValue.fromJson)
          .where((v) => v.id != 0 && v.value.isNotEmpty)
          .toList(),
    );
  }

  /// Показывать ли характеристику в панели.
  ///
  /// Диапазоны (рост, объём двигателя) пока не показываем: их поле выглядит
  /// иначе, чем список значений, и делать его наполовину хуже, чем не делать
  /// вовсе. Характеристику без значений показывать тоже не за чем.
  bool get isSelectable => !isRange && values.isNotEmpty && title.isNotEmpty;
}

/// Способ получения: самовывоз или доставка.
@immutable
class StoreDeliveryOption {
  final String key;
  final String title;
  final bool available;

  const StoreDeliveryOption({
    required this.key,
    required this.title,
    required this.available,
  });

  factory StoreDeliveryOption.fromJson(Map<String, dynamic> json) {
    return StoreDeliveryOption(
      key: '${json['key'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      available: json['available'] != false,
    );
  }
}

/// Вариант оценки: «от 5», «от 4».
@immutable
class StoreRatingOption {
  final int value;
  final String title;

  const StoreRatingOption({required this.value, required this.title});

  factory StoreRatingOption.fromJson(Map<String, dynamic> json) {
    return StoreRatingOption(
      value: int.tryParse('${json['value']}') ?? 0,
      title: '${json['title'] ?? ''}'.trim(),
    );
  }
}

/// Что вообще можно выбрать у этого продавца.
@immutable
class StoreFilterOptions {
  final List<StoreFilterOption> shops;
  final List<StoreFilterOption> categories;
  final List<StoreFilterOption> brands;
  final double? priceMin;
  final double? priceMax;
  final List<StoreDeliveryOption> delivery;
  final List<StoreRatingOption> ratings;
  final List<StoreAttribute> attributes;

  const StoreFilterOptions({
    this.shops = const [],
    this.categories = const [],
    this.brands = const [],
    this.priceMin,
    this.priceMax,
    this.delivery = const [],
    this.ratings = const [],
    this.attributes = const [],
  });

  static List<StoreFilterOption> _options(dynamic raw) {
    return ((raw as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StoreFilterOption.fromJson)
        .where((o) => o.id != 0 && o.name.isNotEmpty)
        .toList();
  }

  factory StoreFilterOptions.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] is Map)
        ? Map<String, dynamic>.from(json['price'] as Map)
        : <String, dynamic>{};

    return StoreFilterOptions(
      shops: _options(json['shops']),
      categories: _options(json['categories']),
      brands: _options(json['brands']),
      priceMin: double.tryParse('${price['min']}'),
      priceMax: double.tryParse('${price['max']}'),
      delivery: ((json['delivery'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StoreDeliveryOption.fromJson)
          .where((d) => d.key.isNotEmpty && d.available)
          .toList(),
      ratings: ((json['ratings'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StoreRatingOption.fromJson)
          .where((r) => r.value > 0)
          .toList(),
      attributes: ((json['attributes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StoreAttribute.fromJson)
          .where((a) => a.isSelectable)
          .toList(),
    );
  }

  /// Есть ли вообще что показывать. У продавца с двумя объявлениями панель
  /// может оказаться пустой, и тогда честнее сказать об этом, чем открыть
  /// пустой экран.
  bool get isEmpty =>
      shops.isEmpty &&
      categories.isEmpty &&
      brands.isEmpty &&
      attributes.isEmpty &&
      delivery.isEmpty &&
      ratings.isEmpty &&
      priceMin == null &&
      priceMax == null;
}

/// Что человек отметил в панели.
@immutable
class StoreFilterSelection {
  final Set<int> shopIds;
  final int? categoryId;
  final Set<int> brandIds;
  final double? priceMin;
  final double? priceMax;

  /// Отмеченные значения характеристик: размер, цвет, принт.
  final Set<int> attributeValueIds;

  final int? ratingMin;

  /// `pickup` или `courier`.
  final String? delivery;

  const StoreFilterSelection({
    this.shopIds = const {},
    this.categoryId,
    this.brandIds = const {},
    this.priceMin,
    this.priceMax,
    this.attributeValueIds = const {},
    this.ratingMin,
    this.delivery,
  });

  bool get isEmpty =>
      shopIds.isEmpty &&
      categoryId == null &&
      brandIds.isEmpty &&
      priceMin == null &&
      priceMax == null &&
      attributeValueIds.isEmpty &&
      ratingMin == null &&
      delivery == null;

  bool get isNotEmpty => !isEmpty;

  /// Сколько условий выбрано. Показывается числом на значке фильтра.
  int get count {
    var total = 0;

    if (shopIds.isNotEmpty) total++;
    if (categoryId != null) total++;
    if (brandIds.isNotEmpty) total++;
    if (priceMin != null || priceMax != null) total++;
    if (attributeValueIds.isNotEmpty) total++;
    if (ratingMin != null) total++;
    if (delivery != null) total++;

    return total;
  }

  StoreFilterSelection copyWith({
    Set<int>? shopIds,
    int? categoryId,
    bool clearCategory = false,
    Set<int>? brandIds,
    double? priceMin,
    bool clearPriceMin = false,
    double? priceMax,
    bool clearPriceMax = false,
    Set<int>? attributeValueIds,
    int? ratingMin,
    bool clearRating = false,
    String? delivery,
    bool clearDelivery = false,
  }) {
    return StoreFilterSelection(
      shopIds: shopIds ?? this.shopIds,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      brandIds: brandIds ?? this.brandIds,
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      attributeValueIds: attributeValueIds ?? this.attributeValueIds,
      ratingMin: clearRating ? null : (ratingMin ?? this.ratingMin),
      delivery: clearDelivery ? null : (delivery ?? this.delivery),
    );
  }

  /// Параметры для запроса ТОВАРОВ.
  ///
  /// Списки уходят в том виде, в каком их ждёт сервер: `shop_ids[]=1&…`.
  /// Собирается здесь, а не на экране: два места сборки однажды разойдутся.
  String toProductsQuery() {
    final parts = <String>[];

    for (final id in shopIds) {
      parts.add('shop_ids[]=$id');
    }

    if (categoryId != null) parts.add('category_id=$categoryId');

    for (final id in brandIds) {
      parts.add('brand_id[]=$id');
    }

    if (priceMin != null) parts.add('price_min=${_money(priceMin!)}');
    if (priceMax != null) parts.add('price_max=${_money(priceMax!)}');

    for (final id in attributeValueIds) {
      parts.add('attributes[value_selected][]=$id');
    }

    if (ratingMin != null) parts.add('rating_min=$ratingMin');
    if (delivery != null) parts.add('delivery=$delivery');

    return parts.isEmpty ? '' : '&${parts.join('&')}';
  }

  /// Тело запроса ОБЪЯВЛЕНИЙ.
  ///
  /// У объявления нет ни бренда, ни размера, ни цвета, поэтому к ним применимы
  /// только раздел и цена. Остальное сюда не кладём: сервер такие поля не
  /// примет, а молча отбросить их значит обещать человеку отбор, которого нет.
  Map<String, dynamic> toAdvertsBody() {
    return <String, dynamic>{
      if (categoryId != null) 'category_id': categoryId,
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
    };
  }

  /// Применимы ли выбранные условия к объявлениям вообще.
  ///
  /// Выбрали бренд или размер — объявления показывать нельзя: у них таких
  /// полей нет, и оставить их в выдаче значит показать вещи, которые условию
  /// не отвечают.
  bool get keepsAdverts =>
      shopIds.isEmpty &&
      brandIds.isEmpty &&
      attributeValueIds.isEmpty &&
      ratingMin == null &&
      delivery == null;

  static String _money(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }
}

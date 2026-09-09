// ============================================================
// Публикация товаров, группы и бренды (макет 09.09.2026).
// ============================================================
//
// Модели ручные, без кодогенерации: полей мало, а freezed здесь дал бы ещё
// два сгенерированных файла на каждое изменение макета, который пока
// меняется каждый день.

/// Группа позиций внутри публикации: «Куртки зима».
class ProductGroup {
  const ProductGroup({
    required this.id,
    required this.name,
    this.image,
    this.order = 0,
    this.productsCount = 0,
    this.products = const [],
  });

  final int id;
  final String name;

  /// Обложка группы. Приходит готовой ссылкой.
  final String? image;

  final int order;

  /// Сколько позиций в группе. Считает сервер: выкачивать позиции ради
  /// цифры под обложкой незачем.
  final int productsCount;

  /// Позиции. Приезжают только когда запрошена публикация целиком.
  final List<ProductPosition> products;

  factory ProductGroup.fromJson(Map<String, dynamic> data) {
    final raw = data['products'];

    return ProductGroup(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      image: data['image']?.toString(),
      order: _int(data['order']) ?? 0,
      productsCount: _int(data['products_count']) ?? 0,
      products: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(ProductPosition.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Позиция: тот же товар, что лежит на витрине.
///
/// Здесь только то, что показывает экран группы: картинка, название, цена,
/// размер и цвет. Полная карточка товара живёт в `ProductItem`.
class ProductPosition {
  const ProductPosition({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.position,
    this.size,
    this.color,
    this.stockQuantity = 0,
  });

  final int id;
  final String name;
  final num price;
  final String? image;

  /// «Номер позиции» с макета.
  final int? position;

  final String? size;
  final String? color;
  final int stockQuantity;

  factory ProductPosition.fromJson(Map<String, dynamic> data) {
    final images = data['images'];

    return ProductPosition(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      price: _num(data['price']) ?? 0,
      image: data['image']?.toString().isNotEmpty == true
          ? data['image'].toString()
          : (images is List && images.isNotEmpty ? '${images.first}' : null),
      position: _int(data['position']),
      stockQuantity: _int(data['stock_quantity']) ?? 0,
    );
  }
}

/// Публикация: экран «Добавить товар» целиком.
class ProductPublication {
  const ProductPublication({
    required this.id,
    required this.categoryId,
    this.categoryName = '',
    this.categoryPath = '',
    this.brandId,
    this.brandName,
    this.shopId,
    this.shopName,
    this.isAutoRenew = false,
    this.isPublished = false,
    this.groups = const [],
    this.needsShop = false,
  });

  final int id;

  final int categoryId;
  final String categoryName;

  /// «Одежда / Верхняя / Куртки» — строка под названием раздела.
  final String categoryPath;

  final int? brandId;
  final String? brandName;

  /// Точка продаж. Пусто означает, что выбрать её придётся до публикации:
  /// заказы приходят в точку.
  final int? shopId;
  final String? shopName;

  final bool isAutoRenew;
  final bool isPublished;

  final List<ProductGroup> groups;

  /// Сервер не смог выбрать точку сам: у продавца их несколько.
  final bool needsShop;

  factory ProductPublication.fromJson(
    Map<String, dynamic> data, {
    bool needsShop = false,
  }) {
    final category = data['category'];
    final brand = data['brand'];
    final shop = data['shop'];
    final groups = data['groups'];

    return ProductPublication(
      id: _int(data['id']) ?? 0,
      categoryId: category is Map ? (_int(category['id']) ?? 0) : 0,
      categoryName: category is Map ? '${category['name'] ?? ''}' : '',
      categoryPath: category is Map ? '${category['path'] ?? ''}' : '',
      brandId: brand is Map ? _int(brand['id']) : null,
      brandName: brand is Map ? '${brand['name'] ?? ''}' : null,
      shopId: shop is Map ? _int(shop['id']) : null,
      shopName: shop is Map ? '${shop['name'] ?? ''}' : null,
      isAutoRenew: data['is_auto_renew'] == true,
      isPublished: data['is_published'] == true,
      groups: groups is List
          ? groups
                .whereType<Map<String, dynamic>>()
                .map(ProductGroup.fromJson)
                .toList()
          : const [],
      needsShop: needsShop,
    );
  }

  ProductPublication copyWith({
    int? brandId,
    String? brandName,
    bool? isAutoRenew,
    List<ProductGroup>? groups,
  }) {
    return ProductPublication(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryPath: categoryPath,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      shopId: shopId,
      shopName: shopName,
      isAutoRenew: isAutoRenew ?? this.isAutoRenew,
      isPublished: isPublished,
      groups: groups ?? this.groups,
      needsShop: needsShop,
    );
  }
}

/// Бренд из справочника.
class ProductBrand {
  const ProductBrand({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductBrand.fromJson(Map<String, dynamic> data) => ProductBrand(
    id: _int(data['id']) ?? 0,
    name: '${data['name'] ?? ''}',
  );
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

/// Товар в витрине и в карточке.
///
/// Одна модель на оба случая намеренно. Список приходит короче карточки, и
/// недостающие поля остаются пустыми: две почти одинаковые модели разъехались
/// бы на первой же правке, а разница между ними всего в описании и картинках.
class ProductItem {
  final int id;
  final String name;
  final String? slug;
  final String? sku;

  /// Цена приходит строкой (`"4900.00"`): у денег на сервере decimal, и
  /// превращать её в double по дороге значит однажды получить 4899.9999.
  final String price;

  final String? image;
  final List<String> images;

  final int stockQuantity;
  final bool inStock;

  final String? description;

  final int? categoryId;
  final BrandBrief? brand;
  final ShopBrief? shop;

  /// Оценка и число отзывов. `rating` пустой, если отзывов ещё нет: ноль
  /// означал бы плохую оценку, а не отсутствие оценок.
  final double? rating;
  final int reviewsCount;

  /// Время приготовления, для еды. Пустое у обычных товаров.
  final int? cookingTimeMinutes;

  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    required this.inStock,
    this.slug,
    this.sku,
    this.image,
    this.images = const [],
    this.description,
    this.categoryId,
    this.brand,
    this.shop,
    this.rating,
    this.reviewsCount = 0,
    this.cookingTimeMinutes,
  });

  factory ProductItem.fromJson(Map<String, dynamic> data) {
    return ProductItem(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      slug: data['slug']?.toString(),
      sku: data['sku']?.toString(),
      price: '${data['price'] ?? '0'}',
      image: data['image']?.toString(),
      images: data['images'] is List
          ? (data['images'] as List).map((e) => '$e').toList()
          : const [],
      stockQuantity: _int(data['stock_quantity']) ?? 0,
      inStock: data['in_stock'] == true || (_int(data['stock_quantity']) ?? 0) > 0,
      description: data['description']?.toString(),
      categoryId: _int(data['category_id']),
      brand: BrandBrief.tryParse(data['brand']),
      shop: ShopBrief.tryParse(data['shop']),
      rating: _double(data['rating']),
      reviewsCount: _int(data['reviews_count']) ?? 0,
      cookingTimeMinutes: _int(data['cooking_time_minutes']),
    );
  }

  /// Цена в виде «4 900 ₽». Разряды разделяем пробелом: длинные числа без
  /// разделителя читаются с трудом, а именно по цене человек и выбирает.
  String get priceLabel {
    final value = double.tryParse(price) ?? 0;
    final whole = value.truncate().toString();

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class BrandBrief {
  final int id;
  final String name;
  final String? image;

  const BrandBrief({required this.id, required this.name, this.image});

  static BrandBrief? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = ProductItem._int(raw['id']);
    if (id == null) return null;

    return BrandBrief(
      id: id,
      name: '${raw['name'] ?? ''}',
      image: raw['image']?.toString(),
    );
  }
}

class ShopBrief {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;

  const ShopBrief({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
  });

  static ShopBrief? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = ProductItem._int(raw['id']);
    if (id == null) return null;

    return ShopBrief(
      id: id,
      name: '${raw['name'] ?? ''}',
      address: raw['address']?.toString(),
      phone: raw['phone']?.toString(),
      isActive: raw['is_active'] != false,
    );
  }
}

/// Раздел каталога товаров.
///
/// Дерево приходит с сервера готовым: собирать его на клиенте из плоского
/// списка значит повторять одну работу в приложении, на сайте и в админке.
class ProductCategory {
  final int id;
  final String name;
  final String? slug;
  final String? image;

  /// Конечная категория: товары висят на них. Неконечную сервер разворачивает
  /// сам, поэтому нажимать можно на любую.
  final bool isEndpoint;

  final List<ProductCategory> children;

  const ProductCategory({
    required this.id,
    required this.name,
    this.slug,
    this.image,
    this.isEndpoint = false,
    this.children = const [],
  });

  factory ProductCategory.fromJson(Map<String, dynamic> data) {
    final raw = data['children'] ?? data['categories'];

    return ProductCategory(
      id: ProductItem._int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      slug: data['slug']?.toString(),
      image: data['image']?.toString(),
      isEndpoint: data['is_endpoint'] == true,
      children: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(ProductCategory.fromJson)
                .toList()
          : const [],
    );
  }

  bool get hasChildren => children.isNotEmpty;
}

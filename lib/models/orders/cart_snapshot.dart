/// Корзина с сервера, разложенная по точкам продавца.
///
/// Имена `CartSnapshot` и `CartLine`, а не `CartState` и `CartItem`,
/// намеренно: в `lib/features/cart` лежит старая корзина-макет с такими
/// именами. Она держит товары в памяти, собирает их из объявлений и с
/// сервером не разговаривает вовсе. Её надо снять, когда новые экраны
/// заменят её целиком, а до тех пор имена не должны сталкиваться.
///
/// Раскладка приходит с сервера не для красоты: товары разных точек станут
/// РАЗНЫМИ заказами, у каждого свой код получения и своя выдача. Человек
/// должен увидеть это до оформления, а не после.
class CartSnapshot {
  final List<CartShopGroup> shops;
  final int itemsCount;
  final double total;

  /// Токен гостевой корзины. Приходит только тому, кто не вошёл в аккаунт.
  final String? cartToken;

  const CartSnapshot({
    required this.shops,
    required this.itemsCount,
    required this.total,
    this.cartToken,
  });

  factory CartSnapshot.empty() =>
      const CartSnapshot(shops: [], itemsCount: 0, total: 0);

  factory CartSnapshot.fromJson(Map<String, dynamic> data) {
    final shops = data['shops'];

    return CartSnapshot(
      shops: shops is List
          ? shops
                .whereType<Map<String, dynamic>>()
                .map(CartShopGroup.fromJson)
                .toList()
          : const [],
      itemsCount: _int(data['items_count']) ?? 0,
      total: _double(data['total']) ?? 0,
      cartToken: data['cart_token']?.toString(),
    );
  }

  bool get isEmpty => shops.isEmpty;

  /// Есть ли позиции, которые нельзя купить прямо сейчас.
  ///
  /// Они остаются в списке намеренно: молча выкинуть их значит заставить
  /// человека гадать, куда делся товар.
  bool get hasUnavailable =>
      shops.any((shop) => shop.items.any((item) => !item.isAvailable));

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

class CartShopGroup {
  final int shopId;
  final String shopName;
  final String? address;
  final String? phone;
  final bool shopIsActive;

  final List<CartLine> items;
  final double total;

  /// Сколько готовить весь заказ, для еды. Это МАКСИМУМ по позициям, а не
  /// сумма: на кухне готовят параллельно.
  final int? cookingTimeMinutes;

  const CartShopGroup({
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.total,
    this.address,
    this.phone,
    this.shopIsActive = true,
    this.cookingTimeMinutes,
  });

  factory CartShopGroup.fromJson(Map<String, dynamic> data) {
    final shop = data['shop'];
    final items = data['items'];

    return CartShopGroup(
      shopId: shop is Map ? (CartSnapshot._int(shop['id']) ?? 0) : 0,
      shopName: shop is Map ? '${shop['name'] ?? ''}' : '',
      address: shop is Map ? shop['address']?.toString() : null,
      phone: shop is Map ? shop['phone']?.toString() : null,
      shopIsActive: shop is Map ? shop['is_active'] != false : true,
      items: items is List
          ? items.whereType<Map<String, dynamic>>().map(CartLine.fromJson).toList()
          : const [],
      total: CartSnapshot._double(data['total']) ?? 0,
      cookingTimeMinutes: CartSnapshot._int(data['cooking_time_minutes']),
    );
  }
}

class CartLine {
  final int productId;
  final String name;
  final String? image;
  final String price;
  final int quantity;
  final double sum;
  final int stockQuantity;

  final bool isAvailable;

  /// Почему купить нельзя. Текст приходит с сервера готовым к показу.
  final String? unavailableReason;

  const CartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.sum,
    required this.stockQuantity,
    required this.isAvailable,
    this.image,
    this.unavailableReason,
  });

  factory CartLine.fromJson(Map<String, dynamic> data) {
    return CartLine(
      productId: CartSnapshot._int(data['product_id']) ?? 0,
      name: '${data['name'] ?? ''}',
      image: data['image']?.toString(),
      price: '${data['price'] ?? '0'}',
      quantity: CartSnapshot._int(data['quantity']) ?? 1,
      sum: CartSnapshot._double(data['sum']) ?? 0,
      stockQuantity: CartSnapshot._int(data['stock_quantity']) ?? 0,
      isAvailable: data['is_available'] != false,
      unavailableReason: data['unavailable_reason']?.toString(),
    );
  }
}

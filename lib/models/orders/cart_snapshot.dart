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

  /// Сколько всего позиций лежит в корзине, включая недоступные. Это число
  /// для значка на корзине: человек положил их туда, и они там есть.
  final int itemsCount;

  /// Сколько позиций реально уйдёт в заказ. Это число про деньги.
  ///
  /// Разделено с `itemsCount` намеренно (задача 69). Одним числом получалась
  /// картина «одна позиция за 1290 рублей, итого 0 рублей»: сумма считает
  /// только доступное, а счётчик считал всё, и человек видел просто неверный
  /// подсчёт.
  final int availableItemsCount;

  final int unavailableItemsCount;

  /// Сумма к оплате в точке. Ноль при непустой корзине означает «заказать
  /// сейчас нечего», и экран обязан сказать это словами.
  final double total;

  /// Можно ли оформлять. Приходит с сервера готовым, чтобы приложение и сайт
  /// не выводили это правило каждый по-своему.
  final bool canCheckout;

  /// Токен гостевой корзины. Приходит только тому, кто не вошёл в аккаунт.
  final String? cartToken;

  /// Контакты для подстановки в форму оформления: то, чем этот покупатель
  /// оформлял в прошлый раз, иначе профиль. Может быть пусто, если он ещё
  /// ничего не заказывал и не вошёл.
  final CartContacts contacts;

  /// Предупреждение об оплате и подпись к галочке подтверждения.
  ///
  /// Текст приходит с сервера, а не зашит в приложении: он один для сайта и
  /// приложения, и переписывать его в двух местах значит однажды переписать
  /// в одном.
  final CartPaymentNotice payment;

  const CartSnapshot({
    required this.shops,
    required this.itemsCount,
    required this.total,
    this.availableItemsCount = 0,
    this.unavailableItemsCount = 0,
    this.canCheckout = false,
    this.cartToken,
    this.contacts = const CartContacts(),
    this.payment = const CartPaymentNotice(),
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

      // Старый сервер этих полей не присылает. Тогда считаем, что доступно
      // всё: так вело себя приложение до задачи 69, и это лучше, чем
      // заблокировать оформление из-за отсутствующего поля.
      availableItemsCount:
          _int(data['available_items_count']) ?? _int(data['items_count']) ?? 0,
      unavailableItemsCount: _int(data['unavailable_items_count']) ?? 0,
      canCheckout: data['can_checkout'] is bool
          ? data['can_checkout'] as bool
          : (_double(data['total']) ?? 0) > 0,

      total: _double(data['total']) ?? 0,
      cartToken: data['cart_token']?.toString(),
      contacts: CartContacts.fromJson(data['contacts']),
      payment: CartPaymentNotice.fromJson(data['payment']),
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

/// Контакты покупателя, которые сервер предлагает подставить.
///
/// Комментария здесь нет намеренно: он относится к конкретному заказу, и
/// подставить вчерашнее «без лука» в сегодняшний значит молча передать
/// продавцу чужую просьбу.
class CartContacts {
  final String? name;
  final String? phone;
  final String? email;

  const CartContacts({this.name, this.phone, this.email});

  factory CartContacts.fromJson(dynamic data) {
    if (data is! Map) return const CartContacts();

    return CartContacts(
      name: _text(data['name']),
      phone: _text(data['phone']),
      email: _text(data['email']),
    );
  }

  bool get isEmpty => name == null && phone == null && email == null;

  /// Пустую строку считаем отсутствием значения: подставленный пробел
  /// выглядит как заполненное поле и только мешает.
  static String? _text(dynamic value) {
    if (value == null) return null;

    final text = '$value'.trim();

    return text.isEmpty ? null : text;
  }
}

class CartShopGroup {
  final int shopId;
  final String shopName;
  final String? address;
  final String? phone;
  final bool shopIsActive;

  /// Куда платить этой точке: список способов с реквизитами.
  ///
  /// Показывается ДО оформления, а не после: деньги идут продавцу напрямую,
  /// мимо площадки, и вернуть их мы не сможем.
  final List<CartPaymentMethod> paymentMethods;

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
    this.paymentMethods = const [],
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
      paymentMethods: shop is Map && shop['payment_details'] is List
          ? (shop['payment_details'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CartPaymentMethod.fromJson)
                .where((method) => method.type.isNotEmpty)
                .toList()
          : const [],
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

/// Предупреждение об оплате: текст и подпись к галочке.
///
/// Пустые значения означают старый сервер, который этого блока не присылает.
/// Тогда галочка не показывается и не требуется: ломать оформление из-за
/// отсутствующего поля нельзя.
class CartPaymentMethod {
  final String type;
  final Map<String, String> fields;

  const CartPaymentMethod({required this.type, this.fields = const {}});

  factory CartPaymentMethod.fromJson(Map<String, dynamic> data) {
    final fields = <String, String>{};

    data.forEach((key, value) {
      if (key == 'type') return;
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) fields[key] = text;
    });

    return CartPaymentMethod(
      type: '${data['type'] ?? ''}'.trim(),
      fields: fields,
    );
  }

  /// Название способа по-русски. Незнакомый вид показываем как есть: лучше
  /// непонятное слово, чем пустая строка вместо способа оплаты.
  String get title {
    switch (type) {
      case 'cash':
        return 'Наличными';
      case 'card':
        return 'Переводом на карту';
      case 'sbp':
        return 'По СБП';
      case 'account':
        return 'На расчётный счёт';
      default:
        return type;
    }
  }

  /// Подпись поля реквизита.
  static String fieldTitle(String key) {
    switch (key) {
      case 'phone':
        return 'Телефон';
      case 'bank':
        return 'Банк';
      case 'number':
        return 'Номер карты';
      case 'holder':
        return 'Получатель';
      case 'account':
        return 'Счёт';
      case 'bic':
        return 'БИК';
      case 'inn':
        return 'ИНН';
      case 'comment':
        return 'Комментарий';
      default:
        return key;
    }
  }
}

class CartPaymentNotice {
  final String notice;
  final String confirmLabel;

  /// Требует ли сервер галочку. Старый сервер поля не присылает, и тогда
  /// оформление работает как раньше.
  final bool required;

  const CartPaymentNotice({
    this.notice = '',
    this.confirmLabel = '',
    this.required = false,
  });

  factory CartPaymentNotice.fromJson(dynamic data) {
    if (data is! Map) return const CartPaymentNotice();

    return CartPaymentNotice(
      notice: '${data['notice'] ?? ''}'.trim(),
      confirmLabel: '${data['confirm_label'] ?? ''}'.trim(),
      required: data['required'] == true,
    );
  }

  bool get isEmpty => notice.isEmpty && confirmLabel.isEmpty;
}

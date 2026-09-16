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

  /// Корзина из отмеченных позиций (14.09.2026).
  ///
  /// Нужна экрану оформления: он показывает состав и сумму, и если человек
  /// выбрал галочками две позиции из пяти, показывать ему сумму всей корзины
  /// значит соврать о том, сколько он сейчас заплатит.
  ///
  /// Суммы пересчитываем ЗДЕСЬ, хотя обычно их считает сервер. Причина:
  /// выбор живёт на экране и до оформления серверу не известен, а спрашивать
  /// корзину заново на каждую галочку значит ждать сеть при каждом нажатии.
  /// Итог заказа всё равно посчитает сервер, здесь мы показываем ожидание.
  ///
  /// Недоступные позиции в подсчёт не идут: их нельзя купить, и в сумме их
  /// нет и у сервера.
  CartSnapshot onlyProducts(Set<int> productIds) {
    if (productIds.isEmpty) return CartSnapshot.empty();

    final groups = <CartShopGroup>[];
    var items = 0;
    var available = 0;
    var unavailable = 0;
    var sum = 0.0;

    for (final shop in shops) {
      final lines =
          shop.items.where((line) => productIds.contains(line.productId)).toList();

      if (lines.isEmpty) continue;

      var shopSum = 0.0;

      for (final line in lines) {
        items++;

        if (line.isAvailable) {
          available++;
          shopSum += line.sum;
        } else {
          unavailable++;
        }
      }

      sum += shopSum;

      groups.add(
        CartShopGroup(
          shopId: shop.shopId,
          shopName: shop.shopName,
          address: shop.address,
          phone: shop.phone,
          shopIsActive: shop.shopIsActive,
          cookingTimeMinutes: shop.cookingTimeMinutes,
          paymentMethods: shop.paymentMethods,

          // Способы получения переносим как есть. Их легко потерять: здесь
          // группа собирается заново, и всё, что не перечислено явно,
          // подставляется пустым. Именно так выбор доставки и пропадал с
          // экрана оформления, хотя сервер его присылал: экран получает не
          // корзину целиком, а отобранные галочками позиции.
          deliveryOptions: shop.deliveryOptions,

          items: lines,
          total: shopSum,
        ),
      );
    }

    return CartSnapshot(
      shops: groups,
      itemsCount: items,
      availableItemsCount: available,
      unavailableItemsCount: unavailable,
      total: sum,
      canCheckout: available > 0,
      cartToken: cartToken,
      contacts: contacts,
      payment: payment,
    );
  }

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

  /// Как можно получить заказ из этой точки (16.09.2026): самовывоз всегда
  /// плюс доставка, которую продавец завёл в публикациях этих товаров.
  final List<CartDeliveryOption> deliveryOptions;

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
    this.deliveryOptions = const [],
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
      // Новый сервер присылает готовый список способов у группы. Старый
      // присылал только реквизиты внутри точки, и тогда разбираем их: иначе
      // на обновлённом приложении со старым сервером блок оплаты опустеет.
      paymentMethods: data['payment_methods'] is List
          ? (data['payment_methods'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CartPaymentMethod.fromJson)
                .where((method) => method.key.isNotEmpty)
                .toList()
          : (shop is Map && shop['payment_details'] is List
                ? (shop['payment_details'] as List)
                      .whereType<Map<String, dynamic>>()
                      .map(CartPaymentMethod.fromLegacy)
                      .where((method) => method.key.isNotEmpty)
                      .toList()
                : const []),
      items: items is List
          ? items.whereType<Map<String, dynamic>>().map(CartLine.fromJson).toList()
          : const [],
      total: CartSnapshot._double(data['total']) ?? 0,
      cookingTimeMinutes: CartSnapshot._int(data['cooking_time_minutes']),
      // Старый сервер списка не присылает: тогда остаётся один самовывоз, как
      // было до появления доставки.
      deliveryOptions: data['delivery_options'] is List
          ? (data['delivery_options'] as List)
              .whereType<Map<String, dynamic>>()
              .map(CartDeliveryOption.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Способ получения заказа.
///
/// Цена здесь для показа. При оформлении клиент присылает только номер
/// способа, а цену подставляет сервер: иначе её можно было бы назначить себе
/// самому прямо в запросе (16.09.2026).
class CartDeliveryOption {
  /// Пусто у самовывоза: он не строка справочника, а исходный способ.
  final int? id;

  /// `pickup` или `courier`.
  final String type;

  final String name;
  final String? description;
  final double price;

  const CartDeliveryOption({
    required this.type,
    required this.name,
    this.id,
    this.description,
    this.price = 0,
  });

  factory CartDeliveryOption.fromJson(Map<String, dynamic> data) =>
      CartDeliveryOption(
        id: CartSnapshot._int(data['id']),
        type: '${data['type'] ?? 'courier'}',
        name: '${data['name'] ?? ''}',
        description: data['description']?.toString(),
        price: CartSnapshot._double(data['price']) ?? 0,
      );

  bool get isCourier => type == 'courier';
}

class CartLine {
  final int productId;

  /// Номер МОДЕЛИ (15.09.2026).
  ///
  /// В корзине лежит вариант — красная 46-го, — а сердечко ставится на вещь
  /// целиком, как и отзывы. Сохраняли бы вариант, в избранном оказалось бы
  /// пять одинаковых курток разного размера.
  ///
  /// У старого сервера поля нет: тогда это тот же номер, что и у позиции.
  final int modelId;

  final String name;

  /// «красный, 46» — какой именно вариант лежит в корзине. Пусто у товара без
  /// вариантов.
  final String variantLabel;

  final String? image;
  final String price;
  final int quantity;
  final double sum;
  final int stockQuantity;

  final bool isAvailable;

  /// Почему купить нельзя. Текст приходит с сервера готовым к показу.
  final String? unavailableReason;

  /// Сердечко: лежит ли МОДЕЛЬ в избранном и под каким номером записи.
  final bool isWishlisted;
  final int? wishlistId;

  const CartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.sum,
    required this.stockQuantity,
    required this.isAvailable,
    int? modelId,
    this.variantLabel = '',
    this.image,
    this.unavailableReason,
    this.isWishlisted = false,
    this.wishlistId,
  }) : modelId = modelId ?? productId;

  factory CartLine.fromJson(Map<String, dynamic> data) {
    final productId = CartSnapshot._int(data['product_id']) ?? 0;

    return CartLine(
      productId: productId,
      modelId: CartSnapshot._int(data['model_id']) ?? productId,
      name: '${data['name'] ?? ''}',
      variantLabel: '${data['variant_label'] ?? ''}'.trim(),
      image: data['image']?.toString(),
      price: '${data['price'] ?? '0'}',
      quantity: CartSnapshot._int(data['quantity']) ?? 1,
      sum: CartSnapshot._double(data['sum']) ?? 0,
      stockQuantity: CartSnapshot._int(data['stock_quantity']) ?? 0,
      isAvailable: data['is_available'] != false,
      unavailableReason: data['unavailable_reason']?.toString(),
      isWishlisted: data['is_wishlisted'] == true,
      wishlistId: CartSnapshot._int(data['wishlist_id']),
    );
  }
}

/// Способ оплаты, который принимает точка.
///
/// С 15.09.2026 список приходит ГРУППОЙ, а не внутри точки, и собирается на
/// сервере из двух мест сразу: того, что продавец отметил в кабинете, и
/// старых реквизитов точки. Покупатель выбирает из этого списка один способ,
/// и выбор уходит в заказ.
///
/// Разбор старой формы (`shop.payment_details`) оставлен намеренно: если
/// приложение обновится раньше сервера, человек должен увидеть реквизиты, а
/// не пустой блок.
class CartPaymentMethod {
  /// Ключ справочника: `cash`, `card`, `sbp`, `bank_transfer` и так далее.
  final String key;

  final String title;

  /// Пояснение под названием. У наличных это «платите при получении».
  final String hint;

  /// Реквизиты строками «подпись: значение», уже готовые к показу.
  final List<CartPaymentField> fields;

  /// Нужна ли галочка «я понимаю, что перевожу деньги продавцу напрямую».
  ///
  /// У наличных не нужна: денег заранее никто не переводит. Решает сервер, а
  /// не приложение, иначе сайт и приложение однажды решат по-разному.
  final bool needsAcknowledgement;

  const CartPaymentMethod({
    required this.key,
    required this.title,
    this.hint = '',
    this.fields = const [],
    this.needsAcknowledgement = true,
  });

  factory CartPaymentMethod.fromJson(Map<String, dynamic> data) {
    final fields = data['fields'];

    return CartPaymentMethod(
      key: '${data['key'] ?? ''}'.trim(),
      title: '${data['title'] ?? ''}'.trim(),
      hint: '${data['hint'] ?? ''}'.trim(),
      fields: fields is List
          ? fields
                .whereType<Map<String, dynamic>>()
                .map(CartPaymentField.fromJson)
                .where((field) => field.value.isNotEmpty)
                .toList()
          : const [],
      needsAcknowledgement: data['needs_acknowledgement'] != false,
    );
  }

  /// Старая форма: строка реквизитов точки со своим набором полей.
  factory CartPaymentMethod.fromLegacy(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}'.trim();
    final fields = <CartPaymentField>[];

    data.forEach((key, value) {
      if (key == 'type') return;

      final text = '${value ?? ''}'.trim();

      if (text.isNotEmpty) {
        fields.add(CartPaymentField(label: fieldTitle(key), value: text));
      }
    });

    return CartPaymentMethod(
      key: type,
      title: legacyTitle(type),
      fields: fields,
      needsAcknowledgement: type != 'cash',
    );
  }

  bool get isCash => key == 'cash';

  /// Название способа по-русски для старой формы. Незнакомый вид показываем
  /// как есть: лучше непонятное слово, чем пустая строка вместо способа.
  static String legacyTitle(String type) {
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

  /// Подпись поля реквизита в старой форме.
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

/// Одна строка реквизитов: подпись и значение, оба с сервера.
class CartPaymentField {
  final String label;
  final String value;

  const CartPaymentField({required this.label, required this.value});

  factory CartPaymentField.fromJson(Map<String, dynamic> data) {
    return CartPaymentField(
      label: '${data['label'] ?? ''}'.trim(),
      value: '${data['value'] ?? ''}'.trim(),
    );
  }
}

class CartPaymentNotice {
  final String notice;
  final String confirmLabel;

  /// Требует ли сервер галочку. Старый сервер поля не присылает, и тогда
  /// оформление работает как раньше.
  final bool required;

  /// Заголовок блока выбора способа оплаты.
  final String title;

  /// Что показать вместо галочки, когда выбраны наличные (15.09.2026).
  final String cashNotice;

  const CartPaymentNotice({
    this.notice = '',
    this.confirmLabel = '',
    this.required = false,
    this.title = 'Способ оплаты',
    this.cashNotice = '',
  });

  factory CartPaymentNotice.fromJson(dynamic data) {
    if (data is! Map) return const CartPaymentNotice();

    final title = '${data['title'] ?? ''}'.trim();

    return CartPaymentNotice(
      notice: '${data['notice'] ?? ''}'.trim(),
      confirmLabel: '${data['confirm_label'] ?? ''}'.trim(),
      required: data['required'] == true,
      title: title.isEmpty ? 'Способ оплаты' : title,
      cashNotice: '${data['cash_notice'] ?? ''}'.trim(),
    );
  }

  bool get isEmpty => notice.isEmpty && confirmLabel.isEmpty;
}

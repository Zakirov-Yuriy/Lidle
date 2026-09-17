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

  /// Может ли ЭТОТ человек оставить отзыв (15.09.2026).
  ///
  /// Решает сервер: отзыв оставляет только тот, кто купил товар и забрал
  /// заказ. Повторять это правило в приложении значит однажды показать
  /// кнопку, которая ответит отказом.
  final bool canReview;

  /// Почему отзыв нельзя оставить. Текст готовый, с сервера.
  final String? reviewNotAllowed;

  /// Свой отзыв, если человек его уже писал: диалог открывается заполненным,
  /// а кнопка подписана «Изменить отзыв».
  final ProductReview? myReview;

  /// Отзывы, которые видит покупатель: опубликованные, с оценкой 4 и выше.
  final List<ProductReview> reviews;

  /// Сохранён ли товар в избранном у ЭТОГО человека (15.09.2026).
  final bool isWishlisted;

  /// Номер записи избранного: по нему сердечко снимается одним запросом.
  final int? wishlistId;

  /// Когда товар появился на витрине, строкой «дд.мм.гггг» (15.09.2026).
  ///
  /// Приходит готовой с сервера, как у объявления: считается она по дате
  /// публикации витрины и дате самого товара, и повторять этот расчёт на
  /// клиенте значит однажды разойтись с лентой. Пусто у старого сервера.
  final String date;

  /// Время приготовления, для еды. Пустое у обычных товаров.
  final int? cookingTimeMinutes;

  /// Можно ли заказать товар через сайт.
  ///
  /// Решает раздел, а не товар: если администратор не повесил на него атрибут
  /// оплаты, корзины нет. Товар при этом остаётся на витрине и покупается на
  /// месте у продавца.
  ///
  /// По умолчанию `true`: старый сервер поля не присылает, и приложение
  /// должно вести себя как раньше, а не прятать кнопку у всех подряд.
  final bool canOrder;

  /// Готовый текст «почему заказа нет». Приходит с сервера, пустой когда
  /// заказ есть.
  final String? orderNotice;

  /// Характеристики: разрешение экрана, материал, вес. Набор задаётся в
  /// админке на раздел, поэтому фронт его не знает заранее и просто рисует
  /// то, что пришло. В списке товаров пустой: сервер отдаёт характеристики
  /// только в карточке.
  final List<ProductAttribute> attributes;

  /// Варианты модели: красная 46-го, зелёная 48-го.
  ///
  /// Пусто у книги и у любого товара без цветов и размеров. Когда список не
  /// пуст, покупатель ВЫБИРАЕТ вариант, и в корзину уходит его номер, а не
  /// номер модели: остаток и цена лежат на варианте.
  final List<ProductVariant> variants;

  bool get hasVariants => variants.isNotEmpty;

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
    this.attributes = const [],
    this.canOrder = true,
    this.orderNotice,
    this.variants = const [],
    this.date = '',
    this.isWishlisted = false,
    this.wishlistId,
    this.canReview = false,
    this.reviewNotAllowed,
    this.myReview,
    this.reviews = const [],
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
      date: '${data['date'] ?? ''}'.trim(),
      isWishlisted: data['is_wishlisted'] == true,
      wishlistId: _int(data['wishlist_id']),
      canReview: data['can_review'] == true,
      reviewNotAllowed: () {
        final text = '${data['review_not_allowed'] ?? ''}'.trim();

        return text.isEmpty ? null : text;
      }(),
      myReview: data['my_review'] is Map<String, dynamic>
          ? ProductReview.fromJson(data['my_review'] as Map<String, dynamic>)
          : null,
      reviews: data['reviews'] is List
          ? (data['reviews'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ProductReview.fromJson)
                .toList()
          : const [],
      cookingTimeMinutes: _int(data['cooking_time_minutes']),
      canOrder: data['can_order'] != false,
      orderNotice: () {
        final notice = '${data['order_notice'] ?? ''}'.trim();
        return notice.isEmpty ? null : notice;
      }(),
      attributes: data['attributes'] is List
          ? (data['attributes'] as List)
                .map(ProductAttribute.tryParse)
                .whereType<ProductAttribute>()
                .toList()
          : const [],

      // Варианты модели: цвет плюс размер (14.09.2026). Сервер кладёт их и в
      // `variants`, и в `children` — второе имя осталось ради сайта.
      variants: () {
        final raw = data['variants'] ?? data['children'];

        if (raw is! List) return const <ProductVariant>[];

        return raw
            .whereType<Map<String, dynamic>>()
            .map(ProductVariant.fromJson)
            .toList();
      }(),
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

/// Одна характеристика товара.
///
/// Значение приходит уже готовой строкой: несколько выбранных значений
/// сервер склеивает запятой сам. Собирать это в приложении значило бы
/// повторять одну работу в приложении, на сайте и в админке, и получить три
/// разных «Хлопок, Шёлк».
class ProductAttribute {
  final int id;
  final String title;
  final String value;

  const ProductAttribute({
    required this.id,
    required this.title,
    required this.value,
  });

  static ProductAttribute? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final id = ProductItem._int(raw['id']);
    if (id == null) return null;

    final title = '${raw['title'] ?? ''}'.trim();
    final value = '${raw['value'] ?? ''}'.trim();

    // Характеристика без названия или без значения ничего не сообщает:
    // строка «: 4K» в карточке выглядит поломкой.
    if (title.isEmpty || value.isEmpty) return null;

    return ProductAttribute(id: id, title: title, value: value);
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

  /// График работы точки: `{"mon-fri": "09:00-18:00"}` (17.09.2026).
  ///
  /// Свободная форма: ключ это день или диапазон дней, значение часы. Разбирать
  /// его жёстко нельзя, продавец пишет как ему удобно, поэтому показываем
  /// строками как есть, а «сегодня» вычисляем, только когда ключ понятен.
  final Map<String, String> schedule;

  /// Владелец точки (15.09.2026).
  ///
  /// По нему открывается страница продавца со всеми его объявлениями и
  /// товарами. Считает его сервер: у новых точек владелец проставлен прямо, у
  /// старых достаётся через компанию, и повторять этот разбор на клиенте
  /// значит однажды разойтись с сервером в том, чей это товар.
  ///
  /// Пусто у старого сервера — тогда кнопки продавца просто нет.
  final int? userId;

  /// Логотип магазина (17.09.2026): картинка компании, а если её нет, аватар
  /// продавца. Пусто, если нет ни того, ни другого: заглушку рисует экран.
  final String? image;

  /// Год прихода продавца на Лидле, строкой: «2024». Только год, точная дата
  /// регистрации это личные данные продавца.
  final String? since;

  /// Оценка продавца и число публичных отзывов о нём.
  ///
  /// Считаются по тем же отзывам, что показывает страница продавца, поэтому
  /// карточка товара и страница продавца не расходятся в числах.
  final double? rating;
  final int reviewsCount;

  /// Подписан ли ЭТОТ человек на продавца. Подписка это запись избранного с
  /// типом «пользователь», та же, что на странице продавца.
  final bool isWishlisted;

  /// Номер записи избранного: по нему подписка снимается одним запросом.
  final int? wishlistId;

  const ShopBrief({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
    this.userId,
    this.schedule = const {},
    this.image,
    this.since,
    this.rating,
    this.reviewsCount = 0,
    this.isWishlisted = false,
    this.wishlistId,
  });

  /// Оценка строкой для подписи: «4.5» или пусто, если отзывов нет.
  String get ratingLabel => rating == null ? '' : rating!.toStringAsFixed(1);

  /// Строка или ничего. Пустую строку сервер присылает наравне с `null`, и
  /// отличать их на экране незачем: и то и другое значит «нечего показать».
  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty || text == 'null' ? null : text;
  }

  /// Копия с другим состоянием подписки: экран меняет её, не перезагружая
  /// карточку целиком.
  ShopBrief copyWithSubscription({required bool isWishlisted, int? wishlistId}) {
    return ShopBrief(
      id: id,
      name: name,
      address: address,
      phone: phone,
      isActive: isActive,
      userId: userId,
      schedule: schedule,
      image: image,
      since: since,
      rating: rating,
      reviewsCount: reviewsCount,
      isWishlisted: isWishlisted,
      wishlistId: wishlistId,
    );
  }

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
      userId: ProductItem._int(raw['user_id']),
      schedule: raw['schedule'] is Map
          ? Map<String, String>.fromEntries(
              (raw['schedule'] as Map).entries.map(
                (e) => MapEntry('${e.key}', '${e.value ?? ''}'.trim()),
              ),
            )
          : const {},
      image: _clean(raw['image']),
      since: _clean(raw['since']),
      rating: ProductItem._double(raw['rating']),
      reviewsCount: ProductItem._int(raw['reviews_count']) ?? 0,
      isWishlisted: raw['is_wishlisted'] == true,
      wishlistId: ProductItem._int(raw['wishlist_id']),
    );
  }

  /// Часы работы одной строкой для показа рядом со способом получения.
  ///
  /// Пытаемся найти сегодняшний день: ключи бывают `mon`, `пн`, `mon-fri`.
  /// Не разобрали — показываем первую строку графика как есть: это лучше, чем
  /// молчать, а гадать за продавца мы не вправе.
  String? get todayHours {
    if (schedule.isEmpty) return null;

    const names = <String, int>{
      'mon': 1, 'пн': 1,
      'tue': 2, 'вт': 2,
      'wed': 3, 'ср': 3,
      'thu': 4, 'чт': 4,
      'fri': 5, 'пт': 5,
      'sat': 6, 'сб': 6,
      'sun': 7, 'вс': 7,
    };

    final today = DateTime.now().weekday;

    for (final entry in schedule.entries) {
      final key = entry.key.toLowerCase().replaceAll(' ', '');

      if (entry.value.isEmpty) continue;

      final parts = key.split('-');

      if (parts.length == 2) {
        final from = names[parts[0]];
        final to = names[parts[1]];

        if (from != null && to != null && today >= from && today <= to) {
          return 'Сегодня ${entry.value}';
        }

        continue;
      }

      if (names[key] == today) return 'Сегодня ${entry.value}';
    }

    final first = schedule.entries.firstWhere(
      (e) => e.value.isNotEmpty,
      orElse: () => const MapEntry('', ''),
    );

    if (first.value.isEmpty) return null;

    return '${first.key} ${first.value}'.trim();
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

/// Вариант модели: цвет плюс размер.
///
/// Это отдельный товар со своим номером, ценой и остатком. Покупателю он
/// показывается не карточкой, а выбором внутри карточки модели.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.price,
    required this.stockQuantity,
    this.inStock = false,
    this.isAvailable = false,
    this.image,
    this.images = const [],
    this.colorId,
    this.colorName,
    this.colorCode,
    this.dimensionId,
    this.dimensionName,
    this.label,
  });

  final int id;
  final String price;
  final int stockQuantity;
  final bool inStock;

  /// Можно ли его купить прямо сейчас: считает сервер тем же правилом, что и
  /// витрина. Снятый с продажи вариант недоступен даже с остатком.
  final bool isAvailable;

  final String? image;
  final List<String> images;

  final int? colorId;
  final String? colorName;

  /// «#43A047». Может быть пустым: код заполняли не у всех цветов.
  final String? colorCode;

  final int? dimensionId;
  final String? dimensionName;

  /// «красный, 46» — собирает сервер, чтобы приложение и сайт писали
  /// одинаково.
  final String? label;

  factory ProductVariant.fromJson(Map<String, dynamic> data) {
    final color = data['color'];
    final dimension = data['dimension'];

    return ProductVariant(
      id: ProductItem._int(data['id']) ?? 0,
      price: '${data['price'] ?? '0'}',
      stockQuantity: ProductItem._int(data['stock_quantity']) ?? 0,
      inStock: data['in_stock'] == true,
      isAvailable: data['is_available'] == true,
      image: data['image']?.toString(),
      images: data['images'] is List
          ? (data['images'] as List).map((e) => '$e').toList()
          : const [],
      colorId: color is Map ? ProductItem._int(color['id']) : null,
      colorName: color is Map ? color['name']?.toString() : null,
      colorCode: color is Map ? color['code']?.toString() : null,
      dimensionId: dimension is Map ? ProductItem._int(dimension['id']) : null,
      dimensionName: dimension is Map ? dimension['name']?.toString() : null,
      label: data['label']?.toString(),
    );
  }

  /// Цена варианта в виде «4 900 ₽».
  String get priceLabel {
    final value = double.tryParse(price) ?? 0;
    final whole = value.truncate().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '$buffer ₽';
  }
}

/// Отзыв о товаре (15.09.2026).
///
/// Разбирает ДВА вида ответа сразу, и это не лень. Карточка товара отдаёт
/// отзывы полями 2023 года (`reaction`, `text`, `like`), а новая ручка
/// отзывов — общим для площадки словарём (`rating`, `comment`, `likes`),
/// тем же, каким приходят отзывы на объявления и на компании. Пока живы оба,
/// клиент должен понимать оба, иначе список в карточке и список на экране
/// отзывов разойдутся.
class ProductReview {
  final int id;

  /// Оценка от одной до пяти звёзд.
  final int rating;

  final String comment;
  final List<String> images;

  final String author;

  /// Свой отзыв можно исправить или убрать: кнопку показываем только автору.
  final bool isMine;

  final int likes;
  final int dislikes;

  /// Когда отзыв оставлен, строкой с сервера.
  final String date;

  const ProductReview({
    required this.id,
    required this.rating,
    this.comment = '',
    this.images = const [],
    this.author = '',
    this.isMine = false,
    this.likes = 0,
    this.dislikes = 0,
    this.date = '',
  });

  factory ProductReview.fromJson(Map<String, dynamic> data) {
    final images = data['images'];

    return ProductReview(
      id: ProductItem._int(data['id']) ?? 0,
      rating: ProductItem._int(data['rating'] ?? data['reaction']) ?? 0,
      comment: '${data['comment'] ?? data['text'] ?? ''}'.trim(),
      images: images is List
          ? images.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [],
      author: '${data['author'] ?? ''}'.trim(),
      isMine: data['is_mine'] == true,
      likes: ProductItem._int(data['likes'] ?? data['like']) ?? 0,
      dislikes: ProductItem._int(data['dislikes'] ?? data['dislike']) ?? 0,
      date: '${data['date'] ?? data['created_at'] ?? ''}'.trim(),
    );
  }

  /// Дата коротко, «15.09.2026». Сервер отдаёт её машинным видом, а человеку
  /// в списке нужен день, а не момент с часовым поясом.
  String get shortDate {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) return date;

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}';
  }
}

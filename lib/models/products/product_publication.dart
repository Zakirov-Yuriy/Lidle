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

/// Цвет из общего справочника.
///
/// У товара цвет это НЕ характеристика раздела, а своё поле: так товары
/// устроены с 2023 года. Поэтому он приезжает отдельно от `attributes` и в
/// форме позиции стоит своим полем.
class ProductColor {
  const ProductColor({required this.id, required this.name, this.code});

  final int id;
  final String name;

  /// Код цвета для квадратика, «#43A047». Может быть пустым: в справочнике
  /// его заполняли не у всех.
  final String? code;

  factory ProductColor.fromJson(Map<String, dynamic> data) => ProductColor(
    id: _int(data['id']) ?? 0,
    name: '${data['name'] ?? ''}',
    code: data['code']?.toString(),
  );
}

/// Характеристика позиции: «Размер: 54», «Цвет: зелёный».
///
/// Набор характеристик у каждого раздела свой, его заводит администратор.
/// Поэтому здесь не поля «размер» и «цвет», а список: в мебели это будет
/// «Материал» и «Ширина», и карточка покажет их без единой правки.
class ProductPositionAttribute {
  const ProductPositionAttribute({
    required this.id,
    required this.title,
    required this.value,
    this.valueIds = const [],
  });

  final int id;
  final String title;
  final String value;

  /// Номера выбранных значений справочника. Пусто у характеристик, которые
  /// человек вписывает руками. Нужны, чтобы открыть правку с уже отмеченными
  /// вариантами.
  final List<int> valueIds;

  factory ProductPositionAttribute.fromJson(Map<String, dynamic> data) {
    final ids = data['values_id'];

    return ProductPositionAttribute(
      id: _int(data['id']) ?? 0,
      title: '${data['title'] ?? ''}',
      value: '${data['value'] ?? ''}',
      valueIds: ids is List
          ? ids.map(_int).whereType<int>().toList()
          : const [],
    );
  }
}

/// Позиция: тот же товар, что лежит на витрине.
///
/// Здесь то, что показывает карточка позиции в кабинете и что нужно, чтобы
/// открыть её на правку. Полная карточка товара для покупателя живёт в
/// `ProductItem`.
class ProductPosition {
  const ProductPosition({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.images = const [],
    this.position,
    this.description = '',
    this.groupId,
    this.brandId,
    this.stockQuantity = 0,
    this.attributes = const [],
    this.color,
  });

  final int id;
  final String name;
  final num price;
  final String? image;

  /// Все картинки позиции ссылками.
  final List<String> images;

  /// «Номер позиции» с макета.
  final int? position;

  final String description;
  final int? groupId;
  final int? brandId;
  final int stockQuantity;

  /// Характеристики раздела, заполненные при заведении.
  final List<ProductPositionAttribute> attributes;

  /// Цвет из справочника. Своё поле товара, а не характеристика раздела.
  final ProductColor? color;

  factory ProductPosition.fromJson(Map<String, dynamic> data) {
    final images = data['images'];
    final attributes = data['attributes'];

    return ProductPosition(
      id: _int(data['id']) ?? 0,
      name: '${data['name'] ?? ''}',
      price: _num(data['price']) ?? 0,
      image: data['image']?.toString().isNotEmpty == true
          ? data['image'].toString()
          : (images is List && images.isNotEmpty ? '${images.first}' : null),
      images: images is List
          ? images.map((item) => '$item').where((item) => item.isNotEmpty).toList()
          : const [],
      position: _int(data['position']),
      description: '${data['description'] ?? ''}',
      groupId: _int(data['group_id']),
      brandId: _int(data['brand_id']),
      stockQuantity: _int(data['stock_quantity']) ?? 0,

      // Характеристики приезжают только с полной публикацией: в списке
      // товаров сервер их не считает.
      attributes: attributes is List
          ? attributes
                .whereType<Map<String, dynamic>>()
                .map(ProductPositionAttribute.fromJson)
                .toList()
          : const [],
      color: data['color'] is Map
          ? ProductColor.fromJson(
              Map<String, dynamic>.from(data['color'] as Map),
            )
          : null,
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
    this.paymentMethods = const [],
    this.paymentSettings = const {},
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

  /// Ключи способов оплаты, которые принимает продавец. Пусто означает, что
  /// он ещё не выбирал, а не «не принимает ничего».
  final List<String> paymentMethods;

  /// Настройки способов: ключ способа → его настройка. Пусто у тех, кого
  /// ещё не настраивали.
  final Map<String, PaymentSetting> paymentSettings;

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
      paymentMethods: data['payment_methods'] is List
          ? (data['payment_methods'] as List)
                .map((item) => '$item')
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      paymentSettings: _settings(data['payment_settings']),
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
    List<String>? paymentMethods,
    Map<String, PaymentSetting>? paymentSettings,
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
      paymentMethods: paymentMethods ?? this.paymentMethods,
      paymentSettings: paymentSettings ?? this.paymentSettings,
      groups: groups ?? this.groups,
      needsShop: needsShop,
    );
  }
}

/// Настройка одного способа оплаты.
class PaymentSetting {
  const PaymentSetting({
    required this.account,
    this.last4,
    this.legalName,
    this.shortName,
    this.receiptName,
    this.inn,
    this.kpp,
    this.ogrn,
    this.selfEmployed = false,
  });

  /// Куда приходят деньги: `cash` или `bank_account`.
  final String account;

  /// Последние четыре цифры карты.
  ///
  /// Только четыре, и это не экономия: полный номер карты нигде не
  /// хранится, ни на сервере, ни в приложении. Продавцу для узнавания своей
  /// карты хватает хвоста, а держать у себя платёжные данные значит брать
  /// на себя требования к их защите.
  final String? last4;

  /// Реквизиты организации: нужны СБП, чтобы платёж дошёл и попал в чек.
  final String? legalName;
  final String? shortName;
  final String? receiptName;
  final String? inn;
  final String? kpp;
  final String? ogrn;

  /// Самозанятый: у него нет ни КПП, ни ОГРН.
  final bool selfEmployed;

  /// Номер карты так, как его показывают везде: «•••• •••• •••• 2345».
  String get maskedCard => last4 == null ? '' : '•••• •••• •••• $last4';

  Map<String, dynamic> toJson() => {
        'account': account,
        if (last4 != null) 'last4': last4,
        if (legalName != null) 'legal_name': legalName,
        if (shortName != null) 'short_name': shortName,
        if (receiptName != null) 'receipt_name': receiptName,
        if (inn != null) 'inn': inn,
        if (kpp != null) 'kpp': kpp,
        if (ogrn != null) 'ogrn': ogrn,
        'self_employed': selfEmployed,
      };
}

/// Настройки способов из ответа сервера.
Map<String, PaymentSetting> _settings(dynamic raw) {
  if (raw is! Map) return const {};

  final result = <String, PaymentSetting>{};

  raw.forEach((key, value) {
    if (value is! Map) return;

    final account = value['account'];

    if (account == null) return;

    final last4 = value['last4']?.toString().trim() ?? '';

    String? text(dynamic raw) {
      final value = raw?.toString().trim() ?? '';

      return value.isEmpty ? null : value;
    }

    result['$key'] = PaymentSetting(
      account: '$account',
      last4: last4.isEmpty ? null : last4,
      legalName: text(value['legal_name']),
      shortName: text(value['short_name']),
      receiptName: text(value['receipt_name']),
      inn: text(value['inn']),
      kpp: text(value['kpp']),
      ogrn: text(value['ogrn']),
      selfEmployed: value['self_employed'] == true,
    );
  });

  return result;
}

/// Способ оплаты из справочника сервера: ключ и название.
///
/// Названия приходят с сервера, чтобы приложение не держало вторую копию
/// списка: пункт переименуют — переименуется везде. Так же устроены доступы
/// сотрудника.
class PaymentMethod {
  const PaymentMethod({
    required this.key,
    required this.title,
    this.hint = '',
    this.needsSetup = false,
    this.form,
    this.field,
    this.action,
    this.actionHint,
  });

  final String key;
  final String title;

  /// Что показать под названием на экране настройки.
  final String hint;

  /// Нужны ли этому способу реквизиты. Наличным не нужны: у них вместо
  /// кнопки просто объяснение.
  final bool needsSetup;

  /// Какую форму открывать: `card` или `company`. Пусто — экрана ещё нет.
  ///
  /// Решает сервер, чтобы приложение не держало свой список «что чем
  /// настраивается»: он разошёлся бы с правдой в первый же день.
  final String? form;

  /// Подпись поля на экране настройки, например «Номер банковской карты».
  final String? field;

  /// Надпись на кнопке привязки, например «Привязать карту».
  final String? action;

  /// Объяснение под кнопкой привязки.
  final String? actionHint;

  /// Есть ли у способа готовый экран настройки.
  ///
  /// Узнаём по текстам с сервера: у способов, чей экран ещё не нарисован,
  /// их нет. Так приложению не приходится держать список «что уже сделано»,
  /// который разойдётся с правдой в первый же день.
  bool get hasSetupScreen => needsSetup && (form ?? '').isNotEmpty;

  factory PaymentMethod.fromJson(Map<String, dynamic> data) {
    String? text(dynamic value) {
      final result = value?.toString().trim() ?? '';

      return result.isEmpty ? null : result;
    }

    return PaymentMethod(
      key: '${data['key'] ?? ''}',
      title: '${data['title'] ?? ''}',
      hint: '${data['hint'] ?? ''}',
      needsSetup: data['needs_setup'] == true,
      form: text(data['form']),
      field: text(data['field']),
      action: text(data['action']),
      actionHint: text(data['action_hint']),
    );
  }
}

/// Куда приходят деньги по способу: касса или расчётный счёт.
class PaymentAccount {
  const PaymentAccount({required this.key, required this.title});

  final String key;
  final String title;

  factory PaymentAccount.fromJson(Map<String, dynamic> data) => PaymentAccount(
        key: '${data['key'] ?? ''}',
        title: '${data['title'] ?? ''}',
      );
}

/// Справочник оплаты целиком: способы и счета.
class PaymentDictionary {
  const PaymentDictionary({this.methods = const [], this.accounts = const []});

  final List<PaymentMethod> methods;
  final List<PaymentAccount> accounts;

  String accountTitle(String? key) {
    for (final account in accounts) {
      if (account.key == key) return account.title;
    }

    return '';
  }
}

/// Бренд из справочника.
class ProductBrand {
  const ProductBrand({
    required this.id,
    required this.name,
    this.productsCount = 0,
  });

  final int id;
  final String name;

  /// Сколько товаров продавца уже заведено под этим брендом. Считает сервер:
  /// по своим товарам, а не по всему справочнику.
  final int productsCount;

  factory ProductBrand.fromJson(Map<String, dynamic> data) => ProductBrand(
    id: _int(data['id']) ?? 0,
    name: '${data['name'] ?? ''}',
    productsCount: _int(data['products_count']) ?? 0,
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

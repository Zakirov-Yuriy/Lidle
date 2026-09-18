import 'package:lidle/models/products/product_item.dart';

/// Заказ. Одна модель для покупателя и для продавца.
///
/// Так же, как у броней: заказ это один и тот же предмет разговора, и
/// расхождения между «моей покупкой» и «моим заказом» приводят к спорам на
/// ровном месте. Что показывать, решают экраны.
class OrderModel {
  final int id;
  final String number;

  /// `new`, `accepted`, `ready`, `completed`, `cancelled_by_buyer`,
  /// `cancelled_by_seller`.
  final String status;

  /// Подпись состояния приходит готовой: переводить на клиенте нельзя, иначе
  /// приложение и админка однажды назовут одно и то же по-разному.
  final String statusTitle;

  /// Код получения. Покупатель называет его в точке, продавец сверяет.
  final String? pickupCode;

  final String total;
  final int? cookingTimeMinutes;

  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? comment;
  final String? cancelReason;

  final ShopBrief? shop;
  final List<OrderLine> items;

  /// Чем платят по заказу: «Наличные», «Системы быстрых платежей» и так
  /// далее. Название приходит копией из заказа, а не из справочника: пункт
  /// могли переименовать, а заказ должен остаться таким, каким его оформляли
  /// (15.09.2026). Пусто у заказов, оформленных до выбора способа.
  final String? paymentMethodTitle;

  /// Ключ способа оплаты: `cash`, `card`, `sbp`, `bank_transfer` (17.09.2026).
  ///
  /// Нужен экрану подробностей: там способы показаны списком, и отмечать
  /// выбранный надо по ключу, а не сравнением названий. Название продавец
  /// может однажды переименовать, ключ остаётся.
  final String? paymentMethod;

  /// Какие способы точка принимала на момент заказа.
  ///
  /// Снимок с заказа, а не нынешние настройки точки: в подробностях человек
  /// смотрит на то, из чего он выбирал тогда.
  final List<String> paymentTypes;

  /// Расчёт на месте при получении. Продавцу это главное: ждать наличные у
  /// прилавка или проверять поступление.
  final bool paymentOnPickup;

  /// Как человек получает заказ: `pickup` или `courier` (16.09.2026).
  final String deliveryType;

  /// Название способа копией: «Самовывоз», «Курьером по городу».
  final String? deliveryTitle;

  /// Цена доставки. Отдельно от суммы товаров: по сумме товаров считается
  /// выручка, и подмешивать в неё доставку значит испортить обе цифры.
  final String deliveryPrice;

  /// Куда везти. Пусто у самовывоза.
  final String? deliveryAddress;

  /// Подъезд, этаж, домофон.
  final String? deliveryComment;

  /// Кто везёт. Пусто, пока продавец не назначил курьера.
  final int? courierStaffId;
  final String? courierName;

  /// Курьер целиком: фото, должность и контакты (18.09.2026).
  ///
  /// Пусто у самовывоза и пока курьера не назначили. Контакты приходят из
  /// карточки сотрудника, а не копией в заказ: телефон человек меняет, и
  /// звонить надо по нынешнему.
  final OrderCourier? courier;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;

  const OrderModel({
    required this.id,
    required this.number,
    required this.status,
    required this.statusTitle,
    required this.total,
    required this.items,
    this.pickupCode,
    this.cookingTimeMinutes,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.comment,
    this.cancelReason,
    this.shop,
    this.paymentMethodTitle,
    this.paymentMethod,
    this.paymentTypes = const [],
    this.paymentOnPickup = false,
    this.deliveryType = 'pickup',
    this.deliveryTitle,
    this.deliveryPrice = '0',
    this.deliveryAddress,
    this.deliveryComment,
    this.courierStaffId,
    this.courierName,
    this.courier,
    this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.pickedUpAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> data) {
    final items = data['items'];

    return OrderModel(
      id: _int(data['id']) ?? 0,
      number: '${data['number'] ?? ''}',
      status: '${data['status'] ?? ''}',
      statusTitle: '${data['status_title'] ?? ''}',
      pickupCode: data['pickup_code']?.toString(),
      total: '${data['total'] ?? '0'}',
      cookingTimeMinutes: _int(data['cooking_time_minutes']),
      contactName: data['contact_name']?.toString(),
      contactPhone: data['contact_phone']?.toString(),
      contactEmail: data['contact_email']?.toString(),
      comment: data['comment']?.toString(),
      cancelReason: data['cancel_reason']?.toString(),
      shop: ShopBrief.tryParse(data['shop']),
      paymentMethodTitle: data['payment'] is Map
          ? data['payment']['method_title']?.toString()
          : null,
      paymentMethod: data['payment'] is Map
          ? data['payment']['method']?.toString()
          : null,
      paymentTypes: data['payment'] is Map && data['payment']['types'] is List
          ? (data['payment']['types'] as List)
              .map((type) => '$type'.trim())
              .where((type) => type.isNotEmpty)
              .toList()
          : const [],
      paymentOnPickup:
          data['payment'] is Map && data['payment']['on_pickup'] == true,
      items: items is List
          ? items.whereType<Map<String, dynamic>>().map(OrderLine.fromJson).toList()
          : const [],
      deliveryType: data['delivery'] is Map
          ? '${data['delivery']['type'] ?? 'pickup'}'
          : 'pickup',
      deliveryTitle: data['delivery'] is Map
          ? data['delivery']['title']?.toString()
          : null,
      deliveryPrice: data['delivery'] is Map
          ? '${data['delivery']['price'] ?? '0'}'
          : '0',
      deliveryAddress: data['delivery'] is Map
          ? data['delivery']['address']?.toString()
          : null,
      deliveryComment: data['delivery'] is Map
          ? data['delivery']['comment']?.toString()
          : null,
      courierStaffId:
          data['courier'] is Map ? _int(data['courier']['staff_id']) : null,
      courierName:
          data['courier'] is Map ? data['courier']['name']?.toString() : null,
      courier: data['courier'] is Map
          ? OrderCourier.fromJson(Map<String, dynamic>.from(data['courier']))
          : null,
      createdAt: _date(data['created_at']),
      acceptedAt: _date(data['accepted_at']),
      readyAt: _date(data['ready_at']),
      pickedUpAt: _date(data['picked_up_at']),
    );
  }

  /// Живой заказ: его ещё разбирают, он занимает товар.
  bool get isAlive =>
      status == 'new' || status == 'accepted' || status == 'ready';

  bool get isCancelled =>
      status == 'cancelled_by_buyer' || status == 'cancelled_by_seller';

  /// Заказ везёт курьер, а не забирают в точке.
  bool get isCourier => deliveryType == 'courier';

  /// Курьера ещё не назначили. Продавцу это главный вопрос по такому заказу.
  bool get needsCourier => isCourier && (courierName ?? '').isEmpty;

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Дату разбираем без приведения к поясу устройства: сервер отдаёт момент
  /// со смещением, и `DateTime.parse` уводит его в UTC. Для подписи «когда
  /// заказали» этого достаточно, но для времени выдачи пришлось бы держать
  /// строку, как мы делаем в бронировании.
  static DateTime? _date(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse('$value');
  }
}

/// Строка или ничего: пустую строку сервер не присылает, но чужой ответ
/// проще привести к `null` здесь, чем ловить пустую картинку на экране.
String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}

double? _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class OrderLine {
  /// Номер позиции в заказе (16.09.2026). Нужен, чтобы принять или отклонить
  /// именно этот товар: продавец решает по каждому отдельно.
  final int id;

  /// `pending`, `accepted`, `rejected`.
  final String status;

  /// Подпись состояния приходит готовой с сервера.
  final String statusTitle;

  /// Почему отклонили. Пишет продавец, видит покупатель.
  final String? rejectReason;

  final int? productId;
  final String name;
  final String? sku;

  /// Картинка товара готовой ссылкой. Пусто у заказов, оформленных до
  /// 10.09.2026, и у товаров без фотографии — тогда рисуем заглушку.
  final String? image;

  final String price;
  final int quantity;
  final double sum;

  const OrderLine({
    this.id = 0,
    this.status = 'pending',
    this.statusTitle = '',
    this.rejectReason,
    required this.name,
    required this.price,
    required this.quantity,
    required this.sum,
    this.productId,
    this.sku,
    this.image,
  });

  factory OrderLine.fromJson(Map<String, dynamic> data) {
    return OrderLine(
      id: OrderModel._int(data['id']) ?? 0,
      status: '${data['status'] ?? 'pending'}',
      statusTitle: '${data['status_title'] ?? ''}',
      rejectReason: data['reject_reason']?.toString(),
      productId: OrderModel._int(data['product_id']),
      name: '${data['name'] ?? ''}',
      sku: data['sku']?.toString(),
      image: _text(data['image']),
      price: '${data['price'] ?? '0'}',
      quantity: OrderModel._int(data['quantity']) ?? 1,
      sum: _double(data['sum']) ?? 0,
    );
  }

  /// По этой позиции продавец ещё не решил.
  bool get isPending => status == 'pending';

  /// Товар снят с заказа и вернулся в продажу.
  bool get isRejected => status == 'rejected';
}

/// Курьер заказа (18.09.2026).
///
/// Это сотрудник продавца, а не пользователь приложения: учётной записи у него
/// нет, войти он не может, и переписки с ним тоже нет. Поэтому связь с ним это
/// телефон и мессенджеры, которые продавец завёл в его карточке.
///
/// Пустые поля здесь обычное дело: продавец заполняет карточку по мере того,
/// как договаривается с человеком, а сотрудника могли и вовсе удалить. Экран
/// показывает то, что есть, и не рисует пустых строк.
class OrderCourier {
  final int? staffId;
  final String name;

  /// Должность строкой, как её написал продавец: «Пеший курьер», «На авто».
  final String? position;

  final String? image;
  final String? phone;
  final String? phoneExtra;
  final String? telegram;
  final String? whatsapp;
  final String? vk;
  final String? city;

  /// Рейтинг курьера и число оценок (18.09.2026).
  ///
  /// Считается по всем оценкам этого сотрудника, а не только по высоким:
  /// оценивают работу человека, и прятать тройки значило бы показывать не то,
  /// что есть. Пусто, пока его никто не оценивал.
  final double? rating;
  final int reviewsCount;

  /// Может ли ЭТОТ человек оценить курьера. Решает сервер: оценивает
  /// покупатель и только после получения заказа.
  final bool canReview;

  /// Почему оценить нельзя. Текст готовый, с сервера.
  final String? reviewNotAllowed;

  /// Своя прежняя оценка: диалог открывается заполненным.
  final int? myRating;
  final String? myReviewText;

  const OrderCourier({
    this.staffId,
    this.name = '',
    this.position,
    this.image,
    this.phone,
    this.phoneExtra,
    this.telegram,
    this.whatsapp,
    this.vk,
    this.city,
    this.rating,
    this.reviewsCount = 0,
    this.canReview = false,
    this.reviewNotAllowed,
    this.myRating,
    this.myReviewText,
  });

  factory OrderCourier.fromJson(Map<String, dynamic> data) {
    return OrderCourier(
      staffId: OrderModel._int(data['staff_id']),
      name: '${data['name'] ?? ''}'.trim(),
      position: _text(data['position']),
      image: _text(data['image']),
      phone: _text(data['phone']),
      phoneExtra: _text(data['phone_extra']),
      telegram: _text(data['telegram']),
      whatsapp: _text(data['whatsapp']),
      vk: _text(data['vk']),
      city: _text(data['city']),
      rating: _double(data['rating']),
      reviewsCount: OrderModel._int(data['reviews_count']) ?? 0,
      canReview: data['can_review'] == true,
      reviewNotAllowed: _text(data['review_not_allowed']),
      myRating: data['my_review'] is Map
          ? OrderModel._int(data['my_review']['rating'])
          : null,
      myReviewText: data['my_review'] is Map
          ? _text(data['my_review']['text'])
          : null,
    );
  }

  /// Телефоны, которые есть, без пустых мест.
  List<String> get phones => [
        if ((phone ?? '').isNotEmpty) phone!,
        if ((phoneExtra ?? '').isNotEmpty) phoneExtra!,
      ];

  /// Есть ли чем связаться. Когда нечем, экран курьера открывать незачем.
  bool get hasContacts =>
      phones.isNotEmpty ||
      (telegram ?? '').isNotEmpty ||
      (whatsapp ?? '').isNotEmpty ||
      (vk ?? '').isNotEmpty;
}

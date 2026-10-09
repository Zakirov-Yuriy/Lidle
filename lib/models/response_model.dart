/// Отклик на объявление.
///
/// Экраны откликов были нарисованы по макету и жили на придуманных данных.
/// 09.10.2026 (задача 15) под ними появился сервер, и модель научилась
/// читать ответ: `GET /v1/me/responses` и `GET /v1/me/responses/received`.
/// Разбор полей: back/api/adverts/responses-api.md.
///
/// Поля из макета оставлены как есть, чтобы не переписывать вёрстку. Те, что
/// сервер не отдаёт (рейтинг, город, ссылки), приходят пустыми, и экран их
/// просто не показывает: придумывать «Мариуполь» и «@AndrawP» за человека
/// нельзя, на этом уже обожглись в предложениях цены.
class ResponseModel {
  final String id;
  final String category;
  final String title;
  final double price;
  final String userName;
  final String userAvatar;
  final double rating;
  final List<String>? phoneNumbers;
  final String? telegram;
  final String? whatsapp;
  final String? vk;
  final String? city;

  /// Номер отклика числом: нужен ручке «принять или отклонить».
  final int? responseId;

  /// Кто откликнулся. По нему открывается переписка.
  final String? userId;

  /// На что откликнулись: номер объявления.
  final int? advertId;

  /// Текст отклика. Это главное в отклике, а не цена.
  final String? message;

  /// Состояние: 1 новый, 2 принят, 3 отклонён.
  final int? statusId;

  /// Название состояния, как его отдал сервер.
  final String? statusName;

  /// Когда откликнулись, уже строкой в виде дд.мм.гггг.
  final String? createdAt;

  /// Аватарка из сети. Пусто — экран рисует заглушку.
  final String? avatarUrl;

  /// Картинка объявления, на которое откликнулись.
  final String? advertImage;

  ResponseModel({
    required this.id,
    required this.category,
    required this.title,
    required this.price,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    this.phoneNumbers,
    this.telegram,
    this.whatsapp,
    this.vk,
    this.city,
    this.responseId,
    this.userId,
    this.advertId,
    this.message,
    this.statusId,
    this.statusName,
    this.createdAt,
    this.avatarUrl,
    this.advertImage,
  });

  /// Разбор ответа сервера.
  ///
  /// Числа приходят числами, а не строками: цена объявления это `int`, а
  /// цена отклика `decimal`. Приводим аккуратно, через `num`, иначе
  /// получается «type 'int' is not a subtype of type 'String?'» — ровно та
  /// ошибка, на которой упал экран предложений цены 09.10.2026.
  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final status = json['status'] as Map<String, dynamic>?;

    // Цену показываем ту, что назвал откликнувшийся, а если он её не
    // называл — ту, что стоит в объявлении.
    final offered = _number(json['price']);
    final asked = _number(model?['price']);

    return ResponseModel(
      id: '${json['id'] ?? ''}',
      responseId: _int(json['id']),
      category: _text(model?['name']) ?? 'Объявление',
      title: _text(model?['name']) ?? '',
      price: offered ?? asked ?? 0,
      userName: _text(user?['name']) ?? 'Пользователь',
      // Путь к файлу-заглушке оставляем пустым: карточка сама решает, что
      // рисовать, когда аватарки нет.
      userAvatar: '',
      avatarUrl: _text(user?['avatar']),
      rating: 0,
      userId: user?['id'] == null ? null : '${user!['id']}',
      advertId: _int(model?['id']),
      advertImage: _text(model?['thumbnail']),
      message: _text(json['message']),
      statusId: _int(status?['id']),
      statusName: _text(status?['name']),
      createdAt: _text(json['created_at']),
    );
  }

  /// Новый, то есть автор объявления его ещё не рассматривал.
  bool get isNew => statusId == null || statusId == 1;

  /// Принят.
  bool get isAccepted => statusId == 2;

  /// Отклонён.
  bool get isRejected => statusId == 3;

  static String? _text(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = '$value'.trim();

    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('${value ?? ''}');
  }

  static double? _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse('${value ?? ''}'.replaceAll(',', '.'));
  }
}

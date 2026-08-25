// ============================================================
//  Модель отзыва для экранов личного кабинета.
//  Один формат на три источника: отзывы объявлений (мои и полученные)
//  и отзывы о моей компании. Бэк отдаёт совместимые поля, поэтому
//  разбор общий, а различается только `kind` — от него зависят
//  доступные действия и адрес, куда уходит ответ.
// ============================================================

/// Какого рода отзыв и что с ним можно делать.
enum ReviewKind {
  /// Отзыв, который оставил я на чужое объявление. Могу удалить.
  /// Источник: GET /v1/me/reviews
  mine,

  /// Отзыв, который оставили на МОЁ объявление. Могу ответить и пожаловаться.
  /// Источник: GET /v1/me/received-reviews
  received,

  /// Отзыв о МОЕЙ компании. Могу ответить и пожаловаться.
  /// Источник: GET /v1/company/reviews
  company,
}

class ReviewModel {
  /// Id отзыва на бэке — нужен для удаления, ответа и жалобы.
  final int id;

  /// Откуда отзыв и какие действия доступны.
  final ReviewKind kind;

  /// Картинка слева: превью объявления (мои/полученные) либо аватар автора
  /// (отзывы компании). null, если бэк ничего не прислал.
  final String? imageUrl;

  /// Заголовок: название объявления либо имя автора отзыва.
  final String title;

  /// Дата в готовом виде — «12 августа», бэк форматирует сам.
  final String date;

  /// Оценка 1..5.
  final double rating;

  /// Текст отзыва (может быть пустым — отзыв только с оценкой).
  final String text;

  /// Ответ владельца объявления/компании, null если не отвечали.
  final String? reply;

  /// Дата ответа в виде «19 августа», null если ответа нет.
  final String? replyDate;

  /// На что оставлен отзыв: на компанию или на объявление.
  ///
  /// Во вкладке «Мои отзывы» приходят оба типа вперемешку (бэк отдаёт поле
  /// `type`), а удаление и правка у них ведут на разные эндпоинты — поэтому
  /// тип надо знать. Для остальных вкладок это всегда отзыв на объявление
  /// или на компанию по самой вкладке.
  final bool isCompanyReview;

  /// Id компании — нужен для удаления и правки отзыва о компании
  /// (путь /v1/companies/{companyId}/reviews/{id}). null для отзыва на объявление.
  final int? companyId;

  const ReviewModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.rating,
    required this.text,
    this.imageUrl,
    this.reply,
    this.replyDate,
    this.isCompanyReview = false,
    this.companyId,
  });

  /// Есть ли ответ на отзыв.
  bool get hasReply => (reply ?? '').trim().isNotEmpty;

  /// Можно ли удалить — только свой собственный отзыв.
  bool get canDelete => kind == ReviewKind.mine;

  /// Можно ли ответить — на отзыв о моём объявлении или моей компании.
  bool get canReply => kind != ReviewKind.mine;

  /// Можно ли пожаловаться — на чужой отзыв (на свой нельзя, бэк вернёт 422).
  bool get canReport => kind != ReviewKind.mine;

  /// Разбор ответа API. Формат общий для всех трёх списков:
  /// { id, title, thumbnail, date, comment, rating, reply, reply_date }
  factory ReviewModel.fromJson(Map<String, dynamic> json, ReviewKind kind) {
    // Имя автора у отзывов компании приходит и в title, и в user_name —
    // берём первое непустое, чтобы не зависеть от того, какой ресурс ответил.
    final rawTitle = _str(json['title']) ?? _str(json['user_name']) ?? '';
    final rawImage = _str(json['thumbnail']) ?? _str(json['user_avatar']);

    // Во вкладке «Мои отзывы» бэк присылает type = advert | company.
    // На вкладке «Моя компания» отдельного type нет — там всё про компанию.
    final type = _str(json['type']);
    final isCompany =
        type == 'company' || (type == null && kind == ReviewKind.company);

    return ReviewModel(
      id: _int(json['id']) ?? 0,
      kind: kind,
      title: rawTitle.isNotEmpty ? rawTitle : 'Без названия',
      imageUrl: rawImage,
      date: _str(json['date']) ?? '',
      rating: (_num(json['rating']) ?? 0).toDouble(),
      text: _str(json['comment']) ?? '',
      reply: _str(json['reply']),
      replyDate: _str(json['reply_date']),
      isCompanyReview: isCompany,
      companyId: _int(json['company_id']),
    );
  }

  /// Разбор списка из поля `data` ответа с пагинацией.
  static List<ReviewModel> listFromResponse(
    Map<String, dynamic> response,
    ReviewKind kind,
  ) {
    final raw = response['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e), kind))
        .toList();
  }

  /// Сколько всего страниц в ответе (для подгрузки при прокрутке).
  /// Возвращает 1, если бэк не прислал meta.
  static int lastPageFromResponse(Map<String, dynamic> response) {
    final meta = response['meta'];
    if (meta is Map) {
      final lp = _int(meta['last_page']);
      if (lp != null && lp > 0) return lp;
    }
    return 1;
  }

  /// Общее число отзывов из meta (для подписи «N отзывов»).
  static int? totalFromResponse(Map<String, dynamic> response) {
    final meta = response['meta'];
    if (meta is Map) return _int(meta['total']);
    return null;
  }

  ReviewModel copyWith({String? reply, String? replyDate}) {
    return ReviewModel(
      id: id,
      kind: kind,
      title: title,
      date: date,
      rating: rating,
      text: text,
      imageUrl: imageUrl,
      reply: reply ?? this.reply,
      replyDate: replyDate ?? this.replyDate,
      isCompanyReview: isCompanyReview,
      companyId: companyId,
    );
  }

  // ─── разбор значений: бэк может прислать число строкой или null ───

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}

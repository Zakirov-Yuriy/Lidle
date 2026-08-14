import 'package:json_annotation/json_annotation.dart';

part 'main_content_model.g.dart';

/// Модель для главной страницы (GET /content/main)
@JsonSerializable()
class MainContent {
  final MainContentData data;

  MainContent({required this.data});

  factory MainContent.fromJson(Map<String, dynamic> json) =>
      _$MainContentFromJson(json);
  Map<String, dynamic> toJson() => _$MainContentToJson(this);
}

@JsonSerializable()
class MainContentData {
  final List<MainCatalog> catalogs;
  final List<MainAdvert> adverts;

  MainContentData({required this.catalogs, required this.adverts});

  factory MainContentData.fromJson(Map<String, dynamic> json) =>
      _$MainContentDataFromJson(json);
  Map<String, dynamic> toJson() => _$MainContentDataToJson(this);
}

@JsonSerializable()
class MainCatalog {
  final int id;
  final String name;
  final String? thumbnail;
  final String slug;
  final ContentType type;
  final String order;

  MainCatalog({
    required this.id,
    required this.name,
    this.thumbnail,
    required this.slug,
    required this.type,
    required this.order,
  });

  factory MainCatalog.fromJson(Map<String, dynamic> json) =>
      _$MainCatalogFromJson(json);
  Map<String, dynamic> toJson() => _$MainCatalogToJson(this);
}

@JsonSerializable()
class MainAdvert {
  final int id;
  final String date;
  final String name;
  final String price;
  final String? thumbnail;
  final AdvertStatus status;
  final String address;
  final int views_count;
  final int click_count;
  final int share_count;
  final ContentType type;

  MainAdvert({
    required this.id,
    required this.date,
    required this.name,
    required this.price,
    this.thumbnail,
    required this.status,
    required this.address,
    required this.views_count,
    required this.click_count,
    required this.share_count,
    required this.type,
  });

  factory MainAdvert.fromJson(Map<String, dynamic> json) =>
      _$MainAdvertFromJson(json);
  Map<String, dynamic> toJson() => _$MainAdvertToJson(this);
}

@JsonSerializable()
class AdvertStatus {
  final int id;
  final String title;

  AdvertStatus({required this.id, required this.title});

  factory AdvertStatus.fromJson(Map<String, dynamic> json) =>
      _$AdvertStatusFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertStatusToJson(this);
}

@JsonSerializable()
class ContentType {
  final int id;
  final String? type;
  final String? path;

  ContentType({required this.id, this.type, this.path});

  factory ContentType.fromJson(Map<String, dynamic> json) =>
      _$ContentTypeFromJson(json);
  Map<String, dynamic> toJson() => _$ContentTypeToJson(this);
}

/// Модель для объявлений пользователя (GET /me/adverts)
@JsonSerializable()
class UserAdvert {
  final int id;
  final String? name;
  final String? thumbnail;
  final String? price;
  final String? slug;
  final String? address;
  @JsonKey(name: 'views_count')
  final int? viewsCount;
  @JsonKey(name: 'click_count')
  final int? clickCount;
  @JsonKey(name: 'share_count')
  final int? shareCount;
  @JsonKey(name: 'call_count')
  final int? callCount;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  final ContentType? type;

  /// Обработано ли объявление ИИ (приходит с сервера как ai_processed).
  @JsonKey(name: 'ai_processed')
  final bool? aiProcessed;

  /// Отредактировал ли менеджер объявление перед публикацией
  /// (приходит с сервера как is_reviewed). Пока false — кнопка
  /// «Опубликовать» на экране модерации ведёт на редактирование.
  @JsonKey(name: 'is_reviewed')
  final bool? isReviewed;

  /// Пришло ли объявление из фида (приходит с сервера как is_feed).
  @JsonKey(name: 'is_feed')
  final bool? isFeed;

  /// ИИ реально переписал видимый заголовок/описание (приходит как
  /// ai_rewritten). Значок «Ai» на карточке рисуем ТОЛЬКО по нему: если у
  /// объявления сгенерировано лишь SEO (а текст оригинальный), значка нет.
  @JsonKey(name: 'ai_rewritten')
  final bool? aiRewritten;

  UserAdvert({
    required this.id,
    this.name,
    this.thumbnail,
    this.price,
    this.slug,
    this.address,
    this.viewsCount,
    this.clickCount,
    this.shareCount,
    this.callCount,
    this.createdAt,
    this.type,
    this.aiProcessed,
    this.isReviewed,
    this.isFeed,
    this.aiRewritten,
  });

  factory UserAdvert.fromJson(Map<String, dynamic> json) =>
      _$UserAdvertFromJson(json);
  Map<String, dynamic> toJson() => _$UserAdvertToJson(this);
}

/// Модель для мета-информации объявлений пользователя (GET /me/adverts/meta)
@JsonSerializable()
class AdvertMetaResponse {
  final List<AdvertMetaData> data;

  AdvertMetaResponse({required this.data});

  factory AdvertMetaResponse.fromJson(Map<String, dynamic> json) =>
      _$AdvertMetaResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertMetaResponseToJson(this);
}

@JsonSerializable()
class AdvertMetaData {
  final List<AdvertMetaCatalog> catalogs;
  final List<AdvertMetaTab> tabs;

  AdvertMetaData({required this.catalogs, required this.tabs});

  factory AdvertMetaData.fromJson(Map<String, dynamic> json) =>
      _$AdvertMetaDataFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertMetaDataToJson(this);
}

@JsonSerializable()
class AdvertMetaCatalog {
  @JsonKey(name: 'catalog_id')
  final int catalogId;
  final String name;
  final List<AdvertMetaCategory> categories;

  AdvertMetaCatalog({
    required this.catalogId,
    required this.name,
    required this.categories,
  });

  factory AdvertMetaCatalog.fromJson(Map<String, dynamic> json) =>
      _$AdvertMetaCatalogFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertMetaCatalogToJson(this);
}

@JsonSerializable()
class AdvertMetaCategory {
  @JsonKey(name: 'category_id')
  final int categoryId;
  final String name;

  /// Флаги «в каких вкладках реально есть эта категория» (приходят с бэка).
  /// По ним на экране «Мои объявления» показываем в чипсах только те
  /// каталоги/категории, что есть в выбранной вкладке.
  @JsonKey(name: 'has_active')
  final bool? hasActive; // «Активные» (статус 1)
  @JsonKey(name: 'has_inactive')
  final bool? hasInactive; // «Неактивные» (статус 2)
  @JsonKey(name: 'has_archive')
  final bool? hasArchive; // «Архив» (статус 8)
  @JsonKey(name: 'has_moderation')
  final bool? hasModeration; // «На модерации» (статус 3/4)
  @JsonKey(name: 'has_crm')
  final bool? hasCrm; // «CRM» (статус 1 + фид)
  @JsonKey(name: 'has_manual')
  final bool? hasManual; // «Все» (статус 1 без фида)

  AdvertMetaCategory({
    required this.categoryId,
    required this.name,
    this.hasActive,
    this.hasInactive,
    this.hasArchive,
    this.hasModeration,
    this.hasCrm,
    this.hasManual,
  });

  factory AdvertMetaCategory.fromJson(Map<String, dynamic> json) =>
      _$AdvertMetaCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertMetaCategoryToJson(this);
}

@JsonSerializable()
class AdvertMetaTab {
  @JsonKey(name: 'advert_status_id')
  final int advertStatusId;
  final String name;

  AdvertMetaTab({required this.advertStatusId, required this.name});

  factory AdvertMetaTab.fromJson(Map<String, dynamic> json) =>
      _$AdvertMetaTabFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertMetaTabToJson(this);
}

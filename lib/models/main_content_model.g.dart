// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_content_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MainContent _$MainContentFromJson(Map<String, dynamic> json) => MainContent(
  data: MainContentData.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MainContentToJson(MainContent instance) =>
    <String, dynamic>{'data': instance.data};

MainContentData _$MainContentDataFromJson(Map<String, dynamic> json) =>
    MainContentData(
      catalogs: (json['catalogs'] as List<dynamic>)
          .map((e) => MainCatalog.fromJson(e as Map<String, dynamic>))
          .toList(),
      adverts: (json['adverts'] as List<dynamic>)
          .map((e) => MainAdvert.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MainContentDataToJson(MainContentData instance) =>
    <String, dynamic>{
      'catalogs': instance.catalogs,
      'adverts': instance.adverts,
    };

MainCatalog _$MainCatalogFromJson(Map<String, dynamic> json) => MainCatalog(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  thumbnail: json['thumbnail'] as String?,
  slug: json['slug'] as String,
  type: ContentType.fromJson(json['type'] as Map<String, dynamic>),
  order: json['order'] as String,
);

Map<String, dynamic> _$MainCatalogToJson(MainCatalog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'thumbnail': instance.thumbnail,
      'slug': instance.slug,
      'type': instance.type,
      'order': instance.order,
    };

MainAdvert _$MainAdvertFromJson(Map<String, dynamic> json) => MainAdvert(
  id: (json['id'] as num).toInt(),
  date: json['date'] as String,
  name: json['name'] as String,
  price: json['price'] as String,
  thumbnail: json['thumbnail'] as String?,
  status: AdvertStatus.fromJson(json['status'] as Map<String, dynamic>),
  address: json['address'] as String,
  views_count: (json['views_count'] as num).toInt(),
  click_count: (json['click_count'] as num).toInt(),
  share_count: (json['share_count'] as num).toInt(),
  type: ContentType.fromJson(json['type'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MainAdvertToJson(MainAdvert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'name': instance.name,
      'price': instance.price,
      'thumbnail': instance.thumbnail,
      'status': instance.status,
      'address': instance.address,
      'views_count': instance.views_count,
      'click_count': instance.click_count,
      'share_count': instance.share_count,
      'type': instance.type,
    };

AdvertStatus _$AdvertStatusFromJson(Map<String, dynamic> json) => AdvertStatus(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
);

Map<String, dynamic> _$AdvertStatusToJson(AdvertStatus instance) =>
    <String, dynamic>{'id': instance.id, 'title': instance.title};

ContentType _$ContentTypeFromJson(Map<String, dynamic> json) => ContentType(
  id: (json['id'] as num).toInt(),
  type: json['type'] as String,
  path: json['path'] as String,
);

Map<String, dynamic> _$ContentTypeToJson(ContentType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'path': instance.path,
    };

UserAdvert _$UserAdvertFromJson(Map<String, dynamic> json) => UserAdvert(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  thumbnail: json['thumbnail'] as String?,
  price: json['price'] as String,
  slug: json['slug'] as String,
  address: json['address'] as String,
  viewsCount: (json['views_count'] as num).toInt(),
  clickCount: (json['click_count'] as num).toInt(),
  shareCount: (json['share_count'] as num).toInt(),
  createdAt: json['created_at'] as String,
  type: ContentType.fromJson(json['type'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserAdvertToJson(UserAdvert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'thumbnail': instance.thumbnail,
      'price': instance.price,
      'slug': instance.slug,
      'address': instance.address,
      'views_count': instance.viewsCount,
      'click_count': instance.clickCount,
      'share_count': instance.shareCount,
      'created_at': instance.createdAt,
      'type': instance.type,
    };

AdvertMetaResponse _$AdvertMetaResponseFromJson(Map<String, dynamic> json) =>
    AdvertMetaResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => AdvertMetaData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AdvertMetaResponseToJson(AdvertMetaResponse instance) =>
    <String, dynamic>{'data': instance.data};

AdvertMetaData _$AdvertMetaDataFromJson(Map<String, dynamic> json) =>
    AdvertMetaData(
      catalogs: (json['catalogs'] as List<dynamic>)
          .map((e) => AdvertMetaCatalog.fromJson(e as Map<String, dynamic>))
          .toList(),
      tabs: (json['tabs'] as List<dynamic>)
          .map((e) => AdvertMetaTab.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AdvertMetaDataToJson(AdvertMetaData instance) =>
    <String, dynamic>{'catalogs': instance.catalogs, 'tabs': instance.tabs};

AdvertMetaCatalog _$AdvertMetaCatalogFromJson(Map<String, dynamic> json) =>
    AdvertMetaCatalog(
      catalogId: (json['catalog_id'] as num).toInt(),
      name: json['name'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => AdvertMetaCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AdvertMetaCatalogToJson(AdvertMetaCatalog instance) =>
    <String, dynamic>{
      'catalog_id': instance.catalogId,
      'name': instance.name,
      'categories': instance.categories,
    };

AdvertMetaCategory _$AdvertMetaCategoryFromJson(Map<String, dynamic> json) =>
    AdvertMetaCategory(
      categoryId: (json['category_id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$AdvertMetaCategoryToJson(AdvertMetaCategory instance) =>
    <String, dynamic>{
      'category_id': instance.categoryId,
      'name': instance.name,
    };

AdvertMetaTab _$AdvertMetaTabFromJson(Map<String, dynamic> json) =>
    AdvertMetaTab(
      advertStatusId: (json['advert_status_id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$AdvertMetaTabToJson(AdvertMetaTab instance) =>
    <String, dynamic>{
      'advert_status_id': instance.advertStatusId,
      'name': instance.name,
    };

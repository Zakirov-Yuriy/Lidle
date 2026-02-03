// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Catalog _$CatalogFromJson(Map<String, dynamic> json) => Catalog(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  thumbnail: json['thumbnail'] as String?,
  slug: json['slug'] as String,
  type: CatalogType.fromJson(json['type'] as Map<String, dynamic>),
  order: json['order'] as String?,
  categories: (json['categories'] as List<dynamic>?)
      ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CatalogToJson(Catalog instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'thumbnail': instance.thumbnail,
  'slug': instance.slug,
  'type': instance.type,
  'order': instance.order,
  'categories': instance.categories,
};

CatalogType _$CatalogTypeFromJson(Map<String, dynamic> json) => CatalogType(
  id: (json['id'] as num).toInt(),
  type: json['type'] as String,
  path: json['path'] as String,
);

Map<String, dynamic> _$CatalogTypeToJson(CatalogType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'path': instance.path,
    };

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num).toInt(),
  catalog_id: (json['catalog_id'] as num).toInt(),
  name: json['name'] as String,
  breadcrumbs: json['breadcrumbs'] as String?,
  thumbnail: json['thumbnail'] as String?,
  slug: json['slug'] as String,
  type: CatalogType.fromJson(json['type'] as Map<String, dynamic>),
  order: json['order'] as String?,
  is_endpoint: json['is_endpoint'] as bool,
  children: (json['children'] as List<dynamic>?)
      ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'catalog_id': instance.catalog_id,
  'name': instance.name,
  'breadcrumbs': instance.breadcrumbs,
  'thumbnail': instance.thumbnail,
  'slug': instance.slug,
  'type': instance.type,
  'order': instance.order,
  'is_endpoint': instance.is_endpoint,
  'children': instance.children,
};

CatalogResponse _$CatalogResponseFromJson(Map<String, dynamic> json) =>
    CatalogResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => Catalog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CatalogResponseToJson(CatalogResponse instance) =>
    <String, dynamic>{'data': instance.data};

CatalogsResponse _$CatalogsResponseFromJson(Map<String, dynamic> json) =>
    CatalogsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => Catalog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CatalogsResponseToJson(CatalogsResponse instance) =>
    <String, dynamic>{'data': instance.data};

CategoriesResponse _$CategoriesResponseFromJson(Map<String, dynamic> json) =>
    CategoriesResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
      links: json['links'] == null
          ? null
          : CategoriesLinks.fromJson(json['links'] as Map<String, dynamic>),
      meta: json['meta'] == null
          ? null
          : CategoriesMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CategoriesResponseToJson(CategoriesResponse instance) =>
    <String, dynamic>{
      'data': instance.data,
      'links': instance.links,
      'meta': instance.meta,
    };

CategoriesLinks _$CategoriesLinksFromJson(Map<String, dynamic> json) =>
    CategoriesLinks(
      first: json['first'] as String?,
      last: json['last'] as String?,
      prev: json['prev'] as String?,
      next: json['next'] as String?,
    );

Map<String, dynamic> _$CategoriesLinksToJson(CategoriesLinks instance) =>
    <String, dynamic>{
      'first': instance.first,
      'last': instance.last,
      'prev': instance.prev,
      'next': instance.next,
    };

CategoriesMeta _$CategoriesMetaFromJson(Map<String, dynamic> json) =>
    CategoriesMeta(
      current_page: (json['current_page'] as num).toInt(),
      from: (json['from'] as num).toInt(),
      last_page: (json['last_page'] as num).toInt(),
      path: json['path'] as String,
      per_page: (json['per_page'] as num).toInt(),
      to: (json['to'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$CategoriesMetaToJson(CategoriesMeta instance) =>
    <String, dynamic>{
      'current_page': instance.current_page,
      'from': instance.from,
      'last_page': instance.last_page,
      'path': instance.path,
      'per_page': instance.per_page,
      'to': instance.to,
      'total': instance.total,
    };

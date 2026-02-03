import 'package:json_annotation/json_annotation.dart';

part 'catalog_category_model.g.dart';

/// Модель каталога (версия из API документации)
@JsonSerializable()
class Catalog {
  final int id;
  final String name;
  final String? thumbnail;
  final String slug;
  final CatalogType type;
  final String? order;
  final List<Category>? categories;

  Catalog({
    required this.id,
    required this.name,
    this.thumbnail,
    required this.slug,
    required this.type,
    this.order,
    this.categories,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) =>
      _$CatalogFromJson(json);
  Map<String, dynamic> toJson() => _$CatalogToJson(this);
}

/// Тип каталога (Adverts, Works и т.д.)
@JsonSerializable()
class CatalogType {
  final int id;
  final String type;
  final String path;

  CatalogType({required this.id, required this.type, required this.path});

  factory CatalogType.fromJson(Map<String, dynamic> json) =>
      _$CatalogTypeFromJson(json);
  Map<String, dynamic> toJson() => _$CatalogTypeToJson(this);
}

/// Модель категории
@JsonSerializable()
class Category {
  final int id;
  final int catalog_id;
  final String name;
  final String? breadcrumbs;
  final String? thumbnail;
  final String slug;
  final CatalogType type;
  final String? order;
  final bool is_endpoint;
  final List<Category>? children;

  Category({
    required this.id,
    required this.catalog_id,
    required this.name,
    this.breadcrumbs,
    this.thumbnail,
    required this.slug,
    required this.type,
    this.order,
    required this.is_endpoint,
    this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}

/// Ответ при получении каталога с категориями
@JsonSerializable()
class CatalogResponse {
  final List<Catalog> data;

  CatalogResponse({required this.data});

  factory CatalogResponse.fromJson(Map<String, dynamic> json) =>
      _$CatalogResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CatalogResponseToJson(this);
}

/// Ответ при получении списка каталогов
@JsonSerializable()
class CatalogsResponse {
  final List<Catalog> data;

  CatalogsResponse({required this.data});

  factory CatalogsResponse.fromJson(Map<String, dynamic> json) =>
      _$CatalogsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CatalogsResponseToJson(this);
}

/// Ответ при поиске категорий
@JsonSerializable()
class CategoriesResponse {
  final List<Category> data;
  final CategoriesLinks? links;
  final CategoriesMeta? meta;

  CategoriesResponse({required this.data, this.links, this.meta});

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$CategoriesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CategoriesResponseToJson(this);
}

@JsonSerializable()
class CategoriesLinks {
  final String? first;
  final String? last;
  final String? prev;
  final String? next;

  CategoriesLinks({this.first, this.last, this.prev, this.next});

  factory CategoriesLinks.fromJson(Map<String, dynamic> json) =>
      _$CategoriesLinksFromJson(json);
  Map<String, dynamic> toJson() => _$CategoriesLinksToJson(this);
}

@JsonSerializable()
class CategoriesMeta {
  final int current_page;
  final int from;
  final int last_page;
  final String path;
  final int per_page;
  final int to;
  final int total;

  CategoriesMeta({
    required this.current_page,
    required this.from,
    required this.last_page,
    required this.path,
    required this.per_page,
    required this.to,
    required this.total,
  });

  factory CategoriesMeta.fromJson(Map<String, dynamic> json) =>
      _$CategoriesMetaFromJson(json);
  Map<String, dynamic> toJson() => _$CategoriesMetaToJson(this);
}

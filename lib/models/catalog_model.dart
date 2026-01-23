import 'package:lidle/models/advert_model.dart';

class Catalog {
  final int id;
  final String name;
  final String? thumbnail;
  final String slug;
  final CatalogType type;
  final int? order;

  Catalog({
    required this.id,
    required this.name,
    this.thumbnail,
    required this.slug,
    required this.type,
    this.order,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      id: json['id'],
      name: json['name'],
      thumbnail: json['thumbnail'],
      slug: json['slug'],
      type: CatalogType.fromJson(json['type']),
      order: json['order'] as int?,
    );
  }
}

class CatalogType {
  final int id;
  final String slug;

  CatalogType({required this.id, required this.slug});

  factory CatalogType.fromJson(Map<String, dynamic> json) {
    return CatalogType(id: json['id'], slug: json['slug']);
  }
}

class Category {
  final int id;
  final int catalogId;
  final String name;
  final String? breadcrumbs;
  final String? thumbnail;
  final String slug;
  final CategoryType type;
  final String? order;
  final bool isEndpoint;
  final List<Category>? children;

  Category({
    required this.id,
    required this.catalogId,
    required this.name,
    this.breadcrumbs,
    this.thumbnail,
    required this.slug,
    required this.type,
    this.order,
    required this.isEndpoint,
    this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      catalogId: json['catalog_id'],
      name: json['name'],
      breadcrumbs: json['breadcrumbs'],
      thumbnail: json['thumbnail'],
      slug: json['slug'],
      type: CategoryType.fromJson(json['type']),
      order: json['order'],
      isEndpoint: json['is_endpoint'] ?? false,
      children: json['children'] != null
          ? (json['children'] as List<dynamic>)
                .map((item) => Category.fromJson(item as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}

class CategoryType {
  final int id;
  final String slug;

  CategoryType({required this.id, required this.slug});

  factory CategoryType.fromJson(Map<String, dynamic> json) {
    return CategoryType(id: json['id'], slug: json['slug']);
  }
}

class CatalogWithCategories {
  final int id;
  final String name;
  final String? thumbnail;
  final String slug;
  final CatalogType type;
  final int? order;
  final List<Category> categories;

  CatalogWithCategories({
    required this.id,
    required this.name,
    this.thumbnail,
    required this.slug,
    required this.type,
    this.order,
    required this.categories,
  });

  factory CatalogWithCategories.fromJson(Map<String, dynamic> json) {
    return CatalogWithCategories(
      id: json['id'],
      name: json['name'],
      thumbnail: json['thumbnail'],
      slug: json['slug'],
      type: CatalogType.fromJson(json['type']),
      order: json['order'] as int?,
      categories: (json['categories'] as List<dynamic>)
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CatalogsResponse {
  final List<Catalog> data;

  CatalogsResponse({required this.data});

  factory CatalogsResponse.fromJson(Map<String, dynamic> json) {
    return CatalogsResponse(
      data: (json['data'] as List<dynamic>)
          .map((item) => Catalog.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategoriesResponse {
  final List<Category> data;
  final Links links;
  final Meta meta;

  CategoriesResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    return CategoriesResponse(
      data: (json['data'] as List<dynamic>)
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList(),
      links: Links.fromJson(json['links']),
      meta: Meta.fromJson(json['meta']),
    );
  }
}

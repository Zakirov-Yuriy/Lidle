import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/services/api_service.dart';

/// Витрина товаров: список, разделы, карточка.
///
/// Отдельно от объявлений намеренно. Товар и объявление это разные сущности с
/// разными таблицами и разными разделами каталога; складывать их в один сервис
/// значит однажды отфильтровать товары категорией объявлений.
class ProductsService {
  /// Список товаров.
  ///
  /// Все отборы необязательные: витрина должна открываться и без единого
  /// фильтра. Этим она отличается от списка объявлений, где категория
  /// обязательна.
  static Future<ProductsPage> list({
    int? categoryId,
    String? categorySlug,
    int? catalogId,
    String? search,
    int? shopId,
    double? priceMin,
    double? priceMax,
    bool inStockOnly = false,
    String? sort,
    int page = 1,
    int perPage = 30,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };

    if (categoryId != null) query['category_id'] = '$categoryId';
    if (categorySlug != null && categorySlug.isNotEmpty) {
      query['category_slug'] = categorySlug;
    }
    if (catalogId != null) query['catalog_id'] = '$catalogId';
    if (search != null && search.trim().length >= 2) {
      query['search'] = search.trim();
    }
    if (shopId != null) query['shop_id'] = '$shopId';
    if (priceMin != null) query['price_min'] = _money(priceMin);
    if (priceMax != null) query['price_max'] = _money(priceMax);
    if (inStockOnly) query['in_stock'] = '1';
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;

    final path = '/products?${_queryString(query)}';

    try {
      final response = await ApiService.get(path);

      return ProductsPage.fromJson(response);
    } catch (e) {
      log.e('Не удалось загрузить товары: $e');

      // Ошибку НЕ превращаем в пустой список. Пустая витрина и сломанный
      // запрос выглядят одинаково, а причины у них противоположные: в первом
      // случае надо менять раздел, во втором чинить сервер. Сегодня мы на этом
      // потеряли полчаса, разыскивая «пропавшие» товары, пока сервер честно
      // отвечал пятисоткой.
      return ProductsPage.failed('$e');
    }
  }

  /// Дерево разделов товаров.
  ///
  /// Приходит готовым деревом, а не плоским списком: собирать его на клиенте
  /// значит повторять ту же работу в приложении, на сайте и в админке.
  static Future<List<ProductCategory>> catalogs() async {
    try {
      final response = await ApiService.get('/products/catalogs');
      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(ProductCategory.fromJson)
          .toList();
    } catch (e) {
      log.d('Не удалось загрузить разделы товаров: $e');

      return const [];
    }
  }

  /// Раздел по слагу вместе с хлебными крошками и подразделами.
  static Future<ProductCategoryPage?> category(String slug) async {
    try {
      final response = await ApiService.get('/products/categories/$slug');
      final data = response['data'];

      if (data is! Map<String, dynamic>) return null;

      return ProductCategoryPage.fromJson(data);
    } catch (e) {
      log.d('Не удалось загрузить раздел $slug: $e');

      return null;
    }
  }

  /// Карточка товара.
  static Future<ProductItem?> details(int productId) async {
    try {
      final response = await ApiService.get('/products/$productId');
      final data = response['data'];

      // Карточка исторически приходит коллекцией из одного элемента, как и у
      // объявлений. Разбираем оба вида, чтобы не сломаться при выравнивании.
      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        return ProductItem.fromJson(data.first as Map<String, dynamic>);
      }

      if (data is Map<String, dynamic>) {
        return ProductItem.fromJson(data);
      }

      return null;
    } catch (e) {
      log.d('Не удалось загрузить товар $productId: $e');

      return null;
    }
  }

  static String _queryString(Map<String, String> query) {
    return query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  /// Деньги в запрос отправляем строкой без экспоненты: `1.0E+7` сервер не
  /// поймёт, а `toString()` у больших double именно так и пишет.
  static String _money(double value) => value.toStringAsFixed(2);
}

/// Страница списка товаров вместе с пагинацией.
class ProductsPage {
  final List<ProductItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Текст ошибки, если загрузка не удалась. `null` — всё хорошо, даже если
  /// товаров ноль: пустой раздел это не ошибка.
  final String? error;

  const ProductsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.error,
  });

  factory ProductsPage.empty() =>
      const ProductsPage(items: [], currentPage: 1, lastPage: 1, total: 0);

  factory ProductsPage.failed(String error) =>
      ProductsPage(items: const [], currentPage: 1, lastPage: 1, total: 0,
          error: error);

  bool get isFailed => error != null;

  factory ProductsPage.fromJson(Map<String, dynamic> response) {
    final data = response['data'];
    final meta = response['meta'];

    return ProductsPage(
      items: data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ProductItem.fromJson)
                .toList()
          : const [],
      currentPage: meta is Map ? (_int(meta['current_page']) ?? 1) : 1,
      lastPage: meta is Map ? (_int(meta['last_page']) ?? 1) : 1,
      total: meta is Map ? (_int(meta['total']) ?? 0) : 0,
    );
  }

  bool get hasMore => currentPage < lastPage;

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Раздел каталога со своими крошками и подразделами.
class ProductCategoryPage {
  final ProductCategory category;
  final List<ProductCategory> breadcrumbs;
  final List<ProductCategory> children;

  const ProductCategoryPage({
    required this.category,
    required this.breadcrumbs,
    required this.children,
  });

  factory ProductCategoryPage.fromJson(Map<String, dynamic> data) {
    final crumbs = data['breadcrumbs'];
    final children = data['children'];

    return ProductCategoryPage(
      category: ProductCategory.fromJson(data),
      breadcrumbs: crumbs is List
          ? crumbs
                .whereType<Map<String, dynamic>>()
                .map(ProductCategory.fromJson)
                .toList()
          : const [],
      children: children is List
          ? children
                .whereType<Map<String, dynamic>>()
                .map(ProductCategory.fromJson)
                .toList()
          : const [],
    );
  }
}

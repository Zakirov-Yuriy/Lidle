import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/product_favorites_service.dart';

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

      final page = ProductsPage.fromJson(response);

      _rememberFavorites(page.items);

      return page;
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
  static Future<List<ProductCategory>> catalogs({
    /// Только разделы, в которых есть товары (14.09.2026).
    ///
    /// Витрина рисует разделы лентой кнопок сверху, и пустой раздел там
    /// только мешает: человек нажимает «Обувь», видит «ничего не найдено» и
    /// решает, что приложение сломалось.
    bool onlyWithProducts = false,
  }) async {
    try {
      final response = await ApiService.get(
        '/products/catalogs${onlyWithProducts ? '?only_with_products=1' : ''}',
      );
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
      ProductItem? product;

      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        product = ProductItem.fromJson(data.first as Map<String, dynamic>);
      } else if (data is Map<String, dynamic>) {
        product = ProductItem.fromJson(data);
      }

      // Сердечко живёт в общем состоянии: тот же товар виден и в ленте, и в
      // разделе, и собственная память карточки разошлась бы с правдой.
      if (product != null) {
        _rememberFavorites([product]);
      }

      return product;
    } catch (e) {
      log.d('Не удалось загрузить товар $productId: $e');

      return null;
    }
  }

  /// Похожие предложения к товару (17.09.2026).
  ///
  /// Подбирает сервер: тот же раздел, любые продавцы, сам товар исключён,
  /// сортировка по близости цены. Правило живёт на сервере, а не здесь:
  /// повторять его в приложении и на сайте значит однажды показать разные
  /// подборки для одного товара.
  static Future<List<ProductItem>> similar(int productId, {int limit = 10}) async {
    try {
      final response = await ApiService.get(
        '/products/$productId/similar?limit=$limit',
      );

      final data = response['data'];

      if (data is! List) return const [];

      final items = data
          .whereType<Map<String, dynamic>>()
          .map(ProductItem.fromJson)
          .toList();

      // Сердечки тех же товаров живут в общем состоянии: подборка стоит рядом
      // с лентой, и своя память у неё разошлась бы с правдой.
      _rememberFavorites(items);

      return items;
    } catch (e) {
      log.d('Похожие товары не загрузились ($productId): $e');

      return const [];
    }
  }

  /// Оставить или переписать отзыв о товаре (15.09.2026).
  ///
  /// Возвращает `null`, если всё хорошо, иначе текст ошибки с сервера — он
  /// написан для показа человеку («Отзыв можно оставить после того, как
  /// заберёте заказ с этим товаром»), и придумывать свой значит сказать менее
  /// точно.
  static Future<String?> submitReview(
    int productId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await ApiService.post('/products/$productId/reviews', {
        'reaction': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'text': comment.trim(),
      });

      if (response['success'] == true) return null;

      return '${response['message'] ?? 'Не получилось сохранить отзыв'}';
    } catch (e) {
      log.d('Отзыв о товаре $productId не сохранился: $e');

      return 'Не получилось сохранить отзыв. Проверьте связь.';
    }
  }

  /// Изменить свой отзыв о товаре (18.09.2026).
  ///
  /// Оценка у товара зовётся `reaction`, а не `rating`: так называется
  /// колонка, и так её ждёт сервер. Возвращает `null` при успехе и текст
  /// ошибки иначе, как и остальные методы здесь.
  static Future<String?> updateReview(
    int reviewId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await ApiService.put('/product-reviews/$reviewId', {
        'reaction': rating,
        if (comment != null) 'text': comment.trim(),
      });

      if (response['success'] == true) return null;

      return '${response['message'] ?? 'Не получилось изменить отзыв'}';
    } catch (e) {
      log.d('Отзыв $reviewId не изменился: $e');

      return 'Не получилось изменить отзыв. Проверьте связь.';
    }
  }

  /// Ответ продавца на отзыв о его товаре (21.09.2026).
  ///
  /// Поле `comment`, как у ответа на отзыв объявления: диалог ответа общий.
  /// Возвращает тело ответа сервера (`reply`, `replied_at`) при успехе и
  /// `null` иначе, ровно как `ApiService.replyAdvertReview`: диалогу так
  /// проще, он не различает, чей это отзыв.
  static Future<Map<String, dynamic>?> replyReview(
    int reviewId, {
    required String comment,
  }) async {
    try {
      final response = await ApiService.post(
        '/product-reviews/$reviewId/reply',
        {'comment': comment.trim()},
      );

      if (response['success'] == true) return response;

      return null;
    } catch (e) {
      log.d('Ответ на отзыв о товаре $reviewId не сохранился: $e');

      return null;
    }
  }

  /// Удалить свой отзыв.
  static Future<String?> deleteReview(int reviewId) async {
    try {
      final response = await ApiService.delete('/product-reviews/$reviewId');

      if (response['success'] == true) return null;

      return '${response['message'] ?? 'Не получилось удалить отзыв'}';
    } catch (e) {
      log.d('Отзыв $reviewId не удалился: $e');

      return 'Не получилось удалить отзыв. Проверьте связь.';
    }
  }

  /// Отзывы товара отдельной страницей: в карточке их десять, остальные здесь.
  static Future<List<ProductReview>> reviews(int productId, {int page = 1}) async {
    try {
      final response = await ApiService.get(
        '/products/$productId/reviews?page=$page',
      );

      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(ProductReview.fromJson)
          .toList();
    } catch (e) {
      log.d('Отзывы товара $productId не загрузились: $e');

      return const [];
    }
  }

  /// Перенести сердечки из ответа в общее состояние.
  ///
  /// Признак приходит с каждой карточкой, а показывают его разные экраны, и
  /// держать его в каждом списке отдельно значит однажды увидеть в ленте
  /// одно, а в разделе другое.
  static void _rememberFavorites(List<ProductItem> items) {
    for (final item in items) {
      ProductFavoritesService.remember(
        item.id,
        item.isWishlisted,
        item.wishlistId,
      );
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

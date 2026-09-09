// ============================================================
// Кабинет продавца: публикации товаров, группы, позиции, бренды.
// ============================================================
//
// Экраны «Добавить товар» и «Добавить позицию» (макет 09.09.2026).
//
// Главное, что стоит помнить, читая это: ПОЗИЦИЯ ЭТО ОБЫЧНЫЙ ТОВАР. Отдельной
// ручки «создать позицию» нет, всё уходит в `/me/products` — тот же адрес,
// которым кабинет пользуется с задачи 4. Публикация и группа приезжают
// вместе с товаром тремя полями.
//
// Документация: back/api/product-publications-api.md

import 'package:lidle/core/logger.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/services/api_service.dart';

class ProductsCabinetApi {
  // ── Публикация ────────────────────────────────────────────────────

  /// Завести публикацию. Делается сразу после выбора раздела: картинки групп
  /// и позиций заливаются на сервер, а заливать их некуда, пока публикации
  /// нет.
  static Future<ProductPublication> createPublication({
    required int categoryId,
    int? brandId,
    int? shopId,
    bool isAutoRenew = false,
  }) async {
    final response = await ApiService.post('/me/product-publications', {
      'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (shopId != null) 'shop_id': shopId,
      'is_auto_renew': isAutoRenew,
    });

    return ProductPublication.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),

      // Сервер честно говорит, что точку продаж он выбрать не смог: у
      // продавца их несколько. Экран должен спросить, а не молчать.
      needsShop: response['needs_shop'] == true,
    );
  }

  /// Публикация целиком: группы с обложками и позиции внутри них.
  static Future<ProductPublication> publication(int id) async {
    final response = await ApiService.get('/me/product-publications/$id');

    return ProductPublication.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Изменить публикацию: бренд, автопродление, точка продаж.
  static Future<ProductPublication> updatePublication(
    int id, {
    int? categoryId,
    int? brandId,
    int? shopId,
    bool? isAutoRenew,
  }) async {
    final response = await ApiService.put('/me/product-publications/$id', {
      if (categoryId != null) 'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (shopId != null) 'shop_id': shopId,
      if (isAutoRenew != null) 'is_auto_renew': isAutoRenew,
    });

    return ProductPublication.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Опубликовать: публикация и все её позиции уходят на витрину разом.
  ///
  /// Отказы сервера осмысленные, и их надо показывать человеку как есть:
  /// «выберите магазин» и «нет ни одной позиции» это не ошибки связи.
  static Future<ProductPublication> publish(int id) async {
    final response = await ApiService.post(
      '/me/product-publications/$id/publish',
      const {},
    );

    return ProductPublication.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Группы ────────────────────────────────────────────────────────

  static Future<ProductGroup> createGroup({
    required int publicationId,
    required String name,
    int? order,
  }) async {
    final response = await ApiService.post(
      '/me/product-publications/$publicationId/groups',
      {
        'name': name,
        if (order != null) 'order': order,
      },
    );

    return ProductGroup.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  static Future<ProductGroup> renameGroup(int groupId, String name) async {
    final response = await ApiService.put(
      '/me/product-publications/groups/$groupId',
      {'name': name},
    );

    return ProductGroup.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  static Future<void> deleteGroup(int groupId) async {
    await ApiService.delete('/me/product-publications/groups/$groupId');
  }

  /// Обложка группы.
  ///
  /// Обложка одна: новая заменяет старую, старый файл сервер удаляет сам.
  static Future<ProductGroup> uploadGroupImage(
    int groupId,
    String filePath,
  ) async {
    final response = await ApiService.uploadFile(
      '/me/product-publications/groups/$groupId/image',
      filePath: filePath,
      fieldName: 'image',
    );

    return ProductGroup.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Позиция ───────────────────────────────────────────────────────

  /// Поля формы позиции для раздела: «Тип одежды», «С принтом», «Размер».
  ///
  /// Ручка та же по смыслу, что у объявлений, и модель `Attribute` та же —
  /// поэтому форма позиции рисуется теми же виджетами, что форма подачи
  /// объявления, и выглядит для человека одинаково.
  static Future<List<Attribute>> positionFields(int categoryId) async {
    final response = await ApiService.getWithQuery(
      '/me/products/attributes',
      {'category_id': categoryId},
    );

    final data = response['data'];

    if (data is! List) return const [];

    final fields = <Attribute>[];

    for (final item in data) {
      if (item is Map<String, dynamic>) {
        try {
          fields.add(Attribute.fromJson(item));
        } catch (e) {
          // Одно испорченное поле не должно уносить всю форму: человек
          // заполнит остальные и сохранит товар.
          log.d('Поле характеристики не разобралось: $e');
        }
      }
    }

    return fields;
  }

  /// Завести позицию. Это обычный товар: `/me/products`.
  static Future<int> createPosition({
    required int publicationId,
    required int categoryId,
    required String name,
    required num price,
    required int stockQuantity,
    int? groupId,
    int? position,
    int? brandId,
    int? colorId,
    String? description,
    Map<String, dynamic>? attributes,
  }) async {
    final response = await ApiService.post('/me/products', {
      'publication_id': publicationId,
      if (groupId != null) 'group_id': groupId,
      if (position != null) 'position': position,
      'category_id': categoryId,
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'price': price,
      'stock_quantity': stockQuantity,
      if (brandId != null) 'brand_id': brandId,
      if (colorId != null) 'color_id': colorId,
      if (attributes != null) 'attributes': attributes,
    });

    final data = response['data'];

    return data is Map && data['id'] is int ? data['id'] as int : 0;
  }

  /// Картинки позиции. Ручка та же, что у товаров кабинета с задачи 4.
  ///
  /// Сервер заменяет набор целиком, поэтому уже сохранённые картинки, если их
  /// надо оставить, приезжают именами в том же запросе.
  static Future<void> uploadPositionImages(
    int productId,
    List<String> filePaths, {
    List<String> keep = const [],
  }) async {
    if (filePaths.isEmpty && keep.isEmpty) return;

    await ApiService.uploadImages(
      '/me/products/$productId/images',
      filePaths: filePaths,
      existingImages: keep,
    );
  }

  static Future<void> updatePosition(
    int productId, {
    String? name,
    num? price,
    int? stockQuantity,
    int? groupId,
    int? position,
    int? brandId,
    int? colorId,
    String? description,
    Map<String, dynamic>? attributes,
  }) async {
    await ApiService.put('/me/products/$productId', {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (stockQuantity != null) 'stock_quantity': stockQuantity,
      if (groupId != null) 'group_id': groupId,
      if (position != null) 'position': position,
      if (brandId != null) 'brand_id': brandId,
      if (colorId != null) 'color_id': colorId,
      if (attributes != null) 'attributes': attributes,
    });
  }

  // ── Бренды ────────────────────────────────────────────────────────

  /// Поиск по мере ввода.
  static Future<List<ProductBrand>> brands({String? search}) async {
    final response = await ApiService.getWithQuery('/me/brands', {
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final data = response['data'];

    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ProductBrand.fromJson)
        .toList();
  }

  /// Мои бренды: те, под которыми продавец уже что-то завёл, с числом
  /// товаров в каждом.
  ///
  /// У продавца бывает несколько брендов, и в каждом свои товары (решение
  /// заказчика от 09.09.2026). Выбор бренда на экране публикации переключает
  /// витрину: открывается то, что под этим брендом уже заведено.
  static Future<List<ProductBrand>> myBrands() async {
    final response = await ApiService.get('/me/brands/mine');

    final data = response['data'];

    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ProductBrand.fromJson)
        .toList();
  }

  /// Кнопка «Создать» у бренда.
  ///
  /// Бренд с таким же названием сервер не заводит второй раз, а возвращает
  /// существующий. Для экрана разницы нет: в обоих случаях приходит бренд,
  /// который надо подставить в поле.
  static Future<ProductBrand> createBrand(String name) async {
    final response = await ApiService.post('/me/brands', {'name': name});

    return ProductBrand.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }
}

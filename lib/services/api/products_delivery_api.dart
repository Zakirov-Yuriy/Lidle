// ============================================================
// Доставка публикации: группы и способы (макет 10.09.2026).
// ============================================================
//
// Ручки повторяют товарные один в один — те же действия в том же порядке,
// потому что и экран доставки повторяет экран групп товара.
//
// Документация: back/api/product-publications-api.md

import 'package:lidle/models/products/product_delivery.dart';
import 'package:lidle/services/api_service.dart';

class ProductsDeliveryApi {
  /// Вся доставка публикации: группы с их способами и способы вне групп.
  static Future<PublicationDelivery> load(int publicationId) async {
    final response = await ApiService.get(
      '/me/product-publications/$publicationId/deliveries',
    );

    return PublicationDelivery.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  // ── Группы ────────────────────────────────────────────────────────

  static Future<DeliveryGroup> createGroup({
    required int publicationId,
    required String name,
    int? order,
  }) async {
    final response = await ApiService.post(
      '/me/product-publications/$publicationId/delivery-groups',
      {
        'name': name,
        if (order != null) 'order': order,
      },
    );

    return DeliveryGroup.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  static Future<void> renameGroup(int groupId, String name) async {
    await ApiService.put(
      '/me/product-publications/delivery-groups/$groupId',
      {'name': name},
    );
  }

  static Future<void> deleteGroup(int groupId) async {
    await ApiService.delete('/me/product-publications/delivery-groups/$groupId');
  }

  /// Обложка группы. Одна: новая заменяет старую.
  static Future<void> uploadGroupImage(int groupId, String filePath) async {
    await ApiService.uploadFile(
      '/me/product-publications/delivery-groups/$groupId/image',
      filePath: filePath,
      fieldName: 'image',
    );
  }

  // ── Способы ───────────────────────────────────────────────────────

  static Future<DeliveryOption> createOption({
    required int publicationId,
    required String name,
    String? description,
    num? priceFrom,
    int? groupId,
    int? order,
  }) async {
    final response = await ApiService.post(
      '/me/product-publications/$publicationId/delivery-options',
      {
        'name': name,
        if (description != null) 'description': description,
        if (priceFrom != null) 'price_from': priceFrom,
        if (groupId != null) 'group_id': groupId,
        if (order != null) 'order': order,
      },
    );

    return DeliveryOption.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Изменить способ. Группу можно снять, прислав `groupId` = 0.
  ///
  /// Цену передаём всегда, когда её трогали: `null` здесь означает «убрать
  /// цену», а не «не менять», и различить это можно только флагом.
  static Future<void> updateOption(
    int optionId, {
    String? name,
    String? description,
    num? priceFrom,
    bool touchPrice = false,
    int? groupId,
    int? order,
  }) async {
    await ApiService.put(
      '/me/product-publications/delivery-options/$optionId',
      {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (touchPrice) 'price_from': priceFrom,
        if (groupId != null) 'group_id': groupId,
        if (order != null) 'order': order,
      },
    );
  }

  static Future<void> deleteOption(int optionId) async {
    await ApiService.delete(
      '/me/product-publications/delivery-options/$optionId',
    );
  }

  static Future<void> uploadOptionImage(int optionId, String filePath) async {
    await ApiService.uploadFile(
      '/me/product-publications/delivery-options/$optionId/image',
      filePath: filePath,
      fieldName: 'image',
    );
  }
}

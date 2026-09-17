// ============================================================
// "Состав фильтра витрины продавца"
// ============================================================
//
// Панель строится по ответу сервера, а не по заранее записанному списку: у
// одного продавца одежда с размерами и цветами, у другого еда, у третьего
// техника. Жёсткий набор блоков показал бы первому лишнее, а второму пустоту.

import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/store_filters.dart';
import 'package:lidle/services/api_service.dart';

class StoreFiltersService {
  StoreFiltersService._();

  /// Что можно выбрать в фильтре витрины продавца [userId].
  ///
  /// [categoryId] уточняет характеристики: выбрали раздел, и в ответ приходят
  /// размер, цвет и принт именно этого раздела.
  static Future<StoreFilterOptions?> load({
    required String userId,
    int? categoryId,
    String? token,
  }) async {
    final id = int.tryParse(userId.trim());

    if (id == null) return null;

    final query = categoryId == null ? '' : '?category_id=$categoryId';

    try {
      final response = await ApiService.get(
        '/users/$id/store-filters$query',
        token: token,
      );

      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      if (data.isEmpty) return null;

      return StoreFilterOptions.fromJson(data);
    } catch (e) {
      // Молча: фильтр это дополнение к витрине, и если состав не приехал,
      // страница должна работать как прежде, а не показывать ошибку.
      log.d('Состав фильтра витрины не загрузился: $e');

      return null;
    }
  }
}

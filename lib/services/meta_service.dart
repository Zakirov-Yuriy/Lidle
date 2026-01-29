import 'package:lidle/models/filter_meta_model.dart';
import 'package:lidle/services/api_service.dart';

/// Сервис для работы с фильтрами и мета-информацией
class MetaService {
  /// Получить фильтры по категориям или каталогу
  /// Нельзя передавать оба параметра одновременно!
  static Future<FilterMetaResponse> getFilters({
    int? categoryId,
    int? catalogId,
    String? token,
  }) async {
    if (categoryId != null && catalogId != null) {
      throw Exception('Cannot specify both categoryId and catalogId');
    }
    if (categoryId == null && catalogId == null) {
      throw Exception('Must specify either categoryId or catalogId');
    }

    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await ApiService.getWithQuery(
        '/meta/filters',
        queryParams,
        token: token,
      );
      return FilterMetaResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load filters: $e');
    }
  }

  /// Получить список причин жалоб по типу
  /// type может быть: "users", или type_id из объектов карточек
  static Future<ReportsResponse> getReports({
    String? type,
    int? typeId,
    String? token,
  }) async {
    if (type != null && typeId != null) {
      throw Exception('Cannot specify both type and typeId');
    }
    if (type == null && typeId == null) {
      throw Exception('Must specify either type or typeId');
    }

    try {
      final body = <String, dynamic>{};
      if (type != null) body['type'] = type;
      if (typeId != null) body['type_id'] = typeId;

      final response = await ApiService.getWithQuery(
        '/content/reports',
        body,
        token: token,
      );
      return ReportsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load reports: $e');
    }
  }
}

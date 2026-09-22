// ============================================================
// Attributes API — атрибуты для создания объявления и для фильтров.
// ============================================================
// Извлечено из lib/services/api_service.dart:
//   - getAdvertCreationAttributes()    строки 718–784
//   - getMetaFilters()                  строки 1211–1281
//   - getListingsFilterAttributes()     строки 1873–1941
//
// Все три метода работают с атрибутами категорий — объединены в одном модуле.
// Логика идентична оригиналу.

import 'package:lidle/core/logger.dart';
import 'package:lidle/models/advert_form_config.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/services/api_service.dart';

class AttributesApi {
  /// Блок `form` из последнего ответа `/adverts/create` по категории
  /// (22.09.2026). Форма подачи читает его сразу после загрузки атрибутов,
  /// поэтому отдельный запрос не нужен.
  static final Map<int, AdvertFormConfig> _formByCategory = {};

  static AdvertFormConfig formFor(int categoryId) =>
      _formByCategory[categoryId] ?? AdvertFormConfig.fallback;

  /// Поля экранов блоков «Добавить …» по номеру блока (22.09.2026):
  /// «Название зала», «Этаж зала» у «Добавить общий план зала». Сервер отдаёт
  /// их вложенными в атрибут блока (`fields`). В модель Attribute их не
  /// кладём (она генерируется freezed), храним рядом.
  static final Map<int, List<Attribute>> _blockFields = {};

  static List<Attribute> blockFields(int blockId) =>
      _blockFields[blockId] ?? const [];

  /// Получить атрибуты для формы создания объявления.
  /// GET /v1/adverts/create?category_id=X
  static Future<List<Attribute>> getAdvertCreationAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      final response = await ApiService.getWithQuery(
        '/adverts/create',
        {'category_id': categoryId},
        token: token,
      );

      // API возвращает: {"success":true,"data":[{"type":{...},"attributes":[...]}]}
      // data — это List с одним элементом
      final dataNode = response['data'];

      List<dynamic>? attributesJson;

      Map<String, dynamic>? firstItem;

      if (dataNode is List && dataNode.isNotEmpty) {
        firstItem = dataNode[0] as Map<String, dynamic>?;
      } else if (dataNode is Map<String, dynamic>) {
        firstItem = dataNode;
      }

      attributesJson = firstItem?['attributes'] as List<dynamic>?;

      final form = firstItem?['form'];
      if (form is Map<String, dynamic>) {
        _formByCategory[categoryId] = AdvertFormConfig.fromJson(form);
      } else {
        _formByCategory.remove(categoryId);
      }

      if (attributesJson == null || attributesJson.isEmpty) {
        throw Exception('No attributes found in response');
      }

      // Парсим атрибуты с обработкой ошибок
      final attributes = <Attribute>[];
      for (int i = 0; i < attributesJson.length; i++) {
        try {
          final json = attributesJson[i];
          if (json is Map<String, dynamic>) {
            final attr = Attribute.fromJson(json);
            attributes.add(attr);

            final fields = json['fields'];
            if (fields is List && fields.isNotEmpty) {
              _blockFields[attr.id] = fields
                  .whereType<Map<String, dynamic>>()
                  .map(Attribute.fromJson)
                  .toList()
                ..sort((a, b) => a.order.compareTo(b.order));
            } else {
              _blockFields.remove(attr.id);
            }
          }
        } catch (_) {
          // Пропускаем повреждённый атрибут
        }
      }

      return attributes;
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getAdvertCreationAttributes(
            categoryId: categoryId,
            token: newToken,
          );
        }
      }
      throw Exception('Failed to load advert creation attributes: $e');
    }
  }

  /// Получить фильтры для категории.
  /// GET /v1/meta/filters?category_id=X&catalog_id=Y
  static Future<MetaFiltersResponse> getMetaFilters({
    int? categoryId,
    int? catalogId,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await ApiService.getWithQuery(
        '/meta/filters',
        queryParams,
        token: token,
      );

      // API returns { "success": true, "data": {"sort": [...], "filters": [...]} }
      final data = response['data'] ?? response;

      // Диагностика "Вам предложат цену" фильтра (сохранено из оригинала)
      if (data['filters'] is List) {
        final filtersList = data['filters'] as List;
        bool found = false;
        for (final filter in filtersList) {
          final title = filter['title']?.toString() ?? '';
          if (title.contains('предложат') ||
              title.contains('цену') ||
              title.contains('offer') ||
              title.contains('price')) {
            found = true;
          }
        }
        if (!found) {
          // NOTE: фильтр "Вам предложат цену" REQUIRED но не возвращается API.
          // Добавляется программно в _loadAttributes() в DynamicFilter.
        }
      }

      try {
        return MetaFiltersResponse.fromJson(data);
      } catch (parseError) {
        rethrow;
      }
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getMetaFilters(
            categoryId: categoryId,
            catalogId: catalogId,
            token: newToken,
          );
        }
      }
      throw Exception('Failed to load meta filters: $e');
    }
  }

  /// Получить атрибуты для листинга объявлений (экраны фильтров).
  /// GET /v1/adverts/create?category_id=X
  /// Отличие от getAdvertCreationAttributes: более прощающая обработка ошибок —
  /// при любом сбое возвращает `{success: false, ...}` вместо выброса.
  static Future<Map<String, dynamic>> getListingsFilterAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      log.d(
        '🔵 [AttributesApi.getListingsFilterAttributes] START - categoryId=$categoryId, token=${token != null ? 'YES' : 'NO'}',
      );

      // 🔒 Если нет токена — вернуть пустой result, а не падать
      if (token == null || token.isEmpty) {
        log.d(
          '⚠️ [AttributesApi.getListingsFilterAttributes] Пользователь не авторизован (нет токена)',
        );
        return {
          'success': true,
          'data': [],
          'message': 'User not authenticated',
        };
      }

      final response = await ApiService.getWithQuery(
        '/adverts/create',
        {'category_id': categoryId},
        token: token,
      );

      log.d('🔵 [AttributesApi] Raw response: $response');
      log.d(
        '🔵 [AttributesApi] Response data type: ${response['data'].runtimeType}',
      );

      // Если требуется токен и он истёк — обновить и повторить
      if (response['message'] != null &&
          response['message'].toString().contains('Token expired')) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getListingsFilterAttributes(
            categoryId: categoryId,
            token: newToken,
          );
        }
      }

      // Структура ответа: {"data": [{"type": {...}, "attributes": [...]}]}
      List<dynamic> attributes = [];
      if (response['data'] is List) {
        final dataList = response['data'] as List<dynamic>;
        log.d('🔵 [AttributesApi] dataList length: ${dataList.length}');
        if (dataList.isNotEmpty && dataList[0] is Map) {
          final firstItem = dataList[0] as Map<String, dynamic>;
          log.d(
            '🔵 [AttributesApi] firstItem keys: ${firstItem.keys.toList()}',
          );
          attributes = firstItem['attributes'] as List<dynamic>? ?? [];
          log.d(
            '🔵 [AttributesApi] Extracted ${attributes.length} attributes',
          );
        } else {
          log.d(
            '🔵 [AttributesApi] dataList is empty or first item is not Map',
          );
        }
      } else {
        log.d(
          '🔵 [AttributesApi] response[data] is not List, it is: ${response['data'].runtimeType}',
        );
      }

      log.d(
        '🔵 [AttributesApi.getListingsFilterAttributes] SUCCESS - returning ${attributes.length} attributes',
      );
      return {
        'success': true,
        'data': attributes,
        'message': response['message'],
      };
    } catch (e) {
      log.d('🔴 [AttributesApi.getListingsFilterAttributes] ERROR: $e');
      log.d('🔴 [AttributesApi] Stack: ${StackTrace.current}');
      return {'success': false, 'data': [], 'message': e.toString()};
    }
  }
}

// ============================================================
// "API методы для работы с объявлениями (listings/adverts) и предложениями (offers)"
// ============================================================

import 'package:lidle/models/filter_models.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/create_advert_model.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/network/http_client.dart';
import 'package:lidle/models/offer_model.dart';

/// Remote класс для всех операций с объявлениями (listings) и предложениями (offers).
///
/// Включает методы для:
/// - Получения и управления объявлениями (create, update, get)
/// - Загрузки фотографий
/// - Работы с предложениями (offers) по цене
/// - Фильтрации объявлений
class ListingsRemote {
  /// Получить атрибуты для создания объявления в конкретной категории
  static Future<List<Attribute>> getAdvertCreationAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      final response = await HttpClient.getWithQuery('/adverts/create', {
        'category_id': categoryId,
      }, token: token);

      // API возвращает: {"success":true,"data":[{"type":{...},"attributes":[...]}]}
      final dataNode = response['data'];

      List<dynamic>? attributesJson;

      if (dataNode is List && dataNode.isNotEmpty) {
        // data это List - берём первый элемент
        final firstItem = dataNode[0] as Map<String, dynamic>?;
        attributesJson = firstItem?['attributes'] as List<dynamic>?;
      } else if (dataNode is Map<String, dynamic>) {
        // data это Map - берём attributes напрямую
        attributesJson = dataNode['attributes'] as List<dynamic>?;
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
          }
        } catch (e) {
          // Пропускаем неправильно форматированные атрибуты
        }
      }

      return attributes;
    } catch (e) {
      throw Exception('Failed to load advert creation attributes: $e');
    }
  }

  /// Получить список объявлений с поддержкой фильтрации и пагинации
  static Future<AdvertsResponse> getAdverts({
    int? categoryId,
    int? catalogId,
    String? sort,
    Map<String, dynamic>? filters,
    int? page,
    int? limit,
    String? token,
    bool withAttributes = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;
      if (sort != null) queryParams['sort'] = sort;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      // Обработка сложной структуры фильтров с поддержкой вложенных параметров
      if (filters != null && filters.isNotEmpty) {
        log.d('📦 ListingsRemote.getAdverts - Processing filters');
        filters.forEach((key, value) {
          if (key == 'value_selected' && value is Map<String, dynamic>) {
            value.forEach((attrId, attrValue) {
              if (attrValue is Set) {
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = (attrValue as Set).toList().cast<String>();
              } else if (attrValue is List) {
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = attrValue;
              } else {
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = attrValue.toString();
              }
            });
          } else if (key == 'values' && value is Map<String, dynamic>) {
            value.forEach((attrId, attrValue) {
              if (attrValue is Map<String, dynamic>) {
                attrValue.forEach((rangeKey, rangeValue) {
                  if (rangeValue != null &&
                      rangeValue.toString().isNotEmpty &&
                      rangeValue.toString().trim().isNotEmpty) {
                    final paramKey = 'filters[values][$attrId][$rangeKey]';
                    queryParams[paramKey] = rangeValue.toString();
                  }
                });
              } else if (attrValue is Set || attrValue is List) {
                final listValue = attrValue is Set
                    ? (attrValue as Set).toList()
                    : attrValue as List;
                if (listValue.isNotEmpty) {
                  for (int i = 0; i < listValue.length; i++) {
                    final paramKey = 'filters[values][$attrId][$i]';
                    queryParams[paramKey] = listValue[i].toString();
                  }
                }
              } else {
                final paramKey = 'filters[values][$attrId]';
                queryParams[paramKey] = attrValue.toString();
              }
            });
          } else if (value is Map<String, dynamic>) {
            value.forEach((subKey, subValue) {
              final paramKey = 'filters[$key][$subKey]';
              queryParams[paramKey] = subValue.toString();
            });
          } else if (value is Set || value is List) {
            final listValue =
                value is Set ? (value as Set).toList() : value as List;
            if (listValue.isNotEmpty) {
              for (int i = 0; i < listValue.length; i++) {
                final paramKey = 'filters[$key][$i]';
                queryParams[paramKey] = listValue[i].toString();
              }
            }
          } else {
            final paramKey = 'filters[$key]';
            queryParams[paramKey] = value.toString();
          }
        });
      }

      if (withAttributes) {
        queryParams['include'] = 'attributes';
      }

      final response = await HttpClient.getWithQuery(
        '/adverts',
        queryParams,
        token: token,
      );

      return AdvertsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load adverts: $e');
    }
  }

  /// Получить одно объявление по ID с полной информацией
  static Future<Advert> getAdvert(int id, {String? token}) async {
    try {
      final response = await HttpClient.getWithQuery('/adverts/$id', {
        'with': 'attributes,user',
      }, token: token);

      final data = response['data'];

      if (data is List) {
        return Advert.fromJson(data[0] as Map<String, dynamic>);
      } else {
        return Advert.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      throw Exception('Failed to load advert: $e');
    }
  }

  /// Получить объявление с атрибутами
  static Future<Advert?> getAdvertWithAttributes(
    int id, {
    String? token,
  }) async {
    try {
      final response = await HttpClient.getWithQuery('/adverts/$id', {
        'with': 'attributes',
      }, token: token);

      final data = response['data'];
      if (data is List && data.isNotEmpty) {
        return Advert.fromJson(data[0] as Map<String, dynamic>);
      } else if (data is Map<String, dynamic>) {
        return Advert.fromJson(data);
      }
      return null;
    } catch (e) {
      log.d('⚠️ Failed to load attributes for advert $id: $e');
      return null;
    }
  }

  /// Загрузить атрибуты для нескольких объявлений параллельно
  static Future<Map<int, Advert>> getAdvertsWithAttributes(
    List<int> advertIds, {
    String? token,
  }) async {
    final results = <int, Advert>{};

    // Загружаем максимум 5 одновременно, чтобы не перегружать API
    const batchSize = 5;
    for (int i = 0; i < advertIds.length; i += batchSize) {
      final batch = advertIds.sublist(
        i,
        (i + batchSize > advertIds.length) ? advertIds.length : i + batchSize,
      );

      final futures = batch.map(
        (id) => getAdvertWithAttributes(id, token: token),
      );
      final adverts = await Future.wait(futures);

      for (int j = 0; j < batch.length; j++) {
        final id = batch[j];
        final advert = adverts[j];
        if (advert != null) {
          results[id] = advert;
        }
      }
    }

    return results;
  }

  /// Создать новое объявление
  static Future<Map<String, dynamic>> createAdvert(
    CreateAdvertRequest request, {
    String? token,
  }) async {
    try {
      final json = request.toJson();
      log.d('🚀 ListingsRemote.createAdvert: POST /adverts');
      
      final response = await HttpClient.post('/adverts', json, token: token);
      return response;
    } catch (e) {
      throw Exception('Failed to create advert: $e');
    }
  }

  /// Обновить существующее объявление
  static Future<Map<String, dynamic>> updateAdvert(
    int advertId,
    CreateAdvertRequest request, {
    String? token,
  }) async {
    try {
      final json = request.toJson();
      log.d('🔄 ListingsRemote.updateAdvert: PUT /adverts/$advertId');

      final response = await HttpClient.put('/adverts/$advertId', json, token: token);
      return response;
    } catch (e) {
      throw Exception('Failed to update advert: $e');
    }
  }

  /// Загрузить фотографии для объявления через multipart/form-data
  static Future<Map<String, dynamic>> uploadAdvertImages(
    List<String> imagePaths, {
    String? token,
  }) async {
    try {
      // Используем базовый uploadFile метод с endpoint для adverts
      // API ожидает файлы в поле "images[]" или "photos[]"
      if (imagePaths.isEmpty) {
        throw Exception('No images to upload');
      }

      // Для упрощения - загружаем первое изображение
      // В реальном приложении может потребоваться batch upload
      final response = await HttpClient.post(
        '/adverts/images',
        {'file': imagePaths.first},
        token: token,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to upload advert images: $e');
    }
  }

  /// Получить атрибуты фильтрации для объявлений
  static Future<Map<String, dynamic>> getListingsFilterAttributes({
    int? categoryId,
    int? catalogId,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await HttpClient.getWithQuery(
        '/meta/filters',
        queryParams,
        token: token,
      );

      final data = response['data'] ?? response;
      return data;
    } catch (e) {
      throw Exception('Failed to load listing filter attributes: $e');
    }
  }

  /// Сохранить просмотр объявления
  static Future<void> saveAdvertView(int advertId, {String? token}) async {
    try {
      await HttpClient.post('/adverts/$advertId/view', {}, token: token);
    } catch (e) {
      // Не пробрасываем ошибку, так как это некритично
      log.d('Failed to save advert view: $e');
    }
  }

  /// Поделиться объявлением
  static Future<void> shareAdvert(int advertId, {String? token}) async {
    try {
      await HttpClient.post('/adverts/$advertId/share', {}, token: token);
    } catch (e) {
      log.d('Failed to share advert: $e');
    }
  }

  // =========================================================================
  // OFFERS (Предложения по цене)
  // =========================================================================

  /// Отправить предложение по цене для объявления
  static Future<Map<String, dynamic>> submitPriceOffer({
    required int advertId,
    required String price,
    String? comment,
    String? token,
  }) async {
    try {
      final response = await HttpClient.post(
        '/adverts/$advertId/offers',
        {
          'price': price,
          if (comment != null) 'comment': comment,
        },
        token: token,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to submit price offer: $e');
    }
  }

  /// Получить предложения полученные на объявление (для продавца)
  static Future<List<Map<String, dynamic>>> getPriceOffers({
    int? advertId,
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (advertId != null) queryParams['advert_id'] = advertId;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await HttpClient.getWithQuery(
        '/user/offers',
        queryParams,
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load price offers: $e');
    }
  }

  /// Получить мои предложения (для покупателя)
  static Future<List<Map<String, dynamic>>> getMyOffers({
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await HttpClient.getWithQuery(
        '/user/my-offers',
        queryParams,
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load my offers: $e');
    }
  }

  /// Получить принятые предложения
  static Future<List<Map<String, dynamic>>> getOffersReceivedList({
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await HttpClient.getWithQuery(
        '/user/received-offers',
        queryParams,
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load received offers: $e');
    }
  }

  /// Получить все полученные предложения
  static Future<List<Map<String, dynamic>>> getAllReceivedOffers({
    String? token,
  }) async {
    try {
      final response = await HttpClient.get(
        '/user/all-offers',
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load all received offers: $e');
    }
  }

  /// Обновить статус полученного предложения
  static Future<Map<String, dynamic>> updateReceivedOfferStatus({
    required int offerId,
    required String status,
    String? token,
  }) async {
    try {
      final response = await HttpClient.put(
        '/user/offers/$offerId',
        {'status': status},
        token: token,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to update received offer status: $e');
    }
  }

  /// Обновить статус своего предложения (для покупателя)
  static Future<Map<String, dynamic>> updateOfferStatus({
    required int offerId,
    required String status,
    String? token,
  }) async {
    try {
      final response = await HttpClient.put(
        '/user/my-offers/$offerId',
        {'status': status},
        token: token,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to update offer status: $e');
    }
  }
}

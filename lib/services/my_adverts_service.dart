import 'package:json_annotation/json_annotation.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/services/api_service.dart';

part 'my_adverts_service.g.dart';

@JsonSerializable()
class Meta {
  @JsonKey(name: 'current_page')
  final int? currentPage;
  @JsonKey(name: 'per_page')
  final int? perPage;
  @JsonKey(name: 'last_page')
  final int? lastPage;
  final int? total;

  Meta({this.currentPage, this.perPage, this.lastPage, this.total});

  factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);
  Map<String, dynamic> toJson() => _$MetaToJson(this);
}

@JsonSerializable()
class MyAdvertsResponse {
  final List<UserAdvert> data;
  final Meta? meta;
  final int? total;

  // Convenience getters
  int? get page => meta?.currentPage;
  int? get perPage => meta?.perPage;
  int? get lastPage => meta?.lastPage;

  MyAdvertsResponse({required this.data, this.meta, this.total});

  factory MyAdvertsResponse.fromJson(Map<String, dynamic> json) =>
      _$MyAdvertsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MyAdvertsResponseToJson(this);
}

@JsonSerializable()
class CreateAdvertRequest {
  @JsonKey(name: 'category_id')
  final int categoryId;
  final String title;
  final String description;
  final int price;
  final String? address;
  @JsonKey(name: 'address_id')
  final int? addressId;
  final Map<String, dynamic>? values;
  final List<String>? images;

  CreateAdvertRequest({
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    this.address,
    this.addressId,
    this.values,
    this.images,
  });

  factory CreateAdvertRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAdvertRequestFromJson(json);

  Map<String, dynamic> toJson() {
    final map = _$CreateAdvertRequestToJson(this);
    // Удалить null значения
    map.removeWhere((key, value) => value == null);
    return map;
  }
}

@JsonSerializable()
class UpdateAdvertRequest {
  final String? title;
  final String? description;
  final int? price;
  final String? address;
  @JsonKey(name: 'address_id')
  final int? addressId;
  final Map<String, dynamic>? values;
  final List<String>? images;

  UpdateAdvertRequest({
    this.title,
    this.description,
    this.price,
    this.address,
    this.addressId,
    this.values,
    this.images,
  });

  factory UpdateAdvertRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateAdvertRequestFromJson(json);

  Map<String, dynamic> toJson() {
    final map = _$UpdateAdvertRequestToJson(this);
    map.removeWhere((key, value) => value == null);
    return map;
  }
}

class MyAdvertsService {
  /// Получить мета-информацию объявлений (каталоги и категории с объявлениями)
  static Future<AdvertMetaResponse> getAdvertsMeta({
    required String token,
  }) async {
    try {
      final response = await ApiService.get('/me/adverts/meta', token: token);

      return AdvertMetaResponse.fromJson(response);
    } catch (e) {
      throw Exception('Ошибка при загрузке мета-информации объявлений: $e');
    }
  }

  /// Получить список мои объявлений текущего пользователя
  static Future<MyAdvertsResponse> getMyAdverts({
    int? page,
    int? statusId,
    int? catalogId,
    int? categoryId,
    int? limit,
    required String token,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) {
        params['page'] = page;
      }
      if (statusId != null) {
        params['advert_status_id'] = statusId;
      }
      if (catalogId != null) {
        params['catalog_id'] = catalogId;
      }
      if (categoryId != null) {
        params['category_id'] = categoryId;
      }
      if (limit != null) {
        params['per_page'] = limit;
      }

      final response = await ApiService.getWithQuery(
        '/me/adverts',
        params,
        token: token,
      );

      return MyAdvertsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Ошибка при загрузке объявлений: $e');
    }
  }

  /// Создать новое объявление
  static Future<MainAdvert> createAdvert({
    required int categoryId,
    required String title,
    required String description,
    required int price,
    String? address,
    int? addressId,
    Map<String, dynamic>? values,
    List<String>? images,
    required String token,
  }) async {
    try {
      final request = CreateAdvertRequest(
        categoryId: categoryId,
        title: title,
        description: description,
        price: price,
        address: address,
        addressId: addressId,
        values: values,
        images: images,
      );

      final response = await ApiService.post(
        '/me/adverts',
        request.toJson(),
        token: token,
      );

      // Проверить структуру ответа
      if (response.containsKey('data')) {
        return MainAdvert.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        return MainAdvert.fromJson(response);
      }
    } catch (e) {
      throw Exception('Ошибка при создании объявления: $e');
    }
  }

  /// Обновить объявление
  static Future<MainAdvert> updateAdvert({
    required int advertId,
    String? title,
    String? description,
    int? price,
    String? address,
    int? addressId,
    Map<String, dynamic>? values,
    List<String>? images,
    required String token,
  }) async {
    try {
      final request = UpdateAdvertRequest(
        title: title,
        description: description,
        price: price,
        address: address,
        addressId: addressId,
        values: values,
        images: images,
      );

      final response = await ApiService.put(
        '/me/adverts/$advertId',
        request.toJson(),
        token: token,
      );

      if (response.containsKey('data')) {
        return MainAdvert.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        return MainAdvert.fromJson(response);
      }
    } catch (e) {
      throw Exception('Ошибка при обновлении объявления: $e');
    }
  }

  /// Удалить объявление
  static Future<void> deleteAdvert({
    required int advertId,
    required String token,
  }) async {
    try {
      await ApiService.delete('/me/adverts/$advertId', token: token);
    } catch (e) {
      throw Exception('Ошибка при удалении объявления: $e');
    }
  }

  /// Обновить статус объявления
  static Future<void> updateAdvertStatus({
    required int advertId,
    required int statusId,
    required String token,
  }) async {
    try {
      await ApiService.put('/me/adverts/$advertId/update_status', {
        'advert_status_id': statusId,
      }, token: token);
    } catch (e) {
      throw Exception('Ошибка при обновлении статуса объявления: $e');
    }
  }

  /// Активировать объявление (изменение статуса на активный - 1)
  static Future<void> activateAdvert({
    required int advertId,
    required String token,
  }) async {
    try {
      await updateAdvertStatus(advertId: advertId, statusId: 1, token: token);
    } catch (e) {
      throw Exception('Ошибка при активации объявления: $e');
    }
  }

  /// Деактивировать объявление (изменение статуса на неактивный - 2)
  static Future<void> deactivateAdvert({
    required int advertId,
    required String token,
  }) async {
    try {
      await updateAdvertStatus(advertId: advertId, statusId: 2, token: token);
    } catch (e) {
      throw Exception('Ошибка при деактивации объявления: $e');
    }
  }
}

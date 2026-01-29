import 'package:json_annotation/json_annotation.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/services/api_service.dart';

part 'my_adverts_service.g.dart';

@JsonSerializable()
class MyAdvertsResponse {
  final List<MainAdvert> data;
  final int? total;
  final int? page;
  @JsonKey(name: 'per_page')
  final int? perPage;
  @JsonKey(name: 'last_page')
  final int? lastPage;

  MyAdvertsResponse({
    required this.data,
    this.total,
    this.page,
    this.perPage,
    this.lastPage,
  });

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
  /// Получить список мои объявлений текущего пользователя
  static Future<MyAdvertsResponse> getMyAdverts({
    int? page,
    required String token,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) {
        params['page'] = page;
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

  /// Активировать объявление
  static Future<MainAdvert> activateAdvert({
    required int advertId,
    required String token,
  }) async {
    try {
      final response = await ApiService.post(
        '/me/adverts/$advertId/activate',
        {},
        token: token,
      );

      if (response.containsKey('data')) {
        return MainAdvert.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        return MainAdvert.fromJson(response);
      }
    } catch (e) {
      throw Exception('Ошибка при активации объявления: $e');
    }
  }

  /// Деактивировать объявление
  static Future<MainAdvert> deactivateAdvert({
    required int advertId,
    required String token,
  }) async {
    try {
      final response = await ApiService.post(
        '/me/adverts/$advertId/deactivate',
        {},
        token: token,
      );

      if (response.containsKey('data')) {
        return MainAdvert.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        return MainAdvert.fromJson(response);
      }
    } catch (e) {
      throw Exception('Ошибка при деактивации объявления: $e');
    }
  }
}

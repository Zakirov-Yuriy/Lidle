// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_adverts_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyAdvertsResponse _$MyAdvertsResponseFromJson(Map<String, dynamic> json) =>
    MyAdvertsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => MainAdvert.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt(),
      page: (json['page'] as num?)?.toInt(),
      perPage: (json['per_page'] as num?)?.toInt(),
      lastPage: (json['last_page'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MyAdvertsResponseToJson(MyAdvertsResponse instance) =>
    <String, dynamic>{
      'data': instance.data,
      'total': instance.total,
      'page': instance.page,
      'per_page': instance.perPage,
      'last_page': instance.lastPage,
    };

CreateAdvertRequest _$CreateAdvertRequestFromJson(Map<String, dynamic> json) =>
    CreateAdvertRequest(
      categoryId: (json['category_id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toInt(),
      address: json['address'] as String?,
      addressId: (json['address_id'] as num?)?.toInt(),
      values: json['values'] as Map<String, dynamic>?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CreateAdvertRequestToJson(
  CreateAdvertRequest instance,
) => <String, dynamic>{
  'category_id': instance.categoryId,
  'title': instance.title,
  'description': instance.description,
  'price': instance.price,
  'address': instance.address,
  'address_id': instance.addressId,
  'values': instance.values,
  'images': instance.images,
};

UpdateAdvertRequest _$UpdateAdvertRequestFromJson(Map<String, dynamic> json) =>
    UpdateAdvertRequest(
      title: json['title'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toInt(),
      address: json['address'] as String?,
      addressId: (json['address_id'] as num?)?.toInt(),
      values: json['values'] as Map<String, dynamic>?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$UpdateAdvertRequestToJson(
  UpdateAdvertRequest instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'price': instance.price,
  'address': instance.address,
  'address_id': instance.addressId,
  'values': instance.values,
  'images': instance.images,
};

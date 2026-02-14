// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Region _$RegionFromJson(Map<String, dynamic> json) =>
    Region(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$RegionToJson(Region instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

RegionsResponse _$RegionsResponseFromJson(Map<String, dynamic> json) =>
    RegionsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => Region.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RegionsResponseToJson(RegionsResponse instance) =>
    <String, dynamic>{'data': instance.data};

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
  id: (json['id'] as num?)?.toInt(),
  type: json['type'] as String,
  main_region: json['main_region'] == null
      ? null
      : Region.fromJson(json['main_region'] as Map<String, dynamic>),
  region: json['region'] == null
      ? null
      : Region.fromJson(json['region'] as Map<String, dynamic>),
  city: json['city'] == null
      ? null
      : Region.fromJson(json['city'] as Map<String, dynamic>),
  district: json['district'] == null
      ? null
      : Region.fromJson(json['district'] as Map<String, dynamic>),
  street: json['street'] == null
      ? null
      : Region.fromJson(json['street'] as Map<String, dynamic>),
  building: json['building'] == null
      ? null
      : Region.fromJson(json['building'] as Map<String, dynamic>),
  building_number: json['building_number'] as String?,
  full_address: json['full_address'] as String,
);

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'main_region': instance.main_region,
  'region': instance.region,
  'city': instance.city,
  'district': instance.district,
  'street': instance.street,
  'building': instance.building,
  'building_number': instance.building_number,
  'full_address': instance.full_address,
};

AddressesResponse _$AddressesResponseFromJson(Map<String, dynamic> json) =>
    AddressesResponse(
      success: json['success'] as bool?,
      data: (json['data'] as List<dynamic>)
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AddressesResponseToJson(AddressesResponse instance) =>
    <String, dynamic>{'success': instance.success, 'data': instance.data};

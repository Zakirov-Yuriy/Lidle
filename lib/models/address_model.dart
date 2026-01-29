import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';

/// Модель региона
@JsonSerializable()
class Region {
  final int id;
  final String name;

  Region({required this.id, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) => _$RegionFromJson(json);
  Map<String, dynamic> toJson() => _$RegionToJson(this);
}

/// Ответ при получении списка регионов
@JsonSerializable()
class RegionsResponse {
  final List<Region> data;

  RegionsResponse({required this.data});

  factory RegionsResponse.fromJson(Map<String, dynamic> json) =>
      _$RegionsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$RegionsResponseToJson(this);
}

/// Модель адреса (результат поиска)
@JsonSerializable()
class Address {
  final String type; // street, city, region и т.д.
  final Region? main_region;
  final Region? region;
  final Region? city;
  final Region? district;
  final Region? street;
  final String full_address;

  Address({
    required this.type,
    this.main_region,
    this.region,
    this.city,
    this.district,
    this.street,
    required this.full_address,
  });

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

/// Ответ при поиске адресов
@JsonSerializable()
class AddressesResponse {
  final bool? success;
  final List<Address> data;

  AddressesResponse({this.success, required this.data});

  factory AddressesResponse.fromJson(Map<String, dynamic> json) =>
      _$AddressesResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AddressesResponseToJson(this);
}

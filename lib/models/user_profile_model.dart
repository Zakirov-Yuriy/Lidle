import 'package:json_annotation/json_annotation.dart';

part 'user_profile_model.g.dart';

@JsonSerializable()
class UserProfileResponse {
  final bool? success;
  final List<UserProfile> data;

  UserProfileResponse({this.success, required this.data});

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$UserProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileResponseToJson(this);
}

@JsonSerializable()
class UserProfile {
  final int? id;
  final String name;
  @JsonKey(name: 'last_name')
  final String lastName;
  final String email;
  final String? phone;
  final String? nickname;
  final String? avatar;
  final String? about;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @JsonKey(name: 'email_verified_at')
  final String? emailVerifiedAt;
  @JsonKey(name: 'phone_verified_at')
  final String? phoneVerifiedAt;
  @JsonKey(name: 'offers_count')
  final int? offersCount;
  @JsonKey(name: 'new_offers_count')
  final int? newOffersCount;
  final Map<String, dynamic>? contacts;
  @JsonKey(name: 'qr_code')
  final Map<String, dynamic>? qrCode;

  UserProfile({
    this.id,
    required this.name,
    required this.lastName,
    required this.email,
    this.phone,
    this.nickname,
    this.avatar,
    this.about,
    this.createdAt,
    this.updatedAt,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.offersCount,
    this.newOffersCount,
    this.contacts,
    this.qrCode,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

@JsonSerializable()
class UpdateProfileRequest {
  final String? name;
  final String? email;
  final String? phone;
  final String? about;
  final String? avatar;

  UpdateProfileRequest({
    this.name,
    this.email,
    this.phone,
    this.about,
    this.avatar,
  });

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestFromJson(json);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (about != null) data['about'] = about;
    if (avatar != null) data['avatar'] = avatar;
    return data;
  }
}

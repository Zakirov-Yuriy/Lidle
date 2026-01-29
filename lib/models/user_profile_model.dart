import 'package:json_annotation/json_annotation.dart';

part 'user_profile_model.g.dart';

@JsonSerializable()
class UserProfileResponse {
  final UserProfile data;

  UserProfileResponse({required this.data});

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$UserProfileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileResponseToJson(this);
}

@JsonSerializable()
class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? phone;
  @JsonKey(name: 'phone_verified')
  final bool phoneVerified;
  @JsonKey(name: 'email_verified')
  final bool emailVerified;
  final String? avatar;
  final String? about;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.phoneVerified,
    required this.emailVerified,
    this.avatar,
    this.about,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfileResponse _$UserProfileResponseFromJson(Map<String, dynamic> json) =>
    UserProfileResponse(
      data: UserProfile.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserProfileResponseToJson(
  UserProfileResponse instance,
) => <String, dynamic>{'data': instance.data};

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String?,
  phoneVerified: json['phone_verified'] as bool,
  emailVerified: json['email_verified'] as bool,
  avatar: json['avatar'] as String?,
  about: json['about'] as String?,
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'phone_verified': instance.phoneVerified,
      'email_verified': instance.emailVerified,
      'avatar': instance.avatar,
      'about': instance.about,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

UpdateProfileRequest _$UpdateProfileRequestFromJson(
  Map<String, dynamic> json,
) => UpdateProfileRequest(
  name: json['name'] as String?,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  about: json['about'] as String?,
  avatar: json['avatar'] as String?,
);

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfileResponse _$UserProfileResponseFromJson(Map<String, dynamic> json) =>
    UserProfileResponse(
      success: json['success'] as bool?,
      data: (json['data'] as List<dynamic>)
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserProfileResponseToJson(
  UserProfileResponse instance,
) => <String, dynamic>{'success': instance.success, 'data': instance.data};

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  lastName: json['last_name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String?,
  nickname: json['nickname'] as String?,
  avatar: json['avatar'] as String?,
  about: json['about'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  emailVerifiedAt: json['email_verified_at'] as String?,
  phoneVerifiedAt: json['phone_verified_at'] as String?,
  offersCount: (json['offers_count'] as num?)?.toInt(),
  newOffersCount: (json['new_offers_count'] as num?)?.toInt(),
  contacts: json['contacts'] as Map<String, dynamic>?,
  qrCode: json['qr_code'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'nickname': instance.nickname,
      'avatar': instance.avatar,
      'about': instance.about,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'email_verified_at': instance.emailVerifiedAt,
      'phone_verified_at': instance.phoneVerifiedAt,
      'offers_count': instance.offersCount,
      'new_offers_count': instance.newOffersCount,
      'contacts': instance.contacts,
      'qr_code': instance.qrCode,
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

Map<String, dynamic> _$UpdateProfileRequestToJson(
  UpdateProfileRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'about': instance.about,
  'avatar': instance.avatar,
};

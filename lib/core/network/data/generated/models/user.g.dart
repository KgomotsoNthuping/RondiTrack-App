// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  phoneNumber: json['phoneNumber'] as String,
  id: json['id'] as String?,
  passwordHash: json['passwordHash'] as String?,
  version: (json['version'] as num?)?.toInt(),
  platformRole: (json['platformRole'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'email': instance.email,
  'phoneNumber': instance.phoneNumber,
  'passwordHash': instance.passwordHash,
  'version': instance.version,
  'platformRole': instance.platformRole,
};

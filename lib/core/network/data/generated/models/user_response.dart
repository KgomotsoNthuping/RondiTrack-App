// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_response.g.dart';

/// Shape/representation returned to API user.
@JsonSerializable()
class UserResponse {
  const UserResponse({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.version,
  });

  factory UserResponse.fromJson(Map<String, Object?> json) =>
      _$UserResponseFromJson(json);

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final int version;

  Map<String, Object?> toJson() => _$UserResponseToJson(this);
}

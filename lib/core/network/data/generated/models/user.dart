// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'platform_role.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.id,
    this.passwordHash,
    this.version,
    this.platformRole,
  });

  factory User.fromJson(Map<String, Object?> json) => _$UserFromJson(json);

  final String? id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? passwordHash;
  final int? version;
  final PlatformRole? platformRole;

  Map<String, Object?> toJson() => _$UserToJson(this);
}

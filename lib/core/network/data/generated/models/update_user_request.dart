// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_user_request.g.dart';

/// Information the client is allowed to update
@JsonSerializable()
class UpdateUserRequest {
  const UpdateUserRequest({
    this.fullName,
    this.email,
    this.phoneNumber,
    this.version,
  });

  factory UpdateUserRequest.fromJson(Map<String, Object?> json) =>
      _$UpdateUserRequestFromJson(json);

  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final int? version;

  Map<String, Object?> toJson() => _$UpdateUserRequestToJson(this);
}

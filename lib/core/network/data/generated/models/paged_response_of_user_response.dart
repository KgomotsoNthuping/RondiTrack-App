// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_response.dart';

part 'paged_response_of_user_response.g.dart';

@JsonSerializable()
class PagedResponseOfUserResponse {
  const PagedResponseOfUserResponse({
    required this.items,
    required this.nextPageToken,
  });

  factory PagedResponseOfUserResponse.fromJson(Map<String, Object?> json) =>
      _$PagedResponseOfUserResponseFromJson(json);

  final List<UserResponse> items;
  final String nextPageToken;

  Map<String, Object?> toJson() => _$PagedResponseOfUserResponseToJson(this);
}

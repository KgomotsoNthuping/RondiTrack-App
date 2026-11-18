// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'member_stokvel_home_response.dart';

part 'member_home_response.g.dart';

@JsonSerializable()
class MemberHomeResponse {
  const MemberHomeResponse({required this.stokvels});

  factory MemberHomeResponse.fromJson(Map<String, Object?> json) =>
      _$MemberHomeResponseFromJson(json);

  final List<MemberStokvelHomeResponse> stokvels;

  Map<String, Object?> toJson() => _$MemberHomeResponseToJson(this);
}

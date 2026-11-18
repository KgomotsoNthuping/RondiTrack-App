// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'stokvel_member_role.dart';

part 'cycle_contribution_response.g.dart';

@JsonSerializable()
class CycleContributionResponse {
  const CycleContributionResponse({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.memberRole,
    required this.amount,
  });

  factory CycleContributionResponse.fromJson(Map<String, Object?> json) =>
      _$CycleContributionResponseFromJson(json);

  final String id;
  final String userId;
  final String userFullName;
  final StokvelMemberRole memberRole;
  final double amount;

  Map<String, Object?> toJson() => _$CycleContributionResponseToJson(this);
}

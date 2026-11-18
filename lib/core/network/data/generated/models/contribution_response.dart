// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'contribution_response.g.dart';

@JsonSerializable()
class ContributionResponse {
  const ContributionResponse({
    required this.id,
    required this.stokvelId,
    required this.userId,
    required this.contributionCycleId,
    required this.amount,
  });

  factory ContributionResponse.fromJson(Map<String, Object?> json) =>
      _$ContributionResponseFromJson(json);

  final String id;
  final String stokvelId;
  final String userId;
  final String contributionCycleId;
  final double amount;

  Map<String, Object?> toJson() => _$ContributionResponseToJson(this);
}

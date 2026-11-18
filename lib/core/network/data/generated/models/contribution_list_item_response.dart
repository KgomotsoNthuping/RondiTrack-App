// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'contribution_list_item_response.g.dart';

@JsonSerializable()
class ContributionListItemResponse {
  const ContributionListItemResponse({
    required this.id,
    required this.contributionCycleId,
    required this.amountInCents,
    required this.status,
    required this.paidAtUtc,
    required this.cycleNumber,
  });

  factory ContributionListItemResponse.fromJson(Map<String, Object?> json) =>
      _$ContributionListItemResponseFromJson(json);

  final String id;
  final String contributionCycleId;
  final int amountInCents;
  final String status;
  final DateTime? paidAtUtc;
  final int cycleNumber;

  Map<String, Object?> toJson() => _$ContributionListItemResponseToJson(this);
}

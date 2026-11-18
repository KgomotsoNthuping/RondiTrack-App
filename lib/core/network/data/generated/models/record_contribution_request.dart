// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'record_contribution_request.g.dart';

@JsonSerializable()
class RecordContributionRequest {
  const RecordContributionRequest({
    this.userId,
    this.contributionCycleId,
    this.amount,
  });

  factory RecordContributionRequest.fromJson(Map<String, Object?> json) =>
      _$RecordContributionRequestFromJson(json);

  final String? userId;
  final String? contributionCycleId;
  final double? amount;

  Map<String, Object?> toJson() => _$RecordContributionRequestToJson(this);
}

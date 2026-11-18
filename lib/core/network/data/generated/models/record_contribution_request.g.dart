// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_contribution_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecordContributionRequest _$RecordContributionRequestFromJson(
  Map<String, dynamic> json,
) => RecordContributionRequest(
  userId: json['userId'] as String?,
  contributionCycleId: json['contributionCycleId'] as String?,
  amount: (json['amount'] as num?)?.toDouble(),
);

Map<String, dynamic> _$RecordContributionRequestToJson(
  RecordContributionRequest instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'contributionCycleId': instance.contributionCycleId,
  'amount': instance.amount,
};

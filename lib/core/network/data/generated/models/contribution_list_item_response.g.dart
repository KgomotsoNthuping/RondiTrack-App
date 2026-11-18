// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contribution_list_item_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContributionListItemResponse _$ContributionListItemResponseFromJson(
  Map<String, dynamic> json,
) => ContributionListItemResponse(
  id: json['id'] as String,
  contributionCycleId: json['contributionCycleId'] as String,
  amountInCents: (json['amountInCents'] as num).toInt(),
  status: json['status'] as String,
  paidAtUtc: json['paidAtUtc'] == null
      ? null
      : DateTime.parse(json['paidAtUtc'] as String),
  cycleNumber: (json['cycleNumber'] as num).toInt(),
);

Map<String, dynamic> _$ContributionListItemResponseToJson(
  ContributionListItemResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'contributionCycleId': instance.contributionCycleId,
  'amountInCents': instance.amountInCents,
  'status': instance.status,
  'paidAtUtc': instance.paidAtUtc?.toIso8601String(),
  'cycleNumber': instance.cycleNumber,
};

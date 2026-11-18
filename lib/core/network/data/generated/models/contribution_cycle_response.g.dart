// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contribution_cycle_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContributionCycleResponse _$ContributionCycleResponseFromJson(
  Map<String, dynamic> json,
) => ContributionCycleResponse(
  id: json['id'] as String,
  stokvelId: json['stokvelId'] as String,
  cycleNumber: (json['cycleNumber'] as num).toInt(),
  targetAmount: (json['targetAmount'] as num).toDouble(),
  version: (json['version'] as num).toInt(),
  status: json['status'] as String,
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  totalCollectedInCents: (json['totalCollectedInCents'] as num).toInt(),
  amountDueInCents: (json['amountDueInCents'] as num).toInt(),
);

Map<String, dynamic> _$ContributionCycleResponseToJson(
  ContributionCycleResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'stokvelId': instance.stokvelId,
  'cycleNumber': instance.cycleNumber,
  'targetAmount': instance.targetAmount,
  'version': instance.version,
  'status': instance.status,
  'dueDate': instance.dueDate?.toIso8601String(),
  'totalCollectedInCents': instance.totalCollectedInCents,
  'amountDueInCents': instance.amountDueInCents,
};

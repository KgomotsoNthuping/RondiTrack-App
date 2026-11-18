// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_contribution_cycle_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateContributionCycleRequest _$CreateContributionCycleRequestFromJson(
  Map<String, dynamic> json,
) => CreateContributionCycleRequest(
  cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
  targetAmount: (json['targetAmount'] as num?)?.toDouble(),
  version: (json['version'] as num?)?.toInt(),
);

Map<String, dynamic> _$CreateContributionCycleRequestToJson(
  CreateContributionCycleRequest instance,
) => <String, dynamic>{
  'cycleNumber': instance.cycleNumber,
  'targetAmount': instance.targetAmount,
  'version': instance.version,
};

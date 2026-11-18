// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_contribution_cycle_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateContributionCycleRequest _$UpdateContributionCycleRequestFromJson(
  Map<String, dynamic> json,
) => UpdateContributionCycleRequest(
  cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
  targetAmount: (json['targetAmount'] as num?)?.toDouble(),
  version: (json['version'] as num?)?.toInt(),
);

Map<String, dynamic> _$UpdateContributionCycleRequestToJson(
  UpdateContributionCycleRequest instance,
) => <String, dynamic>{
  'cycleNumber': instance.cycleNumber,
  'targetAmount': instance.targetAmount,
  'version': instance.version,
};

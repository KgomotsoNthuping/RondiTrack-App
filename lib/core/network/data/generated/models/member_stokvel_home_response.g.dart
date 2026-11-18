// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_stokvel_home_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberStokvelHomeResponse _$MemberStokvelHomeResponseFromJson(
  Map<String, dynamic> json,
) => MemberStokvelHomeResponse(
  stokvelId: json['stokvelId'] as String,
  name: json['name'] as String,
  role: json['role'] as String,
  currentCycle: (json['currentCycle'] as num?)?.toInt(),
  cycleStatus: json['cycleStatus'] as String?,
  cycleDueDate: json['cycleDueDate'] == null
      ? null
      : DateTime.parse(json['cycleDueDate'] as String),
  paidThisCycleInCents: (json['paidThisCycleInCents'] as num?)?.toInt(),
  stillOwedInCents: (json['stillOwedInCents'] as num?)?.toInt(),
  nextPayoutDateUtc: json['nextPayoutDateUtc'] == null
      ? null
      : DateTime.parse(json['nextPayoutDateUtc'] as String),
  arrearsInCents: (json['arrearsInCents'] as num).toInt(),
);

Map<String, dynamic> _$MemberStokvelHomeResponseToJson(
  MemberStokvelHomeResponse instance,
) => <String, dynamic>{
  'stokvelId': instance.stokvelId,
  'name': instance.name,
  'role': instance.role,
  'currentCycle': instance.currentCycle,
  'cycleStatus': instance.cycleStatus,
  'cycleDueDate': instance.cycleDueDate?.toIso8601String(),
  'paidThisCycleInCents': instance.paidThisCycleInCents,
  'stillOwedInCents': instance.stillOwedInCents,
  'nextPayoutDateUtc': instance.nextPayoutDateUtc?.toIso8601String(),
  'arrearsInCents': instance.arrearsInCents,
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stokvel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stokvel _$StokvelFromJson(Map<String, dynamic> json) => Stokvel(
  name: json['name'] as String,
  monthlyContribution: (json['monthlyContribution'] as num).toDouble(),
  currentPeriod: (json['currentPeriod'] as num).toInt(),
  totalPeriods: (json['totalPeriods'] as num).toInt(),
  id: json['id'] as String?,
  rules: json['rules'] as String?,
  version: (json['version'] as num?)?.toInt(),
  members: (json['members'] as List<dynamic>?)
      ?.map((e) => User.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$StokvelToJson(Stokvel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'monthlyContribution': instance.monthlyContribution,
  'currentPeriod': instance.currentPeriod,
  'totalPeriods': instance.totalPeriods,
  'rules': instance.rules,
  'version': instance.version,
  'members': instance.members,
};

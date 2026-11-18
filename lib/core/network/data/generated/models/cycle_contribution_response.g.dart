// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cycle_contribution_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CycleContributionResponse _$CycleContributionResponseFromJson(
  Map<String, dynamic> json,
) => CycleContributionResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  userFullName: json['userFullName'] as String,
  memberRole: (json['memberRole'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
);

Map<String, dynamic> _$CycleContributionResponseToJson(
  CycleContributionResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'userFullName': instance.userFullName,
  'memberRole': instance.memberRole,
  'amount': instance.amount,
};

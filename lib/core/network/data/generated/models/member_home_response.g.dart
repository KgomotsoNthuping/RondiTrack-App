// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_home_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberHomeResponse _$MemberHomeResponseFromJson(Map<String, dynamic> json) =>
    MemberHomeResponse(
      stokvels: (json['stokvels'] as List<dynamic>)
          .map(
            (e) =>
                MemberStokvelHomeResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$MemberHomeResponseToJson(MemberHomeResponse instance) =>
    <String, dynamic>{'stokvels': instance.stokvels};

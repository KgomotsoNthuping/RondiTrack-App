// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_response_of_user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedResponseOfUserResponse _$PagedResponseOfUserResponseFromJson(
  Map<String, dynamic> json,
) => PagedResponseOfUserResponse(
  items: (json['items'] as List<dynamic>)
      .map((e) => UserResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextPageToken: json['nextPageToken'] as String,
);

Map<String, dynamic> _$PagedResponseOfUserResponseToJson(
  PagedResponseOfUserResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'nextPageToken': instance.nextPageToken,
};

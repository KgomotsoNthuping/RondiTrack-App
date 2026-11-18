// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_response_of_contribution_list_item_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedResponseOfContributionListItemResponse
_$PagedResponseOfContributionListItemResponseFromJson(
  Map<String, dynamic> json,
) => PagedResponseOfContributionListItemResponse(
  items: (json['items'] as List<dynamic>)
      .map(
        (e) => ContributionListItemResponse.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  nextPageToken: json['nextPageToken'] as String,
);

Map<String, dynamic> _$PagedResponseOfContributionListItemResponseToJson(
  PagedResponseOfContributionListItemResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'nextPageToken': instance.nextPageToken,
};

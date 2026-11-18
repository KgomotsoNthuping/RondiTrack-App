// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_response_of_cycle_contribution_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedResponseOfCycleContributionResponse
_$PagedResponseOfCycleContributionResponseFromJson(Map<String, dynamic> json) =>
    PagedResponseOfCycleContributionResponse(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) =>
                CycleContributionResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      nextPageToken: json['nextPageToken'] as String,
    );

Map<String, dynamic> _$PagedResponseOfCycleContributionResponseToJson(
  PagedResponseOfCycleContributionResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'nextPageToken': instance.nextPageToken,
};

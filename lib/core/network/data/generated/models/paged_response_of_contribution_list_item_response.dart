// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'contribution_list_item_response.dart';

part 'paged_response_of_contribution_list_item_response.g.dart';

@JsonSerializable()
class PagedResponseOfContributionListItemResponse {
  const PagedResponseOfContributionListItemResponse({
    required this.items,
    required this.nextPageToken,
  });

  factory PagedResponseOfContributionListItemResponse.fromJson(
    Map<String, Object?> json,
  ) => _$PagedResponseOfContributionListItemResponseFromJson(json);

  final List<ContributionListItemResponse> items;
  final String nextPageToken;

  Map<String, Object?> toJson() =>
      _$PagedResponseOfContributionListItemResponseToJson(this);
}

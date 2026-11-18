// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'cycle_contribution_response.dart';

part 'paged_response_of_cycle_contribution_response.g.dart';

@JsonSerializable()
class PagedResponseOfCycleContributionResponse {
  const PagedResponseOfCycleContributionResponse({
    required this.items,
    required this.nextPageToken,
  });

  factory PagedResponseOfCycleContributionResponse.fromJson(
    Map<String, Object?> json,
  ) => _$PagedResponseOfCycleContributionResponseFromJson(json);

  final List<CycleContributionResponse> items;
  final String nextPageToken;

  Map<String, Object?> toJson() =>
      _$PagedResponseOfCycleContributionResponseToJson(this);
}

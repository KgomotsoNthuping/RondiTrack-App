// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/contribution_cycle_response.dart';
import '../models/create_contribution_cycle_request.dart';
import '../models/paged_response_of_cycle_contribution_response.dart';
import '../models/update_contribution_cycle_request.dart';

part 'contributions_cycle_client.g.dart';

@RestApi()
abstract class ContributionsCycleClient {
  factory ContributionsCycleClient(Dio dio, {String? baseUrl}) =
      _ContributionsCycleClient;

  @GET('/api/v1/stokvels/{stokvelId}/cycles')
  Future<HttpResponse<List<ContributionCycleResponse>>>
  getApiV1StokvelsStokvelIdCycles({
    @Path('stokvelId') required String stokvelId,
  });

  @POST('/api/v1/stokvels/{stokvelId}/cycles')
  Future<HttpResponse<ContributionCycleResponse>>
  postApiV1StokvelsStokvelIdCycles({
    @Path('stokvelId') required String stokvelId,
    @Body() required CreateContributionCycleRequest body,
  });

  @GET('/api/v1/stokvels/{stokvelId}/cycles/{cycleId}')
  Future<HttpResponse<ContributionCycleResponse>>
  getApiV1StokvelsStokvelIdCyclesCycleId({
    @Path('stokvelId') required String stokvelId,
    @Path('cycleId') required String cycleId,
  });

  @PUT('/api/v1/stokvels/{stokvelId}/cycles/{cycleId}')
  Future<HttpResponse<ContributionCycleResponse>>
  putApiV1StokvelsStokvelIdCyclesCycleId({
    @Path('stokvelId') required String stokvelId,
    @Path('cycleId') required String cycleId,
    @Body() required UpdateContributionCycleRequest body,
  });

  @DELETE('/api/v1/stokvels/{stokvelId}/cycles/{cycleId}')
  Future<HttpResponse<void>> deleteApiV1StokvelsStokvelIdCyclesCycleId({
    @Path('stokvelId') required String stokvelId,
    @Path('cycleId') required String cycleId,
  });

  @GET('/api/v1/stokvels/{stokvelId}/cycles/{cycleId}/contributions')
  Future<HttpResponse<PagedResponseOfCycleContributionResponse>>
  getApiV1StokvelsStokvelIdCyclesCycleIdContributions({
    @Path('stokvelId') required String stokvelId,
    @Path('cycleId') required String cycleId,
    @Query('PageSize') int? pageSize,
    @Query('PageToken') String? pageToken,
    @Query('Sort') String? sort,
    @Query('UserId') String? userId,
    @Query('MemberRole') String? memberRole,
  });
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/contribution_response.dart';
import '../models/paged_response_of_contribution_list_item_response.dart';
import '../models/record_contribution_request.dart';

part 'contributions_client.g.dart';

@RestApi()
abstract class ContributionsClient {
  factory ContributionsClient(Dio dio, {String? baseUrl}) =
      _ContributionsClient;

  @GET('/api/v1/stokvels/{stokvelId}/contributions')
  Future<HttpResponse<PagedResponseOfContributionListItemResponse>>
  getApiV1StokvelsStokvelIdContributions({
    @Path('stokvelId') required String stokvelId,
    @Query('pageToken') String? pageToken,
    @Query('pageSize') int? pageSize = 20,
  });

  @POST('/api/v1/stokvels/{stokvelId}/contributions')
  Future<HttpResponse<ContributionResponse>>
  postApiV1StokvelsStokvelIdContributions({
    @Path('stokvelId') required String stokvelId,
    @Body() required RecordContributionRequest body,
    @Header('Idempotency-Key') String? idempotencyKey,
  });
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/paged_response_of_user_response.dart';

part 'stokvel_member_client.g.dart';

@RestApi()
abstract class StokvelMemberClient {
  factory StokvelMemberClient(Dio dio, {String? baseUrl}) =
      _StokvelMemberClient;

  @GET('/api/v1/stokvels/{stokvelId}/members')
  Future<HttpResponse<PagedResponseOfUserResponse>>
  getApiV1StokvelsStokvelIdMembers({
    @Path('stokvelId') required String stokvelId,
    @Query('PageSize') int? pageSize,
    @Query('PageToken') String? pageToken,
    @Query('Sort') String? sort,
    @Query('MemberRole') String? memberRole,
  });
}

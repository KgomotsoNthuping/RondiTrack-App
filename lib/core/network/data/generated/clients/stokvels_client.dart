// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/stokvel.dart';

part 'stokvels_client.g.dart';

@RestApi()
abstract class StokvelsClient {
  factory StokvelsClient(Dio dio, {String? baseUrl}) = _StokvelsClient;

  @GET('/api/v1/stokvels/{id}')
  Future<HttpResponse<Stokvel>> getApiV1StokvelsId({
    @Path('id') required String id,
  });

  @PUT('/api/v1/stokvels/{id}')
  Future<HttpResponse<Stokvel>> putApiV1StokvelsId({
    @Path('id') required String id,
    @Body() required Stokvel body,
  });

  @DELETE('/api/v1/stokvels/{id}')
  Future<HttpResponse<void>> deleteApiV1StokvelsId({
    @Path('id') required String id,
  });
}

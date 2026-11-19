// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/user_response.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  @POST('/api/v1/auth/register')
  Future<HttpResponse<UserResponse>> postApiV1AuthRegister({
    @Body() required RegisterRequest body,
  });

  @POST('/api/v1/auth/login')
  Future<HttpResponse<AuthResponse>> postApiV1AuthLogin({
    @Body() required LoginRequest body,
  });

  @POST('/api/v1/auth/refresh')
  Future<HttpResponse<AuthResponse>> postApiV1AuthRefresh();

  @POST('/api/v1/auth/logout')
  Future<HttpResponse<void>> postApiV1AuthLogout();
}

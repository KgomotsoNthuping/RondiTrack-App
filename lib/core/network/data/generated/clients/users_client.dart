// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/update_user_request.dart';
import '../models/user_response.dart';

part 'users_client.g.dart';

@RestApi()
abstract class UsersClient {
  factory UsersClient(Dio dio, {String? baseUrl}) = _UsersClient;

  /// Gets a specific user.
  ///
  /// Looks up a user using the supplied unique identifier.
  ///
  /// This endpoint does not create or modify any data.
  ///
  /// [id] - The unique identifier of the user.
  @GET('/api/v1/users/{id}')
  Future<HttpResponse<UserResponse>> getApiV1UsersId({
    @Path('id') required String id,
  });

  /// Updates an existing user.
  ///
  /// Replaces the editable profile details of an existing user.
  ///
  /// The user's identifier and creation timestamp cannot be changed.
  ///
  /// [id] - The unique identifier of the user being updated.
  @PUT('/api/v1/users/{id}')
  Future<HttpResponse<UserResponse>> putApiV1UsersId({
    @Path('id') required String id,
    @Body() required UpdateUserRequest body,
  });

  /// Deletes a user.
  ///
  /// Deletes the requested user only when the user is not currently.
  ///
  /// a member of a stokvel.
  ///
  ///
  ///
  /// Membership protection is a business rule and is enforced by.
  ///
  /// the service layer.
  ///
  /// [id] - The unique identifier of the user being deleted.
  @DELETE('/api/v1/users/{id}')
  Future<HttpResponse<void>> deleteApiV1UsersId({
    @Path('id') required String id,
  });
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/auth_client.dart';
import 'clients/contributions_client.dart';
import 'clients/contributions_cycle_client.dart';
import 'clients/me_client.dart';
import 'clients/stokvel_member_client.dart';
import 'clients/stokvels_client.dart';
import 'clients/users_client.dart';

/// Api | v1 `v1.0.0`
class RondiTrackApi {
  RondiTrackApi(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  AuthClient? _auth;
  ContributionsClient? _contributions;
  ContributionsCycleClient? _contributionsCycle;
  MeClient? _me;
  StokvelMemberClient? _stokvelMember;
  StokvelsClient? _stokvels;
  UsersClient? _users;

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  ContributionsClient get contributions =>
      _contributions ??= ContributionsClient(_dio, baseUrl: _baseUrl);

  ContributionsCycleClient get contributionsCycle =>
      _contributionsCycle ??= ContributionsCycleClient(_dio, baseUrl: _baseUrl);

  MeClient get me => _me ??= MeClient(_dio, baseUrl: _baseUrl);

  StokvelMemberClient get stokvelMember =>
      _stokvelMember ??= StokvelMemberClient(_dio, baseUrl: _baseUrl);

  StokvelsClient get stokvels =>
      _stokvels ??= StokvelsClient(_dio, baseUrl: _baseUrl);

  UsersClient get users => _users ??= UsersClient(_dio, baseUrl: _baseUrl);
}

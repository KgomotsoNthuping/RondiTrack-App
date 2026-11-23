import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/invites/domain/invite_repository.dart';

part 'api_invite_repository.g.dart';

@Riverpod(keepAlive: true)
ApiInviteRepository apiInviteRepository(Ref ref) {
  return ApiInviteRepository(ref.watch(apiDioProvider));
}

final class ApiInviteRepository implements InviteRepository {
  new(this._dio);

  final Dio _dio;

  static final _validCode = RegExp(r'^[A-Za-z0-9_-]{1,256}$');

  @override
  Future<Result<InvitePreview>> preview(String code) {
    return _request(
      code,
      joining: false,
      decode: (json) {
        final member = json['alreadyMember'];

        if (member is! bool) {
          throw const FormatException('Invalid invite response.');
        }

        return InvitePreview(
          stokvelId: _text(json, 'stokvelId'),
          name: _text(json, 'name'),
          alreadyMember: member,
        );
      },
    );
  }

  @override
  Future<Result<JoinedInvite>> join(String code) {
    return _request(
      code,
      joining: true,
      decode: (json) => JoinedInvite(
        stokvelId: _text(json, 'stokvelId'),
        name: _text(json, 'name'),
      ),
    );
  }

  Future<Result<T>> _request<T>(
    String code, {
    required bool joining,
    required T Function(Map<String, Object?>) decode,
  }) {
    return apiResult(() async {
      if (!_validCode.hasMatch(code)) {
        throw const NotFoundFailure();
      }

      final path = '/api/v1/invites/${Uri.encodeComponent(code)}';

      Response<Object?> response;

      try {
        response = joining
            ? await _dio.post<Object?>('$path/join')
            : await _dio.get<Object?>(path);
      } on DioException catch (error) {
        if (error.response?.statusCode == 410) {
          throw RuleFailure(
            detail: expiredInviteMessage,
            correlationId: responseCorrelationId(error.response),
          );
        }

        rethrow;
      }

      try {
        final json = response.data;

        if (json is! Map<String, Object?>) {
          throw const FormatException();
        }

        return decode(json);
      } on Object {
        throw ServerFailure(correlationId: responseCorrelationId(response));
      }
    }, isRead: !joining);
  }

  static String _text(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid invite response.');
    }

    return value;
  }
}

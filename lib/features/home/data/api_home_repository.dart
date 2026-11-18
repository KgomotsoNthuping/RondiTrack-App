import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/generated/rondi_track_api.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/home/data/home_mapper.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';

part 'api_home_repository.g.dart';

@Riverpod(keepAlive: true)
ApiHomeRepository apiHomeRepository(Ref ref) {
  return ApiHomeRepository(ref.watch(apiDioProvider));
}

final class ApiHomeRepository {
  new(Dio dio) : _api = createApiClient(dio);

  final RondiTrackApi _api;

  Future<Result<List<HomeEntry>>> fetchHome(String userId) {
    return apiResult(() async {
      final response = await _api.me.getApiV1MeHome();
      return mapHome(response.data);
    }, isRead: true);
  }
}

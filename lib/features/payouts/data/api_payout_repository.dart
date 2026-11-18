import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/generated/rondi_track_api.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';

part 'api_payout_repository.g.dart';

@Riverpod(keepAlive: true)
ApiPayoutRepository apiPayoutRepository(Ref ref) {
  return ApiPayoutRepository(ref.watch(apiDioProvider));
}

final class ApiPayoutRepository {
  new(Dio dio) : _api = createApiClient(dio);

  final RondiTrackApi _api;

  Future<Result<PayoutOrder>> fetchOrder(String userId, PayoutCycleKey cycle) {
    return apiResult<PayoutOrder>(() async {
      final (home, response) = await (
        _api.me.getApiV1MeHome(),
        _api.contributionsCycle.getApiV1StokvelsStokvelIdCyclesCycleId(
          stokvelId: cycle.stokvelId,
          cycleId: cycle.cycleId,
        ),
      ).wait;

      final isMember = home.data.stokvels.any(
        (item) => item.stokvelId == cycle.stokvelId,
      );

      if (!isMember || response.data.stokvelId != cycle.stokvelId) {
        throw const NotFoundFailure();
      }

      throw const RuleFailure(
        detail: 'Payout order is not available from this API yet.',
      );
    }, isRead: true);
  }
}

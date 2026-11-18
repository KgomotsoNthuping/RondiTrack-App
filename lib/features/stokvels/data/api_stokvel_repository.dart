import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/api_client.dart';
import 'package:ronditrack/core/network/data/api_result.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/network/data/generated/models/contribution_cycle_response.dart';
import 'package:ronditrack/core/network/data/generated/models/member_stokvel_home_response.dart';
import 'package:ronditrack/core/network/data/generated/rondi_track_api.dart';
import 'package:ronditrack/core/pagination/page.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_mapper.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

part 'api_stokvel_repository.g.dart';

@Riverpod(keepAlive: true)
ApiStokvelRepository apiStokvelRepository(Ref ref) {
  return ApiStokvelRepository(ref.watch(apiDioProvider));
}

final class ApiStokvelRepository {
  new(Dio dio) : _api = createApiClient(dio);

  final RondiTrackApi _api;

  Future<Result<Stokvel>> fetchDetail(
    String userId,
    String stokvelId, {
    String? cycleId,
  }) {
    return apiResult(() async {
      final (detailResponse, homeResponse) = await (
        _api.stokvels.getApiV1StokvelsId(id: stokvelId),
        _api.me.getApiV1MeHome(),
      ).wait;

      MemberStokvelHomeResponse? ownMembership;

      for (final item in homeResponse.data.stokvels) {
        if (item.stokvelId == stokvelId) {
          ownMembership = item;
          break;
        }
      }

      if (ownMembership == null) {
        throw const NotFoundFailure();
      }

      ContributionCycleResponse? selectedCycle;

      if (cycleId != null) {
        selectedCycle =
            (await _api.contributionsCycle
                    .getApiV1StokvelsStokvelIdCyclesCycleId(
                      stokvelId: stokvelId,
                      cycleId: cycleId,
                    ))
                .data;

        if (selectedCycle.stokvelId != stokvelId) {
          throw const NotFoundFailure();
        }
      } else {
        final cycles =
            (await _api.contributionsCycle.getApiV1StokvelsStokvelIdCycles(
              stokvelId: stokvelId,
            )).data;

        for (final cycle in cycles) {
          if (cycle.cycleNumber == ownMembership.currentCycle) {
            selectedCycle = cycle;
            break;
          }
        }
      }

      final members = await collectApiPages<({String id, String name})>((
        token,
      ) async {
        final page = (await _api.stokvelMember.getApiV1StokvelsStokvelIdMembers(
          stokvelId: stokvelId,
          pageSize: 20,
          pageToken: token,
        )).data;

        return Page(
          items: [
            for (final user in page.items) (id: user.id, name: user.fullName),
          ],
          nextPageToken: apiNextPageToken(page.nextPageToken),
        );
      });

      final names = {for (final member in members) member.id: member.name};

      final contributions = await collectApiPages<Contribution>((token) async {
        final page =
            (await _api.contributions.getApiV1StokvelsStokvelIdContributions(
              stokvelId: stokvelId,
              pageSize: 20,
              pageToken: token,
            )).data;

        return mapContributions(
          page,
          userId: userId,
          memberName: names[userId] ?? userId,
        );
      });

      return mapStokvel(
        detailResponse.data,
        membership: Membership(
          stokvelId: stokvelId,
          role: StokvelRole.fromApi(ownMembership.role),
        ),
        memberCount: names.length,
        contributions: contributions,
        cycle: selectedCycle,
      );
    }, isRead: true);
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/api_repository_adapters.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';
import 'package:ronditrack/features/stokvels/data/api_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

part 'stokvel_detail_provider.g.dart';

typedef StokvelDetail = ({Stokvel stokvel, Set<StokvelAction> actions});

@riverpod
StokvelRepository stokvelRepository(Ref ref) {
  if (!ref.watch(useApiRepositoriesProvider)) {
    return FakeStokvelRepository(
      workDelay: const Duration(seconds: 2),
      nalediJoinedFamily: ref.watch(familyInviteProvider),
    );
  }

  final token = ref.watch(accessTokenStoreProvider);

  return StokvelResultAdapter(
    ref.watch(apiStokvelRepositoryProvider).fetchDetail,
    subject: token?.userId,
  );
}

@riverpod
Future<StokvelDetail?> stokvelDetail(
  Ref ref,
  String stokvelId, {
  String? cycleId,
}) async {
  final persona = ref.watch(demoSessionProvider);

  if (persona == null) {
    return null;
  }

  final userId = ref.watch(accessTokenStoreProvider)?.userId ?? persona.name;
  final repository = ref.watch(stokvelRepositoryProvider);

  final stokvel = cycleId != null && repository is StokvelCycleRepository
      ? await repository.fetchCycleDetail(userId, stokvelId, cycleId)
      : await repository.fetchDetail(userId, stokvelId);

  if (stokvel == null) {
    return null;
  }

  final cycle = stokvel.currentCycle;
  ContributionStatus? ownStatus;

  for (final contribution in stokvel.contributions) {
    if (contribution.cycleId == cycle?.id && contribution.userId == userId) {
      ownStatus = contribution.status;
      break;
    }
  }

  return (
    stokvel: stokvel,
    actions: availableActions((
      stokvel.membership.role,
      cycle?.status,
      ownStatus,
    )),
  );
}

ScreenState<StokvelDetail> stokvelDetailViewState(
  AsyncValue<StokvelDetail?> state,
) {
  return state.when(
    skipLoadingOnReload: false,
    skipLoadingOnRefresh: false,
    loading: () => const ScreenLoading<StokvelDetail>(),
    error: (error, _) =>
        screenFailure(error, fallback: 'Could not load this stokvel.'),
    data: (detail) {
      if (detail == null) {
        return const ScreenFailure<StokvelDetail>('Not found');
      }

      if (detail.stokvel.currentCycle == null &&
          detail.stokvel.contributions.isEmpty) {
        return const ScreenEmpty<StokvelDetail>();
      }

      return ScreenData(detail);
    },
  );
}

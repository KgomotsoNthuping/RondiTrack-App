import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';

part 'stokvel_detail_provider.g.dart';

typedef StokvelDetail = ({Stokvel stokvel, Set<StokvelAction> actions});

@riverpod
StokvelRepository stokvelRepository(Ref ref) => FakeStokvelRepository(
  workDelay: const Duration(seconds: 2),
  nalediJoinedFamily: ref.watch(familyInviteProvider),
);

/// Loads detail and computes the active member's available actions.
@riverpod
Future<StokvelDetail?> stokvelDetail(Ref ref, String stokvelId) async {
  final userId = ref.watch(demoSessionProvider)?.name;
  if (userId == null) {
    return null;
  }
  final repository = ref.watch(stokvelRepositoryProvider);
  final stokvel = await repository.fetchDetail(userId, stokvelId);
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

/// Converts the detail request into a renderable screen state.
ScreenState<StokvelDetail> stokvelDetailViewState(
  AsyncValue<StokvelDetail?> state,
) {
  return state.when(
    skipLoadingOnRefresh: false,
    loading: () => const ScreenLoading<StokvelDetail>(),
    error: (_, _) =>
        const ScreenFailure<StokvelDetail>('Could not load this stokvel.'),
    data: (detail) {
      if (detail == null) {
        return const ScreenFailure<StokvelDetail>('Not found');
      }

      final stokvel = detail.stokvel;
      if (stokvel.currentCycle == null && stokvel.contributions.isEmpty) {
        return const ScreenEmpty<StokvelDetail>();
      }
      return ScreenData(detail);
    },
  );
}

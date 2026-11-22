import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/api_repository_adapters.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/data/api_home_repository.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';

part 'home_provider.g.dart';

@Riverpod(dependencies: [accountKey, FamilyInvite])
HomeRepository homeRepository(Ref ref) {
  requireAccount(ref);

  if (!ref.watch(useApiRepositoriesProvider)) {
    return FakeHomeRepository(
      nalediJoinedFamily: ref.watch(familyInviteProvider),
    );
  }

  return HomeResultAdapter(ref.watch(apiHomeRepositoryProvider).fetchHome);
}

@Riverpod(dependencies: [accountKey, MembershipRevision, homeRepository])
class Home extends _$Home {
  @override
  Future<List<HomeEntry>> build(String userId) {
    requireAccount(ref, userId: userId);
    ref.watch(membershipRevisionProvider);

    return ref.watch(homeRepositoryProvider).fetchHome(userId);
  }
}

ScreenState<List<HomeEntry>> homeViewState(AsyncValue<List<HomeEntry>> state) {
  return state.when(
    skipLoadingOnRefresh: state.hasValue,
    skipError: state.isRefreshing,
    loading: () => const ScreenLoading<List<HomeEntry>>(),
    data: (entries) => entries.isEmpty
        ? const ScreenEmpty<List<HomeEntry>>()
        : ScreenData(entries),
    error: (error, _) =>
        screenFailure(error, fallback: 'Could not load your stokvels.'),
  );
}

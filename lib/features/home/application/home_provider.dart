import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/domain/home_repository.dart';

part 'home_provider.g.dart';

@riverpod
HomeRepository homeRepository(Ref ref) => const FakeHomeRepository();

@riverpod
class Home extends _$Home {
  @override
  Future<List<HomeEntry>> build(String userId) {
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
    error: (_, _) =>
        const ScreenFailure<List<HomeEntry>>('Could not load your stokvels.'),
  );
}

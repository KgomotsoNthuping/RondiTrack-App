import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

part 'activity_provider.g.dart';

typedef ActivityEntry = ({String stokvelName, Contribution contribution});

@riverpod
Future<List<ActivityEntry>> activityFeed(Ref ref, String userId) async {
  final home = ref.watch(homeProvider(userId).future);
  final repository = ref.watch(stokvelRepositoryProvider);
  final memberships = await home;

  final stokvels = await Future.wait(
    memberships.map(
      (entry) => repository.fetchDetail(userId, entry.membership.stokvelId),
    ),
  );

  final entries = <ActivityEntry>[
    for (final stokvel in stokvels)
      if (stokvel != null)
        for (final contribution in stokvel.contributions)
          (stokvelName: stokvel.name, contribution: contribution),
  ];

  entries.sort((first, second) {
    final firstDate = first.contribution.paidAtUtc;
    final secondDate = second.contribution.paidAtUtc;

    if (firstDate == null) {
      return secondDate == null ? 0 : 1;
    }
    if (secondDate == null) {
      return -1;
    }

    return secondDate.compareTo(firstDate);
  });

  return entries;
}

ScreenState<List<ActivityEntry>> activityViewState(
  AsyncValue<List<ActivityEntry>> state,
) {
  return state.when(
    skipLoadingOnRefresh: false,
    loading: () => const ScreenLoading<List<ActivityEntry>>(),
    data: (entries) => entries.isEmpty
        ? const ScreenEmpty<List<ActivityEntry>>()
        : ScreenData(entries),
    error: (_, _) => const ScreenFailure<List<ActivityEntry>>(
      'Could not load your activity.',
    ),
  );
}
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

part 'activity_provider.g.dart';

typedef ActivityEntry = ({String stokvelName, Contribution contribution});

@Riverpod(
  dependencies: [accountKey, MembershipRevision, Home, stokvelRepository],
)
Future<List<ActivityEntry>> activityFeed(Ref ref, String userId) async {
  final account = requireAccount(ref, userId: userId);
  ref.watch(membershipRevisionProvider);

  final home = ref.watch(homeProvider(userId).future);
  final repository = ref.watch(stokvelRepositoryProvider);
  final memberships = await home;

  if (!ref.mounted || ref.read(accountKeyProvider) != account) {
    throw const UnauthorizedFailure();
  }

  final stokvels = await Future.wait(
    memberships.map(
      (entry) => repository.fetchDetail(userId, entry.membership.stokvelId),
    ),
  );

  final entries =
      <ActivityEntry>[
        for (final stokvel in stokvels)
          if (stokvel != null)
            for (final contribution in stokvel.contributions)
              (stokvelName: stokvel.name, contribution: contribution),
      ]..sort((first, second) {
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
    error: (error, _) =>
        screenFailure(error, fallback: 'Could not load your activity.'),
  );
}

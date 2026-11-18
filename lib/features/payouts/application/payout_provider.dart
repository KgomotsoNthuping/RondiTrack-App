import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/api_repository_adapters.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';
import 'package:ronditrack/features/payouts/data/api_payout_repository.dart';
import 'package:ronditrack/features/payouts/data/fake_payout_repository.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';

part 'payout_provider.g.dart';

@riverpod
PayoutRepository payoutRepository(Ref ref) {
  if (!ref.watch(useApiRepositoriesProvider)) {
    return FakePayoutRepository(
      stokvelRepository: ref.watch(stokvelRepositoryProvider),
      nalediJoinedFamily: ref.watch(familyInviteProvider),
    );
  }

  ref.watch(accessTokenStoreProvider);

  return PayoutResultAdapter(ref.watch(apiPayoutRepositoryProvider).fetchOrder);
}

@riverpod
Future<PayoutOrder> payoutOrder(Ref ref, PayoutCycleKey cycle) async {
  final persona = ref.watch(demoSessionProvider);

  if (persona == null) {
    throw const PayoutOrderNotFound();
  }

  return ref.watch(payoutRepositoryProvider).fetchOrder(persona.name, cycle);
}

ScreenState<PayoutOrder> payoutOrderViewState(AsyncValue<PayoutOrder> state) {
  return state.when(
    skipLoadingOnReload: false,
    skipLoadingOnRefresh: false,
    loading: () => const ScreenLoading<PayoutOrder>(),
    data: (order) => order.entries.isEmpty
        ? const ScreenEmpty<PayoutOrder>()
        : ScreenData(order),
    error: (error, _) => error is PayoutOrderNotFound
        ? const ScreenFailure<PayoutOrder>('Not found', canRetry: false)
        : screenFailure(error, fallback: 'Could not load the payout order.'),
  );
}

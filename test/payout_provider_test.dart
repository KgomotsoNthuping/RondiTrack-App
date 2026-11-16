import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';

const _family = (stokvelId: 'family-savers', cycleId: 'family-cycle-1');
const _work = (stokvelId: 'work-savers', cycleId: 'work-cycle-1');

const _familyOrder = PayoutOrder(
  stokvelId: 'family-savers',
  cycleId: 'family-cycle-1',
  entries: [
    PayoutOrderEntry(
      userId: 'lerato',
      memberName: 'Lerato',
      position: 1,
      amount: Cents(150_000),
      status: PayoutStatus.next,
    ),
  ],
);

const _workOrder = PayoutOrder(
  stokvelId: 'work-savers',
  cycleId: 'work-cycle-1',
  entries: [],
);

void main() {
  test('maps a request failure to a retryable screen state', () {
    final state = payoutOrderViewState(
      AsyncError<PayoutOrder>(Exception('Offline'), StackTrace.empty),
    );

    expect(
      state,
      isA<ScreenFailure<PayoutOrder>>()
          .having(
            (failure) => failure.message,
            'message',
            'Could not load the payout order.',
          )
          .having((failure) => failure.canRetry, 'canRetry', isTrue),
    );
  });

  test('keeps loading, empty and data separate across two cycles', () async {
    final familyPending = Completer<PayoutOrder>();
    final workPending = Completer<PayoutOrder>();
    final requests = <PayoutCycleKey>[];

    final repository = _StubPayoutRepository((userId, cycle) {
      expect(userId, 'lerato');
      requests.add(cycle);
      return cycle == _family ? familyPending.future : workPending.future;
    });

    final container = ProviderContainer.test(
      retry: appProviderRetry,
      overrides: [
        demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.lerato),
        payoutRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final familyProvider = payoutOrderProvider(_family);
    final workProvider = payoutOrderProvider(_work);
    final family = container.listen(familyProvider, (_, _) {});
    final work = container.listen(workProvider, (_, _) {});

    expect(
      payoutOrderViewState(family.read()),
      isA<ScreenLoading<PayoutOrder>>(),
    );
    expect(
      payoutOrderViewState(work.read()),
      isA<ScreenLoading<PayoutOrder>>(),
    );

    workPending.complete(_workOrder);
    await container.read(workProvider.future);

    expect(payoutOrderViewState(work.read()), isA<ScreenEmpty<PayoutOrder>>());
    expect(
      payoutOrderViewState(family.read()),
      isA<ScreenLoading<PayoutOrder>>(),
    );

    familyPending.complete(_familyOrder);
    await container.read(familyProvider.future);

    expect(
      payoutOrderViewState(family.read()),
      isA<ScreenData<PayoutOrder>>().having(
        (data) => data.value,
        'order',
        _familyOrder,
      ),
    );
    expect(payoutOrderViewState(work.read()), isA<ScreenEmpty<PayoutOrder>>());
    expect(requests, unorderedEquals([_family, _work]));
  });

  test(
    'emits not found after one request using the app retry policy',
    () async {
      var requests = 0;
      final repository = _StubPayoutRepository((userId, cycle) async {
        expect(userId, 'naledi');
        expect(cycle, _family);
        requests += 1;
        throw const PayoutOrderNotFound();
      });

      final container = ProviderContainer.test(
        retry: appProviderRetry,
        overrides: [
          demoSessionProvider.overrideWithBuild((_, _) => DemoPersona.naledi),
          payoutRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final provider = payoutOrderProvider(_family);
      final subscription = container.listen(provider, (_, _) {});

      await expectLater(
        container.read(provider.future),
        throwsA(isA<PayoutOrderNotFound>()),
      );

      expect(requests, 1);
      expect(
        payoutOrderViewState(subscription.read()),
        isA<ScreenFailure<PayoutOrder>>()
            .having((failure) => failure.message, 'message', 'Not found')
            .having((failure) => failure.canRetry, 'canRetry', isFalse),
      );
    },
  );
}

final class _StubPayoutRepository implements PayoutRepository {
  const new(this._fetch);

  final Future<PayoutOrder> Function(String userId, PayoutCycleKey cycle)
  _fetch;

  @override
  Future<PayoutOrder> fetchOrder(String userId, PayoutCycleKey cycle) {
    return _fetch(userId, cycle);
  }
}

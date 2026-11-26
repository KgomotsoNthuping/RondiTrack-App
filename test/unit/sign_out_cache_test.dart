import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/data/drift_session_persistence.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';

import '../support/assignment_12_1_fixtures.dart';

void main() {
  late AppDatabase database;
  late TestSession session;
  late PaymentOutbox outbox;

  setUp(() async {
    database = memoryDatabase();
    session = await TestSession.start(
      persistence: DriftSessionPersistence(database),
    );
    outbox = PaymentOutbox(database);

    await HomeCache(database).replace(
      generation: database.generation,
      userId: testUserId,
      entries: [testHomeEntry],
      updatedAtUtc: testNow,
    );
    await StokvelCache(database).replace(
      generation: database.generation,
      userId: testUserId,
      value: testStokvel,
      updatedAtUtc: testNow,
    );

    final payment = await outbox.enqueue(
      generation: database.generation,
      userId: testUserId,
      stokvelId: testStokvelId,
      cycleId: testCycleId,
      amount: const Cents(10000),
      createdAtUtc: testNow.subtract(const Duration(hours: 24)),
    );

    await outbox.requireReview(
      generation: database.generation,
      payment: payment,
      phase: PaymentPhase.expired,
      kind: PaymentNoticeKind.expired,
      nowUtc: testNow,
    );
  });

  tearDown(() async {
    session.dispose();
    await database.close();
  });

  test('ordinary sign-out protects pending payments', () async {
    final epoch = session.coordinator.epoch;
    final result = await session.coordinator.signOut();

    expect(result, isA<Err<void>>());
    expect((result as Err<void>).failure, isA<RuleFailure>());
    expect(session.coordinator.epoch, epoch);
    expect(session.coordinator.state, isA<AuthSignedIn>());
    expect(await outbox.read(testUserId), hasLength(1));

    for (final table in database.allTables) {
      expect(await database.select(table).get(), isNotEmpty);
    }

    verifyNever(
      () => session.api.logout(refreshToken: any(named: 'refreshToken')),
    );
  });

  test('confirmed discard clears every local table and credentials', () async {
    final generation = database.generation;

    final result = await session.coordinator.signOut(
      discardPendingPayments: true,
    );

    expect(result, isA<Ok<void>>());
    expect(session.coordinator.state, isA<AuthSignedOut>());
    expect(await session.store.read(), isNull);
    expect(database.generation, greaterThan(generation));

    for (final table in database.allTables) {
      expect(await database.select(table).get(), isEmpty);
    }

    expect(
      await HomeCache(database).replace(
        generation: generation,
        userId: testUserId,
        entries: [testHomeEntry],
        updatedAtUtc: testNow,
      ),
      isFalse,
    );
    expect(await HomeCache(database).read(testUserId), isNull);
    verify(() => session.api.logout(refreshToken: any(named: 'refreshToken')))
        .called(1);
  });

  test(
    '401 preserves pending intent but blocks authenticated access',
    () async {
      final original = (await outbox.read(testUserId)).single;

      when(
        () => session.api.refresh(refreshToken: any(named: 'refreshToken')),
      ).thenAnswer((_) async => const Err<AuthTokens>(UnauthorizedFailure()));

      expect(await session.coordinator.refresh(), isA<Err<AccessToken>>());

      final state = session.coordinator.state as AuthSignedIn;
      final restored = (await outbox.read(testUserId)).single;

      expect(state.identity.userId, testUserId);
      expect(state.currentAccessToken, isNull);
      expect(state.failure, isA<UnauthorizedFailure>());
      expect(await session.store.read(), isNull);
      expect(
        await session.coordinator.tokenForRequest(),
        isA<Err<AccessToken>>(),
      );
      expect(restored.key, original.key);
      expect(restored.frozenBody, original.frozenBody);
      expect(await HomeCache(database).read(testUserId), isNotNull);
      expect(
        (await DriftSessionPersistence(database).readIdentity())?.userId,
        testUserId,
      );
      verify(
        () => session.api.refresh(refreshToken: any(named: 'refreshToken')),
      ).called(1);
    },
  );
}

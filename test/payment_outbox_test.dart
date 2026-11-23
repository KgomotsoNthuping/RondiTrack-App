import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

void main() {
  late AppDatabase database;
  late PaymentOutbox store;

  final createdAt = DateTime.utc(2026, 11, 23, 10);

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

    store = PaymentOutbox(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<PendingPayment> enqueue() {
    return store.enqueue(
      generation: database.generation,
      userId: 'user-1',
      stokvelId: 'stokvel-1',
      cycleId: 'cycle-1',
      amount: const Cents(125050),
      createdAtUtc: createdAt,
    );
  }

  PaymentWorker worker({
    required Future<PaymentReply> Function(PendingPayment) send,
    required DateTime Function() clock,
  }) {
    final result = PaymentWorker(
      store: store,
      userId: 'user-1',
      send: send,
      isCurrent: () => true,
      canSend: () => true,
      onResolved: (_) async {},
      clock: clock,
    );

    addTearDown(result.dispose);
    return result;
  }

  test('a second tap reuses the stored intent', () async {
    var keyCalls = 0;

    final controlledStore = PaymentOutbox(
      database,
      newKey: () {
        keyCalls++;
        return 'payment-key-$keyCalls';
      },
    );

    Future<PendingPayment> save(Cents amount) {
      return controlledStore.enqueue(
        generation: database.generation,
        userId: 'user-1',
        stokvelId: 'stokvel-1',
        cycleId: 'cycle-1',
        amount: amount,
        createdAtUtc: createdAt,
      );
    }

    final first = await save(const Cents(125050));
    final second = await save(const Cents(250100));

    expect(first.key, second.key);
    expect(first.frozenBody, second.frozenBody);
    expect(second.amount.value, 125050);
    expect(keyCalls, 1);
  });

  test('no answer keeps the payment and its original body', () async {
    final original = await enqueue();

    final subject = worker(
      clock: () => createdAt,
      send: (_) async => const PaymentUnanswered(OfflineFailure(isRead: false)),
    );

    await subject.drain();

    final saved = (await store.read('user-1')).single;

    expect(saved.key, original.key);
    expect(saved.frozenBody, original.frozenBody);
    expect(saved.createdAtUtc, original.createdAtUtc);
    expect(saved.phase, PaymentPhase.pending);
  });

  test('accepted payment is removed and its notice persists', () async {
    final original = await enqueue();

    final subject = worker(
      clock: () => createdAt,
      send: (_) async => const PaymentAccepted('contribution-1'),
    );

    await subject.drain();

    expect(await store.read('user-1'), isEmpty);

    final notice = (await store.watchNotices('user-1').first).single;

    expect(notice.key, original.key);
    expect(notice.kind, PaymentNoticeKind.paid);
    expect(notice.contributionId, 'contribution-1');
  });

  test(
    'a permanent refusal removes the attempt and saves its reason',
    () async {
      await enqueue();

      final subject = worker(
        clock: () => createdAt,
        send: (_) async => const PaymentRefused(
          ConflictFailure(detail: 'Already recorded for this cycle.'),
        ),
      );

      await subject.drain();

      expect(await store.read('user-1'), isEmpty);

      final notice = (await store.watchNotices('user-1').first).single;

      expect(notice.kind, PaymentNoticeKind.refused);
      expect(notice.detail, 'Already recorded for this cycle.');
    },
  );

  test('429 waits and then retries the same key', () async {
    final original = await enqueue();
    var now = createdAt;
    final attempts = <PendingPayment>[];

    final subject = worker(
      clock: () => now,
      send: (payment) async {
        attempts.add(payment);

        if (attempts.length == 1) {
          return PaymentWaiting(createdAt.add(const Duration(seconds: 20)));
        }

        return const PaymentAccepted('contribution-1');
      },
    );

    await subject.drain();
    await subject.drain();

    expect(attempts, hasLength(1));

    now = createdAt.add(const Duration(seconds: 20));

    await subject.drain();

    expect(attempts, hasLength(2));
    expect(attempts[0].key, original.key);
    expect(attempts[1].key, original.key);
    expect(attempts[0].frozenBody, attempts[1].frozenBody);
  });

  test(
    'expired attempts are never sent, even if the clock moves back',
    () async {
      await enqueue();

      var now = createdAt.add(const Duration(hours: 24));
      var attempts = 0;

      final subject = worker(
        clock: () => now,
        send: (_) async {
          attempts++;
          return const PaymentAccepted('contribution-1');
        },
      );

      await subject.drain();

      expect(attempts, 0);
      expect((await store.read('user-1')).single.phase, PaymentPhase.expired);

      now = createdAt.add(const Duration(hours: 1));

      await subject.drain();

      expect(attempts, 0);
    },
  );

  test(
    'the key and JSON body survive closing and reopening the file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ronditrack-outbox-',
      );

      final file = File('${directory.path}/payments.sqlite');

      try {
        final firstDatabase = AppDatabase(NativeDatabase(file));

        late PendingPayment original;

        try {
          original = await PaymentOutbox(firstDatabase).enqueue(
            generation: firstDatabase.generation,
            userId: 'user-1',
            stokvelId: 'stokvel-1',
            cycleId: 'cycle-1',
            amount: const Cents(125050),
            createdAtUtc: createdAt,
          );
        } finally {
          await firstDatabase.close();
        }

        final reopened = AppDatabase(NativeDatabase(file));

        try {
          final restored = (await PaymentOutbox(reopened).read('user-1'))
              .single;

          expect(restored.key, original.key);
          expect(restored.frozenBody, original.frozenBody);
          expect(restored.createdAtUtc, original.createdAtUtc);
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

import '../support/assignment_12_1_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'notification event runs after the durable write and cannot fail payment',
    () async {
      final db = memoryDatabase();
      final outbox = PaymentOutbox(db);

      var notified = false;

      final worker = PaymentWorker(
        store: outbox,
        userId: testUserId,
        isCurrent: () => true,
        canSend: () => true,
        clock: () => testNow,
        onQueued: () {
          notified = true;
          throw StateError('Notification feature unavailable');
        },
        send: (payment) async {
          expect(notified, isTrue);

          final stored = await outbox.read(testUserId);

          expect(stored.single.key, payment.key);

          return const PaymentUnanswered(OfflineFailure(isRead: false));
        },
        onResolved: (_) async {},
      );

      try {
        final payment = await worker.enqueue(
          stokvelId: testStokvelId,
          cycleId: testCycleId,
          amount: const Cents(10000),
        );

        expect(notified, isTrue);

        expect((await outbox.read(testUserId)).single.key, payment.key);
      } finally {
        worker.dispose();
        await db.close();
      }
    },
  );
}

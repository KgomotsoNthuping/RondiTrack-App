import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/payments/application/payment_worker.dart';
import 'package:ronditrack/features/payments/data/payment_outbox.dart';
import 'package:ronditrack/features/payments/data/payment_sender.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';

import 'support/assignment_12_1_fixtures.dart';
import 'support/scripted_http_adapter.dart';

void main() {
  test('a second tap reuses the frozen intent and amount', () async {
    final h = _Harness();
    addTearDown(h.close);

    final first = await h.enqueue();
    final second = await h.enqueue(amount: const Cents(20000));

    expect(second.key, first.key);
    expect(second.frozenBody, first.frozenBody);
    expect(second.amount.value, 10000);
    expect(h.keyCalls, 1);
    expect(await h.store.read(testUserId), hasLength(1));
  });

  test(
    'lost response retries the same key and creates one contribution',
    () async {
      final ledger = _Ledger()..loseNextReply = true;
      final h = _Harness(ledger: ledger);
      addTearDown(h.close);
      final original = await h.enqueue();

      await HomeCache(h.database).replace(
        generation: h.database.generation,
        userId: testUserId,
        entries: [testHomeEntry],
        updatedAtUtc: testNow,
      );
      await StokvelCache(h.database).replace(
        generation: h.database.generation,
        userId: testUserId,
        value: testStokvel,
        updatedAtUtc: testNow,
      );

      await h.worker.drain();

      final pending = (await h.store.read(testUserId)).single;
      expect(pending.key, original.key);
      expect(pending.frozenBody, original.frozenBody);
      expect(pending.phase, PaymentPhase.pending);
      expect(await h.store.watchNotices(testUserId).first, isEmpty);
      expect(h.resolved, 0);
      expect((await HomeCache(h.database).read(testUserId))!.value, [
        testHomeEntry,
      ]);
      expect(
        (await StokvelCache(h.database).read(testUserId, testStokvelId))!.value,
        testStokvel,
      );

      await h.worker.drain();

      expect(h.adapter.requests.map((request) => _key(request.headers)), [
        original.key,
        original.key,
      ]);
      expect(h.adapter.requests.map((request) => request.body), [
        original.frozenBody,
        original.frozenBody,
      ]);
      expect(ledger.contributions, hasLength(1));
      expect(await h.store.read(testUserId), isEmpty);
      expect(
        (await h.store.watchNotices(testUserId).first).single.kind,
        PaymentNoticeKind.paid,
      );
      expect(h.resolved, 1);
    },
  );

  for (final header in ['20', 'Tue, 01 Jan 2030 12:00:20 GMT']) {
    test('429 waits and reuses the same key: $header', () async {
      final ledger = _Ledger()..retryAfter = header;
      final h = _Harness(ledger: ledger);
      addTearDown(h.close);
      final original = await h.enqueue();

      await h.worker.drain();

      final pending = (await h.store.read(testUserId)).single;
      expect(pending.phase, PaymentPhase.waiting);
      expect(pending.retryAtUtc, testNow.add(const Duration(seconds: 20)));

      h.now = testNow.add(const Duration(seconds: 19));
      await h.worker.drain();
      expect(h.adapter.requests, hasLength(1));
      expect(ledger.contributions, isEmpty);

      h.now = testNow.add(const Duration(seconds: 20));
      await h.worker.drain();

      expect(h.adapter.requests.map((request) => _key(request.headers)), [
        original.key,
        original.key,
      ]);
      expect(h.adapter.requests.map((request) => request.body), [
        original.frozenBody,
        original.frozenBody,
      ]);
      expect(ledger.contributions, hasLength(1));
      expect(await h.store.read(testUserId), isEmpty);
    });
  }

  test(
    'restart during a request reopens the file and reuses its key',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ronditrack-outbox-',
      );
      final file = File('${directory.path}/payments.sqlite');
      final committed = Completer<void>();
      final release = Completer<void>();
      final ledger = _Ledger()
        ..loseNextReply = true
        ..committed = committed
        ..releaseLostReply = release;
      final first = _Harness(
        database: AppDatabase(NativeDatabase(file)),
        ledger: ledger,
      );
      _Harness? second;
      Future<void>? inFlight;

      try {
        final original = await first.enqueue();
        inFlight = first.worker.drain();

        await committed.future.timeout(const Duration(seconds: 3));
        expect(first.worker.sending, isTrue);
        expect(ledger.contributions, hasLength(1));

        await first.close();
        release.complete();
        await inFlight;

        second = _Harness(
          database: AppDatabase(NativeDatabase(file)),
          ledger: ledger,
        );
        final restored = (await second.store.read(testUserId)).single;

        expect(restored.key, original.key);
        expect(restored.frozenBody, original.frozenBody);
        expect(restored.createdAtUtc, original.createdAtUtc);

        await second.worker.drain();

        expect(
          [
            _key(first.adapter.requests.single.headers),
            _key(second.adapter.requests.single.headers),
          ],
          [original.key, original.key],
        );
        expect(second.adapter.requests.single.body, original.frozenBody);
        expect(second.keyCalls, 0);
        expect(ledger.contributions, hasLength(1));
        expect(await second.store.read(testUserId), isEmpty);
        expect(
          (await second.store.watchNotices(testUserId).first).single.kind,
          PaymentNoticeKind.paid,
        );
      } finally {
        if (!release.isCompleted) {
          release.complete();
        }
        if (inFlight case final pending?) {
          await pending;
        }
        await first.close();
        if (second case final reopened?) {
          await reopened.close();
        }
        await directory.delete(recursive: true);
      }
    },
  );

  for (final reason in [
    'Already paid for this cycle.',
    'This cycle is closed.',
    'The key belongs to another body.',
  ]) {
    test('409 stops and explains: $reason', () async {
      final h = _Harness(respond: (_) => jsonResponse(409, {'detail': reason}));
      addTearDown(h.close);
      await h.enqueue();

      await h.worker.drain();
      await h.worker.drain();

      expect(await h.store.read(testUserId), isEmpty);
      final notice = (await h.store.watchNotices(testUserId).first).single;
      expect(notice.kind, PaymentNoticeKind.refused);
      expect(notice.detail, reason);
      expect(h.adapter.requests, hasLength(1));
      expect(h.resolved, 1);
    });
  }

  for (final status in [400, 403, 404, 422]) {
    test('$status records a terminal refusal without another send', () async {
      final h = _Harness(
        respond: (_) => jsonResponse(status, {
          'detail': 'The API refused this payment.',
          'errors': {
            'amountInCents': ['Check this amount.'],
          },
        }),
      );
      addTearDown(h.close);
      await h.enqueue();

      await h.worker.drain();
      await h.worker.drain();

      expect(await h.store.read(testUserId), isEmpty);
      final notice = (await h.store.watchNotices(testUserId).first).single;
      expect(notice.kind, PaymentNoticeKind.refused);
      expect(notice.detail, isNotEmpty);
      if (status == 400) {
        expect(notice.errors['amountInCents'], ['Check this amount.']);
      }
      expect(h.adapter.requests, hasLength(1));
    });
  }

  for (final status in [200, 201, 401, 500, 503]) {
    test('$status without a valid confirmation keeps the attempt', () async {
      final h = _Harness(
        respond: (_) => jsonResponse(status, {'id': 'incomplete'}),
      );
      addTearDown(h.close);
      final original = await h.enqueue();

      await h.worker.drain();

      final saved = (await h.store.read(testUserId)).single;
      expect(saved.key, original.key);
      expect(saved.frozenBody, original.frozenBody);
      expect(saved.phase, PaymentPhase.pending);
      expect(await h.store.watchNotices(testUserId).first, isEmpty);
      expect(h.resolved, 0);
    });
  }

  test('expired attempts never resend after the clock moves back', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.enqueue();

    h.now = testNow.add(const Duration(hours: 24));
    await h.worker.drain();
    expect((await h.store.read(testUserId)).single.phase, PaymentPhase.expired);

    h.now = testNow.add(const Duration(hours: 1));
    await h.worker.drain();

    expect(h.adapter.requests, isEmpty);
    expect(
      (await h.store.watchNotices(testUserId).first).single.kind,
      PaymentNoticeKind.expired,
    );
  });

  test('future creation time stops for clock review', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.enqueue();
    h.now = testNow.subtract(const Duration(minutes: 1));

    await h.worker.drain();

    expect(h.adapter.requests, isEmpty);
    expect(
      (await h.store.read(testUserId)).single.phase,
      PaymentPhase.clockMismatch,
    );
  });
}

String _key(Map<String, dynamic> headers) =>
    headers.entries
            .singleWhere(
              (entry) => entry.key.toLowerCase() == 'idempotency-key',
            )
            .value
        as String;

final class _Harness {
  new({
    AppDatabase? database,
    _Ledger? ledger,
    FutureOr<ResponseBody> Function(RequestOptions)? respond,
  }) : database = database ?? memoryDatabase(),
       ledger = ledger ?? _Ledger() {
    adapter = ScriptedHttpAdapter(respond ?? this.ledger.respond);
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'))
      ..httpClientAdapter = adapter;
    store = PaymentOutbox(
      this.database,
      newKey: () => 'test-intent-${++keyCalls}',
    );
    final sender = PaymentSender(() => dio, clock: () => now);
    worker = PaymentWorker(
      store: store,
      userId: testUserId,
      send: sender.send,
      isCurrent: () => true,
      canSend: () => true,
      onResolved: (_) async {
        resolved++;
      },
      clock: () => now,
    );
  }

  final AppDatabase database;
  final _Ledger ledger;
  late final ScriptedHttpAdapter adapter;
  late final Dio dio;
  late final PaymentOutbox store;
  late final PaymentWorker worker;
  DateTime now = testNow;
  int keyCalls = 0;
  int resolved = 0;
  bool _closed = false;

  Future<PendingPayment> enqueue({Cents amount = const Cents(10000)}) =>
      store.enqueue(
        generation: database.generation,
        userId: testUserId,
        stokvelId: testStokvelId,
        cycleId: testCycleId,
        amount: amount,
        createdAtUtc: now,
      );

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    worker.dispose();
    dio.close(force: true);
    await database.close();
  }
}

final class _Ledger {
  final contributions = <String, ({String body, Map<String, Object?> data})>{};
  bool loseNextReply = false;
  String? retryAfter;
  Completer<void>? committed;
  Completer<void>? releaseLostReply;

  Future<ResponseBody> respond(RequestOptions request) async {
    final header = retryAfter;
    if (header != null) {
      retryAfter = null;
      return jsonResponse(
        429,
        {},
        headers: {
          'retry-after': [header],
        },
      );
    }

    final key = _key(request.headers);
    final body = request.data! as String;
    final previous = contributions[key];

    if (previous != null && previous.body != body) {
      return jsonResponse(409, {'detail': 'Key/body conflict.'});
    }
    if (previous == null && contributions.isNotEmpty) {
      return jsonResponse(409, {'detail': 'Already paid for this cycle.'});
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final contribution =
        previous ??
        (
          body: body,
          data: <String, Object?>{
            'id': 'contribution-1',
            'userId': decoded['userId'],
            'stokvelId': testStokvelId,
            'contributionCycleId': testCycleId,
            'amountInCents': decoded['amountInCents'],
            'status': 'Paid',
          },
        );
    contributions[key] = contribution;

    if (loseNextReply) {
      loseNextReply = false;
      committed?.complete();
      final gate = releaseLostReply;
      if (gate != null) {
        await gate.future;
      }
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    }

    return jsonResponse(201, contribution.data);
  }
}

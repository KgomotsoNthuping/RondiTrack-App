import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/application/cycle_editor.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';

import '../support/assignment_12_1_fixtures.dart';

void main() {
  final initial = EditableCycle.fromCache(testStokvel.currentCycle!);

  EditableCycle saved(int version) => EditableCycle(
    id: initial.id,
    number: 2,
    target: const Cents(70000),
    collected: initial.collected,
    version: version,
    status: initial.status,
  );

  test('save displays the preview until the server confirms it', () async {
    final response = Completer<EditableCycle>();
    final calls = <(int, Cents, int)>[];
    final controller = CycleEditor(
      initial: initial,
      loadLatest: () async => initial,
      save: (number, target, version) {
        calls.add((number, target, version));
        return response.future;
      },
    );
    addTearDown(controller.dispose);

    final request = controller.submit(2, const Cents(70000));

    expect(controller.saving, isTrue);
    expect(controller.displayed.number, 2);
    expect(controller.displayed.target.value, 70000);
    expect(controller.latest.version, 1);

    response.complete(saved(2));

    expect(await request, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.latest.version, 2);
    expect(calls.single.$3, 1);
  });

  test('conflict loads the new version and requires review', () async {
    final calls = <(int, Cents, int)>[];
    var reloads = 0;
    final controller = CycleEditor(
      initial: initial,
      loadLatest: () async {
        reloads++;
        return saved(2);
      },
      save: (number, target, version) async {
        calls.add((number, target, version));
        if (calls.length == 1) {
          throw const ConflictFailure();
        }
        return saved(3);
      },
    );
    addTearDown(controller.dispose);

    expect(await controller.submit(2, const Cents(70000)), isFalse);
    expect(controller.failure, isA<ConflictFailure>());
    expect(controller.requiresReview, isTrue);
    expect(controller.canAcceptLatest, isTrue);
    expect(controller.latest.version, 2);
    expect(reloads, 1);

    expect(await controller.submit(2, const Cents(70000)), isFalse);
    expect(calls, hasLength(1));

    controller.acceptLatest();

    expect(await controller.submit(2, const Cents(70000)), isTrue);
    expect(calls.map((call) => call.$3), [1, 2]);
    expect(controller.latest.version, 3);
    expect(controller.requiresReview, isFalse);
  });
}

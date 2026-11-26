import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/home/presentation/home_stokvel_card.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

import 'support/assignment_12_1_fixtures.dart';

void main() {
  group('HomeStokvelCard', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? RondiTrackTheme.light
          : RondiTrackTheme.dark;

      unawaited(
        goldenTest(
          'renders its visual states in ${brightness.name}',
          fileName: 'home_stokvel_card_${brightness.name}',
          builder: () => GoldenTestGroup(
            columns: 2,
            columnWidthBuilder: (_) => const FixedColumnWidth(400),
            scenarioConstraints: const BoxConstraints.tightFor(width: 360),
            children: [
              for (final scenario in _scenarios)
                GoldenTestScenario.builder(
                  name: scenario.name,
                  builder: (context) {
                    final family = Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .fontFamily;

                    final cardTheme = theme.copyWith(
                      textTheme: theme.textTheme.apply(fontFamily: family),
                      primaryTextTheme: theme.primaryTextTheme.apply(
                        fontFamily: family,
                      ),
                    );

                    return Theme(
                      data: cardTheme,
                      child: Material(
                        color: cardTheme.scaffoldBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: HomeStokvelCard(
                            entry: scenario.entry,
                            onTap: () {},
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }
  });
}

final _base = testHomeEntry.copyWith(
  cycleDueDate: (year: 2030, month: 1, day: 31),
  paidThisCycle: const Cents(5000),
  stillOwed: const Cents(5000),
  nextPayoutDateUtc: DateTime.utc(2030, 2, 1, 10),
);

HomeEntry _role(StokvelRole role, {required bool paidUp}) => _base.copyWith(
  membership: Membership(stokvelId: testStokvelId, role: role),
  arrears: Cents(paidUp ? 0 : 5000),
  paidThisCycle: Cents(paidUp ? 10000 : 5000),
  stillOwed: Cents(paidUp ? 0 : 5000),
);

final _scenarios = <({String name, HomeEntry entry})>[
  (
    name: 'Treasurer · arrears',
    entry: _role(StokvelRole.treasurer, paidUp: false),
  ),
  (
    name: 'Treasurer · up to date',
    entry: _role(StokvelRole.treasurer, paidUp: true),
  ),
  (name: 'Member · arrears', entry: _role(StokvelRole.member, paidUp: false)),
  (name: 'Member · up to date', entry: _role(StokvelRole.member, paidUp: true)),
  (
    name: 'Member · unknown status',
    entry: _base.copyWith(cycleStatus: CycleStatus.fromApi('FutureStatus')),
  ),
  (
    name: 'Treasurer · closed cycle',
    entry: _role(
      StokvelRole.treasurer,
      paidUp: true,
    ).copyWith(cycleStatus: CycleStatus.closed),
  ),
  (
    name: 'Member · paid out cycle',
    entry: _role(
      StokvelRole.member,
      paidUp: true,
    ).copyWith(cycleStatus: CycleStatus.paidOut),
  ),
  (
    name: 'Member · no cycle or payout',
    entry: _base.copyWith(
      currentCycleNumber: null,
      cycleStatus: null,
      cycleDueDate: null,
      nextPayoutDateUtc: null,
    ),
  ),
  (
    name: 'Member · payment details unavailable',
    entry: _base.copyWith(
      cycleDueDate: null,
      paidThisCycle: null,
      stillOwed: null,
    ),
  ),
];

import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

void main() {
  test('maps cycle statuses and their labels', () {
    const examples = [
      ('Open', CycleStatus.open, 'Open'),
      ('Closed', CycleStatus.closed, 'Closed'),
      ('PaidOut', CycleStatus.paidOut, 'Paid out'),
      ('Reopened', CycleStatus.unknown, 'Unknown cycle status'),
      ('open', CycleStatus.unknown, 'Unknown cycle status'),
    ];

    for (final (wire, expected, label) in examples) {
      final status = CycleStatus.fromApi(wire);
      expect(status, expected, reason: wire);
      expect(status.label, label, reason: wire);
    }
  });

  test('maps contribution statuses and their labels', () {
    const examples = [
      ('Pending', ContributionStatus.pending, 'Pending'),
      ('Paid', ContributionStatus.paid, 'Paid'),
      ('Confirmed', ContributionStatus.confirmed, 'Confirmed'),
      ('PartPaid', ContributionStatus.unknown, 'Unknown contribution status'),
    ];

    for (final (wire, expected, label) in examples) {
      final status = ContributionStatus.fromApi(wire);
      expect(status, expected, reason: wire);
      expect(status.label, label, reason: wire);
    }
  });

  test('maps membership roles and their labels', () {
    const examples = [
      ('Member', StokvelRole.member, 'Member'),
      ('Treasurer', StokvelRole.treasurer, 'Treasurer'),
      ('Admin', StokvelRole.admin, 'Admin'),
      ('Auditor', StokvelRole.unknown, 'Unknown role'),
      ('member', StokvelRole.unknown, 'Unknown role'),
    ];

    for (final (wire, expected, label) in examples) {
      final role = StokvelRole.fromApi(wire);
      expect(role, expected, reason: wire);
      expect(role.label, label, reason: wire);
    }
  });

  test('Lerato has two stokvel roles under one login', () {
    const leratoHome = [
      HomeEntry(
        membership: Membership(
          stokvelId: 'family-savers',
          role: StokvelRole.treasurer,
        ),
        name: 'Family Savers',
        arrears: Cents(0),
        cycleStatus: CycleStatus.open,
      ),
      HomeEntry(
        membership: Membership(
          stokvelId: 'work-savers',
          role: StokvelRole.member,
        ),
        name: 'Work Savers',
        arrears: Cents(0),
        cycleStatus: CycleStatus.open,
      ),
    ];

    final family = leratoHome.singleWhere(
      (entry) => entry.membership.stokvelId == 'family-savers',
    );
    final work = leratoHome.singleWhere(
      (entry) => entry.membership.stokvelId == 'work-savers',
    );

    expect(family.membership.role, StokvelRole.treasurer);
    expect(work.membership.role, StokvelRole.member);

    expect(
      availableActions((
        family.membership.role,
        family.cycleStatus,
        ContributionStatus.confirmed,
      )),
      unorderedEquals([StokvelAction.uploadProof, StokvelAction.closeCycle]),
    );
    expect(
      availableActions((
        work.membership.role,
        work.cycleStatus,
        ContributionStatus.paid,
      )),
      unorderedEquals([StokvelAction.uploadProof]),
    );
  });

  group('availableActions', () {
    const member = StokvelRole.member;
    const treasurer = StokvelRole.treasurer;
    const admin = StokvelRole.admin;
    const open = CycleStatus.open;
    const closed = CycleStatus.closed;
    const pending = ContributionStatus.pending;
    const paid = ContributionStatus.paid;
    const confirmed = ContributionStatus.confirmed;
    const pay = StokvelAction.pay;
    const uploadProof = StokvelAction.uploadProof;
    const closeCycle = StokvelAction.closeCycle;
    const recordPayout = StokvelAction.recordPayout;

    const rules = <(String, StokvelActionContext, Set<StokvelAction>)>[
      ('unknown role', (StokvelRole.unknown, open, null), {}),
      ('missing cycle', (treasurer, null, null), {}),
      ('paid-out cycle', (admin, CycleStatus.paidOut, paid), {}),
      ('unknown cycle', (admin, CycleStatus.unknown, null), {}),
      (
        'unknown contribution status',
        (treasurer, open, ContributionStatus.unknown),
        {},
      ),
      ('closed Treasurer cycle', (treasurer, closed, confirmed), {}),
      ('closed Admin cycle', (admin, closed, null), {recordPayout}),
      ('Member without a contribution', (member, open, null), {pay}),
      ('Member with a contribution', (member, open, pending), {uploadProof}),
      (
        'Treasurer without a contribution',
        (treasurer, open, null),
        {pay, closeCycle},
      ),
      (
        'Treasurer with a contribution',
        (treasurer, open, confirmed),
        {uploadProof, closeCycle},
      ),
      (
        'Admin without a contribution',
        (admin, open, null),
        {pay, recordPayout},
      ),
      (
        'Admin with a contribution',
        (admin, open, paid),
        {uploadProof, recordPayout},
      ),
    ];

    for (final (name, context, expected) in rules) {
      test(name, () {
        expect(availableActions(context), unorderedEquals(expected));
      });
    }
  });
}

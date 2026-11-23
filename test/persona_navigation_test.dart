import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/features/activity/application/activity_provider.dart';
import 'package:ronditrack/features/activity/presentation/activity_screen.dart';
import 'package:ronditrack/features/auth/presentation/sign_in_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/fake_home_repository.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';
import 'package:ronditrack/features/invites/application/family_invite.dart';
import 'package:ronditrack/features/invites/application/invite_provider.dart';
import 'package:ronditrack/features/invites/presentation/invite_preview_screen.dart';
import 'package:ronditrack/features/payouts/application/payout_provider.dart';
import 'package:ronditrack/features/payouts/presentation/payouts_screen.dart';
import 'package:ronditrack/features/profile/presentation/profile_screen.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/data/fake_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_detail_screen.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvels_screen.dart';

const _family = '/stokvels/family-savers';
const _work = '/stokvels/work-savers';
const _familyCycle = '$_family/cycles/family-cycle-1';
const _familyPayouts = '$_familyCycle/payouts';
const _workPayouts = '$_work/cycles/work-cycle-1/payouts';
const _switcherLabel = 'Switch demo profile';

const _homeFixtures = FakeHomeRepository(delay: Duration.zero);
const _stokvelFixtures = FakeStokvelRepository(delay: Duration.zero);

const _personas = [
  (
    persona: DemoPersona.lerato,
    home: ['Family Savers', 'Work Savers'],
    familyRole: 'Treasurer',
    workRole: 'Member',
    familyPayouts: 'Next to be paid',
    workPayouts: 'No payout order yet.',
    familyReview: true,
  ),
  (
    persona: DemoPersona.nandi,
    home: ['Family Savers'],
    familyRole: 'Member',
    workRole: 'Not found',
    familyPayouts: 'Next to be paid',
    workPayouts: 'Not found',
    familyReview: false,
  ),
  (
    persona: DemoPersona.naledi,
    home: <String>[],
    familyRole: 'Not found',
    workRole: 'Not found',
    familyPayouts: 'Not found',
    workPayouts: 'Not found',
    familyReview: false,
  ),
];

@Dependencies([homeRepository, Home, payoutOrder, stokvelDetail, activityFeed, joinInvite, accountKey, FamilyInvite])
void main() {
  for (final scenario in _personas) {
    final persona = scenario.persona;

    testWidgets('${persona.name} sees the correct Home memberships', (
      tester,
    ) async {
      await _pumpSignedIn(tester, persona);

      expect(find.text('Signed in as ${persona.displayName}'), findsOneWidget);

      for (final name in ['Family Savers', 'Work Savers']) {
        expect(
          find.text(name),
          scenario.home.contains(name) ? findsOneWidget : findsNothing,
        );
      }

      if (scenario.home.isEmpty) {
        expect(find.text('You have no stokvels yet.'), findsOneWidget);
        expect(
          find.text('Ask a stokvel administrator to send you an invite.'),
          findsOneWidget,
        );
      }
    });

    testWidgets('${persona.name} sees stokvel actions for each membership', (
      tester,
    ) async {
      final router = await _pumpSignedIn(tester, persona);

      for (final (path, label) in [
        (_family, scenario.familyRole),
        (_work, scenario.workRole),
      ]) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(find.byType(StokvelDetailScreen), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(
          find.text('Close cycle'),
          label == 'Treasurer' ? findsOneWidget : findsNothing,
        );
      }
    });

    testWidgets('${persona.name} sees payouts for each membership', (
      tester,
    ) async {
      final router = await _pumpSignedIn(tester, persona);

      for (final (path, label, canReview) in [
        (_familyPayouts, scenario.familyPayouts, scenario.familyReview),
        (_workPayouts, scenario.workPayouts, false),
      ]) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(find.byType(PayoutsScreen), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(
          find.widgetWithText(OutlinedButton, 'Review payout'),
          canReview ? findsOneWidget : findsNothing,
        );
      }
    });
  }

  for (final flavor in [AppFlavor.staging, AppFlavor.prod]) {
    testWidgets('${flavor.name} omits the persona switcher', (tester) async {
      final router = await _pumpSignedIn(
        tester,
        DemoPersona.lerato,
        flavor: flavor,
      );

      for (final path in ['/', _family, '/profile']) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(
          find.byType(PopupMenuButton<DemoPersona>, skipOffstage: false),
          findsNothing,
        );
      }
    });
  }

  testWidgets('switching on an open stokvel clears the previous first frame', (
    tester,
  ) async {
    final nandiDetail = Completer<Stokvel?>();
    final repository = _StubStokvelRepository((userId, stokvelId) {
      if (userId == 'nandi' && stokvelId == 'family-savers') {
        return nandiDetail.future;
      }

      return _stokvelFixtures.fetchDetail(userId, stokvelId);
    });
    final router = await _pumpSignedIn(
      tester,
      DemoPersona.lerato,
      stokvelRepository: repository,
    );

    router.go(_family);
    await tester.pumpAndSettle();

    final detail = find.byType(StokvelDetailScreen);
    final leratoContribution = find.descendant(
      of: detail,
      matching: find.text('Lerato'),
    );

    expect(find.text('Close cycle'), findsOneWidget);
    expect(leratoContribution, findsOneWidget);

    await tester.tap(find.byTooltip(_switcherLabel));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<DemoPersona>, 'Nandi'),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(detail),
      listen: false,
    );

    expect(container.read(demoSessionProvider), DemoPersona.nandi);
    expect(router.routeInformationProvider.value.uri.path, _family);
    expect(find.text('Close cycle'), findsNothing);
    expect(leratoContribution, findsNothing);
    expect(
      find.descendant(
        of: detail,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    nandiDetail.complete(
      await _stokvelFixtures.fetchDetail('nandi', 'family-savers'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Close cycle'), findsNothing);

    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(demoSessionProvider), isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(find.byTooltip(_switcherLabel), findsNothing);

    router.go(_family);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(detail, findsNothing);
  });

  testWidgets('opens every address from the README route table', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [
          homeRepositoryProvider.overrideWithValue(_homeFixtures),
          stokvelRepositoryProvider.overrideWithValue(_stokvelFixtures),
        ],
        child: RondiTrackApp(config: _config(AppFlavor.dev)),
      ),
    );
    await tester.pumpAndSettle();

    final signIn = find.byType(SignInScreen);
    final router = GoRouter.of(tester.element(signIn));
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');

    await tester.enterText(find.byType(TextField), DemoPersona.lerato.email);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    for (final (address, screen) in const <(String, Type)>[
      ('/', HomeScreen),
      ('/stokvels', StokvelsScreen),
      (_family, StokvelDetailScreen),
      (_familyCycle, StokvelCycleScreen),
      (_familyPayouts, PayoutsScreen),
      ('/activity', ActivityScreen),
      ('/profile', ProfileScreen),
      ('/join/family-invite', InvitePreviewScreen),
    ]) {
      router.go(address);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, address);
      expect(find.byType(screen), findsOneWidget);
    }
  });
}

AppConfig _config(AppFlavor flavor) {
  return AppConfig.parse(
    nativeFlavor: flavor.name,
    configuredFlavor: flavor.name,
    apiBaseUrl: 'http://10.0.2.2:5227',
  );
}

void _setViewport(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(550, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

@Dependencies([homeRepository, Home, payoutOrder, stokvelDetail])
Future<GoRouter> _pumpSignedIn(
  WidgetTester tester,
  DemoPersona persona, {
  AppFlavor flavor = AppFlavor.dev,
  StokvelRepository stokvelRepository = _stokvelFixtures,
}) async {
  _setViewport(tester);

  await tester.pumpWidget(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [
        demoSessionProvider.overrideWithBuild((_, _) => persona),
        homeRepositoryProvider.overrideWithValue(_homeFixtures),
        stokvelRepositoryProvider.overrideWithValue(stokvelRepository),
      ],
      child: RondiTrackApp(config: _config(flavor)),
    ),
  );
  await tester.pumpAndSettle();

  return GoRouter.of(tester.element(find.byType(HomeScreen)));
}

final class _StubStokvelRepository implements StokvelRepository {
  const new(this._fetch);

  final Future<Stokvel?> Function(String userId, String stokvelId) _fetch;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) {
    return _fetch(userId, stokvelId);
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/features/home/data/api_home_repository.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/data/api_stokvel_repository.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

const _cursor = 'opaque+/cursor==';

void main() {
  test('Home JSON becomes membership roles and integer cents', () async {
    final adapter = _FixtureAdapter();
    final dio = _dio(adapter);

    final entries = _value(
      await ApiHomeRepository(dio).fetchHome('lerato'),
    );

    final family = entries.singleWhere(
      (entry) => entry.name == 'Family Savers',
    );
    final work = entries.singleWhere(
      (entry) => entry.name == 'Work Savers',
    );

    expect(family.membership.role, StokvelRole.treasurer);
    expect(work.membership.role, StokvelRole.member);
    expect(family.paidThisCycle?.value, 50000);
    expect(work.stillOwed?.value, 70000);
    expect(
      family.cycleDueDate,
      (year: 2026, month: 10, day: 31),
    );

    for (final entry in entries) {
      final instant = entry.nextPayoutDateUtc;

      if (instant != null) {
        expect(instant.isUtc, isTrue);
      }
    }
  });

  test('detail preserves versions, amounts, dates and pagination', () async {
    final adapter = _FixtureAdapter();
    final dio = _dio(adapter);

    final stokvel = _value(
      await ApiStokvelRepository(dio).fetchDetail(
        'fixture-user',
        _familyId(),
      ),
    );

    final rawStokvel = _object(_fixture('stokvel.json'));
    final rawCycle = _object(
      (_fixture('cycles.json') as List<Object?>).first,
    );

    expect(stokvel.membership.role, StokvelRole.treasurer);
    expect(stokvel.monthlyContribution.value, 50000);
    expect(stokvel.memberCount, 3);
    expect(stokvel.version, rawStokvel['version']);

    final cycle = stokvel.currentCycle!;

    expect(cycle.version, rawCycle['version']);
    expect(cycle.targetAmount.value, 150000);
    expect(cycle.totalCollected.value, rawCycle['totalCollectedInCents']);
    expect(cycle.amountOutstanding.value, rawCycle['amountDueInCents']);
    expect(cycle.dueDate, (year: 2026, month: 10, day: 31));
    expect(cycle.status, CycleStatus.open);

    expect(stokvel.contributions, isNotEmpty);

    for (final contribution in stokvel.contributions) {
      expect(contribution.userId, 'fixture-user');

      if (contribution.paidAtUtc != null) {
        expect(contribution.paidAtUtc!.isUtc, isTrue);
      }
    }

    final pages = adapter.requests.where(
      (request) => request.uri.path.endsWith('/contributions'),
    ).toList();

    expect(pages, hasLength(2));
    expect(pages.first.queryParameters['pageToken'], isNull);
    expect(pages.last.queryParameters['pageToken'], _cursor);
  });

  test('new role and status strings become unknown', () async {
    final adapter = _FixtureAdapter(unknownStatuses: true);
    final dio = _dio(adapter);

    final entries = _value(
      await ApiHomeRepository(dio).fetchHome('lerato'),
    );

    expect(
      entries.every(
        (entry) => entry.membership.role == StokvelRole.unknown,
      ),
      isTrue,
    );

    final stokvel = _value(
      await ApiStokvelRepository(dio).fetchDetail(
        'fixture-user',
        _familyId(),
      ),
    );

    expect(stokvel.membership.role, StokvelRole.unknown);
    expect(stokvel.currentCycle?.status, CycleStatus.unknown);
    expect(
      stokvel.contributions.every(
        (entry) => entry.status == ContributionStatus.unknown,
      ),
      isTrue,
    );
  });

  test('a detail 404 inside parallel calls stays NotFound', () async {
    final adapter = _FixtureAdapter(missingStokvel: true);
    final dio = _dio(adapter);

    final result = await ApiStokvelRepository(dio).fetchDetail(
      'fixture-user',
      _familyId(),
    );

    expect(
      result,
      isA<Err<Stokvel>>().having(
        (value) => value.failure,
        'failure',
        isA<NotFoundFailure>(),
      ),
    );

    expect(
      adapter.requests.where(
        (request) =>
            request.uri.path == '/api/v1/stokvels/${_familyId()}',
      ),
      hasLength(1),
    );
  });

  test('an unreadable successful response becomes ServerFailure', () async {
    final adapter = _FixtureAdapter(badHome: true);
    final dio = _dio(adapter);

    final result = await ApiHomeRepository(dio).fetchHome('lerato');

    expect(
      result,
      isA<Err<List<HomeEntry>>>().having(
        (value) => value.failure,
        'failure',
        isA<ServerFailure>(),
      ),
    );
  });
}

Dio _dio(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://fixture.invalid'),
  )..httpClientAdapter = adapter;

  addTearDown(() => dio.close(force: true));
  return dio;
}

T _value<T>(Result<T> result) {
  return switch (result) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => fail(
      'Unexpected ${failure.runtimeType}: ${failure.message}',
    ),
  };
}

Object? _fixture(String name) {
  final file = File('test/fixtures/api/$name');

  if (!file.existsSync()) {
    throw StateError(
      'Run tool/capture_api_fixtures.ps1 before repository tests.',
    );
  }

  return jsonDecode(file.readAsStringSync());
}

Map<String, Object?> _object(Object? value) {
  return value as Map<String, Object?>;
}

String _familyId() {
  final dashboard = _object(_fixture('home.json'));

  final family = (dashboard['stokvels']! as List<Object?>)
      .map(_object)
      .singleWhere((item) => item['name'] == 'Family Savers');

  return family['stokvelId']! as String;
}

final class _FixtureAdapter implements HttpClientAdapter {
  new({
    this.unknownStatuses = false,
    this.missingStokvel = false,
    this.badHome = false,
  });

  final bool unknownStatuses;
  final bool missingStokvel;
  final bool badHome;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);

    final root = '/api/v1/stokvels/${_familyId()}';
    final path = options.uri.path;
    var status = 200;
    Object? body;

    if (path == '/api/v1/me/home') {
      final dashboard = _object(_fixture('home.json'));

      if (badHome) {
        body = {'stokvels': 'invalid'};
      } else if (unknownStatuses) {
        body = {
          ...dashboard,
          'stokvels': [
            for (final item
                in dashboard['stokvels']! as List<Object?>)
              {
                ..._object(item),
                'role': 'FutureRole',
                'cycleStatus': 'FutureCycle',
              },
          ],
        };
      } else {
        body = dashboard;
      }
    } else if (path == root && !missingStokvel) {
      body = _fixture('stokvel.json');
    } else if (path == '$root/cycles') {
      final cycles = _fixture('cycles.json')! as List<Object?>;

      body = unknownStatuses
          ? [
              for (final item in cycles)
                {
                  ..._object(item),
                  'status': 'FutureCycle',
                },
            ]
          : cycles;
    } else if (path == '$root/members') {
      body = _fixture('members.json');
    } else if (path == '$root/contributions') {
      final page = _object(_fixture('contributions.json'));

      if (options.queryParameters['pageToken'] == null) {
        body = {
          ...page,
          'items': [
            for (final item in page['items']! as List<Object?>)
              {
                ..._object(item),
                if (unknownStatuses) 'status': 'FutureContribution',
              },
          ],
          'nextPageToken': _cursor,
        };
      } else {
        expect(options.queryParameters['pageToken'], _cursor);

        body = {
          'items': <Object?>[],
          'nextPageToken': '',
        };
      }
    } else {
      status = 404;
      body = {
        'status': 404,
        'correlationId': 'fixture-not-found',
      };
    }

    return Future.value(
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [
            status >= 400
                ? 'application/problem+json'
                : Headers.jsonContentType,
          ],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/dates/south_african_dates.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/money/data/exact_money_json.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/offline/data/cache_json.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

final class StokvelWorkflowApi {
  new(this._readDio);

  final Dio Function() _readDio;
  Future<void> _historyTail = Future<void>.value();

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, Object?>? query,
    String? body,
  }) async {
    try {
      final response = await _readDio().request<String>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );

      return decodeMoneyJson(response.data ?? '');
    } on Object catch (error) {
      throw mapFailure(error, isRead: method == 'GET');
    }
  }

  String _stockPath(String id) => '/api/v1/stokvels/${Uri.encodeComponent(id)}';

  Future<String> create(CreateStokvelDraft draft) async {
    final result = cacheObject(
      await _request(
        'POST',
        '/api/v1/stokvels',
        body: moneyJson(
          {
            'name': draft.name,
            'currentPeriod': draft.currentPeriod,
            'totalPeriods': draft.totalPeriods,
            'rules': draft.rules,
          },
          {'monthlyContribution': draft.monthlyContribution},
        ),
      ),
    );

    return result['id']! as String;
  }

  Future<EditableCycle> cycle(String id, String cycleId) async {
    final result = cacheObject(
      await _request(
        'GET',
        '${_stockPath(id)}/cycles/${Uri.encodeComponent(cycleId)}',
      ),
    );

    if (!_sameId(result['stokvelId'], id) || !_sameId(result['id'], cycleId)) {
      throw const FormatException('The cycle does not match its address.');
    }

    return _editable(result);
  }

  Future<EditableCycle> updateCycle(
    String id,
    String cycleId, {
    required int number,
    required Cents target,
    required int version,
  }) async {
    final result = cacheObject(
      await _request(
        'PUT',
        '${_stockPath(id)}/cycles/${Uri.encodeComponent(cycleId)}',
        body: moneyJson(
          {'cycleNumber': number, 'version': version},
          {'targetAmount': target},
        ),
      ),
    );

    if (!_sameId(result['stokvelId'], id) || !_sameId(result['id'], cycleId)) {
      throw const FormatException('The cycle does not match its address.');
    }

    return _editable(result);
  }

  Future<Stokvel> detail(String userId, String id) async {
    final json = cacheObject(await _request('GET', _stockPath(id)));

    if (!_sameId(json['id'], id)) {
      throw const FormatException('The stokvel does not match its address.');
    }

    final summary = json['currentCycle'] == null
        ? null
        : cacheObject(json['currentCycle']);

    ContributionCycle? current;
    final own = <Contribution>[];

    if (summary != null) {
      final cycleId = summary['id']! as String;
      final metadata = await cycle(id, cycleId);
      final target = _cents(summary['targetAmountInCents']);
      final number = summary['cycleNumber']! as int;

      current = ContributionCycle(
        id: cycleId,
        number: number,
        status: CycleStatus.fromApi(summary['status']! as String),
        targetAmount: target,
        totalCollected: _cents(summary['totalCollectedInCents']),
        amountOutstanding: _cents(summary['amountOutstandingInCents']),
        dueDate: _day(summary['dueDate']),
        version:
            metadata.number == number && metadata.target.value == target.value
            ? metadata.version
            : null,
      );

      String? token;
      final seen = <String>{};

      do {
        final page = await history(id, (
          cycleId: null,
          status: null,
          memberId: userId,
          days: null,
        ), token);

        own.addAll(page.items.where((item) => _sameId(item.cycleId, cycleId)));

        token = page.nextToken;

        if (own.isNotEmpty || token == null) {
          break;
        }

        if (!seen.add(token)) {
          throw const FormatException('The API repeated a cursor.');
        }
      } while (true);
    }

    return Stokvel(
      membership: Membership(
        stokvelId: id,
        role: StokvelRole.fromApi(json['role']! as String),
      ),
      name: json['name']! as String,
      monthlyContribution: _cents(json['monthlyContributionInCents']),
      memberCount: json['memberCount']! as int,
      currentPeriod: json['currentPeriod']! as int,
      totalPeriods: json['totalPeriods']! as int,
      rules: json['rules'] as String?,
      currentCycle: current,
      contributions: own,
    );
  }

  Future<HistoryPage> history(String id, HistoryFilter filter, String? token) {
    final completion = Completer<HistoryPage>();

    _historyTail = _historyTail.then((_) async {
      try {
        final selected = filter.days;

        final bounds = selected == null
            ? null
            : southAfricanDateRange(
                firstDay: selected.first,
                lastDay: selected.last,
              );

        final json = cacheObject(
          await _request(
            'GET',
            '${_stockPath(id)}/contributions',
            query: {
              'pageSize': 20,
              'pageToken': ?token,
              if (filter.memberId != null) 'member': filter.memberId,
              if (bounds != null)
                'from': bounds.fromInclusive.toIso8601String(),
              if (bounds != null) 'to': bounds.toExclusive.toIso8601String(),
            },
          ),
        );

        completion.complete(
          HistoryPage([
            for (final value in cacheList(json['items']))
              _contribution(cacheObject(value)),
          ], _next(json['nextPageToken'])),
        );
      } on Object catch (error, stack) {
        completion.completeError(error, stack);
      }
    });

    return completion.future;
  }

  Future<HistoryOptions> options(String id) async {
    final cycles = cacheList(await _request('GET', '${_stockPath(id)}/cycles'));

    final members = <({String id, String name})>[];
    String? token;
    final seen = <String>{};

    do {
      final page = cacheObject(
        await _request(
          'GET',
          '${_stockPath(id)}/members',
          query: {'pageSize': 20, 'pageToken': ?token},
        ),
      );

      for (final item in cacheList(page['items'])) {
        final member = cacheObject(item);

        members.add((
          id: member['id']! as String,
          name: member['fullName']! as String,
        ));
      }

      token = _next(page['nextPageToken']);

      if (token != null && !seen.add(token)) {
        throw const FormatException('The API repeated a cursor.');
      }
    } while (token != null);

    return (
      cycles: [
        for (final value in cycles)
          (
            id: cacheObject(value)['id']! as String,
            number: cacheObject(value)['cycleNumber']! as int,
          ),
      ],
      members: members,
    );
  }
}

EditableCycle _editable(Map<String, Object?> json) {
  final version = json['version'];

  if (version is! int || version <= 0) {
    throw const FormatException('Refresh this cycle before editing.');
  }

  return EditableCycle(
    id: json['id']! as String,
    number: json['cycleNumber']! as int,
    target: decimalCents(json['targetAmount']! as String),
    collected: _cents(json['totalCollectedInCents']),
    version: version,
    status: CycleStatus.fromApi(json['status']! as String),
    dueDate: _day(json['dueDate']),
  );
}

Contribution _contribution(Map<String, Object?> json) {
  return Contribution(
    id: json['id']! as String,
    cycleId: json['contributionCycleId']! as String,
    cycleNumber: json['cycleNumber']! as int,
    userId: json['userId']! as String,
    memberName: json['memberName']! as String,
    amount: _cents(json['amountInCents']),
    status: ContributionStatus.fromApi(json['status']! as String),
    paidAtUtc: cacheInstantFromJson(json['paidAtUtc']),
  );
}

Cents _cents(Object? value) {
  if (value is! int || value.abs() > 9_007_199_254_740_991) {
    throw const FormatException('Invalid integer cents.');
  }

  return Cents(value);
}

CalendarDate? _day(Object? value) {
  if (value == null) {
    return null;
  }

  final parts = (value as String).split('-').map(int.parse).toList();

  if (parts.length != 3) {
    throw const FormatException('Invalid calendar date.');
  }

  final date = DateTime.utc(parts[0], parts[1], parts[2]);

  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw const FormatException('Invalid calendar date.');
  }

  return (year: parts[0], month: parts[1], day: parts[2]);
}

String? _next(Object? value) {
  final token = value as String?;
  return token == null || token.isEmpty ? null : token;
}

bool _sameId(Object? value, String expected) {
  return value is String && value.toLowerCase() == expected.toLowerCase();
}

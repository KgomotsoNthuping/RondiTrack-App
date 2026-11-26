import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _port = 5899;
const _marker = 'ronditrack-performance-12.1';
const _owner = '11111111-1111-4111-8111-111111111111';
const _email = 'perf@example.invalid';
const _password = 'Performance-only-12.1';
const _cookie = 'performance_refresh_token';
const _manifestPath = 'performance-data/seed.json';

Future<void> main(List<String> arguments) async {
  try {
    final action = arguments.isEmpty ? '' : arguments.first;

    if (action == 'serve') {
      await _serve();
      return;
    }

    if (!['seed', 'update', 'cleanup'].contains(action)) {
      throw ArgumentError('Use serve, seed [count], update, or cleanup.');
    }

    final health = await _call('GET', '/__performance/health');

    if (health['fixture'] != _marker) {
      throw StateError('This is not the dedicated performance fixture API.');
    }

    final manifest = File(_manifestPath);

    if (action == 'seed') {
      if (await manifest.exists()) {
        throw StateError('A seed manifest exists. Clean up that run first.');
      }

      final count = arguments.length > 1 ? int.parse(arguments[1]) : 400;

      if (count < 300 || count > 1000) {
        throw ArgumentError(
          'Use between 300 and 1000 synthetic contributions.',
        );
      }

      final run = await _call('POST', '/__performance/runs', {'count': count});

      await manifest.parent.create(recursive: true);
      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert(run),
      );

      stdout.writeln('Created $count contributions. Manifest: $_manifestPath');
      return;
    }

    final saved =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;

    if (saved['fixture'] != _marker || saved['runId'] is! String) {
      throw const FormatException('Invalid performance seed manifest.');
    }

    final id = Uri.encodeComponent(saved['runId']! as String);

    if (action == 'update') {
      await _call('POST', '/__performance/runs/$id/change');

      stdout.writeln('Changed only the second contribution in this seed run.');
    } else {
      final result = await _call('DELETE', '/__performance/runs/$id', {
        'contributionIds': saved['contributionIds'],
      });

      if (result['deleted'] != true) {
        throw StateError('Cleanup was not confirmed.');
      }

      await manifest.delete();

      stdout.writeln(
        'Removed only the recorded run and its synthetic members.',
      );
    }
  } on Object catch (error) {
    stderr.writeln('Performance fixture: $error');
    exitCode = 1;
  }
}

Future<Map<String, dynamic>> _call(
  String method,
  String path, [
  Map<String, Object?>? body,
]) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$_port$path'),
    );

    request.headers.contentType = ContentType.json;

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();

    if (response.statusCode >= 400) {
      throw StateError('HTTP ${response.statusCode}: $text');
    }

    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

final class _Run {
  new(int count)
    : id = _id(),
      cycleId = _id(),
      rows = List.generate(
        count,
        (index) => <String, Object?>{
          'id': _id(),
          'userId': index == 0 ? _owner : _id(),
          'memberName': 'Performance Member $index',
          'cycleNumber': 1,
          'amountInCents': 10000,
          'status': ['Paid', 'Confirmed', 'Pending', 'FutureStatus'][index % 4],
          'paidAtUtc': DateTime.utc(
            2030,
            1,
            1,
            10,
          ).add(Duration(minutes: index)).toIso8601String(),
        },
      ) {
    for (final row in rows) {
      row['stokvelId'] = id;
      row['contributionCycleId'] = cycleId;
    }
  }

  final String id;
  final String cycleId;
  final List<Map<String, Object?>> rows;

  int get collected => rows
      .where((row) => ['Paid', 'Confirmed'].contains(row['status']))
      .fold(0, (total, row) => total + (row['amountInCents']! as int));

  Map<String, Object?> get manifest => {
    'fixture': _marker,
    'runId': id,
    'stokvelId': id,
    'count': rows.length,
    'contributionIds': rows.map((row) => row['id']).toList(),
  };

  Map<String, Object?> get summary => {
    'id': cycleId,
    'cycleNumber': 1,
    'status': 'Open',
    'targetAmountInCents': rows.length * 10000,
    'totalCollectedInCents': collected,
    'amountOutstandingInCents': rows.length * 10000 - collected,
    'dueDate': '2030-01-31',
  };
}

Future<void> _serve() async {
  final runs = <String, _Run>{};
  final tokens = <String>{};

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);

  stdout.writeln('Performance fixture API: http://localhost:$_port');
  stdout.writeln('Synthetic sign-in: $_email / $_password');

  await for (final request in server) {
    try {
      final response = request.response;
      final origin = request.headers.value('origin');

      if (!request.connectionInfo!.remoteAddress.isLoopback) {
        response.statusCode = 403;
        continue;
      }

      if (origin != null) {
        final host = Uri.parse(origin).host;

        if (host != 'localhost' &&
            InternetAddress.tryParse(host)?.isLoopback != true) {
          response.statusCode = 403;
          continue;
        }

        response.headers
          ..set('Access-Control-Allow-Origin', origin)
          ..set('Access-Control-Allow-Credentials', 'true')
          ..set(
            'Access-Control-Allow-Headers',
            'Authorization, Content-Type, Idempotency-Key',
          )
          ..set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
      }

      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        continue;
      }

      final path = request.uri.path;
      final method = request.method;
      final bodyText = await utf8.decoder.bind(request).join();

      final body = bodyText.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(bodyText) as Map<String, dynamic>;

      if (path == '/__performance/health') {
        _reply(response, {'fixture': _marker});
        continue;
      }

      if (path == '/__performance/runs' && method == 'POST') {
        if (runs.isNotEmpty) {
          throw StateError('Clean up the existing fixture run first.');
        }

        final count = body['count'];

        if (count is! int || count < 300 || count > 1000) {
          throw const FormatException('Invalid fixture size.');
        }

        final run = _Run(count);
        runs[run.id] = run;

        _reply(response, run.manifest);
        continue;
      }

      final control = RegExp(r'^/__performance/runs/([^/]+)(/change)?$')
          .firstMatch(path);

      if (control != null) {
        final run = runs[control[1]];

        if (run == null) {
          if (method == 'DELETE') {
            _reply(response, {'deleted': true, 'alreadyAbsent': true});
          } else {
            _reply(response, {'detail': 'Seed run not found.'}, 404);
          }

          continue;
        }

        if (method == 'POST' && control[2] == '/change') {
          final row = run.rows[1];

          row['amountInCents'] = row['amountInCents'] == 10000 ? 10500 : 10000;
          row['status'] = row['status'] == 'Paid' ? 'Confirmed' : 'Paid';

          _reply(response, {'changed': row['id']});
        } else if (method == 'DELETE' && control[2] == null) {
          final ids = (body['contributionIds'] as List<dynamic>).cast<String>();

          final expected = run.rows.map((row) => row['id']! as String).toSet();

          if (ids.length != expected.length ||
              ids.toSet().length != expected.length ||
              !expected.containsAll(ids)) {
            throw StateError('The cleanup manifest does not match this run.');
          }

          runs.remove(run.id);

          _reply(response, {'deleted': true, 'count': expected.length});
        } else {
          response.statusCode = 405;
        }

        continue;
      }

      if (path.startsWith('/api/v1/auth/')) {
        if (path.endsWith('/logout')) {
          response.headers.add(
            'Set-Cookie',
            '$_cookie=; Max-Age=0; Path=/api/v1/auth; '
                'HttpOnly; SameSite=Lax',
          );

          response.statusCode = 204;
          continue;
        }

        final login =
            path.endsWith('/login') &&
            body['email'] == _email &&
            body['password'] == _password;

        final refresh =
            path.endsWith('/refresh') &&
            request.cookies.any(
              (cookie) => cookie.name == _cookie && cookie.value == _marker,
            );

        if (!login && !refresh) {
          _reply(response, {'detail': 'Use the fixture credentials.'}, 401);
          continue;
        }

        final expires = DateTime.now().toUtc().add(const Duration(hours: 4));

        final header = _base64({'alg': 'none', 'typ': 'JWT'});

        final payload = _base64({
          'sub': _owner,
          'email': _email,
          'role': 'Member',
          'jti': _id(),
        });

        final token = '$header.$payload.fixture';
        tokens.add(token);

        response.headers.add(
          'Set-Cookie',
          '$_cookie=$_marker; Path=/api/v1/auth; '
              'HttpOnly; SameSite=Lax',
        );

        _reply(response, {
          'accessToken': token,
          'expiresAtUtc': expires.toIso8601String(),
        });
        continue;
      }

      final authorization = request.headers
          .value('authorization')
          ?.replaceFirst('Bearer ', '');

      if (!tokens.contains(authorization)) {
        _reply(response, {'detail': 'Sign in to the fixture.'}, 401);
        continue;
      }

      final run = runs.isEmpty ? null : runs.values.first;

      if (path == '/api/v1/me/home') {
        _reply(response, {
          'stokvels': [
            if (run != null)
              {
                'stokvelId': run.id,
                'name': 'Performance Savers',
                'role': 'Treasurer',
                'currentCycle': 1,
                'cycleStatus': 'Open',
                'cycleDueDate': '2030-01-31',
                'paidThisCycleInCents': 10000,
                'stillOwedInCents': 0,
                'arrearsInCents': 0,
                'nextPayoutDateUtc': null,
              },
          ],
        });
        continue;
      }

      if (run == null || !path.startsWith('/api/v1/stokvels/${run.id}')) {
        _reply(response, {'detail': 'Fixture not found.'}, 404);
        continue;
      }

      final stock = '/api/v1/stokvels/${run.id}';

      if (method != 'GET') {
        _reply(response, {
          'detail': 'This fixture is for list profiling.',
        }, 422);
      } else if (path == stock) {
        _reply(response, {
          'id': run.id,
          'name': 'Performance Savers',
          'role': 'Treasurer',
          'monthlyContributionInCents': 10000,
          'memberCount': run.rows.length,
          'currentPeriod': 1,
          'totalPeriods': 1,
          'currentCycle': run.summary,
          'rules': 'Synthetic performance data.',
        });
      } else if (path == '$stock/cycles') {
        _reply(response, [
          {'id': run.cycleId, 'cycleNumber': 1},
        ]);
      } else if (path == '$stock/cycles/${run.cycleId}') {
        _reply(response, {
          ...run.summary,
          'stokvelId': run.id,
          'targetAmount': run.rows.length * 100,
          'version': 1,
        });
      } else if (path == '$stock/members') {
        _reply(
          response,
          _page(request.uri, [
            for (final row in run.rows)
              {
                'id': row['userId'],
                'fullName': row['memberName'],
                'email': 'synthetic@example.invalid',
                'phoneNumber': '0000000000',
                'version': 1,
              },
          ]),
        );
      } else if (path == '$stock/contributions') {
        final query = request.uri.queryParameters;

        final from = query['from'] == null
            ? null
            : DateTime.parse(query['from']!);

        final to = query['to'] == null ? null : DateTime.parse(query['to']!);

        final rows = run.rows.where((row) {
          final paid = DateTime.parse(row['paidAtUtc']! as String);

          return (query['member'] == null ||
                  query['member'] == row['userId']) &&
              (from == null || !paid.isBefore(from)) &&
              (to == null || paid.isBefore(to));
        }).toList();

        _reply(response, _page(request.uri, rows));
      } else {
        _reply(response, {'detail': 'Fixture route not found.'}, 404);
      }
    } on Object catch (error) {
      _reply(request.response, {'detail': error.toString()}, 400);
    } finally {
      await request.response.close();
    }
  }
}

Map<String, Object?> _page(Uri uri, List<Map<String, Object?>> rows) {
  final requested = int.tryParse(uri.queryParameters['pageSize'] ?? '20') ?? 20;

  final size = requested.clamp(1, 100).toInt();

  final start = int.tryParse(uri.queryParameters['pageToken'] ?? '0') ?? 0;

  if (start < 0 || start > rows.length) {
    throw const FormatException('Invalid fixture cursor.');
  }

  final end = min(start + size, rows.length);

  return {
    'items': rows.sublist(start, end),
    'nextPageToken': end < rows.length ? '$end' : null,
  };
}

void _reply(HttpResponse response, Object value, [int status = 200]) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
}

String _base64(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _id() {
  final random = Random.secure();

  final bytes = List.generate(16, (_) => random.nextInt(256));

  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

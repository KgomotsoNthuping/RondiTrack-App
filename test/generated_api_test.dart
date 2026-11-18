import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/core/network/data/generated/export.dart';

void main() {
  test('generated Home client returns typed response fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'));
    dio.httpClientAdapter = _HomeAdapter();
    addTearDown(() => dio.close(force: true));

    final api = RondiTrackApi(dio);
    final response = await api.me.getApiV1MeHome();
    final entry = response.data.stokvels.single;

    expect(response.response.statusCode, 200);
    expect(entry.name, 'Family Savers');
    expect(entry.role, 'Treasurer');
    expect(entry.currentCycle, 1);
    expect(entry.cycleStatus, 'Open');
    expect(entry.paidThisCycleInCents, 50_000);
    expect(entry.stillOwedInCents, 0);
    expect(entry.arrearsInCents, 25);
  });
}

final class _HomeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.method, 'GET');
    expect(options.path, '/api/v1/me/home');

    return ResponseBody.fromString(
      jsonEncode({
        'stokvels': [
          {
            'stokvelId': '00000000-0000-0000-0000-000000000001',
            'name': 'Family Savers',
            'role': 'Treasurer',
            'currentCycle': 1,
            'cycleStatus': 'Open',
            'cycleDueDate': '2026-10-31',
            'paidThisCycleInCents': 50_000,
            'stillOwedInCents': 0,
            'nextPayoutDateUtc': '2026-11-30T00:00:00Z',
            'arrearsInCents': 25,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

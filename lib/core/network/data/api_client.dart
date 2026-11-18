import 'package:dio/dio.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/generated/rondi_track_api.dart';
import 'package:ronditrack/core/pagination/page.dart';

RondiTrackApi createApiClient(Dio dio) {
  if (!dio.interceptors.any((item) => item is _PageEndInterceptor)) {
    dio.interceptors.add(_PageEndInterceptor());
  }

  return RondiTrackApi(dio);
}

CalendarDate? apiDate(DateTime? value) {
  if (value == null) {
    return null;
  }

  return (year: value.year, month: value.month, day: value.day);
}

Cents apiRand(double value) {
  if (!value.isFinite || value.abs() * 100 > 9_007_199_254_740_991) {
    throw const FormatException('Invalid API amount.');
  }

  return Cents((value * 100).round());
}

String? apiNextPageToken(String? value) {
  return value == null || value.isEmpty ? null : value;
}

Future<List<T>> collectApiPages<T>(
  Future<Page<T>> Function(String? token) load,
) async {
  final items = <T>[];
  final seen = <String>{};
  String? token;

  do {
    final page = await load(token);
    items.addAll(page.items);
    token = page.nextPageToken;

    if (token != null && !seen.add(token)) {
      throw const FormatException('The API repeated a page token.');
    }
  } while (token != null);

  return List.unmodifiable(items);
}

final class _PageEndInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;

    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        data is Map<String, Object?> &&
        data['items'] is List<Object?> &&
        data['nextPageToken'] == null) {
      response.data = <String, Object?>{...data, 'nextPageToken': ''};
    }

    handler.next(response);
  }
}

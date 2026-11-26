import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/observability/error_reporter.dart';

Failure mapFailure(Object error, {required bool isRead}) {
  final failure = _mapFailure(error, isRead: isRead);
  Reporting.capture(failure, StackTrace.current);
  return failure;
}

Failure _mapFailure(Object error, {required bool isRead}) {
  if (error is OfflineFailure && !isRead) {
    return OfflineFailure(isRead: false, correlationId: error.correlationId);
  }

  if (error is Failure) {
    return error;
  }

  if (error is AsyncError) {
    return _mapFailure(error.error, isRead: isRead);
  }

  if (error is ParallelWaitError<Object?, Object?>) {
    final errors = error.errors;

    final nestedErrors = switch (errors) {
      Iterable<Object?>() => errors,
      (final first, final second) => <Object?>[first, second],
      _ => const <Object?>[],
    };

    Failure? firstFailure;

    for (final nestedError in nestedErrors) {
      if (nestedError == null) {
        continue;
      }

      final failure = _mapFailure(nestedError, isRead: isRead);

      if (failure is NotFoundFailure) {
        return failure;
      }

      firstFailure ??= failure;
    }

    return firstFailure ?? ServerFailure();
  }

  if (error is TimeoutException) {
    return OfflineFailure(isRead: isRead);
  }

  if (error is! DioException) {
    return ServerFailure();
  }

  final response = error.response;
  final status = response?.statusCode;

  if (status != null) {
    final problem = _problem(response?.data);
    final detail = _text(problem['detail']);
    final correlationId = responseCorrelationId(response);

    return switch (status) {
      400 => ValidationFailure(
        errors: _fieldErrors(problem['errors']),
        detail: detail,
        correlationId: correlationId,
      ),
      401 => UnauthorizedFailure(correlationId: correlationId),
      403 => ForbiddenFailure(detail: detail, correlationId: correlationId),
      404 => NotFoundFailure(correlationId: correlationId),
      409 => ConflictFailure(detail: detail, correlationId: correlationId),
      422 => RuleFailure(detail: detail, correlationId: correlationId),
      429 => RateLimitedFailure(
        retryAfterSeconds: _retryAfter(response),
        detail: detail,
        correlationId: correlationId,
      ),
      _ => ServerFailure(correlationId: correlationId),
    };
  }

  final method = error.requestOptions.method.toUpperCase();
  final retryableRead = isRead && (method == 'GET' || method == 'HEAD');
  final cause = error.error;

  if (cause is Failure) {
    return _mapFailure(cause, isRead: retryableRead);
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => OfflineFailure(isRead: retryableRead),
    DioExceptionType.cancel => const OfflineFailure(isRead: false),
    DioExceptionType.badCertificate ||
    DioExceptionType.badResponse ||
    DioExceptionType.unknown ||
    DioExceptionType.transformTimeout => ServerFailure(),
  };
}

String? responseCorrelationId(Response<dynamic>? response) {
  final problem = _problem(response?.data);

  for (final candidate in [
    _text(problem['correlationId']),
    _header(response, 'x-correlation-id'),
  ]) {
    if (candidate != null &&
        RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(candidate)) {
      return candidate;
    }
  }

  return null;
}

Map<String, Object?> _problem(Object? data) {
  var decoded = data;

  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return const {};
    }
  }

  if (decoded is! Map<Object?, Object?>) {
    return const {};
  }

  return {
    for (final MapEntry(key: key, value: value) in decoded.entries)
      if (key is String) key: value,
  };
}

Map<String, List<String>> _fieldErrors(Object? data) {
  if (data is! Map<Object?, Object?>) {
    return const {};
  }

  final result = <String, List<String>>{};

  for (final MapEntry(key: key, value: value) in data.entries) {
    if (key is! String || value is! List<Object?>) {
      continue;
    }

    result[key] = value
        .whereType<String>()
        .where((message) => message.trim().isNotEmpty)
        .toList();
  }

  return result;
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _header(Response<dynamic>? response, String name) {
  final values = response?.headers[name];

  if (values == null || values.isEmpty) {
    return null;
  }

  return _text(values.first);
}

int? _retryAfter(Response<dynamic>? response) {
  final seconds = int.tryParse(_header(response, 'retry-after') ?? '');

  return seconds != null && seconds >= 0 ? seconds : null;
}

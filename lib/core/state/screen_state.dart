import 'package:ronditrack/core/errors/failure.dart';

sealed class ScreenState<T> {
  const new();
}

final class ScreenLoading<T> extends ScreenState<T> {
  const new();
}

final class ScreenEmpty<T> extends ScreenState<T> {
  const new();
}

final class ScreenData<T> extends ScreenState<T> {
  const new(this.value);

  final T value;
}

final class ScreenFailure<T> extends ScreenState<T> {
  const new(
    this.message, {
    this.canRetry = true,
    this.correlationId,
    this.fields = const {},
    this.retryLabel = 'Retry',
  });

  final String message;
  final bool canRetry;
  final String? correlationId;
  final Map<String, List<String>> fields;
  final String retryLabel;
}

ScreenFailure<T> screenFailure<T>(Object error, {required String fallback}) {
  if (error is Failure) {
    return ScreenFailure(
      error.message,
      canRetry: error.canRetry,
      correlationId: error.correlationId,
      fields: error is ValidationFailure ? error.errors : const {},
      retryLabel: error is OfflineFailure ? 'Try again' : 'Retry',
    );
  }

  return ScreenFailure(fallback);
}

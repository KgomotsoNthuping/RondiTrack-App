import 'package:ronditrack/core/errors/failure.dart';

sealed class Result<T> {
  const new();
}

final class Ok<T> extends Result<T> {
  const new(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const new(this.failure);

  final Failure failure;
}
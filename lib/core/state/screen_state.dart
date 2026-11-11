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
  const new(this.message);

  final String message;
}

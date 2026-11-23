final class CachedValue<T> {
  const new({required this.value, required this.updatedAtUtc});

  final T value;
  final DateTime updatedAtUtc;
}

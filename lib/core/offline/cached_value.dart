final class CachedValue<T> {
  const CachedValue({required this.value, required this.updatedAtUtc});

  final T value;
  final DateTime updatedAtUtc;
}

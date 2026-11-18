final class Page<T> {
  new({required Iterable<T> items, required this.nextPageToken})
    : items = List.unmodifiable(items);

  final List<T> items;
  final String? nextPageToken;

  bool get hasMore => nextPageToken != null;
}

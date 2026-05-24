/// Generic paginated state for any list-based feature.
///
/// Tracks loaded items, current page, loading state, and whether
/// more data is available. Works with both offset-based and
/// cursor-based pagination.
class PaginatedState<T> {
  final List<T> items;
  final int page;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const PaginatedState({
    this.items = const [],
    this.page = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  /// Initial loading state.
  factory PaginatedState.loading() =>
      const PaginatedState(isLoading: true);

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get hasError => error != null;
  int get itemCount => items.length;

  PaginatedState<T> copyWith({
    List<T>? items,
    int? page,
    bool? isLoading,
    bool? hasMore,
    Object? Function()? error,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error != null ? error() : this.error,
    );
  }
}

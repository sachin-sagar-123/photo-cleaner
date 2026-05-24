import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paginated_state.dart';

/// Generic [StateNotifier] for paginated data loading.
///
/// Subclass and implement [fetchPage] to provide data from any source
/// (SQLite, API, etc.). Handles loading state, error recovery, and
/// deduplication of concurrent load requests.
///
/// Usage:
/// ```dart
/// class PhotoListNotifier extends PaginatedNotifier<PhotoAsset> {
///   final PhotoDao _dao;
///   PhotoListNotifier(this._dao) : super(pageSize: 50);
///
///   @override
///   Future<List<PhotoAsset>> fetchPage(int page, int pageSize) {
///     return _dao.getPhotos(limit: pageSize, offset: page * pageSize);
///   }
/// }
/// ```
abstract class PaginatedNotifier<T>
    extends StateNotifier<PaginatedState<T>> {
  final int pageSize;
  bool _initialized = false;

  PaginatedNotifier({this.pageSize = 50})
      : super(const PaginatedState());

  /// Implement to fetch a page of data.
  /// Return fewer than [pageSize] items to signal end of data.
  Future<List<T>> fetchPage(int page, int pageSize);

  /// Call from the subclass constructor or provider after all fields
  /// are initialized. Separated from the constructor to avoid calling
  /// [fetchPage] before the subclass is ready.
  void init() {
    if (!_initialized) {
      _initialized = true;
      loadFirstPage();
    }
  }

  /// Load the first page, resetting all state.
  Future<void> loadFirstPage() async {
    state = PaginatedState<T>(isLoading: true);
    try {
      final items = await fetchPage(0, pageSize);
      if (!mounted) return;
      state = PaginatedState<T>(
        items: items,
        page: 0,
        hasMore: items.length >= pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = PaginatedState<T>(error: e);
    }
  }

  /// Load the next page. No-op if already loading or no more data.
  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    final nextPage = state.page + 1;
    state = state.copyWith(isLoading: true, error: () => null);

    try {
      final newItems = await fetchPage(nextPage, pageSize);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...newItems],
        page: nextPage,
        isLoading: false,
        hasMore: newItems.length >= pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: () => e,
      );
    }
  }

  /// Refresh from the beginning (pull-to-refresh).
  Future<void> refresh() => loadFirstPage();
}

import 'package:flutter/material.dart';

import 'paginated_state.dart';

/// Reusable infinite-scroll grid that works with [PaginatedState].
///
/// Triggers [onLoadMore] when the user scrolls within [loadMoreThreshold]
/// of the bottom. Shows a loading indicator at the bottom while fetching.
class PaginatedGrid<T> extends StatelessWidget {
  final PaginatedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback? onRefresh;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets padding;
  final Widget? emptyWidget;
  final Widget? errorWidget;

  /// How many pixels from the bottom to trigger loading more.
  final double loadMoreThreshold;

  const PaginatedGrid({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 2,
    this.mainAxisSpacing = 2,
    this.childAspectRatio = 1.0,
    this.padding = const EdgeInsets.all(2),
    this.emptyWidget,
    this.errorWidget,
    this.loadMoreThreshold = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Initial loading
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error with no data
    if (state.hasError && state.items.isEmpty) {
      return errorWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                const Text('Failed to load', style: TextStyle(color: Colors.white54)),
                if (onRefresh != null)
                  TextButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          );
    }

    // Empty state
    if (state.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text('No items', style: TextStyle(color: Colors.white54)),
          );
    }

    // Total items + optional loading indicator at bottom
    final totalCount = state.items.length + (state.isLoading ? 1 : 0);

    final grid = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= state.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return itemBuilder(context, state.items[index], index);
              },
              childCount: totalCount,
            ),
          ),
        ),
      ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          if (maxScroll - currentScroll <= loadMoreThreshold) {
            onLoadMore();
          }
        }
        return false;
      },
      child: onRefresh != null
          ? RefreshIndicator(onRefresh: () async => onRefresh!(), child: grid)
          : grid,
    );
  }
}

/// Reusable infinite-scroll list variant.
class PaginatedList<T> extends StatelessWidget {
  final PaginatedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback? onRefresh;
  final EdgeInsets padding;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final double loadMoreThreshold;

  const PaginatedList({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.padding = EdgeInsets.zero,
    this.emptyWidget,
    this.errorWidget,
    this.separatorBuilder,
    this.loadMoreThreshold = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError && state.items.isEmpty) {
      return errorWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                const Text('Failed to load', style: TextStyle(color: Colors.white54)),
                if (onRefresh != null)
                  TextButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          );
    }

    if (state.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text('No items', style: TextStyle(color: Colors.white54)),
          );
    }

    final totalCount = state.items.length + (state.isLoading ? 1 : 0);

    final list = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= state.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final item = itemBuilder(context, state.items[index], index);
                if (separatorBuilder != null && index < state.items.length - 1) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [item, separatorBuilder!(context, index)],
                  );
                }
                return item;
              },
              childCount: totalCount,
            ),
          ),
        ),
      ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          if (maxScroll - currentScroll <= loadMoreThreshold) {
            onLoadMore();
          }
        }
        return false;
      },
      child: onRefresh != null
          ? RefreshIndicator(onRefresh: () async => onRefresh!(), child: list)
          : list,
    );
  }
}

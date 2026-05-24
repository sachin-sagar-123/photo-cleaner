import 'package:flutter/material.dart';

import 'paginated_state.dart';

/// Reusable infinite-scroll grid that works with [PaginatedState].
///
/// Triggers [onLoadMore] when the user scrolls within [loadMoreThreshold]
/// of the bottom. Shows a loading indicator below the grid while fetching.
class PaginatedGrid<T> extends StatefulWidget {
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
  State<PaginatedGrid<T>> createState() => _PaginatedGridState<T>();
}

class _PaginatedGridState<T> extends State<PaginatedGrid<T>> {
  bool _loadMoreTriggered = false;

  @override
  void didUpdateWidget(PaginatedGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset trigger when loading finishes so next scroll can fire again
    if (oldWidget.state.isLoading && !widget.state.isLoading) {
      _loadMoreTriggered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading
    if (widget.state.isLoading && widget.state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error with no data
    if (widget.state.hasError && widget.state.items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                const Text('Failed to load',
                    style: TextStyle(color: Colors.white54)),
                if (widget.onRefresh != null)
                  TextButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Retry')),
              ],
            ),
          );
    }

    // Empty state
    if (widget.state.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text('No items', style: TextStyle(color: Colors.white54)),
          );
    }

    final scrollView = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
              childAspectRatio: widget.childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  widget.itemBuilder(context, widget.state.items[index], index),
              childCount: widget.state.items.length,
            ),
          ),
        ),
        // Loading indicator as a separate sliver below the grid
        if (widget.state.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && !_loadMoreTriggered) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
            _loadMoreTriggered = true;
            widget.onLoadMore();
          }
        }
        return false;
      },
      child: widget.onRefresh != null
          ? RefreshIndicator(
              onRefresh: () async => widget.onRefresh!(),
              child: scrollView)
          : scrollView,
    );
  }
}

/// Reusable infinite-scroll list variant.
class PaginatedList<T> extends StatefulWidget {
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
  State<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<PaginatedList<T>> {
  bool _loadMoreTriggered = false;

  @override
  void didUpdateWidget(PaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.isLoading && !widget.state.isLoading) {
      _loadMoreTriggered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.isLoading && widget.state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.state.hasError && widget.state.items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                const Text('Failed to load',
                    style: TextStyle(color: Colors.white54)),
                if (widget.onRefresh != null)
                  TextButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Retry')),
              ],
            ),
          );
    }

    if (widget.state.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text('No items', style: TextStyle(color: Colors.white54)),
          );
    }

    final scrollView = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item =
                    widget.itemBuilder(context, widget.state.items[index], index);
                if (widget.separatorBuilder != null &&
                    index < widget.state.items.length - 1) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [item, widget.separatorBuilder!(context, index)],
                  );
                }
                return item;
              },
              childCount: widget.state.items.length,
            ),
          ),
        ),
        if (widget.state.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && !_loadMoreTriggered) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
            _loadMoreTriggered = true;
            widget.onLoadMore();
          }
        }
        return false;
      },
      child: widget.onRefresh != null
          ? RefreshIndicator(
              onRefresh: () async => widget.onRefresh!(),
              child: scrollView)
          : scrollView,
    );
  }
}

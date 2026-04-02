import 'package:flutter/material.dart';

class AutoPaginatedScroll extends StatelessWidget {
  const AutoPaginatedScroll({
    super.key,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.child,
    this.triggerExtent = 600,
  });

  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Widget child;
  final double triggerExtent;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) {
          return false;
        }
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        if (notification.metrics.extentAfter > triggerExtent) {
          return false;
        }
        if (!hasMore || isLoading || isLoadingMore) {
          return false;
        }
        onLoadMore();
        return false;
      },
      child: child,
    );
  }
}

class PaginatedLoadMoreIndicator extends StatelessWidget {
  const PaginatedLoadMoreIndicator({
    super.key,
    required this.show,
    this.topPadding = 12,
  });

  final bool show;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class PaginatedLoadMoreSliverIndicator extends StatelessWidget {
  const PaginatedLoadMoreSliverIndicator({
    super.key,
    required this.show,
    this.topPadding = 8,
  });

  final bool show;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: PaginatedLoadMoreIndicator(
        show: true,
        topPadding: topPadding,
      ),
    );
  }
}

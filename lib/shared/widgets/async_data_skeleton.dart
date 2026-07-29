import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AsyncRefreshStrip extends StatelessWidget {
  const AsyncRefreshStrip({
    super.key,
    required this.isRefreshing,
  });

  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('async-refresh-strip'),
      height: 2,
      child: AnimatedOpacity(
        opacity: isRefreshing ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: ExcludeSemantics(
          excluding: !isRefreshing,
          child: const LinearProgressIndicator(minHeight: 2),
        ),
      ),
    );
  }
}

class AsyncDataSkeleton extends StatelessWidget {
  const AsyncDataSkeleton({
    super.key,
    this.rowCount = 5,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  final int rowCount;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: rowCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          key: const ValueKey('async-skeleton-row'),
          height: 72,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.border),
          ),
          child: const Row(
            children: [
              Bone.circle(size: 44),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 15),
                    SizedBox(height: 8),
                    Bone.text(words: 4, fontSize: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

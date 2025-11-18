import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';

class PocketsGridSection extends ConsumerWidget {
  const PocketsGridSection({
    super.key,
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
  });

  final PocketsScopeParams scopeParams;
  final shadcnui.ColorScheme colorScheme;
  final bool isPersonalMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);

    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: SizedBox(
            height: 32,
            width: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
        ),
      );
    }

    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          state.error!,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.destructive,
          ),
        ),
      );
    }

    final title = isPersonalMode ? 'My pockets' : 'Household pockets';
    final totalBudget = state.totalBudget;
    final totalSpent = state.totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 12),
        _PocketsHeaderCard(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          colorScheme: colorScheme,
          onTotalChanged: notifier.updateTotalBudget,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.60,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: state.editing.length + 1,
          itemBuilder: (context, index) {
            final isAddTile = index == state.editing.length;
            if (isAddTile) {
              return _AddEnvelopeCard(
                colorScheme: colorScheme,
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) {
                      return EditPocketEnvelopeSheet(
                        scopeParams: scopeParams,
                      );
                    },
                  );
                },
              );
            }

            final pocket = state.editing[index];
            return _PocketCard(
              pocket: pocket,
              colorScheme: colorScheme,
              maxBudget: totalBudget > 0 ? totalBudget : pocket.limit,
              onLimitChanged: (value) =>
                  notifier.updatePocketLimit(pocket.id, value),
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (sheetContext) {
                    return EditPocketEnvelopeSheet(
                      scopeParams: scopeParams,
                      existingEnvelope: pocket,
                    );
                  },
                );
              },
            );
          },
        ),
        if (state.hasChanges) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: notifier.revertChanges,
                  child: const Text('Revert'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: shadcnui.PrimaryButton(
                  onPressed: notifier.saveChanges,
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PocketsHeaderCard extends StatelessWidget {
  const _PocketsHeaderCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.colorScheme,
    required this.onTotalChanged,
  });

  final double totalBudget;
  final double totalSpent;
  final shadcnui.ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0;
    final sliderMin = 100.0;
    final sliderMax = 5000.0;
    final sliderValue =
        effectiveBudget.clamp(sliderMin, sliderMax).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total monthly budget',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                effectiveBudget.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total spent: ${totalSpent.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              color: totalSpent > effectiveBudget
                  ? colorScheme.destructive
                  : colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Adjust total limit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
          Slider(
            value: sliderValue,
            min: sliderMin,
            max: sliderMax,
            activeColor: colorScheme.primary,
            onChanged: onTotalChanged,
          ),
          Text(
            'Changing this scales all pockets proportionally.',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.mutedForeground,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEnvelopeCard extends StatelessWidget {
  const _AddEnvelopeCard({
    required this.colorScheme,
    required this.onTap,
  });

  final shadcnui.ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colorScheme.border.withValues(alpha: 0.8),
          radius: 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.card.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              color: colorScheme.mutedForeground,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final path = Path()..addRRect(rect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final double dashEnd = (distance + dashWidth).clamp(0.0, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, dashEnd),
          Offset.zero,
        );
        distance = dashEnd + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _PocketCard extends StatelessWidget {
  const _PocketCard({
    required this.pocket,
    required this.colorScheme,
    required this.maxBudget,
    required this.onLimitChanged,
    this.onTap,
  });

  final PocketEnvelope pocket;
  final shadcnui.ColorScheme colorScheme;
  final double maxBudget;
  final ValueChanged<double> onLimitChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final safeColor = colorScheme.primary;
    final statusColor = pocket.statusColor(safeColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              color:
                                  colorScheme.muted.withValues(alpha: 0.04),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: pocket.progress,
                              ),
                              duration:
                                  const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Container(
                                  height: constraints.maxHeight * value,
                                  width: constraints.maxWidth,
                                  color: statusColor.withOpacity(0.3),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            color: colorScheme.mutedForeground,
                            size: 18,
                          ),
                          if (pocket.isOverBudget)
                            Icon(
                              Icons.error,
                              color: colorScheme.destructive,
                              size: 18,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        pocket.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pocket.spent.toInt()} / ${pocket.limit.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: pocket.isOverBudget
                              ? colorScheme.destructive
                              : colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: pocket.limit
                            .clamp(0, maxBudget > 0 ? maxBudget : pocket.limit)
                            .toDouble(),
                        min: 0,
                        max: maxBudget > 0 ? maxBudget : pocket.limit,
                        activeColor: statusColor,
                        onChanged: onLimitChanged,
                      ),
                    ),
                  ),
                  Text(
                    'Adjust portion',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    )
    );
  }
}

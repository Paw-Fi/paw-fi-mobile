import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for defaultTargetPlatform
import 'spotlight_step.dart';
import 'spotlight_controller.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class SpotlightTourOverlay extends StatefulWidget {
  final SpotlightTourController controller;
  final List<SpotlightStep> steps;

  const SpotlightTourOverlay({
    Key? key,
    required this.controller,
    required this.steps,
  }) : super(key: key);

  @override
  State<SpotlightTourOverlay> createState() => _SpotlightTourOverlayState();
}

class _SpotlightTourOverlayState extends State<SpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  Rect? _targetRect;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.currentStepNotifier.value;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Initial calculation after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _updateTargetRect() {
    if (!mounted || _currentIndex >= widget.steps.length) return;

    final rect = _calculateTargetRect(_currentIndex);

    setState(() {
      _targetRect = rect;
    });
  }

  Rect? _calculateTargetRect(int index) {
    if (index >= widget.steps.length) return null;
    final step = widget.steps[index];
    final key = step.targetKey;
    final context = key.currentContext;
    if (context != null) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        final pos = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        final padding = step.padding;

        if (step.id == 'pockets_budget_header') {
          debugPrint(
              '🟣 Pockets spotlight: target size=${size.width}x${size.height} at ${pos.dx},${pos.dy}, padding=$padding');
        }

        // For the home unified FAB, the GlobalKey is attached to the
        // entire ExpandableFab, which reserves extra invisible space
        // for the expanding action buttons. Visually, however, we only
        // want to highlight the bottom-right primary FAB circle with
        // an optional halo defined by [padding].
        if (step.id == 'home_unified_fab') {
          const fabSize = 56.0;
          final anchorRect = Rect.fromLTWH(
            pos.dx + size.width - fabSize,
            pos.dy + size.height - fabSize,
            fabSize,
            fabSize,
          );

          if (padding <= 0) {
            return anchorRect;
          }

          return Rect.fromLTWH(
            anchorRect.left - padding,
            anchorRect.top - padding,
            anchorRect.width + padding * 2,
            anchorRect.height + padding * 2,
          );
        }

        // Default behavior: expand the widget's rect by the configured
        // padding to create a subtle halo around the component.
        final rect = Rect.fromLTWH(
          pos.dx - padding,
          pos.dy - padding,
          size.width + padding * 2,
          size.height + padding * 2,
        );

        if (step.id == 'pockets_budget_header') {
          debugPrint('🟣 Pockets spotlight: computed rect=$rect');
        }

        return rect;
      }
    }

    if (step.id == 'pockets_budget_header') {
      debugPrint(
          '🟣 Pockets spotlight: target context or renderBox not ready yet');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.currentStepNotifier,
      builder: (context, index, child) {
        if (index != _currentIndex) {
          _currentIndex = index;
          // When step changes, scroll and recalculate
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTargetRect();
          });
        }

        final currentStep =
            widget.steps.isNotEmpty && _currentIndex < widget.steps.length
                ? widget.steps[_currentIndex]
                : null;

        if (currentStep == null) return const SizedBox.shrink();

        // If we still don't have a valid target rect (e.g. because the
        // target widget was not laid out yet when the tour started),
        // schedule another rect calculation on the next frame. This is
        // especially important for deeply nested widgets like the
        // Pockets header card, which may become ready slightly later
        // than the initial overlay insert.
        if (_targetRect == null || _targetRect!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTargetRect();
            }
          });
        }

        // Use the cached rect calculated when the step became active.
        // If it is still null (e.g. target not found), fall back to a
        // centered rect so the tooltip has a stable position.
        final targetRect = _targetRect ??
            Rect.fromLTWH(
              MediaQuery.of(context).size.width / 2 - 40,
              MediaQuery.of(context).size.height / 2 - 40,
              80,
              80,
            );

        return Stack(
          children: [
            // 1. Dimmed Background with Hole
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _SpotlightPainter(
                rect: targetRect,
                borderRadius: currentStep.borderRadius,
                color: Colors.black.withValues(alpha: 0.7), // Scrim color
              ),
            ),

            // 2. Tooltip Card
            Positioned.fill(
              child: _buildTooltip(context, currentStep, targetRect),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltip(
      BuildContext context, SpotlightStep step, Rect targetRect) {
    // Position the tooltip relative to the highlighted rect, using
    // SpotlightPlacement to choose the side (top/bottom/left/right).

    const screenPadding = EdgeInsets.all(16.0);

    return CustomSingleChildLayout(
      delegate: _TooltipPositionDelegate(
        targetRect: targetRect,
        placement: step.placement,
        screenPadding: screenPadding,
      ),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _SpotlightCard(
            step: step,
            onNext: widget.controller.next,
            onSkip: widget.controller.skip,
            isLast: _currentIndex == widget.steps.length - 1,
            currentIndex: _currentIndex,
            totalSteps: widget.steps.length,
          ),
        ),
      ),
    );
  }
}

class _TooltipPositionDelegate extends SingleChildLayoutDelegate {
  final Rect targetRect;
  final SpotlightPlacement placement;
  final EdgeInsets screenPadding;

  const _TooltipPositionDelegate({
    required this.targetRect,
    required this.placement,
    required this.screenPadding,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth =
        (constraints.maxWidth - screenPadding.horizontal).clamp(0.0, 400.0);
    return BoxConstraints(maxWidth: maxWidth);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = 16.0;

    double dx;
    double dy;

    switch (placement) {
      case SpotlightPlacement.top:
        // Tooltip above the target.
        dy = targetRect.top - gap - childSize.height;
        dx = targetRect.center.dx - childSize.width / 2;
        break;
      case SpotlightPlacement.bottom:
        // Tooltip below the target.
        dy = targetRect.bottom + gap;
        dx = targetRect.center.dx - childSize.width / 2;
        break;
      case SpotlightPlacement.left:
        // Tooltip to the left of the target.
        dx = targetRect.left - gap - childSize.width;
        dy = targetRect.center.dy - childSize.height / 2;
        break;
      case SpotlightPlacement.right:
        // Tooltip to the right of the target.
        dx = targetRect.right + gap;
        dy = targetRect.center.dy - childSize.height / 2;
        break;
      case SpotlightPlacement.center:
        // Center on screen.
        dx = (size.width - childSize.width) / 2;
        dy = (size.height - childSize.height) / 2;
        break;
    }

    // Clamp horizontally within the padded viewport.
    if (dx < screenPadding.left) {
      dx = screenPadding.left;
    } else if (dx + childSize.width > size.width - screenPadding.right) {
      dx = size.width - screenPadding.right - childSize.width;
    }

    // Clamp vertically within the padded viewport.
    if (dy < screenPadding.top) {
      dy = screenPadding.top;
    } else if (dy + childSize.height > size.height - screenPadding.bottom) {
      dy = size.height - screenPadding.bottom - childSize.height;
    }

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _TooltipPositionDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.placement != placement ||
        oldDelegate.screenPadding != screenPadding;
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final double borderRadius;

  _SpotlightPainter({
    required this.rect,
    required this.color,
    this.borderRadius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // layer for the scrim
    final paint = Paint()..color = color;

    // Create a path that covers the whole screen
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create the cutout path
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          rect, Radius.circular(borderRadius))); // Rounded cutout

    // Combine them with difference
    final path =
        Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _SpotlightCard extends StatelessWidget {
  final SpotlightStep step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;
  final int currentIndex;
  final int totalSteps;

  const _SpotlightCard({
    Key? key,
    required this.step,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
    required this.currentIndex,
    required this.totalSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: isIOS
                ? TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    fontFamily: '.SF Pro Display',
                    color: colorScheme.foreground,
                  )
                : theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: isIOS
                ? TextStyle(
                    fontSize: 16,
                    color: colorScheme.mutedForeground,
                    height: 1.4,
                    fontFamily: '.SF Pro Text')
                : theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: colorScheme.mutedForeground,
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip Button
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.mutedForeground,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  context.l10n.skip,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              // Step indicators (centered dots)
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(totalSteps, (index) {
                      final isActive = index == currentIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 8 : 6,
                        height: isActive ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Next/Done Button
              if (isIOS)
                CupertinoButton(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  // ignore: deprecated_member_use
                  minSize: 0,
                  onPressed: onNext,
                  child: Text(
                    isLast ? context.l10n.done : context.l10n.next,
                    style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                )
              else
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(isLast ? context.l10n.done : context.l10n.next),
                ),
            ],
          )
        ],
      ),
    );
  }
}

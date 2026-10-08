import 'dart:math' as math;
import 'dart:ui' as ui show BlurStyle, lerpDouble;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
import 'package:moneko/features/home/presentation/constants/budget_companion_messages.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:moneko/shared/widgets/atmospheric_header_lines.dart';
import 'package:skeletonizer/skeletonizer.dart';

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

/// Page header shared by Personal, Private and Shared dashboards.
class DashboardBudgetHeader extends StatelessWidget {
  const DashboardBudgetHeader({
    super.key,
    required this.summary,
    required this.currency,
    required this.mode,
    required this.onBudgetTap,
    required this.onRetry,
    this.isRefreshing = false,
    this.onAddTap,
    this.onTransferTap,
    this.onInsightsTap,
  });

  final AsyncValue<BudgetCompanionSummary> summary;
  final String currency;
  final HomePeriodMode mode;
  final VoidCallback onBudgetTap;
  final VoidCallback onRetry;
  final bool isRefreshing;
  final VoidCallback? onAddTap;
  final VoidCallback? onTransferTap;
  final VoidCallback? onInsightsTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = summary.valueOrNull;

    final accent =
        switch (value?.reaction ?? BudgetCompanionReaction.planning) {
      BudgetCompanionReaction.happy => colors.success,
      BudgetCompanionReaction.encouraging => colors.info,
      BudgetCompanionReaction.concerned => colors.warning,
      BudgetCompanionReaction.overBudget => colors.destructive,
      BudgetCompanionReaction.planning => colors.info,
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AsyncRefreshStrip(isRefreshing: isRefreshing),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: _motion(context),
          child: value != null
              ? _SummaryValues(
                  key: const ValueKey('dashboard-budget-header-content'),
                  summary: value,
                  currency: currency,
                  mode: mode,
                  accent: accent,
                  onBudgetTap: onBudgetTap,
                  onAddTap: onAddTap,
                  onTransferTap: onTransferTap,
                  onInsightsTap: onInsightsTap,
                )
              : summary.hasError
                  ? _HeaderError(
                      key: const ValueKey('dashboard-budget-header-error'),
                      onRetry: onRetry)
                  : const DashboardBudgetHeaderSkeleton(
                      key: ValueKey('dashboard-budget-header-loading')),
        ),
      ],
    );
    // The header belongs to the page background, without a card surface,
    // border, shadow or rounded container around the mascot and gauge.
    return Padding(
      key: const ValueKey('dashboard-budget-header'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              duration: _motion(context),
              alignment: Alignment.topCenter,
              child: content),
    );
  }
}

String _resolveMascotAsset({
  required bool hasBudget,
  required double? progress,
}) {
  if (!hasBudget || progress == null) {
    return 'lib/assets/mascots/cat-pecentage-0-50.png';
  }
  final percent = (progress * 100).round();
  if (percent <= 50) {
    return 'lib/assets/mascots/cat-pecentage-0-50.png';
  } else if (percent <= 75) {
    return 'lib/assets/mascots/cat-pecentage-50-75.png';
  } else if (percent < 100) {
    return 'lib/assets/mascots/cat-pecentage-75-99.png';
  } else {
    return 'lib/assets/mascots/cat-pecentage-overlimit.png';
  }
}

class _SummaryValues extends StatelessWidget {
  const _SummaryValues({
    super.key,
    required this.summary,
    required this.currency,
    required this.mode,
    required this.accent,
    required this.onBudgetTap,
    this.onAddTap,
    this.onTransferTap,
    this.onInsightsTap,
  });

  final BudgetCompanionSummary summary;
  final String currency;
  final HomePeriodMode mode;
  final Color accent;
  final VoidCallback onBudgetTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onTransferTap;
  final VoidCallback? onInsightsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = summary.remaining;
    final amount = formatCurrency(summary.spent, currency, context: context);
    final foreground = switch (summary.reaction) {
      BudgetCompanionReaction.happy => colors.budgetSuccessForeground,
      BudgetCompanionReaction.concerned => colors.budgetWarningForeground,
      BudgetCompanionReaction.overBudget => colors.budgetDangerForeground,
      _ => colors.budgetInfoForeground,
    };
    final mascotAsset = _resolveMascotAsset(
      hasBudget: summary.hasBudget,
      progress: summary.progress,
    );

    // Daily mode never carries a monthly budget, so it keeps the compact
    // spent-today header instead of a permanently-disabled gauge.
    if (mode == HomePeriodMode.daily) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimatedMascot(
                asset: mascotAsset,
                width: 80,
                height: 40,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _CompanionChatBubble(
                  reaction: summary.reaction,
                  foreground: foreground,
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.budgetCompanionSpentThisDay,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // An unset budget keeps the same gauge silhouette, dimmed, so the section
    // reads as unavailable instead of disappearing entirely.
    final hasBudget = summary.hasBudget;

    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth;
      final gaugeWidth = 210.0.clamp(180.0, cardWidth - 24.0);
      const strokeWidth = 18.0;
      final gaugeHeight = (gaugeWidth + strokeWidth) / 2;
      const catWidth = 96.0;
      const catHeight = 58.0;
      const topClearance = 44.0;
      final totalGaugeSectionHeight = gaugeHeight + topClearance;

      final gaugeAccent = switch (summary.reaction) {
        BudgetCompanionReaction.happy => colors.budgetGaugeSuccess,
        BudgetCompanionReaction.concerned => colors.budgetGaugeWarning,
        BudgetCompanionReaction.overBudget => colors.budgetGaugeDanger,
        _ => colors.budgetGaugeInfo,
      };
      final gaugeColor = hasBudget ? gaugeAccent : colors.mutedForeground;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: cardWidth,
            height: totalGaugeSectionHeight,
            child: _BudgetHeroStage(
              progress: hasBudget ? summary.progress! : null,
              reaction: summary.reaction,
              mascotAsset: mascotAsset,
              gaugeColor: gaugeColor,
              accent: accent,
              foreground: foreground,
              cardWidth: cardWidth,
              gaugeWidth: gaugeWidth,
              strokeWidth: strokeWidth,
              catWidth: catWidth,
              catHeight: catHeight,
              topClearance: topClearance,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '${context.l10n.spent}: $amount',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      amount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.foreground,
                      ),
                    ),
                    if (hasBudget) ...[
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.budgetCompanionSpentOf(formatCurrency(
                            summary.budget!, currency,
                            context: context)),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBudget
                ? (remaining! < 0
                    ? context.l10n.budgetCompanionOver(formatCurrency(
                        remaining.abs(), currency, context: context))
                    : context.l10n.budgetCompanionLeft(
                        formatCurrency(remaining, currency, context: context)))
                : context.l10n.budgetCompanionNoBudget,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: hasBudget && remaining! < 0
                  ? colors.budgetDangerForeground
                  : hasBudget
                      ? colors.budgetInfoForeground
                      : colors.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!hasBudget) ...[
            const SizedBox(height: 8),
            AdaptiveButton(
              label: context.l10n.setBudget,
              style: AdaptiveButtonStyle.plain,
              useNative: false,
              padding: EdgeInsets.zero,
              onPressed: onBudgetTap,
            ),
          ],
        ],
      );
    });
  }
}

/// Choreographs the hero section as one timeline: the gauge rests at 0% for a
/// beat, counts up to the real percentage, the mascot pops in while the gauge
/// is still filling, and the speech bubble reacts last. Later summary changes
/// settle the gauge from its displayed value instead of replaying the intro.
class _BudgetHeroStage extends StatefulWidget {
  const _BudgetHeroStage({
    required this.progress,
    required this.reaction,
    required this.mascotAsset,
    required this.gaugeColor,
    required this.accent,
    required this.foreground,
    required this.cardWidth,
    required this.gaugeWidth,
    required this.strokeWidth,
    required this.catWidth,
    required this.catHeight,
    required this.topClearance,
  });

  /// Unclamped spent/budget ratio; null when no budget is set.
  final double? progress;
  final BudgetCompanionReaction reaction;
  final String mascotAsset;
  final Color gaugeColor;
  final Color accent;
  final Color foreground;
  final double cardWidth;
  final double gaugeWidth;
  final double strokeWidth;
  final double catWidth;
  final double catHeight;
  final double topClearance;

  @override
  State<_BudgetHeroStage> createState() => _BudgetHeroStageState();
}

class _BudgetHeroStageState extends State<_BudgetHeroStage>
    with TickerProviderStateMixin {
  // Intro timeline (2000ms): hold 0% → fill → mascot pop → bubble pop.
  static const _introDuration = Duration(milliseconds: 2000);
  static const _settleDuration = Duration(milliseconds: 700);
  static const _gaugeInterval =
      Interval(0.25, 0.85, curve: Curves.easeInOutCubic);
  static const _mascotInterval = Interval(0.64, 0.92);
  static const _bubbleInterval = Interval(0.84, 1.0);
  // Back-out springs: overshoot slightly past rest, then settle.
  static const _mascotSpring = Cubic(0.34, 1.56, 0.64, 1.0);
  static const _bubbleSpring = Cubic(0.34, 1.42, 0.64, 1.0);

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: _introDuration);
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: _settleDuration);
  late final CurvedAnimation _gaugeFill =
      CurvedAnimation(parent: _intro, curve: _gaugeInterval);
  late final CurvedAnimation _mascotEntrance =
      CurvedAnimation(parent: _intro, curve: _mascotInterval);
  late final CurvedAnimation _bubbleEntrance =
      CurvedAnimation(parent: _intro, curve: _bubbleInterval);
  late final CurvedAnimation _settleCurve =
      CurvedAnimation(parent: _settle, curve: Curves.easeInOutCubic);

  double _introFrom = 0;
  late double _introTo = _target;
  Tween<double>? _settleTween;

  double get _target => widget.progress ?? 0;

  /// Unclamped percentage currently on screen; the arc clamps it to 0–1.
  double get _displayed {
    final tween = _settleTween;
    if (tween != null) return tween.evaluate(_settleCurve);
    return ui.lerpDouble(_introFrom, _introTo, _gaugeFill.value)!;
  }

  @override
  void initState() {
    super.initState();
    // This stage only mounts once a summary has resolved, so the timeline
    // starts exactly when valid data is available.
    _intro.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_intro.isCompleted) {
      _intro.value = 1;
    }
  }

  @override
  void didUpdateWidget(_BudgetHeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) _retarget(_target);
  }

  void _retarget(double target) {
    final shown = _displayed;
    final fill = _gaugeFill.value;
    if (_settleTween == null && fill < 0.98) {
      // Re-aim the running intro so lerp(from, to, fill) still equals what is
      // on screen right now and the remaining fill lands on the new target.
      _introTo = target;
      _introFrom = (shown - fill * target) / (1 - fill);
      return;
    }
    _settleTween = Tween<double>(begin: shown, end: target);
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _gaugeFill.dispose();
    _mascotEntrance.dispose();
    _bubbleEntrance.dispose();
    _settleCurve.dispose();
    _intro.dispose();
    _settle.dispose();
    super.dispose();
  }

  Widget _buildGauge(BuildContext context, double shown) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasBudget = widget.progress != null;
    String percent(double value) =>
        '${formatLocalizedNumber(context, (value * 100).round())}%';
    return BudgetGaugeIndicator(
      key: const ValueKey('budget-companion-progress'),
      value: shown.clamp(0.0, 1.0),
      color: widget.gaugeColor,
      backgroundColor: widget.gaugeColor.withValues(alpha: .15),
      glowColor: hasBudget ? colors.budgetGaugeGlow(widget.gaugeColor) : null,
      strokeWidth: widget.strokeWidth,
      width: widget.gaugeWidth,
      center: !hasBudget
          ? null
          : Semantics(
              label: '${percent(_target)} ${context.l10n.budget}',
              child: Text(
                percent(shown),
                key: const ValueKey('budget-companion-percent'),
                style: WidgetTextStyles.roundedNumber(
                  theme,
                  baseStyle: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: colors.foreground,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMascotEntrance(BuildContext context, Widget? child) {
    final t = _mascotEntrance.value;
    if (t == 0) return const SizedBox.shrink();
    final spring = _mascotSpring.transform(t);
    return Opacity(
      opacity: Curves.easeOut.transform(math.min(1.0, t * 2.5)),
      child: Transform.translate(
        offset: Offset(0, (1 - spring) * 14),
        child: Transform.scale(
          scale: ui.lerpDouble(0.6, 1.0, spring)!,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  Widget _buildBubbleEntrance(BuildContext context, Widget? child) {
    final t = _bubbleEntrance.value;
    if (t == 0) return const SizedBox.shrink();
    final spring = _bubbleSpring.transform(t);
    final towardMascot =
        Directionality.of(context) == TextDirection.rtl ? 8.0 : -8.0;
    return Opacity(
      opacity: Curves.easeOut.transform(math.min(1.0, t * 2)),
      child: Transform.translate(
        offset: Offset(towardMascot * (1 - spring), 6 * (1 - spring)),
        child: Transform.scale(
          scale: ui.lerpDouble(0.6, 1.0, spring)!,
          alignment: AlignmentDirectional.bottomStart,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final cardWidth = widget.cardWidth;
    final mascot = _AnimatedMascot(
      asset: widget.mascotAsset,
      width: widget.catWidth,
      height: widget.catHeight,
      animateEntrance: reduced,
    );
    final bubble = _CompanionChatBubble(
      reaction: widget.reaction,
      foreground: widget.foreground,
      accent: widget.accent,
      animateEntrance: reduced,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AtmosphericHeaderLines(
            color: widget.gaugeColor.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: 0,
          left: (cardWidth - widget.gaugeWidth) / 2,
          child: reduced
              ? _buildGauge(context, _target)
              : AnimatedBuilder(
                  animation: Listenable.merge([_intro, _settle]),
                  builder: (context, _) => _buildGauge(context, _displayed),
                ),
        ),
        Positioned(
          top: widget.topClearance - widget.catHeight + 14,
          left: (cardWidth - widget.catWidth) / 2,
          width: widget.catWidth,
          height: widget.catHeight,
          child: reduced
              ? mascot
              : AnimatedBuilder(
                  animation: _mascotEntrance,
                  builder: _buildMascotEntrance,
                  child: mascot,
                ),
        ),
        PositionedDirectional(
          top: 2,
          start: (cardWidth / 2) + 36,
          end: 4,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    (cardWidth - ((cardWidth / 2) + 40)).clamp(80.0, 200.0),
              ),
              child: reduced
                  ? bubble
                  : AnimatedBuilder(
                      animation: _bubbleEntrance,
                      builder: _buildBubbleEntrance,
                      child: bubble,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedMascot extends StatefulWidget {
  const _AnimatedMascot({
    required this.asset,
    required this.width,
    required this.height,
    this.animateEntrance = true,
  });

  final String asset;
  final double width;
  final double height;

  /// When false the mascot mounts at rest (a parent choreographs its
  /// entrance) but still bounces when the asset changes.
  final bool animateEntrance;

  @override
  State<_AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<_AnimatedMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      value: widget.animateEntrance ? 0 : 1,
    );
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _controller.forward(from: 0.2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      cacheWidth:
          (widget.width * MediaQuery.devicePixelRatioOf(context)).round(),
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(child: image);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: image),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({
    required this.message,
    required this.foreground,
    required this.accent,
    this.animateEntrance = true,
  });

  final String message;
  final Color foreground;
  final Color accent;

  /// When false the first appearance skips the built-in pop (a parent
  /// choreographs it); later message changes still pop.
  final bool animateEntrance;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _charAnimation;
  late Animation<double> _popAnimation;
  late bool _shouldPop = widget.animateEntrance;

  @override
  void initState() {
    super.initState();
    final durationMs = math.min(800, math.max(300, widget.message.length * 28));
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _popAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _charAnimation = StepTween(begin: 1, end: widget.message.length).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.linear),
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(_ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _shouldPop = true;
      final durationMs =
          math.min(800, math.max(300, widget.message.length * 28));
      _controller.duration = Duration(milliseconds: durationMs);
      _charAnimation = StepTween(begin: 1, end: widget.message.length).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.15, 1.0, curve: Curves.linear),
        ),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final count = disableAnimations
            ? widget.message.length
            : _charAnimation.value.clamp(1, widget.message.length);
        final displayedText = widget.message.substring(0, count);
        final scale =
            disableAnimations || !_shouldPop ? 1.0 : _popAnimation.value;

        return Transform.scale(
          scale: scale,
          alignment: AlignmentDirectional.bottomStart,
          child: AnimatedContainer(
            key: const ValueKey('budget-companion-bubble'),
            duration: _motion(context),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: .14),
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(16),
                topEnd: Radius.circular(16),
                bottomEnd: Radius.circular(16),
                bottomStart: Radius.circular(4),
              ),
              border: Border.all(
                color: widget.accent.withValues(alpha: .22),
                width: 0.8,
              ),
            ),
            child: Text(
              displayedText,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
          ),
        );
      },
    );
  }
}

/// Picks one random chat-bubble message for the current budget state once per
/// mount and re-rolls only when the reaction changes, so parent rebuilds do
/// not replay the typing animation.
class _CompanionChatBubble extends StatefulWidget {
  const _CompanionChatBubble({
    required this.reaction,
    required this.foreground,
    required this.accent,
    this.animateEntrance = true,
  });

  final BudgetCompanionReaction reaction;
  final Color foreground;
  final Color accent;
  final bool animateEntrance;

  @override
  State<_CompanionChatBubble> createState() => _CompanionChatBubbleState();
}

class _CompanionChatBubbleState extends State<_CompanionChatBubble> {
  late String _messageKey = randomBudgetCompanionMessageKey(widget.reaction);

  @override
  void didUpdateWidget(_CompanionChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reaction != widget.reaction) {
      _messageKey = randomBudgetCompanionMessageKey(widget.reaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ChatBubble(
      message: resolveBudgetCompanionMessage(context.l10n, _messageKey),
      foreground: widget.foreground,
      accent: widget.accent,
      animateEntrance: widget.animateEntrance,
    );
  }
}

class BudgetGaugeIndicator extends StatelessWidget {
  const BudgetGaugeIndicator({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 18.0,
    this.width = 210.0,
    this.center,
    this.glowColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double width;
  final Widget? center;

  /// Optional halo painted beneath the active arc; omitted when null.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final height = (width + strokeWidth) / 2;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _BudgetGaugePainter(
              progress: value,
              color: color,
              backgroundColor: backgroundColor,
              strokeWidth: strokeWidth,
              glowColor: glowColor,
            ),
          ),
          if (center != null)
            Positioned(
              bottom: 8,
              child: center!,
            ),
        ],
      ),
    );
  }
}

class _BudgetGaugePainter extends CustomPainter {
  const _BudgetGaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    this.glowColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    if (progress > 0) {
      final sweepAngle = (progress.clamp(0.0, 1.0) * math.pi);

      final glow = glowColor;
      if (glow != null) {
        // A blurred, slightly wider copy of the arc underneath reads as a
        // halo that follows the fill without touching the arc's own edge.
        final glowPaint = Paint()
          ..color = glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, strokeWidth * .6);
        canvas.drawArc(rect, math.pi, sweepAngle, false, glowPaint);
      }

      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowColor != glowColor;
  }
}

class _HeaderError extends StatelessWidget {
  const _HeaderError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 220,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.l10n.errorLoadingDashboard,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.mutedForeground)),
            AdaptiveButton(
                label: context.l10n.retry,
                onPressed: onRetry,
                style: AdaptiveButtonStyle.plain,
                useNative: false),
          ],
        ),
      );
}

class DashboardBudgetHeaderSkeleton extends StatelessWidget {
  const DashboardBudgetHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Skeletonizer(
        effect: ShimmerEffect(
            baseColor: colors.skeletonBase,
            highlightColor: colors.skeletonHighlight),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Bone.circle(size: 80),
            const SizedBox(height: 12),
            const Bone.text(words: 1, fontSize: 36),
            const SizedBox(height: 12),
            const Bone.text(words: 4, fontSize: 18),
            const SizedBox(height: 8),
            Bone(
                width: 120,
                height: 26,
                borderRadius: BorderRadius.circular(13)),
          ],
        ),
      ),
    );
  }
}

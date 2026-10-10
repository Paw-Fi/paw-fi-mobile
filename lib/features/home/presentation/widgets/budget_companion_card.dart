import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:skeletonizer/skeletonizer.dart';

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

/// Category spending card beneath the independent dashboard page header.
class BudgetCompanionCard extends StatelessWidget {
  const BudgetCompanionCard({
    super.key,
    required this.data,
    required this.currency,
    required this.onRetry,
    this.useCustomCategoryStyles = false,
  });

  final BudgetCompanionData data;
  final String currency;
  final VoidCallback onRetry;
  final bool useCustomCategoryStyles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final content = Column(
      key: const ValueKey('budget-companion-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategorySheet(
          categories: data.categories.valueOrNull,
          hasError: data.categories.hasError,
          currency: currency,
          useCustomStyles: useCustomCategoryStyles,
          // An unknown summary must not turn empty category data into a
          // claim of zero total spending.
          hasSpending: data.summary.valueOrNull?.spent != 0,
          onRetry: onRetry,
          motion: _motion(context),
        ),
      ],
    );
    return AnimatedContainer(
      key: const ValueKey('budget-companion-card-surface'),
      duration: _motion(context),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              duration: _motion(context),
              alignment: Alignment.topCenter,
              child: content),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.hasError,
    required this.currency,
    required this.useCustomStyles,
    required this.hasSpending,
    required this.onRetry,
    required this.motion,
  });

  final List<BudgetCompanionCategory>? categories;
  final bool hasError;
  final String currency;
  final bool useCustomStyles;
  final bool hasSpending;
  final VoidCallback onRetry;
  final Duration motion;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _introStarted = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
  }

  void _startIntroWhenReady() {
    if (widget.categories == null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _introStarted = true;
      _intro.value = 1;
    } else if (!_introStarted) {
      // Keep this latch above the switcher so refreshes, errors and empty
      // results cannot remount the chart and replay its initial entrance.
      _introStarted = true;
      if (widget.categories!.isEmpty) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIntroWhenReady();
  }

  @override
  void didUpdateWidget(_CategorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startIntroWhenReady();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.budgetCompanionSpentByCategory.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: widget.motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
                        .animate(animation),
                child: child,
              ),
            ),
            child: widget.categories != null
                ? _CategoryBars(
                    categories: widget.categories!,
                    currency: widget.currency,
                    useCustomStyles: widget.useCustomStyles,
                    hasSpending: widget.hasSpending,
                    intro: _intro,
                  )
                : widget.hasError
                    ? _ErrorContent(onRetry: widget.onRetry, compact: true)
                    : const BudgetCompanionSkeleton(),
          ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars(
      {required this.categories,
      required this.currency,
      required this.useCustomStyles,
      required this.hasSpending,
      required this.intro});
  final List<BudgetCompanionCategory> categories;
  final String currency;
  final bool useCustomStyles;
  final bool hasSpending;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                  hasSpending
                      ? context.l10n.budgetCompanionNoCategories
                      : context.l10n.noExpensesYet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground))));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final count = (constraints.maxWidth / (60 * textScale.clamp(1, 2)))
          .floor()
          .clamp(2, 7);
      final hasOverflow = categories.length > count;
      // Bars are centered in each cell. Leave exactly a quarter of the next
      // bar visible, rather than just a quarter of its surrounding cell.
      final itemExtent = hasOverflow
          ? (constraints.maxWidth + _CategoryBar.barWidth / 4) / (count + .5)
          : constraints.maxWidth / categories.length;
      return SingleChildScrollView(
        key: const ValueKey('budget-companion-categories'),
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: EdgeInsets.zero,
        physics: hasOverflow
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: AnimatedBuilder(
            animation: intro,
            builder: (context, child) => Row(children: [
                  for (var index = 0; index < categories.length; index++)
                    SizedBox(
                        key: ValueKey(categories[index].category),
                        width: itemExtent,
                        child: _CategoryBar(
                            category: categories[index],
                            currency: currency,
                            useCustomStyles: useCustomStyles,
                            // Bound the stagger so even long lists finish together.
                            entrance: Interval(.1 + index.clamp(0, 6) * .04,
                                    .76 + index.clamp(0, 6) * .04,
                                    curve: Curves.easeInOutCubic)
                                .transform(intro.value))),
                ])),
      );
    });
  }
}

class _CategoryBar extends StatelessWidget {
  static const double barWidth = 44;
  static const double barAreaHeight = 160;
  static const double iconDiameter = 38;
  const _CategoryBar(
      {required this.category,
      required this.currency,
      required this.useCustomStyles,
      required this.entrance});
  final BudgetCompanionCategory category;
  final String currency;
  final bool useCustomStyles;
  final double entrance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = useCustomStyles
        ? getCategoryColor(category.category, context)
        : getSharedTransactionCategoryColor(category.category, context);
    final amount = formatCurrency(category.amount, currency, context: context);
    final compactAmount =
        formatCompactCurrency(category.amount, currency, context: context);
    final label = getCategoryTranslation(context, category.category);
    return Semantics(
        label: '$label: $amount',
        child: ExcludeSemantics(
            child: Tooltip(
                message: '$label: $amount',
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        height: barAreaHeight,
                        child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              key: ValueKey('budget-bar-${category.category}'),
                              duration: entrance < 1
                                  ? Duration.zero
                                  : _motion(context),
                              curve: Curves.easeOutCubic,
                              width: barWidth,
                              height: barAreaHeight *
                                  category.heightFactor *
                                  entrance,
                              decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                      color.withValues(alpha: .5),
                                      colors.surface),
                                  borderRadius: BorderRadius.circular(16)),
                            ))),
                    const SizedBox(height: 7),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(compactAmount,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: colors.foreground,
                                    fontWeight: FontWeight.w700))),
                    const SizedBox(height: 7),
                    ClipOval(
                        child: Container(
                            width: iconDiameter,
                            height: iconDiameter,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: .16)),
                            child: buildCategoryIcon(category.category,
                                size: iconDiameter,
                                useCustomStyleOverrides: useCustomStyles))),
                  ]),
                ))));
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({super.key, required this.onRetry, this.compact = false});
  final VoidCallback onRetry;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: compact ? 148 : 320,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(context.l10n.errorLoadingDashboard,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.mutedForeground)),
        AdaptiveButton(
            label: context.l10n.retry,
            onPressed: onRetry,
            style: AdaptiveButtonStyle.plain,
            useNative: false),
      ]));
}

class BudgetCompanionSkeleton extends StatelessWidget {
  const BudgetCompanionSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const _CategorySkeleton();
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
        child: Skeletonizer(
      effect: ShimmerEffect(
          baseColor: colors.skeletonBase,
          highlightColor: colors.skeletonHighlight),
      child: Row(children: [
        for (var index = 0; index < 5; index++)
          const Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                height: _CategoryBar.barAreaHeight,
                child: Center(child: Bone.square(size: 38))),
            SizedBox(height: 7),
            Bone.text(words: 1, fontSize: 12),
            SizedBox(height: 7),
            Bone.circle(size: _CategoryBar.iconDiameter),
          ])),
      ]),
    ));
  }
}

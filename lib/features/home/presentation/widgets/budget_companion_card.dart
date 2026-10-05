import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

class BudgetCompanionCard extends StatelessWidget {
  const BudgetCompanionCard({
    super.key,
    required this.data,
    required this.currency,
    required this.mode,
    required this.onBudgetTap,
    required this.onRetry,
    this.useCustomCategoryStyles = false,
  });

  final BudgetCompanionData data;
  final String currency;
  final HomePeriodMode mode;
  final VoidCallback onBudgetTap;
  final VoidCallback onRetry;
  final bool useCustomCategoryStyles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = data.summary.valueOrNull;
    final reaction = summary?.reaction ?? BudgetCompanionReaction.planning;
    final accent = switch (reaction) {
      BudgetCompanionReaction.happy => colors.success,
      BudgetCompanionReaction.encouraging => colors.info,
      BudgetCompanionReaction.concerned => colors.warning,
      BudgetCompanionReaction.overBudget => colors.destructive,
      BudgetCompanionReaction.planning => colors.info,
    };
    final content = AnimatedSwitcher(
      duration: _motion(context),
      child: summary == null
          ? data.summary.hasError
              ? _ErrorContent(
                  key: const ValueKey('budget-companion-error'),
                  onRetry: onRetry)
              : const BudgetCompanionSkeleton(
                  key: ValueKey('budget-companion-loading'))
          : _content(context, summary, accent),
    );
    return AnimatedContainer(
      key: const ValueKey('budget-companion-card-surface'),
      duration: _motion(context),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.homeCardBorder),
        boxShadow: [
          BoxShadow(
              color: colors.homeCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4)
        ],
      ),
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              duration: _motion(context),
              alignment: Alignment.topCenter,
              child: content),
    );
  }

  Widget _content(
      BuildContext context, BudgetCompanionSummary summary, Color accent) {
    return Column(
      key: const ValueKey('budget-companion-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AsyncRefreshStrip(isRefreshing: data.isRefreshing),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          final mascotWidth = (constraints.maxWidth * .34).clamp(80.0, 160.0);
          final largeText = MediaQuery.textScalerOf(context).scale(14) >= 24;
          final values = _SummaryValues(
              summary: summary,
              currency: currency,
              mode: mode,
              accent: accent,
              onBudgetTap: onBudgetTap);
          final mascot = SizedBox(
              width: mascotWidth,
              child: _Mascot(reaction: summary.reaction, accent: accent));
          return largeText
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Align(
                      alignment: AlignmentDirectional.centerEnd, child: mascot),
                  values
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: values),
                  const SizedBox(width: 8),
                  mascot
                ]);
        }),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: _motion(context),
          child: data.categories.valueOrNull != null
              ? _CategoryBars(
                  categories: data.categories.valueOrNull!,
                  currency: currency,
                  useCustomStyles: useCustomCategoryStyles,
                  hasSpending: summary.spent != 0)
              : data.categories.hasError
                  ? _ErrorContent(onRetry: onRetry, compact: true)
                  : const _CategorySkeleton(),
        ),
      ],
    );
  }
}

class _SummaryValues extends StatelessWidget {
  const _SummaryValues(
      {required this.summary,
      required this.currency,
      required this.mode,
      required this.accent,
      required this.onBudgetTap});
  final BudgetCompanionSummary summary;
  final String currency;
  final HomePeriodMode mode;
  final Color accent;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = summary.remaining;
    final amount = formatCurrency(summary.spent, currency, context: context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: '${context.l10n.spent}: $amount',
        child: ExcludeSemantics(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(amount,
                    style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: colors.foreground)))),
      ),
      const SizedBox(height: 4),
      Text(
          summary.hasBudget
              ? context.l10n.budgetCompanionSpentOf(
                  formatCurrency(summary.budget!, currency, context: context))
              : mode == HomePeriodMode.daily
                  ? context.l10n.budgetCompanionSpentThisDay
                  : context.l10n.budgetCompanionNoBudget,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.mutedForeground, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      if (summary.hasBudget) ...[
        Row(children: [
          Expanded(
              child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: summary.barProgress),
            duration: _motion(context),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              key: const ValueKey('budget-companion-progress'),
              value: value,
              minHeight: 14,
              borderRadius: BorderRadius.circular(20),
              color: accent,
              backgroundColor: accent.withValues(alpha: .14),
              semanticsLabel: context.l10n.budget,
              semanticsValue:
                  '${formatLocalizedNumber(context, (summary.progress! * 100).round())}%',
            ),
          )),
          const SizedBox(width: 8),
          Flexible(
              child: Text(
                  '${formatLocalizedNumber(context, (summary.progress! * 100).round())}%',
                  key: const ValueKey('budget-companion-percent'),
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.foreground, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 12),
        Text(
            remaining! < 0
                ? context.l10n.budgetCompanionOver(
                    formatCurrency(remaining.abs(), currency, context: context))
                : context.l10n.budgetCompanionLeft(
                    formatCurrency(remaining, currency, context: context)),
            style: theme.textTheme.titleMedium?.copyWith(
                color: remaining < 0
                    ? colors.budgetDangerForeground
                    : colors.foreground,
                fontWeight: FontWeight.w700)),
      ] else
        AdaptiveButton(
            label: context.l10n.setBudget,
            style: AdaptiveButtonStyle.plain,
            useNative: false,
            padding: EdgeInsets.zero,
            onPressed: onBudgetTap),
    ]);
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot({required this.reaction, required this.accent});
  final BudgetCompanionReaction reaction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final foreground = switch (reaction) {
      BudgetCompanionReaction.happy => colors.budgetSuccessForeground,
      BudgetCompanionReaction.concerned => colors.budgetWarningForeground,
      BudgetCompanionReaction.overBudget => colors.budgetDangerForeground,
      _ => colors.budgetInfoForeground,
    };
    final (asset, message) = switch (reaction) {
      BudgetCompanionReaction.happy => (
          'celebrating',
          l10n.budgetCompanionHappy
        ),
      BudgetCompanionReaction.encouraging => (
          'cheering',
          l10n.budgetCompanionEncouraging
        ),
      BudgetCompanionReaction.concerned => (
          'confused',
          l10n.budgetCompanionConcerned
        ),
      BudgetCompanionReaction.overBudget => (
          'crying',
          l10n.budgetCompanionOops
        ),
      BudgetCompanionReaction.planning => (
          'planning',
          l10n.budgetCompanionPlanning
        ),
    };
    return AnimatedSwitcher(
      duration: _motion(context),
      child: Column(key: ValueKey(reaction), children: [
        AnimatedContainer(
          duration: _motion(context),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: accent.withValues(alpha: .13),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4))),
          child: Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        RepaintBoundary(
            child: Image.asset('lib/assets/mascots/moneko-$asset.png',
                height: 110,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                cacheWidth:
                    (160 * MediaQuery.devicePixelRatioOf(context)).round())),
      ]),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars(
      {required this.categories,
      required this.currency,
      required this.useCustomStyles,
      required this.hasSpending});
  final List<BudgetCompanionCategory> categories;
  final String currency;
  final bool useCustomStyles;
  final bool hasSpending;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return SizedBox(
          height: 160,
          child: Center(
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
      return SizedBox(
        height: 138 + MediaQuery.textScalerOf(context).scale(12) * 1.5,
        child: ListView.builder(
          key: const ValueKey('budget-companion-categories'),
          scrollDirection: Axis.horizontal,
          primary: false,
          padding: EdgeInsets.zero,
          itemExtent: itemExtent,
          itemCount: categories.length,
          physics: hasOverflow
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => _CategoryBar(
            category: categories[index],
            currency: currency,
            useCustomStyles: useCustomStyles,
          ),
        ),
      );
    });
  }
}

class _CategoryBar extends StatelessWidget {
  static const double barWidth = 44;
  const _CategoryBar(
      {required this.category,
      required this.currency,
      required this.useCustomStyles});
  final BudgetCompanionCategory category;
  final String currency;
  final bool useCustomStyles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = useCustomStyles
        ? getCategoryColor(category.category, context)
        : getSharedTransactionCategoryColor(category.category, context);
    final amount = formatCurrency(category.amount, currency, context: context);
    final label = getCategoryTranslation(context, category.category);
    return Semantics(
        label: '$label: $amount',
        child: ExcludeSemantics(
            child: Tooltip(
                message: '$label: $amount',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    SizedBox(
                        height: 86,
                        child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              key: ValueKey('budget-bar-${category.category}'),
                              duration: _motion(context),
                              curve: Curves.easeOutCubic,
                              width: barWidth,
                              height: 86 * category.heightFactor,
                              decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                      color.withValues(alpha: .5),
                                      colors.homeCardSurface),
                                  borderRadius: BorderRadius.circular(16)),
                            ))),
                    const SizedBox(height: 7),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(amount,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: colors.foreground,
                                    fontWeight: FontWeight.w700))),
                    const SizedBox(height: 7),
                    Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: .16)),
                        child: Center(
                            child: buildCategoryIcon(category.category,
                                size: 26,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
        child: Skeletonizer(
      effect: ShimmerEffect(
          baseColor: colors.skeletonBase,
          highlightColor: colors.skeletonHighlight),
      child: const Column(children: [
        SizedBox(
            height: 168,
            child: Row(children: [
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Bone.text(words: 1, fontSize: 36),
                    SizedBox(height: 8),
                    Bone.text(words: 3, fontSize: 14),
                    SizedBox(height: 14),
                    Bone.text(words: 4, fontSize: 14),
                    SizedBox(height: 12),
                    Bone.text(words: 2, fontSize: 18),
                  ])),
              SizedBox(width: 16),
              Bone.circle(size: 90),
            ])),
        Bone.text(words: 5, fontSize: 14),
        SizedBox(height: 20),
        _CategorySkeleton(),
      ]),
    ));
  }
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
      child: SizedBox(
          height: 160,
          child: Row(children: [
            for (var index = 0; index < 5; index++)
              const Expanded(
                  child: Column(children: [
                SizedBox(
                    height: 86, child: Center(child: Bone.square(size: 38))),
                SizedBox(height: 7),
                Bone.text(words: 1, fontSize: 12),
                SizedBox(height: 7),
                Bone.circle(size: 38),
              ])),
          ])),
    ));
  }
}

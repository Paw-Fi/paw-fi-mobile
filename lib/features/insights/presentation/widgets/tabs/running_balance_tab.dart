import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';
import 'package:moneko/features/insights/presentation/widgets/insights_ui.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/beta_pill.dart';

Widget buildRunningBalanceTab(
    BuildContext context, ColorScheme colorScheme, AnalyticsData analyticsData,
    {String? selectedCurrency}) {
  // Filter data by currency if selected
  var expenses = analyticsData.allExpenses;
  var budgets = analyticsData.allBudgets;

  if (selectedCurrency != null) {
    final currency = selectedCurrency.toUpperCase();
    expenses =
        expenses.where((e) => e.currency?.toUpperCase() == currency).toList();
    budgets =
        budgets.where((b) => b.currency?.toUpperCase() == currency).toList();
  }

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightsSectionCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.runningAndDailyBalances,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const BetaPill(),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.help_outline,
                          size: 18,
                          color: colorScheme.mutedForeground,
                        ),
                        onPressed: () =>
                            _showRunningBalanceInfoModal(context, colorScheme),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.budgetVsSpentDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildRunningBalanceChart(
                    context, colorScheme, expenses, budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {
                    'label': context.l10n.runningBalanceLegend,
                    'color': AppTheme.insightsRunning
                  },
                  {
                    'label': context.l10n.budgetLegend,
                    'color': AppTheme.insightsBudget
                  },
                  {
                    'label': context.l10n.spentLegend,
                    'color': AppTheme.insightsSpent
                  },
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _AllTimeSummaryPills(
            colorScheme: colorScheme,
            expenses: expenses,
            budgets: budgets,
            selectedCurrency: selectedCurrency),
      ],
    ),
  );
}

void _showRunningBalanceInfoModal(
    BuildContext context, ColorScheme colorScheme) {
  final slides = _runningBalanceSlides(context);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final controller = PageController();
      int currentPage = 0;

      return StatefulBuilder(
        builder: (context, setState) {
          final isLastPage = currentPage == slides.length - 1;

          return Dialog(
            backgroundColor: colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.runningBalanceGuide,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.runningBalanceIntro,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 26,
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Slides Area
                    SizedBox(
                      height: 240, // Reduced height as content is simpler
                      child: PageView.builder(
                        controller: controller,
                        onPageChanged: (index) {
                          setState(() => currentPage = index);
                        },
                        itemCount: slides.length,
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slide.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.summary,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.mutedForeground,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ...slide.points.map((point) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            point,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Page Indicators
                        Row(
                          children: List.generate(slides.length, (index) {
                            final isActive = currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              width: isActive ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(100),
                              ),
                            );
                          }),
                        ),

                        // Action Buttons
                        Row(
                          children: [
                            if (!isLastPage)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.mutedForeground,
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                child: Text(context.l10n.skip),
                              ),
                            const SizedBox(width: 12),
                            PrimaryAdaptiveButton(
                              onPressed: () {
                                if (!isLastPage) {
                                  controller.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutQuart,
                                  );
                                  setState(() => currentPage += 1);
                                } else {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              child: Text(
                                isLastPage
                                    ? context.l10n.gotIt
                                    : context.l10n.next,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _AllTimeSummaryPills extends StatelessWidget {
  const _AllTimeSummaryPills({
    required this.colorScheme,
    required this.expenses,
    required this.budgets,
    this.selectedCurrency,
  });

  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
  final String? selectedCurrency;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty && budgets.isEmpty) {
      return const SizedBox.shrink();
    }

    DateTime? minDate;
    DateTime? maxDate;
    double totalSpent = 0;
    double totalBudget = 0;

    for (final e in expenses) {
      totalSpent += e.amount;
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      minDate = (minDate == null || d.isBefore(minDate)) ? d : minDate;
      maxDate = (maxDate == null || d.isAfter(maxDate)) ? d : maxDate;
    }
    for (final b in budgets) {
      totalBudget += b.amount;
      final d = DateTime(b.date.year, b.date.month, b.date.day);
      minDate = (minDate == null || d.isBefore(minDate)) ? d : minDate;
      maxDate = (maxDate == null || d.isAfter(maxDate)) ? d : maxDate;
    }

    final net = totalBudget - totalSpent;
    final code = selectedCurrency ?? 'USD';
    final spentTxt = _formatCurrencyValue(context, totalSpent.abs(), code);
    final budgetTxt = _formatCurrencyValue(context, totalBudget.abs(), code);
    final netAbsTxt = _formatCurrencyValue(context, net.abs(), code);
    final spanStart = minDate != null
        ? '${minDate.year}-${minDate.month.toString().padLeft(2, '0')}-${minDate.day.toString().padLeft(2, '0')}'
        : '';
    final spanEnd = maxDate != null
        ? '${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}-${maxDate.day.toString().padLeft(2, '0')}'
        : '';

    final netTint =
        net >= 0 ? AppTheme.insightsProjection : AppTheme.insightsSpent;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.timeline,
          label: context.l10n.allTime,
          value: '$spanStart → $spanEnd',
          tint: colorScheme.primary,
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.shopping_bag_outlined,
          label: context.l10n.spent,
          value: spentTxt,
          tint: AppTheme.insightsSpent,
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.account_balance_wallet_outlined,
          label: context.l10n.budget,
          value: budgetTxt,
          tint: AppTheme.insightsBudget,
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.stacked_line_chart,
          label: context.l10n.net,
          value: net < 0 ? '-$netAbsTxt' : '+$netAbsTxt',
          tint: netTint,
        ),
      ],
    );
  }

  String _formatCurrencyValue(
    BuildContext context,
    double amount,
    String? currencyCode,
  ) {
    final code = currencyCode ?? 'USD';
    final normalized = double.parse(formatAmount(amount));
    final symbol = resolveCurrencySymbol(code);
    final localized = formatLocalizedNumber(context, normalized);
    return '$symbol$localized';
  }
}

class _RunningBalanceSlideData {
  const _RunningBalanceSlideData(
      {required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_RunningBalanceSlideData> _runningBalanceSlides(BuildContext context) {
  return [
    _RunningBalanceSlideData(
      title: context.l10n.whatYouAreSeeing,
      summary: context.l10n.runningBalanceWhatYouSeeDesc,
      points: [
        context.l10n.purpleLineCushion,
        context.l10n.blueBarsBudget,
        context.l10n.redBarsSpent,
      ],
    ),
    _RunningBalanceSlideData(
      title: context.l10n.whyItMatters,
      summary: context.l10n.runningBalanceWhyMattersDesc,
      points: [
        context.l10n.lineTrendingUpward,
        context.l10n.flatDippingLine,
        context.l10n.sharpDrops,
      ],
    ),
    _RunningBalanceSlideData(
      title: context.l10n.howToRespond,
      summary: context.l10n.runningBalanceHowToRespondDesc,
      points: [
        context.l10n.lineRisingDays,
        context.l10n.lineDippingWeekend,
        context.l10n.feelStuckRed,
      ],
    ),
  ];
}

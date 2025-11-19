import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';
import 'package:moneko/features/insights/presentation/widgets/insights_ui.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

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
                    'color': const Color(0xFF8B5CF6)
                  },
                  {
                    'label': context.l10n.budgetLegend,
                    'color': const Color(0xFF3B82F6)
                  },
                  {
                    'label': context.l10n.spentLegend,
                    'color': const Color(0xFFEF4444)
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
          return Theme(
            data: Theme.of(context),
            child: Dialog(
              backgroundColor: colorScheme.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.runningBalanceGuide,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: colorScheme.mutedForeground),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.runningBalanceIntro,
                        style: TextStyle(
                            color: colorScheme.mutedForeground, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: PageView.builder(
                            controller: controller,
                            onPageChanged: (index) {
                              setState(() => currentPage = index);
                            },
                            itemCount: slides.length,
                            itemBuilder: (context, index) {
                              final slide = slides[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.muted.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slide.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      slide.summary,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...slide.points.map((point) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 16,
                                                color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                point,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: colorScheme.foreground,
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
                            }),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(slides.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: currentPage == index
                                  ? colorScheme.primary
                                  : colorScheme.muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Flexible(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: Text(context.l10n.close),
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: PrimaryAdaptiveButton(
                              onPressed: () {
                                if (currentPage < slides.length - 1) {
                                  controller.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                  setState(() => currentPage += 1);
                                } else {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              child: Text(currentPage < slides.length - 1
                                  ? context.l10n.next
                                  : context.l10n.done),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    final spentTxt = formatCurrency(totalSpent.abs(), code);
    final budgetTxt = formatCurrency(totalBudget.abs(), code);
    final netTxt = formatCurrency(net.abs(), code);
    final spanStart = minDate != null
        ? '${minDate.year}-${minDate.month.toString().padLeft(2, '0')}-${minDate.day.toString().padLeft(2, '0')}'
        : '';
    final spanEnd = maxDate != null
        ? '${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}-${maxDate.day.toString().padLeft(2, '0')}'
        : '';

    final netTint =
        net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
          tint: const Color(0xFFEF4444),
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.account_balance_wallet_outlined,
          label: context.l10n.budget,
          value: budgetTxt,
          tint: const Color(0xFF3B82F6),
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.stacked_line_chart,
          label: context.l10n.net,
          value: (net < 0 ? '-' : '+') + netTxt,
          tint: netTint,
        ),
      ],
    );
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

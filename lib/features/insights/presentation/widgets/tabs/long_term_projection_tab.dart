import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';
import 'package:moneko/features/insights/presentation/widgets/insights_ui.dart';
import 'package:moneko/features/utils/currency.dart';

Widget buildLongTermProjectionTab(BuildContext context, shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData, {String? selectedCurrency}) {
  // Filter data by currency if selected
  var expenses = analyticsData.allExpenses;
  var budgets = analyticsData.allBudgets;
  
  if (selectedCurrency != null) {
    final currency = selectedCurrency.toUpperCase();
    expenses = expenses.where((e) => e.currency?.toUpperCase() == currency).toList();
    budgets = budgets.where((b) => b.currency?.toUpperCase() == currency).toList();
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
                    context.l10n.longTermProjection,
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
                        onPressed: () => _showLongTermGuide(context, colorScheme),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.basedOnHistoricalAverages,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildLongTermProjectionChart(context, colorScheme, expenses, budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': context.l10n.month18ProjectionLegend, 'color': const Color(0xFF10B981)},
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _LongTermSummaryPills(colorScheme: colorScheme, expenses: expenses, selectedCurrency: selectedCurrency),
      ],
    ),
  );
}

void _showLongTermGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _longTermSlides(context);
  final controller = PageController();
  int currentPage = 0;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: colorScheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.your18MonthHorizon,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.longTermIntro,
                      style: TextStyle(color: colorScheme.mutedForeground, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: controller,
                        itemCount: slides.length,
                        onPageChanged: (index) => setState(() => currentPage = index),
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          return _LongTermHelpSlide(
                            colorScheme: colorScheme,
                            title: slide.title,
                            summary: slide.summary,
                            bullets: slide.points,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (index) {
                        final active = index == currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 20 : 8,
                          decoration: BoxDecoration(
                            color: active ? colorScheme.primary : colorScheme.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(context.l10n.close),
                        ),
                        const Spacer(),
                        shadcnui.PrimaryButton(
                          onPressed: () {
                            if (currentPage < slides.length - 1) {
                              controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                              setState(() => currentPage += 1);
                            } else {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          child: Text(currentPage < slides.length - 1 ? context.l10n.next : context.l10n.done),
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

class _LongTermSlideData {
  const _LongTermSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_LongTermSlideData> _longTermSlides(BuildContext context) {
  return [
    _LongTermSlideData(
      title: context.l10n.howTheProjectionWorks,
      summary: context.l10n.longTermHowWorksDesc,
      points: [
        context.l10n.greenLineTrends,
        context.l10n.lineDipsSignals,
        context.l10n.largeGoalsDebts,
      ],
    ),
    _LongTermSlideData(
      title: context.l10n.whyItMatters,
      summary: context.l10n.longTermWhyMattersDesc,
      points: [
        context.l10n.upwardSlope,
        context.l10n.flatSlipping,
        context.l10n.watchSeasonalTrends,
      ],
    ),
    _LongTermSlideData(
      title: 'Moves to consider',
      summary: context.l10n.longTermMovesToConsiderDesc,
      points: [
        context.l10n.schedulePaymentIncreases,
        context.l10n.planAheadDips,
        context.l10n.checkProjectionMonthly,
      ],
    ),
  ];
}

class _LongTermHelpSlide extends StatelessWidget {
  const _LongTermHelpSlide({
    required this.colorScheme,
    required this.title,
    required this.summary,
    required this.bullets,
  });

  final shadcnui.ColorScheme colorScheme;
  final String title;
  final String summary;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.foreground),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.trending_up, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LongTermSummaryPills extends StatelessWidget {
  const _LongTermSummaryPills({
    required this.colorScheme,
    required this.expenses,
    this.selectedCurrency,
  });

  final shadcnui.ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final String? selectedCurrency;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();
    final Map<String, double> monthlyTotals = {};
    for (final e in expenses) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + e.amount;
    }
    if (monthlyTotals.isEmpty) return const SizedBox.shrink();
    final total = monthlyTotals.values.fold<double>(0, (a, b) => a + b);
    final months = monthlyTotals.length;
    final avg = total / (months == 0 ? 1 : months);
    final code = selectedCurrency ?? 'USD';
    final totalTxt = formatCurrency(total.abs(), code);
    final avgTxt = formatCurrency(avg.abs(), code);
    final spanLabel = months > 0 ? '${months}m' : '0m';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.timeline,
          label: context.l10n.allTime,
          value: spanLabel,
          tint: colorScheme.primary,
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.shopping_bag_outlined,
          label: context.l10n.spent,
          value: totalTxt,
          tint: const Color(0xFFEF4444),
        ),
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.calendar_view_month,
          label: context.l10n.monthly,
          value: avgTxt,
          tint: const Color(0xFF10B981),
        ),
      ],
    );
  }
}

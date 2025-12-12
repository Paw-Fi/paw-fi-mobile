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

Widget build30DayLookAheadTab(
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
                    context.l10n.day30LookAhead,
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
                            _showThirtyDayGuide(context, colorScheme),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.projectedFromTrailing30Days,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: build30DayProjectionChart(
                    context, colorScheme, expenses, budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {
                    'label': context.l10n.projectedSpendingLegend,
                    'color': const Color(0xFF10B981)
                  },
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ThirtyDaySummaryPills(
            colorScheme: colorScheme,
            expenses: expenses,
            selectedCurrency: selectedCurrency),
      ],
    ),
  );
}

void _showThirtyDayGuide(BuildContext context, ColorScheme colorScheme) {
  final slides = _thirtyDaySlides(context);
  final controller = PageController();
  int currentPage = 0;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.peek30DaysAhead,
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
                        context.l10n.thirtyDayForecastDesc,
                        style: TextStyle(
                            color: colorScheme.mutedForeground, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: PageView.builder(
                          controller: controller,
                          itemCount: slides.length,
                          onPageChanged: (index) =>
                              setState(() => currentPage = index),
                          itemBuilder: (context, index) {
                            final slide = slides[index];
                            return _InsightsHelpSlide(
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
                              color: active
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
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(context.l10n.close),
                          ),
                          const Spacer(),
                          PrimaryAdaptiveButton(
                            onPressed: () {
                              if (currentPage < slides.length - 1) {
                                controller.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut);
                                setState(() => currentPage += 1);
                              } else {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Text(currentPage < slides.length - 1
                                ? context.l10n.next
                                : context.l10n.done),
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

class _InsightsHelpSlideData {
  const _InsightsHelpSlideData(
      {required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_InsightsHelpSlideData> _thirtyDaySlides(BuildContext context) {
  return [
    _InsightsHelpSlideData(
      title: 'What the forecast shows',
      summary:
          'We blend the past 30 days of spending and income to sketch an average week ahead. It smooths out one-off splurges so you can see the usual rhythm.',
      points: [
        context.l10n.greenLineExpected,
        context.l10n.spikesHighlight,
        context.l10n.forecastUpdates,
      ],
    ),
    _InsightsHelpSlideData(
      title: 'Why it matters',
      summary:
          'Forward-looking budgets help you stay proactive. Seeing big days ahead lets you set aside cash instead of scrambling later.',
      points: [
        context.l10n.spotExpensivePatterns,
        context.l10n.catchQuieterWeeks,
        context.l10n.timeRecurringPayments,
      ],
    ),
    _InsightsHelpSlideData(
      title: 'How to play it smart',
      summary:
          'Treat it like a friendly nudge, not a strict rulebook. Adjust your plan with tiny moves that feel doable.',
      points: [
        context.l10n.bigSpikeComing,
        context.l10n.forecastDipping,
        context.l10n.forecastLooksOff,
      ],
    ),
  ];
}

class _InsightsHelpSlide extends StatelessWidget {
  const _InsightsHelpSlide({
    required this.colorScheme,
    required this.title,
    required this.summary,
    required this.bullets,
  });

  final ColorScheme colorScheme;
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: colorScheme.foreground),
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

class _ThirtyDaySummaryPills extends StatelessWidget {
  const _ThirtyDaySummaryPills({
    required this.colorScheme,
    required this.expenses,
    this.selectedCurrency,
  });

  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final String? selectedCurrency;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recent = expenses
        .where((e) => e.date.isAfter(thirtyDaysAgo) && e.date.isBefore(now))
        .toList();
    final total = recent.fold<double>(0, (s, e) => s + e.amount);
    final avgDaily = recent.isEmpty ? 0.0 : total / 30.0;
    final code = selectedCurrency ?? 'USD';
    final totalTxt = _formatCurrencyValue(context, total.abs(), code);
    final avgTxt = _formatCurrencyValue(context, avgDaily.abs(), code);
    final span =
        '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')} → ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        MetricPill(
          colorScheme: colorScheme,
          icon: Icons.calendar_month,
          label: context.l10n.last30Days,
          value: span,
          tint: const Color(0xFF10B981),
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
          icon: Icons.show_chart,
          label: '${context.l10n.day} avg',
          value: avgTxt,
          tint: const Color(0xFF10B981),
        ),
      ],
    );
  }
}

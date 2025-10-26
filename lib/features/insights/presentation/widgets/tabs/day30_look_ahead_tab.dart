import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget build30DayLookAheadTab(BuildContext context, shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData, {String? selectedCurrency}) {
  // Filter data by currency if selected
  var expenses = analyticsData.expenses;
  var budgets = analyticsData.budgets;
  
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
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.border, width: 1),
          ),
          padding: const EdgeInsets.all(16),
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
                        onPressed: () => _showThirtyDayGuide(context, colorScheme),
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
                child: build30DayProjectionChart(context, colorScheme, expenses, budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': context.l10n.projectedSpendingLegend, 'color': const Color(0xFF10B981)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showThirtyDayGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _thirtyDaySlides();
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
                            'Peek 30 days ahead',
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
                      'This forecast uses the last month of activity to guess how lively the next month might be. Think of it as a weather report for your wallet.',
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
                          child: const Text('Close'),
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
                          child: Text(currentPage < slides.length - 1 ? 'Next' : 'Done'),
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

class _InsightsHelpSlideData {
  const _InsightsHelpSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_InsightsHelpSlideData> _thirtyDaySlides() {
  return const [
    _InsightsHelpSlideData(
      title: 'What the forecast shows',
      summary: 'We blend the past 30 days of spending and income to sketch an average week ahead. It smooths out one-off splurges so you can see the usual rhythm.',
      points: [
        'Green line = expected daily spend if the coming month behaves like the last one.',
        'Spikes highlight weeks where your habits usually get pricier (hello, Friday takeaway).',
        'When you log fresh transactions, the forecast gently updates—no need to refresh.',
      ],
    ),
    _InsightsHelpSlideData(
      title: 'Why it matters',
      summary: 'Forward-looking budgets help you stay proactive. Seeing big days ahead lets you set aside cash instead of scrambling later.',
      points: [
        'Spot expensive patterns early and stash a mini-buffer before they arrive.',
        'Catch quieter weeks where you can sweep extra cash into savings or debt payoff.',
        'Use the insight to time recurring payments, subscriptions, or top-ups.',
      ],
    ),
    _InsightsHelpSlideData(
      title: 'How to play it smart',
      summary: 'Treat it like a friendly nudge, not a strict rulebook. Adjust your plan with tiny moves that feel doable.',
      points: [
        'Big spike coming? Pre-book cheaper options or shuffle flexible spends to calmer days.',
        'Forecast dipping? Reward yourself by scheduling an extra savings transfer.',
        'If the forecast looks off, review categories in the Home tab to tidy up any mislabels.',
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
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
                  Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
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

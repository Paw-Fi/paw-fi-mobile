import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget buildLongTermProjectionTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
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
                    'Long-Term Projection',
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
                'Based on historical averages; updates automatically with your data.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildLongTermProjectionChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': '18-Month Projection', 'color': const Color(0xFF10B981)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showLongTermGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _longTermSlides();
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
                            'Your 18-month horizon',
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
                      "This projection blends your steady habits with gentle growth assumptions so you can see where today's choices lead.",
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

class _LongTermSlideData {
  const _LongTermSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_LongTermSlideData> _longTermSlides() {
  return const [
    _LongTermSlideData(
      title: 'How the projection works',
      summary:
          'We roll forward your average income and spending, sprinkling in modest growth so you can see if your plan keeps cash comfortable months ahead.',
      points: [
        'Green line trends with your typical savings rate—upward momentum means your goals are funded.',
        'If the line dips, it signals future months where expenses tend to outrun income.',
        'Large goals or debts are included when you tag them in the Home tab.',
      ],
    ),
    _LongTermSlideData(
      title: 'Why it matters',
      summary: 'Long horizons make big dreams real. See whether your emergency fund, investments, or big purchases stay on track.',
      points: [
        'An upward slope? Celebrate and consider boosting retirement or travel savings.',
        'Flat or slipping? Time to tune budgets or boost income streams before it snowballs.',
        'Watch for seasonal trends—holidays, school terms, or annual renewals often show here first.',
      ],
    ),
    _LongTermSlideData(
      title: 'Moves to consider',
      summary: 'Use the chart to rehearse future decisions. Small tweaks today compound into big wins later.',
      points: [
        'Schedule gentle payment increases on loans when the curve is rising.',
        'Plan ahead for dips by earmarking sinking funds or trimming optional spends.',
        'Check the projection monthly to keep your long game fun and flexible.',
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

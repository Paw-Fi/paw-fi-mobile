import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget buildRunningBalanceTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
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
                    'Running & Daily Balances',
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
                        onPressed: () => _showRunningBalanceInfoModal(context, colorScheme),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Budget vs Spent per day with cumulative running balance.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildRunningBalanceChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': 'Running Balance', 'color': const Color(0xFF8B5CF6)},
                  {'label': 'Budget', 'color': const Color(0xFF3B82F6)},
                  {'label': 'Spent', 'color': const Color(0xFFEF4444)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showRunningBalanceInfoModal(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _runningBalanceSlides();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final controller = PageController();
      int currentPage = 0;

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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Running balance guide',
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
                      "Think of this chart as your personal money coach. Let's walk through what it shows and how to use it.",
                      style: TextStyle(color: colorScheme.mutedForeground, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: controller,
                        itemCount: slides.length,
                        onPageChanged: (index) {
                          setState(() => currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          return _RunningBalanceInfoSlide(
                            colorScheme: colorScheme,
                            title: slide.title,
                            summary: slide.summary,
                            points: slide.points,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (index) {
                        final isActive = index == currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isActive ? 20 : 8,
                          decoration: BoxDecoration(
                            color: isActive ? colorScheme.primary : colorScheme.muted,
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
                              controller.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
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

class _RunningBalanceSlideData {
  const _RunningBalanceSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_RunningBalanceSlideData> _runningBalanceSlides() {
  return const [
    _RunningBalanceSlideData(
      title: 'What you are seeing',
      summary:
          'Your running balance tracks how much breathing room you have after each day of spending. The daily bars show what you planned versus what you actually spent.',
      points: [
        'Purple line: the cushion left after each day. Rising lines mean you are building momentum.',
        'Blue bars: the budget you set for that day.',
        'Red bars: what actually left your account.',
      ],
    ),
    _RunningBalanceSlideData(
      title: 'Why it matters',
      summary:
          'Treat this as a friendly pulse check. It helps you notice when you are ahead of plan so you can keep investing, or when a course correction will keep you on track.',
      points: [
        'Line trending upward = extra cash you can redirect toward savings goals.',
        'Flat or dipping line = time to pause and review big-ticket items.',
        'Sharp drops often match unplanned purchases—tap them to inspect the details.',
      ],
    ),
    _RunningBalanceSlideData(
      title: 'How to respond',
      summary:
          'Use the chart like a coach. Celebrate gains, reset expectations when needed, and give yourself grace—it is about steady progress, not perfection.',
      points: [
        'Line rising for several days? Consider moving a little extra into savings or debt payoff.',
        'Line dipping after a busy weekend? Rebalance upcoming days by trimming small discretionary spends.',
        'Feel stuck in the red? Revisit your budget in the Home tab—small adjustments add up quickly.',
      ],
    ),
  ];
}

class _RunningBalanceInfoSlide extends StatelessWidget {
  const _RunningBalanceInfoSlide({
    required this.colorScheme,
    required this.title,
    required this.summary,
    required this.points,
  });

  final shadcnui.ColorScheme colorScheme;
  final String title;
  final String summary;
  final List<String> points;

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
              fontSize: 14,
              height: 1.4,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star_rounded, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colorScheme.foreground,
                      ),
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

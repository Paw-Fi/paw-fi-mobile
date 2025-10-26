import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget buildRunningBalanceTab(BuildContext context, shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData, {String? selectedCurrency}) {
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
                        onPressed: () => _showRunningBalanceInfoModal(context, colorScheme),
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
                child: buildRunningBalanceChart(context, colorScheme, expenses, budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': context.l10n.runningBalanceLegend, 'color': const Color(0xFF8B5CF6)},
                  {'label': context.l10n.budgetLegend, 'color': const Color(0xFF3B82F6)},
                  {'label': context.l10n.spentLegend, 'color': const Color(0xFFEF4444)},
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
  final slides = _runningBalanceSlides(context);

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
                            context.l10n.runningBalanceGuide,
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
                      context.l10n.runningBalanceIntro,
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
                          child: Text(context.l10n.close),
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

class _RunningBalanceSlideData {
  const _RunningBalanceSlideData({required this.title, required this.summary, required this.points});

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
        'Purple line: the cushion left after each day. Rising lines mean you are building momentum.',
        'Blue bars: the budget you set for that day.',
        'Red bars: what actually left your account.',
      ],
    ),
    _RunningBalanceSlideData(
      title: context.l10n.whyItMatters,
      summary: context.l10n.runningBalanceWhyMattersDesc,
      points: [
        'Line trending upward = extra cash you can redirect toward savings goals.',
        'Flat or dipping line = time to pause and review big-ticket items.',
        'Sharp drops often match unplanned purchases—tap them to inspect the details.',
      ],
    ),
    _RunningBalanceSlideData(
      title: context.l10n.howToRespond,
      summary: context.l10n.runningBalanceHowToRespondDesc,
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

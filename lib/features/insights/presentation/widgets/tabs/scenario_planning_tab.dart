import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/scenario_result_sheet.dart';

Widget buildScenarioPlanningTab(BuildContext context, shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData, {String? selectedCurrency}) {
  return ScenarioPlanningTabContent(context: context, colorScheme: colorScheme, analyticsData: analyticsData, selectedCurrency: selectedCurrency);
}

void _showCategoryGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _scenarioCategorySlides(context);
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
                            context.l10n.scenarioCategoriesGuide,
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
                      context.l10n.categoryGuideIntro,
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
                          return _ScenarioHelpSlide(
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

class _ScenarioSlideData {
  const _ScenarioSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_ScenarioSlideData> _scenarioCategorySlides(BuildContext context) {
  return [
    _ScenarioSlideData(
      title: context.l10n.readTheBarChartLikeAPro,
      summary: context.l10n.categoryChartDesc,
      points: [
        'The left-hand champs are your heavy hitters—perfect candidates for a quick review.',
        'Small but frequent categories hint at habits that may sneak up over time.',
        'Color matches what you see on the Home tab so your brain stays comfy.',
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whyThisViewIsHelpful,
      summary: context.l10n.categoryWhyHelpfulDesc,
      points: [
        'Planning a new goal? Spot categories to trim without touching the fun stuff.',
        'Eyeing a treat-yourself month? See which areas can flex safely.',
        'Use it to double-check that new expenses were tagged correctly—no ghosts allowed.',
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whatToDoWithTheInsight,
      summary: context.l10n.categoryWhatToDoDesc,
      points: [
        'Slide a high bar down a notch by setting a mini limit or switching to lower-cost swaps.',
        'If a bar is non-negotiable (hello, rent), plan around it instead of fighting it.',
        'Revisit after running a scenario to see whether your adjustments stick.',
      ],
    ),
  ];
}

class _ScenarioHelpSlide extends StatelessWidget {
  const _ScenarioHelpSlide({
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
                  Icon(Icons.pie_chart, size: 18, color: colorScheme.primary),
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

class ScenarioPlanningTabContent extends ConsumerStatefulWidget {
  final BuildContext context;
  final shadcnui.ColorScheme colorScheme;
  final AnalyticsData analyticsData;
  final String? selectedCurrency;

  const ScenarioPlanningTabContent({
    super.key,
    required this.context,
    required this.colorScheme,
    required this.analyticsData,
    this.selectedCurrency,
  });

  @override
  ConsumerState<ScenarioPlanningTabContent> createState() => _ScenarioPlanningTabContentState();
}

class _ScenarioPlanningTabContentState extends ConsumerState<ScenarioPlanningTabContent> {
  final TextEditingController _scenarioQuestionController = TextEditingController();
  DateTime? _scenarioDate;
  bool _scenarioLoading = false;

  @override
  void dispose() {
    _scenarioQuestionController.dispose();
    super.dispose();
  }

  void _showToast(String message, {Widget? trailing}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            if (trailing != null) trailing,
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.colorScheme.background == AppTheme.darkBackground;
    final user = ref.watch(authProvider);
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scenario Planning Input
          Container(
            decoration: BoxDecoration(
              color: widget.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.aiScenarioPlanning,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.askAiFinancialAdvisor,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First Row: "Can I" + input
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(context.l10n.canI, style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _scenarioQuestionController,
                            decoration: InputDecoration(
                              hintText: 'buy a \$1,200 laptop',
                              hintStyle: TextStyle(color: widget.colorScheme.mutedForeground),
                              filled: true,
                              fillColor: isDark ? AppTheme.darkInputBg : AppTheme.lightInputBg,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: widget.colorScheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: widget.colorScheme.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: TextStyle(color: widget.colorScheme.foreground),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second Row: "before" + date picker + Check button
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(context.l10n.before, style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600)),
                        ),
                        shadcnui.OutlineButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _scenarioDate ?? now,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365 * 2)),
                              helpText: 'Select target date',
                            );
                            if (picked != null) {
                              setState(() {
                                _scenarioDate = DateTime(picked.year, picked.month, picked.day);
                              });
                            }
                          },
                          child: Text(
                            _scenarioDate == null
                                ? context.l10n.pickDate
                                : '${_scenarioDate!.year}-${_scenarioDate!.month.toString().padLeft(2, '0')}-${_scenarioDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: shadcnui.PrimaryButton(
                              onPressed: _scenarioLoading ? null : () async {
                                final q = _scenarioQuestionController.text.trim();
                                final d = _scenarioDate == null
                                    ? ''
                                    : '${_scenarioDate!.year}-${_scenarioDate!.month.toString().padLeft(2, '0')}-${_scenarioDate!.day.toString().padLeft(2, '0')}';
                                if (q.isEmpty || d.isEmpty) {
                                  _showToast(context.l10n.enterQuestionAndPickDate);
                                  return;
                                }

                                setState(() { _scenarioLoading = true; });

                                // Show loading modal
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) => PopScope(
                                    canPop: false,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(32),
                                        decoration: BoxDecoration(
                                          color: colorScheme.background,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'lib/assets/gifs/loading-anim.gif',
                                              width: 80,
                                              height: 80,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              context.l10n.analyzingScenario,
                                              style: TextStyle(
                                                color: colorScheme.foreground,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              context.l10n.thisMightTakeAWhile,
                                              style: TextStyle(
                                                color: colorScheme.mutedForeground,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                try {
                                  final response = await supabase.functions.invoke(
                                    'ai-scenario-planner',
                                    body: {
                                      'question': 'Can I $q',
                                      'targetDate': d,
                                      'userId': user.uid, // Not trusted by BE, just for logs
                                    },
                                  );

                                  if (!mounted) return;

                                  // Close loading modal
                                  Navigator.of(context, rootNavigator: true).pop();

                                  if (response.data != null && response.data['success'] == true) {
                                    final advice = response.data['advice'] ?? 'No analysis available';
                                    final meta = response.data['meta'] ?? {};

                                    setState(() { _scenarioLoading = false; });

                                    // Auto-show the result sheet
                                    showScenarioResultSheet(context, advice, meta, selectedCurrency: widget.selectedCurrency);
                                  } else {
                                    final error = response.data?['error'] ?? 'Failed to analyze scenario';
                                    throw Exception(error);
                                  }
                                } catch (e) {
                                  if (!mounted) return;

                                  // Close loading modal
                                  Navigator.of(context, rootNavigator: true).pop();

                                  setState(() { _scenarioLoading = false; });
                                  _showToast('Analysis failed: ${e.toString()}');
                                }
                              },
                              child: Text(context.l10n.check, style: TextStyle(color: colorScheme.buttonText, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Where the Money Went
          Container(
            decoration: BoxDecoration(
              color: widget.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.whereTheMoneyWent,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.colorScheme.foreground,
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
                            color: widget.colorScheme.mutedForeground,
                          ),
                          onPressed: () => _showCategoryGuide(context, widget.colorScheme),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.categoryTotalsForSelectedRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: Builder(
                    builder: (context) {
                      // Filter expenses by selected currency if applicable
                      var expenses = widget.analyticsData.expenses;
                      if (widget.selectedCurrency != null) {
                        final currency = widget.selectedCurrency!.toUpperCase();
                        expenses = expenses.where((e) => e.currency?.toUpperCase() == currency).toList();
                      }
                      return buildCategoryBarChart(context, widget.colorScheme, expenses);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';

Widget buildScenarioPlanningTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
  return ScenarioPlanningTabContent(colorScheme: colorScheme, analyticsData: analyticsData);
}

void _showCategoryGuide(BuildContext context, shadcnui.ColorScheme colorScheme) {
  final slides = _scenarioCategorySlides();
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
                            'Make sense of categories',
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
                      "Think of this chart as a bird's-eye view of where each dollar flew. Here's how to read it without needing a calculator.",
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

class _ScenarioSlideData {
  const _ScenarioSlideData({required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_ScenarioSlideData> _scenarioCategorySlides() {
  return const [
    _ScenarioSlideData(
      title: 'Read the bar chart like a pro',
      summary: 'Each bar shows how much a category grabbed in the selected window. Taller bar, bigger bite of your budget.',
      points: [
        'The left-hand champs are your heavy hitters—perfect candidates for a quick review.',
        'Small but frequent categories hint at habits that may sneak up over time.',
        'Color matches what you see on the Home tab so your brain stays comfy.',
      ],
    ),
    _ScenarioSlideData(
      title: 'Why this view is helpful',
      summary: 'Scenario planning works best when you know your baseline. These totals guide where to dial things up or down.',
      points: [
        'Planning a new goal? Spot categories to trim without touching the fun stuff.',
        'Eyeing a treat-yourself month? See which areas can flex safely.',
        'Use it to double-check that new expenses were tagged correctly—no ghosts allowed.',
      ],
    ),
    _ScenarioSlideData(
      title: 'What to do with the insight',
      summary: 'Take one friendly step at a time. Tiny tweaks across big categories move the needle fast.',
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
  final shadcnui.ColorScheme colorScheme;
  final AnalyticsData analyticsData;

  const ScenarioPlanningTabContent({
    super.key,
    required this.colorScheme,
    required this.analyticsData,
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

  void _showScenarioResultSheet(String advice, Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: widget.colorScheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.colorScheme.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Scenario Analysis',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.colorScheme.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: widget.colorScheme.foreground),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Date Badge
                      if (meta['targetDate'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Target: ${meta['targetDate']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.colorScheme.primary,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // AI Advice
                      Text(
                        advice,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: widget.colorScheme.foreground,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Stats Section
                      if (meta['stats'] != null) ...[
                        Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow('Current Balance', '\$${meta['stats']['currentRunningBalance']?.toStringAsFixed(2) ?? '0.00'}'),
                        _buildStatRow('Projected (No Change)', '\$${meta['stats']['projectedNoScenarioByTarget']?.toStringAsFixed(2) ?? '0.00'}'),
                        _buildStatRow('Avg Daily Net', '\$${meta['stats']['avgNetPerDay']?.toStringAsFixed(2) ?? '0.00'}'),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: widget.colorScheme.mutedForeground,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.colorScheme.foreground,
            ),
          ),
        ],
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
                  'AI Scenario Planning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ask your AI financial advisor if you can afford a future expense',
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
                          child: Text('Can I', style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600)),
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
                          child: Text('before', style: TextStyle(color: widget.colorScheme.foreground, fontWeight: FontWeight.w600)),
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
                                ? 'Pick date'
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
                                  _showToast('Please enter a question and pick a date');
                                  return;
                                }

                                setState(() { _scenarioLoading = true; });

                                // Show loading toast
                                _showToast(
                                  'Analyzing scenario...',
                                  trailing: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

                                  if (response.data != null && response.data['success'] == true) {
                                    final advice = response.data['advice'] ?? 'No analysis available';
                                    final meta = response.data['meta'] ?? {};

                                    setState(() { _scenarioLoading = false; });

                                    // Show success toast
                                    _showToast('Analysis complete! Tap to view', trailing: TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        _showScenarioResultSheet(advice, meta);
                                      },
                                      child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ));

                                    // Auto-show the result sheet
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (mounted) {
                                        _showScenarioResultSheet(advice, meta);
                                      }
                                    });
                                  } else {
                                    final error = response.data?['error'] ?? 'Failed to analyze scenario';
                                    throw Exception(error);
                                  }
                                } catch (e) {
                                  if (!mounted) return;

                                  setState(() { _scenarioLoading = false; });
                                  _showToast('Analysis failed: ${e.toString()}');
                                }
                              },
                              child: _scenarioLoading
                                  ?  SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.mutedForeground),
                                      ),
                                    )
                                  :  Text('Check', style: TextStyle(color: colorScheme.mutedForeground, fontWeight: FontWeight.bold)),
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
                      'Where the Money Went',
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
                  'Category totals for the selected range.',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: buildCategoryBarChart(widget.colorScheme, widget.analyticsData.expenses),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

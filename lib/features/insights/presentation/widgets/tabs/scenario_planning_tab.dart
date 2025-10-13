import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';

Widget buildScenarioPlanningTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
  return ScenarioPlanningTabContent(colorScheme: colorScheme, analyticsData: analyticsData);
}

class ScenarioPlanningTabContent extends StatefulWidget {
  final shadcnui.ColorScheme colorScheme;
  final AnalyticsData analyticsData;

  const ScenarioPlanningTabContent({
    super.key,
    required this.colorScheme,
    required this.analyticsData,
  });

  @override
  State<ScenarioPlanningTabContent> createState() => _ScenarioPlanningTabContentState();
}

class _ScenarioPlanningTabContentState extends State<ScenarioPlanningTabContent> {
  final TextEditingController _scenarioQuestionController = TextEditingController();
  DateTime? _scenarioDate;
  bool _scenarioLoading = false;

  @override
  void dispose() {
    _scenarioQuestionController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.colorScheme.background == AppTheme.darkBackground;

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
                  'Scenario Planning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Test if you can afford a future expense based on projections.',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Eg: "Can I buy a \$1,200 laptop before 2025-12-31?"',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              hintText: '',
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
                                    : '${_scenarioDate!.year}-${_scenarioDate!.month.toString().padLeft(2, '0')}-${_scenarioDate!.day.toString().padLeft(2, '0')}' ;
                                if (q.isEmpty || d.isEmpty) {
                                  _showToast('Please enter a question and pick a date');
                                  return;
                                }

                                setState(() { _scenarioLoading = true; });

                                // Show persistent loading overlay
                                final overlayEntry = OverlayEntry(
                                  builder: (context) => Material(
                                    color: Colors.black54,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: shadcnui.Theme.of(context).colorScheme.background,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Analyzing scenario...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: shadcnui.Theme.of(context).colorScheme.foreground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                Overlay.of(context).insert(overlayEntry);

                                try {
                                  // Note: We need to access the provider from a parent widget that has access to ref
                                  // For now, we'll use a callback or pass the function from parent
                                  await _performScenarioAnalysis(q, d);

                                  // Remove loading overlay
                                  overlayEntry.remove();

                                  if (!mounted) return;

                                  _showToast('Scenario analyzed successfully');
                                } catch (e) {
                                  // Remove loading overlay
                                  overlayEntry.remove();

                                  if (!mounted) return;

                                  _showToast('Scenario analysis failed: $e');
                                } finally {
                                  if (mounted) {
                                    setState(() { _scenarioLoading = false; });
                                  }
                                }
                              },
                              child: _scenarioLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Check'),
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
                    Icon(Icons.help_outline, size: 16, color: widget.colorScheme.mutedForeground),
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

  Future<void> _performScenarioAnalysis(String question, String targetDate) async {
    // This would need to be implemented with proper provider access
    // For now, we'll throw an error to indicate this needs to be handled by parent
    throw UnimplementedError('Scenario analysis requires provider access from parent widget');
  }
}

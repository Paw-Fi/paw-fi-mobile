import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/features/pockets/presentation/widgets/envelope_mode_settings_modal.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

class PocketsHeaderCard extends StatelessWidget {
  const PocketsHeaderCard({
    super.key,
    required this.totalBudget,
    required this.totalAllocated,
    required this.totalSpent,
    required this.periodMonth,
    required this.previousBudget,
    required this.onReusePrevious,
    required this.colorScheme,
    required this.onTotalChanged,
    required this.envelopeMode,
    required this.onEnvelopeModeChanged,
    required this.currency,
    required this.hasSeenHelp,
    required this.onHelpSeen,
  });

  final double totalBudget;
  final double totalAllocated;
  final double totalSpent;
  final DateTime periodMonth;
  final double previousBudget;
  final VoidCallback? onReusePrevious;
  final ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;
  final bool envelopeMode;
  final ValueChanged<bool> onEnvelopeModeChanged;
  final String currency;
  final bool hasSeenHelp;
  final VoidCallback onHelpSeen;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    const sliderMin = 0.00;
    const sliderMax = 10000.0;
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();
    final monthLabel = DateFormat('MMM').format(periodMonth);

    // Theme-aware colors for the card
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.012 : 0.02),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Month Label and Help Icon in same row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Empty space to balance the row for true centering
              const SizedBox(width: 48), // Match help icon width
              // Month Label (truly centered)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Help Icon
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint('Help icon tapped');
                  showEnvelopeModeSettingsModal(
                    context,
                    colorScheme,
                    envelopeMode,
                    onEnvelopeModeChanged,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Budget Amount (centered, showing total budget)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Re-using the manual entry logic
              final controller = TextEditingController(
                  text: effectiveBudget.toStringAsFixed(0));
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.setMonthlyBudgetTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close,
                                    color: colorScheme.mutedForeground),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CustomTextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            placeholder: '0',
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryAdaptiveButton(
                              onPressed: () {
                                final val = double.tryParse(controller.text);
                                if (val != null && val >= 0) {
                                  onTotalChanged(val.roundToDouble());
                                  Navigator.pop(context);
                                }
                              },
                              child: Text(context.l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Text(
              formatCurrency(effectiveBudget, currency),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Slider
          SizedBox(
            width: double.infinity,
            child: AdaptiveSlider(
              activeColor: colorScheme.primary,
              value: sliderValue,
              min: sliderMin,
              max: sliderMax,
              onChanged: (value) {
                // Round to nearest 10
                final roundedValue = (value / 10).round() * 10;
                onTotalChanged(roundedValue.toDouble());
              },
              divisions: ((sliderMax - sliderMin) / 10).round(),
            ),
          ),
          const SizedBox(height: 8),
          // Min/Max Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatCurrency(sliderMin, currency),
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatCurrency(sliderMax, currency),
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
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

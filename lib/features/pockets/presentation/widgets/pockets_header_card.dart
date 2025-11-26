import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:flutter/cupertino.dart';
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
    this.onSave,
    required this.currency,
    this.onDateSelected,
  });

  final double totalBudget;
  final double totalAllocated;
  final double totalSpent;
  final DateTime periodMonth;
  final double previousBudget;
  final VoidCallback? onReusePrevious;
  final ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;
  final VoidCallback? onSave;
  final String currency;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    const sliderMin = 0.00;
    const sliderMax = 10000.0;
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();
    final isCurrentYear = periodMonth.year == DateTime.now().year;
    final monthLabel = isCurrentYear
        ? formatLocalizedMonth(context, periodMonth, abbreviated: false)
        : '${formatLocalizedMonth(context, periodMonth, abbreviated: false)} ${periodMonth.year}';

    // Theme-aware colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Month Label
          GestureDetector(
            onTap: () => _pickMonth(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Budget Amount
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showBudgetInputSheet(context, effectiveBudget),
            child: Column(
              children: [
                Text(
                  context.l10n.monthlyBudget,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(effectiveBudget, currency),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Slider Section
          SizedBox(
            width: double.infinity,
            child: AdaptiveSlider(
              activeColor: colorScheme.primary,
              value: sliderValue,
              min: sliderMin,
              max: sliderMax,
              onChanged: (value) {
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

  void _showBudgetInputSheet(BuildContext context, double currentAmount) {
    final controller =
        TextEditingController(text: currentAmount.toStringAsFixed(0));
    // Highlight entire value by default for quick replacement
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      icon:
                          Icon(Icons.close, color: colorScheme.mutedForeground),
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
                        onSave?.call();
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
  }

  void _pickMonth(BuildContext context) {
    if (onDateSelected == null) return;

    final now = DateTime.now();
    final minDate = DateTime(2020);
    final maxDate =
        DateTime(now.year, now.month + 1, 0); // End of current month
    DateTime tempDate = periodMonth;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  Text(
                    'Select Month',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final normalized =
                          DateTime(tempDate.year, tempDate.month, 1);
                      onDateSelected!(normalized);
                      Navigator.pop(context);
                    },
                    child: Text(context.l10n.done),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: periodMonth,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (val) {
                  tempDate = val;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

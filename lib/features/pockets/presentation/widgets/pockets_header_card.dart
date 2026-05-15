import 'package:moneko/core/theme/app_theme.dart';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/pockets/presentation/utils/pocket_budget_amount_steps.dart';
import 'package:flutter/cupertino.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/swipe_hint_row.dart';
import 'package:moneko/core/utils/money_parser.dart';

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
    this.isSkeleton = false,
    this.amountSpotlightKey,
    this.showSwipeHint = false,
  });

  final double totalBudget;
  final double totalAllocated;
  final double totalSpent;
  final DateTime periodMonth;
  final double previousBudget;
  final VoidCallback? onReusePrevious;
  final ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;
  final Future<void> Function()? onSave;
  final String currency;
  final ValueChanged<DateTime>? onDateSelected;
  final bool isSkeleton;
  final GlobalKey? amountSpotlightKey;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    const sliderMin = 0.00;
    final sliderMax = calculatePocketBudgetSliderMax(
      currencyCode: currency,
      values: [
        effectiveBudget,
        totalAllocated,
        totalSpent,
        previousBudget,
      ],
    );
    final desiredSliderStep =
        calculatePocketBudgetSliderStep(sliderMin, sliderMax);
    final sliderDivisions = calculatePocketBudgetSliderDivisions(
        sliderMin, sliderMax, desiredSliderStep);
    final sliderStep =
        (sliderMax - sliderMin) / sliderDivisions; // Actual step with divisions
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();
    final isCurrentYear = periodMonth.year == DateTime.now().year;
    final monthLabel = isCurrentYear
        ? formatLocalizedMonth(context, periodMonth, abbreviated: false)
        : '${formatLocalizedMonth(context, periodMonth, abbreviated: false)} ${periodMonth.year}';

    // Theme-aware colors
    final baseCardColor = colorScheme.cardSurface;
    final cardColor =
        isSkeleton ? colorScheme.surfaceContainerHighest : baseCardColor;
    final textColor = colorScheme.foreground;
    final subTextColor = colorScheme.mutedForeground;
    final sliderRailColor = colorScheme.mutedForeground.withValues(alpha: 0.35);

    String formatLocalizedCurrency(double amount) {
      final normalized = double.parse(formatAmount(amount));
      final symbol = resolveCurrencySymbol(currency);
      final localized = formatLocalizedNumber(context, normalized);
      return '$symbol$localized';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showBudgetInputSheet(context, effectiveBudget),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.pocketHeaderBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.pocketHeaderShadow,
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
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
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

            // Budget Amount (spotlight target)
            KeyedSubtree(
              key: amountSpotlightKey,
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
                  SizedBox(
                    height: 50, // Keep height consistent while text scales
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: FittedBox(
                        key: ValueKey(effectiveBudget),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatLocalizedCurrency(effectiveBudget),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            if (!isSkeleton) ...[
              // Slider Section
              SizedBox(
                width: double.infinity,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colorScheme.primary,
                    inactiveTrackColor: sliderRailColor,
                    trackHeight: 4,
                    thumbColor: colorScheme.primaryForeground,
                  ),
                  child: SizedBox(
                    height: 32,
                    child: AdaptiveSlider(
                      activeColor: colorScheme.primary,
                      thumbColor: colorScheme.primaryForeground,
                      value: sliderValue,
                      min: sliderMin,
                      max: sliderMax,
                      onChanged: (value) {
                        final roundedValue =
                            ((value - sliderMin) / sliderStep).round() *
                                    sliderStep +
                                sliderMin;
                        onTotalChanged(
                          roundedValue.clamp(sliderMin, sliderMax).toDouble(),
                        );
                      },
                      divisions: sliderDivisions,
                    ),
                  ),
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
                      '${resolveCurrencySymbol(currency)}${formatLocalizedNumber(context, sliderMin)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatLocalizedCurrency(sliderMax),
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (showSwipeHint) ...[
                const SizedBox(height: 12),
                const SwipeHintRow(text: 'Swipe right for previous months'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetInputSheet(
      BuildContext context, double currentAmount) async {
    final value = await showCalculatorKeypadSheet(
      context: context,
      initialValue: currentAmount == 0 ? '' : formatAmount(currentAmount),
    );
    if (value == null) return;

    final cents = tryParseMoneyToCents(value);
    final val = cents != null ? centsToAmount(cents) : null;
    if (val != null && val >= 0) {
      onTotalChanged(val);
      onSave?.call();
    }
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
      useSafeArea: true,
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

import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:flutter/cupertino.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

const Map<String, double> _currencyBaselines = {
  'USD': 10000,
  'EUR': 10000,
  'GBP': 10000,
  'CHF': 10000,
  'SGD': 12000,
  'AUD': 10000,
  'CAD': 10000,
  'NZD': 10000,
  'HKD': 60000,
  'CNY': 20000,
  'JPY': 300000,
  'KRW': 6000000,
  'MYR': 10000,
  'INR': 100000,
  'IDR': 15000000,
  'THB': 70000,
  'PHP': 70000,
  'VND': 25000000,
  'PYG': 20000000,
  'BRL': 12000,
  'MXN': 30000,
  'ZAR': 25000,
  'TRY': 70000,
  'NGN': 2000000,
  'PKR': 300000,
  'EGP': 70000,
  'GHS': 40000,
  'KES': 120000,
  'UAH': 250000,
  'RUB': 150000,
  'RSD': 120000,
  'HUF': 300000,
  'CZK': 60000,
  'PLN': 12000,
  'NOK': 50000,
  'SEK': 40000,
  'DKK': 40000,
  'AED': 35000,
  'SAR': 12000,
  'GTQ': 12000,
  'CLP': 900000,
  'DOP': 150000,
  'LKR': 300000,
};

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
    final sliderMax = _calculateSliderMax(
      currencyCode: currency,
      values: [
        effectiveBudget,
        totalAllocated,
        totalSpent,
        previousBudget,
      ],
    );
    final desiredSliderStep = _calculateSliderStep(sliderMin, sliderMax);
    final sliderDivisions =
        _calculateSliderDivisions(sliderMin, sliderMax, desiredSliderStep);
    final sliderStep =
        (sliderMax - sliderMin) / sliderDivisions; // Actual step with divisions
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
                final roundedValue = ((value - sliderMin) / sliderStep).round() *
                        sliderStep +
                    sliderMin;
                onTotalChanged(
                  roundedValue.clamp(sliderMin, sliderMax).toDouble(),
                );
              },
              divisions: sliderDivisions,
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

  Future<void> _showBudgetInputSheet(
      BuildContext context, double currentAmount) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.setMonthlyBudgetTitle,
      description: context.l10n.monthlyBudget,
      confirmLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: currentAmount.toStringAsFixed(0),
        placeholder: '0',
        isRequired: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        validationPattern: RegExp(r'^[0-9,]+$'),
        validationMessage: 'Please enter a valid amount.',
      ),
    );

    if (result == null || !result.confirmed || result.text == null) {
      return;
    }

    final rawText = result.text!.trim();
    final normalized = rawText.replaceAll(',', '');
    final val = double.tryParse(normalized);
    if (val != null && val >= 0) {
      onTotalChanged(val.roundToDouble());
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

  double _calculateSliderMax({
    required String currencyCode,
    required List<double> values,
  }) {
    final normalizedCode = isSupportedCurrencyCode(currencyCode)
        ? currencyCode.toUpperCase()
        : 'USD';
    final baseline = _currencyBaselineMax(normalizedCode);
    final roundingChunk = _currencyChunk(normalizedCode);

    final observedMax = values
        .where((value) => value.isFinite && value > 0)
        .fold<double>(0, math.max);
    final paddedObserved = observedMax > 0 ? observedMax * 1.25 : 0;
    final hardCap = baseline * 3;
    final candidate = math.max(baseline, paddedObserved);
    final capped = math.min(candidate, hardCap).toDouble();

    return _roundUpToChunk(
      capped,
      roundingChunk,
    );
  }

  double _currencyBaselineMax(String currencyCode) {
    const defaultBaseline = 10000.0;
    return _currencyBaselines[currencyCode] ?? defaultBaseline;
  }

  double _currencyChunk(String currencyCode) {
    final baseline = _currencyBaselineMax(currencyCode);
    final rawChunk = baseline / 10;
    return _niceNumber(rawChunk);
  }

  double _calculateSliderStep(double min, double max) {
    final span = max - min;
    if (span <= 0) return 1;

    final targetDivisions = span <= 50000
        ? 1000
        : span <= 500000
            ? 700
            : span <= 20000000
                ? 450
                : 300;
    final rawStep = span / targetDivisions;
    return _niceNumber(rawStep);
  }

  int _calculateSliderDivisions(double min, double max, double step) {
    if (step <= 0) return 1;
    final divisions = ((max - min) / step).round();
    return math.max(1, math.min(divisions, 1200));
  }

  double _roundUpToChunk(double value, double chunk) {
    final safeChunk = chunk.isFinite && chunk > 0 ? chunk : 10000.0;
    if (!value.isFinite || value <= 0) return safeChunk;
    final quotient = value / safeChunk;
    final rounded = quotient.isFinite ? quotient.ceilToDouble() : 1.0;
    return rounded * safeChunk;
  }

  double _niceNumber(double rawStep) {
    if (!rawStep.isFinite || rawStep <= 0) return 1;
    final exponent = (math.log(rawStep) / math.ln10).floor();
    final magnitude = math.pow(10.0, exponent).toDouble();
    final fraction = rawStep / magnitude;

    double niceFraction;
    // Only allow 1, 5, or 10 as the "nice" fraction
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }

    return math.max(1, niceFraction * magnitude);
  }
}

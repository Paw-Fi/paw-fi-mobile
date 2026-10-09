import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/pockets/presentation/utils/pocket_budget_amount_steps.dart';
import 'package:flutter/cupertino.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/swipe_hint_row.dart';
import 'package:moneko/shared/widgets/seamless_header_action.dart';
import 'package:moneko/shared/widgets/header_month_label.dart';
import 'package:moneko/core/utils/money_parser.dart';

class PocketsHeaderCard extends StatelessWidget {
  const PocketsHeaderCard({
    super.key,
    required this.totalBudget,
    this.totalAllocated = 0,
    this.totalSpent = 0,
    required this.periodMonth,
    this.financialMonthStartDay = 1,
    this.previousBudget = 0,
    this.onReusePrevious,
    required this.colorScheme,
    required this.onTotalChanged,
    this.onBudgetEditBlocked,
    this.currencyBudgets = const {},
    this.onCurrencyBudgetChanged,
    this.savingCurrency,
    this.onSave,
    required this.currency,
    this.onDateSelected,
    this.isSkeleton = false,
    this.amountSpotlightKey,
    this.showSwipeHint = false,
    this.showSlider = false,
    this.isSeamless = false,
    this.showEditActions = true,
    this.onAddPocket,
    this.onAddPocketForCurrency,
    this.isAddingPocket = false,
  });

  final double totalBudget;
  final double totalAllocated;
  final double totalSpent;
  final DateTime periodMonth;
  final int financialMonthStartDay;
  final double previousBudget;
  final VoidCallback? onReusePrevious;
  final ColorScheme colorScheme;
  final ValueChanged<double>? onTotalChanged;
  final VoidCallback? onBudgetEditBlocked;
  final Map<String, double> currencyBudgets;
  final Future<void> Function(String currency, double amount)?
      onCurrencyBudgetChanged;
  final String? savingCurrency;
  final Future<void> Function()? onSave;
  final String currency;
  final ValueChanged<DateTime>? onDateSelected;
  final bool isSkeleton;
  final GlobalKey? amountSpotlightKey;
  final bool showSwipeHint;
  final bool showSlider;
  final bool isSeamless;
  final bool showEditActions;
  final VoidCallback? onAddPocket;
  final Future<void> Function(String currency)? onAddPocketForCurrency;
  final bool isAddingPocket;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    const sliderMin = 0.0;
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
      sliderMin,
      sliderMax,
      desiredSliderStep,
    );
    final sliderStep = (sliderMax - sliderMin) / sliderDivisions;
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();
    final nativeBudgets = currencyBudgets.entries
        .map(
          (entry) => MapEntry(
            entry.key.trim().toUpperCase(),
            entry.value > 0 ? entry.value : 0.0,
          ),
        )
        .where((entry) => entry.key.isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    final showCurrencyBreakdown = nativeBudgets.length > 1;
    final isCurrentYear = periodMonth.year == DateTime.now().year;
    final normalizedFinancialStartDay =
        normalizeFinancialMonthStartDay(financialMonthStartDay);
    final monthLabel = normalizedFinancialStartDay == 1
        ? (isCurrentYear
            ? formatLocalizedMonth(context, periodMonth, abbreviated: false)
            : '${formatLocalizedMonth(context, periodMonth, abbreviated: false)} ${periodMonth.year}')
        : _formatFinancialCycleLabel(
            context,
            periodMonth,
            normalizedFinancialStartDay,
          );

    // Theme-aware colors
    final baseCardColor = colorScheme.cardSurface;
    final cardColor =
        isSkeleton ? colorScheme.surfaceContainerHighest : baseCardColor;
    final textColor = colorScheme.foreground;
    final subTextColor = colorScheme.mutedForeground;

    String formatLocalizedCurrency(double amount, [String? currencyCode]) {
      final normalized = double.parse(formatAmount(amount));
      final symbol = resolveCurrencySymbol(currencyCode ?? currency);
      final localized = formatLocalizedNumber(context, normalized);
      return '$symbol$localized';
    }

    final VoidCallback? editBudget = onTotalChanged == null
        ? onBudgetEditBlocked
        : () => _showBudgetInputSheet(
              context,
              currentAmount: effectiveBudget,
              currencyCode: currency,
              onChanged: (value) async {
                onTotalChanged?.call(value);
                await onSave?.call();
              },
            );

    VoidCallback? editCurrencyBudget(MapEntry<String, double> entry) {
      if (onCurrencyBudgetChanged == null || savingCurrency != null) {
        return null;
      }
      return () => _showBudgetInputSheet(
            context,
            currentAmount: entry.value,
            currencyCode: entry.key,
            onChanged: (value) => onCurrencyBudgetChanged!(entry.key, value),
          );
    }

    void showCurrencyBudgetBreakdown() {
      MonekoBottomSheet.show<void>(
        context: context,
        title: context.l10n.monthlyBudget,
        isScrollControlled: true,
        builder: (sheetContext) {
          final sheetColorScheme = Theme.of(sheetContext).colorScheme;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(sheetContext).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: sheetColorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatLocalizedCurrency(effectiveBudget),
                    style: WidgetTextStyles.roundedNumber(
                      Theme.of(context),
                      baseStyle: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: sheetColorScheme.foreground,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  for (final entry in nativeBudgets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CurrencyBudgetRow(
                        currency: entry.key,
                        amount: formatLocalizedCurrency(entry.value, entry.key),
                        colorScheme: sheetColorScheme,
                        isSaving: savingCurrency == entry.key,
                        onTap: null,
                        isSeamless: true,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<String?> chooseNativeCurrency() {
      return MonekoBottomSheet.show<String>(
        context: context,
        title: context.l10n.selectCurrency,
        isScrollControlled: true,
        builder: (sheetContext) {
          final sheetColorScheme = Theme.of(sheetContext).colorScheme;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(sheetContext).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in nativeBudgets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CurrencyBudgetRow(
                        currency: entry.key,
                        amount: formatLocalizedCurrency(entry.value, entry.key),
                        colorScheme: sheetColorScheme,
                        isSaving: false,
                        onTap: () => Navigator.of(sheetContext).pop(entry.key),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<void> chooseNativeCurrencyBudget() async {
      final currencyBudgetChanged = onCurrencyBudgetChanged;
      if (currencyBudgetChanged == null || savingCurrency != null) return;

      final selectedCurrency = await chooseNativeCurrency();

      if (selectedCurrency == null || !context.mounted) return;

      MapEntry<String, double>? selectedBudget;
      for (final entry in nativeBudgets) {
        if (entry.key == selectedCurrency) {
          selectedBudget = entry;
          break;
        }
      }
      if (selectedBudget == null) return;
      final budget = selectedBudget;

      await _showBudgetInputSheet(
        context,
        currentAmount: budget.value,
        currencyCode: budget.key,
        onChanged: (amount) => currencyBudgetChanged(budget.key, amount),
      );
    }

    final Future<void> Function(String currency)? addPocketForCurrency =
        onAddPocketForCurrency;
    final hasAddPocketAction =
        onAddPocket != null || addPocketForCurrency != null;
    final VoidCallback? addPocketAction = addPocketForCurrency == null
        ? onAddPocket
        : isAddingPocket || savingCurrency != null
            ? null
            : () async {
                final selectedCurrency = await chooseNativeCurrency();
                if (selectedCurrency == null || !context.mounted) return;
                await addPocketForCurrency(selectedCurrency);
              };

    final VoidCallback? editBudgetAction = onCurrencyBudgetChanged == null
        ? editBudget
        : savingCurrency != null || isAddingPocket
            ? null
            : () => chooseNativeCurrencyBudget();

    final monthSelector = GestureDetector(
      onTap: () => _pickMonth(context),
      child: Container(
        constraints: isSeamless ? const BoxConstraints(minHeight: 48) : null,
        padding: isSeamless
            ? const EdgeInsets.symmetric(vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: isSeamless
            ? null
            : BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(100),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: isSeamless ? 12 : 13,
                    fontWeight: isSeamless ? FontWeight.w500 : FontWeight.w600,
                    color: isSeamless
                        ? subTextColor
                        : colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 11,
              color: isSeamless
                  ? subTextColor
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSeamless ? null : editBudget,
      child: Container(
        width: double.infinity,
        decoration: isSeamless
            ? null
            : BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.pocketHeaderBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.pocketHeaderShadow,
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
        padding: isSeamless
            ? const EdgeInsets.fromLTRB(8, 16, 8, 20)
            : const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              isSeamless ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (isSeamless)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    context.l10n.monthlyBudget,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ),
                  HeaderMonthLabel(
                    month: periodMonth,
                    textKey: const ValueKey('pockets-header-month-label'),
                  ),
                ],
              )
            else
              monthSelector,

            SizedBox(height: isSeamless ? 12 : 20),

            // Budget Amount Hero (spotlight target)
            KeyedSubtree(
              key: isSeamless ? null : amountSpotlightKey,
              child: Column(
                crossAxisAlignment: isSeamless
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (!isSeamless) ...[
                    Text(
                      context.l10n.monthlyBudget.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: isSeamless
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: isSeamless ? 48 : 52,
                            maxHeight:
                                MediaQuery.textScalerOf(context).scale(16) > 20
                                    ? double.infinity
                                    : isSeamless
                                        ? 48
                                        : 52,
                          ),
                          child: AnimatedSwitcher(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: FittedBox(
                              key: ValueKey(effectiveBudget),
                              fit: BoxFit.scaleDown,
                              alignment: isSeamless
                                  ? AlignmentDirectional.centerStart
                                  : Alignment.center,
                              child: Text(
                                formatLocalizedCurrency(effectiveBudget),
                                style: WidgetTextStyles.roundedNumber(
                                  Theme.of(context),
                                  baseStyle: TextStyle(
                                    fontSize: isSeamless ? 40 : 44,
                                    fontWeight: isSeamless
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: textColor,
                                    letterSpacing: isSeamless ? -1.2 : -1.6,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isSeamless &&
                          !showCurrencyBreakdown &&
                          onTotalChanged != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.pencil,
                          size: 14,
                          color: subTextColor,
                        ),
                      ],
                      if (isSeamless && !isSkeleton && showCurrencyBreakdown)
                        Tooltip(
                          message: context.l10n.pocketRolloverBreakdownTitle,
                          child: Semantics(
                            button: true,
                            label: context.l10n.pocketRolloverBreakdownTitle,
                            child: AdaptiveButton.child(
                              onPressed: showCurrencyBudgetBreakdown,
                              useNative: false,
                              style: AdaptiveButtonStyle.plain,
                              borderRadius: BorderRadius.circular(100),
                              minSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: subTextColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (showSlider && !isSkeleton) ...[
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor:
                      colorScheme.mutedForeground.withValues(alpha: 0.2),
                  trackHeight: 4,
                  thumbColor: colorScheme.primaryForeground,
                  overlayColor: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: SizedBox(
                  height: 32,
                  child: AdaptiveSlider(
                    activeColor: colorScheme.primary,
                    thumbColor: colorScheme.primaryForeground,
                    value: sliderValue,
                    min: sliderMin,
                    max: sliderMax,
                    divisions: sliderDivisions,
                    onChanged: onTotalChanged == null
                        ? null
                        : (value) {
                            final roundedValue =
                                ((value - sliderMin) / sliderStep).round() *
                                        sliderStep +
                                    sliderMin;
                            onTotalChanged!(
                              roundedValue
                                  .clamp(sliderMin, sliderMax)
                                  .toDouble(),
                            );
                          },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatLocalizedCurrency(sliderMin),
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
            ],

            if (!isSeamless)
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: !isSkeleton && showCurrencyBreakdown
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var index = 0;
                                index < nativeBudgets.length;
                                index++) ...[
                              _CurrencyBudgetRow(
                                key: ValueKey(
                                  'currency_budget_${nativeBudgets[index].key}',
                                ),
                                currency: nativeBudgets[index].key,
                                amount: formatLocalizedCurrency(
                                  nativeBudgets[index].value,
                                  nativeBudgets[index].key,
                                ),
                                colorScheme: colorScheme,
                                isSeamless: false,
                                isSaving:
                                    savingCurrency == nativeBudgets[index].key,
                                onTap: editCurrencyBudget(nativeBudgets[index]),
                              ),
                              if (index < nativeBudgets.length - 1)
                                const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

            if (isSeamless && showEditActions) ...[
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (hasAddPocketAction)
                      SeamlessHeaderAction(
                        key: const ValueKey('pocket_add_button'),
                        label: context.l10n.newPocketTitle,
                        icon: CupertinoIcons.plus,
                        onPressed: isSkeleton ? null : addPocketAction,
                        isLoading: isAddingPocket,
                      ),
                    if (hasAddPocketAction) const SizedBox(width: 12),
                    KeyedSubtree(
                      key: amountSpotlightKey,
                      child: SeamlessHeaderAction(
                        key: const ValueKey('budget_edit_button'),
                        label: context.l10n.editBudget,
                        icon: CupertinoIcons.pencil,
                        onPressed: isSkeleton ? null : editBudgetAction,
                        isLoading: onCurrencyBudgetChanged != null &&
                            savingCurrency != null,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (showSwipeHint && !isSkeleton) ...[
              const SizedBox(height: 16),
              SwipeHintRow(text: context.l10n.swipeRightPreviousMonths),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetInputSheet(
    BuildContext context, {
    required double currentAmount,
    required String currencyCode,
    required Future<void> Function(double amount) onChanged,
  }) async {
    final symbol = resolveCurrencySymbol(currencyCode);
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.monthlyBudget,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
        ],
      ),
    );

    final value = await showCalculatorKeypadSheet(
      context: context,
      initialValue: currentAmount == 0 ? '' : formatAmount(currentAmount),
      prefix: symbol,
      header: header,
    );
    if (value == null) return;

    final cents = tryParseMoneyToCents(value);
    final val = cents != null ? centsToAmount(cents) : null;
    if (val != null && val >= 0) {
      await onChanged(val);
    }
  }

  void _pickMonth(BuildContext context) {
    if (onDateSelected == null) return;

    final now = DateTime.now();
    final minDate = DateTime(2020);
    final normalizedFinancialStartDay =
        normalizeFinancialMonthStartDay(financialMonthStartDay);
    final maxDate = financialCycleStartForDate(
      now,
      startDay: normalizedFinancialStartDay,
    );
    DateTime tempDate = financialCycleStartForMonth(
      periodMonth,
      startDay: normalizedFinancialStartDay,
    );
    if (tempDate.isAfter(maxDate)) {
      tempDate = maxDate;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: colorScheme.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.cancel,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
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
                      final normalized = financialCycleStartForMonth(
                        tempDate,
                        startDay: normalizedFinancialStartDay,
                      );
                      onDateSelected!(normalized);
                      Navigator.pop(context);
                    },
                    child: Text(
                      context.l10n.done,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: tempDate,
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

class _CurrencyBudgetRow extends StatelessWidget {
  const _CurrencyBudgetRow({
    super.key,
    required this.currency,
    required this.amount,
    required this.colorScheme,
    required this.isSaving,
    required this.onTap,
    this.isSeamless = false,
  });

  final String currency;
  final String amount;
  final ColorScheme colorScheme;
  final bool isSaving;
  final VoidCallback? onTap;
  final bool isSeamless;

  @override
  Widget build(BuildContext context) {
    final flagPath = getCurrencyFlagPath(currency);
    return Semantics(
      button: !isSeamless,
      enabled: isSeamless ? null : onTap != null,
      label: '$currency $amount',
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: isSeamless ? null : onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSeamless ? 0 : 16,
              vertical: isSeamless ? 4 : 8,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      border: Border.all(
                        color: colorScheme.border.withValues(alpha: 0.25),
                      ),
                    ),
                    child: flagPath == null
                        ? Icon(
                            CupertinoIcons.money_dollar_circle,
                            size: 18,
                            color: colorScheme.mutedForeground,
                          )
                        : ClipOval(
                            child: Image.asset(
                              flagPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currency,
                    style: TextStyle(
                      fontSize: isSeamless ? 13 : 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: isSeamless ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!isSeamless) ...[
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isSaving
                          ? SizedBox(
                              key: const ValueKey('saving'),
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(
                              CupertinoIcons.chevron_forward,
                              key: const ValueKey('chevron'),
                              size: 13,
                              color: colorScheme.mutedForeground
                                  .withValues(alpha: 0.6),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatFinancialCycleLabel(
  BuildContext context,
  DateTime periodMonth,
  int financialMonthStartDay,
) {
  final period = financialCycleForMonth(
    periodMonth,
    startDay: financialMonthStartDay,
  );
  final now = DateTime.now();
  final includeStartYear = period.start.year != now.year;
  final includeEndYear =
      period.end.year != now.year || period.end.year != period.start.year;
  return '${formatLocalizedDate(context, period.start, includeYear: includeStartYear)} - '
      '${formatLocalizedDate(context, period.end, includeYear: includeEndYear)}';
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Frequency option for recurring transactions
class FrequencyOption {
  final String value;
  final String label;

  const FrequencyOption({
    required this.value,
    required this.label,
  });
}

/// A recurrence selection includes a frequency plus an optional interval.
///
/// Examples:
/// - Monthly: {frequency: 'monthly', interval: null}
/// - Every 3 months: {frequency: 'monthly', interval: 3}
class RecurrenceSelection {
  final String frequency;
  final int? interval;

  const RecurrenceSelection({
    required this.frequency,
    this.interval,
  });
}

enum RecurrenceIntervalUnit { days, weeks, months, years }

int recurrenceIntervalMaximum(RecurrenceIntervalUnit unit) {
  return 52;
}

int clampRecurrenceInterval(int number, RecurrenceIntervalUnit unit) {
  return number.clamp(1, recurrenceIntervalMaximum(unit)).toInt();
}

String recurrenceIntervalUnitFrequency(RecurrenceIntervalUnit unit) {
  return switch (unit) {
    RecurrenceIntervalUnit.days => 'daily',
    RecurrenceIntervalUnit.weeks => 'weekly',
    RecurrenceIntervalUnit.months => 'monthly',
    RecurrenceIntervalUnit.years => 'yearly',
  };
}

RecurrenceSelection recurrenceSelectionFromCustomInterval({
  required RecurrenceIntervalUnit unit,
  required int number,
}) {
  final safeNumber = clampRecurrenceInterval(number, unit);
  return RecurrenceSelection(
    frequency: recurrenceIntervalUnitFrequency(unit),
    interval: safeNumber == 1 ? null : safeNumber,
  );
}

/// Default frequency options for recurring transactions (hardcoded - DO NOT USE)
/// Use getDefaultFrequencyOptions(context) instead for localized labels
@Deprecated('Use getDefaultFrequencyOptions(context) for localized labels')
const List<FrequencyOption> defaultFrequencyOptions = [
  FrequencyOption(value: 'daily', label: 'Daily'),
  FrequencyOption(value: 'weekly', label: 'Weekly'),
  FrequencyOption(value: 'biweekly', label: 'Every 2 Weeks'),
  FrequencyOption(value: 'monthly', label: 'Monthly'),
  FrequencyOption(value: 'yearly', label: 'Yearly'),
];

/// Get localized frequency options
List<FrequencyOption> getDefaultFrequencyOptions(BuildContext context) {
  final l10n = context.l10n;
  return [
    FrequencyOption(value: 'daily', label: l10n.daily),
    FrequencyOption(value: 'weekly', label: l10n.weekly),
    FrequencyOption(value: 'biweekly', label: l10n.every2Weeks),
    FrequencyOption(value: 'monthly', label: l10n.monthly),
    FrequencyOption(value: 'yearly', label: l10n.yearly),
  ];
}

/// Shows a frequency picker for recurring transactions
///
/// This is a low-level widget that only handles showing the frequency
/// selection UI and returning the selected frequency. It has no knowledge
/// of what will be done with the selected frequency.
///
/// [context] - BuildContext for showing the modal
/// [currentFrequency] - Currently selected frequency value (e.g., 'monthly')
/// [frequencies] - Optional list of frequency options (defaults to localized options)
///
/// Returns the selected frequency value or null if cancelled
Future<String?> showFrequencyPicker({
  required BuildContext context,
  required String currentFrequency,
  List<FrequencyOption>? frequencies,
}) async {
  final options = frequencies ?? getDefaultFrequencyOptions(context);
  final values = options.map((f) => f.value).toList();
  final initial =
      values.contains(currentFrequency) ? currentFrequency : values.first;

  return await showTransactionSelectionSheet<String>(
    context: context,
    items: values,
    getLabel: (value) {
      final option = options.firstWhere((f) => f.value == value);
      return option.label;
    },
    initial: initial,
  );
}

String formatRecurrenceSelectionLabel(
  BuildContext context, {
  required String frequency,
  required int? interval,
}) {
  final l10n = context.l10n;
  final effectiveInterval = interval;
  switch (frequency) {
    case 'daily':
      return (effectiveInterval != null && effectiveInterval > 1)
          ? l10n.everyXDays(effectiveInterval)
          : l10n.daily;
    case 'weekly':
      return (effectiveInterval != null && effectiveInterval > 1)
          ? l10n.everyXWeeks(effectiveInterval)
          : l10n.weekly;
    case 'biweekly':
      return l10n.every2Weeks;
    case 'monthly':
      return (effectiveInterval != null && effectiveInterval > 1)
          ? l10n.everyXMonths(effectiveInterval)
          : l10n.monthly;
    case 'yearly':
      return (effectiveInterval != null && effectiveInterval > 1)
          ? l10n.everyXYears(effectiveInterval)
          : l10n.yearly;
    default:
      return l10n.unknown;
  }
}

/// Shows a picker that supports interval-based recurrences (e.g. every 3 months).
///
/// Returns null if cancelled.
Future<RecurrenceSelection?> showRecurrencePicker({
  required BuildContext context,
  required String currentFrequency,
  required int? currentInterval,
}) async {
  final options = <RecurrenceSelection>[
    const RecurrenceSelection(frequency: 'daily'),
    const RecurrenceSelection(frequency: 'weekly'),
    const RecurrenceSelection(frequency: 'biweekly'),
    const RecurrenceSelection(frequency: 'monthly'),
    const RecurrenceSelection(frequency: 'monthly', interval: 3),
    const RecurrenceSelection(frequency: 'monthly', interval: 6),
    const RecurrenceSelection(frequency: 'yearly'),
  ];

  String keyOf(RecurrenceSelection s) {
    final i = s.interval;
    return i == null ? s.frequency : '${s.frequency}:$i';
  }

  const customKey = 'custom';
  final values = [...options.map(keyOf), customKey];
  final currentKey = (currentInterval != null && currentInterval > 1)
      ? '$currentFrequency:$currentInterval'
      : currentFrequency;
  final hasArbitraryInterval = currentInterval != null &&
      currentInterval > 1 &&
      !options.any((option) =>
          option.frequency == currentFrequency &&
          option.interval == currentInterval);

  if (hasArbitraryInterval) {
    return _showCustomRecurrencePicker(
      context: context,
      currentFrequency: currentFrequency,
      currentInterval: currentInterval,
    );
  }

  final initial = values.contains(currentKey)
      ? currentKey
      : (values.contains(currentFrequency) ? currentFrequency : values.first);

  final selectedKey = await showTransactionSelectionSheet<String>(
    context: context,
    items: values,
    getLabel: (value) {
      final parts = value.split(':');
      final freq = parts.first;
      final interval = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
      if (value == customKey) return '${context.l10n.custom}...';
      return formatRecurrenceSelectionLabel(
        context,
        frequency: freq,
        interval: interval,
      );
    },
    initial: initial,
    opensInlineContent: (value) => value == customKey,
    inlineContentBuilder: (sheetContext) => _CustomRecurrencePicker(
      initialUnit: _unitForFrequency(currentFrequency),
      initialNumber: currentInterval != null && currentInterval > 0
          ? currentInterval
          : currentFrequency == 'biweekly'
              ? 2
              : 1,
      onCancel: () => Navigator.pop<String>(sheetContext),
      onDone: (selection) => Navigator.pop<String>(
        sheetContext,
        keyOf(selection),
      ),
    ),
  );

  if (selectedKey == null) return null;

  final parts = selectedKey.split(':');
  final freq = parts.first;
  final interval = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
  return RecurrenceSelection(frequency: freq, interval: interval);
}

RecurrenceIntervalUnit _unitForFrequency(String frequency) {
  return switch (frequency) {
    'weekly' || 'biweekly' => RecurrenceIntervalUnit.weeks,
    'monthly' => RecurrenceIntervalUnit.months,
    'yearly' => RecurrenceIntervalUnit.years,
    _ => RecurrenceIntervalUnit.days,
  };
}

String _unitLabel(
  BuildContext context,
  RecurrenceIntervalUnit unit,
  int count,
) {
  return switch (unit) {
    RecurrenceIntervalUnit.days => context.l10n.recurrenceDaysUnit(count),
    RecurrenceIntervalUnit.weeks => context.l10n.recurrenceWeeksUnit(count),
    RecurrenceIntervalUnit.months => context.l10n.recurrenceMonthsUnit(count),
    RecurrenceIntervalUnit.years => context.l10n.recurrenceYearsUnit(count),
  };
}

String _intervalLabel(
  BuildContext context,
  RecurrenceIntervalUnit unit,
  int number,
) {
  return '$number ${_unitLabel(context, unit, number)}';
}

String _capitalizedUnitLabel(
  BuildContext context,
  RecurrenceIntervalUnit unit,
) {
  final label = _unitLabel(context, unit, 2);
  return '${label[0].toUpperCase()}${label.substring(1)}';
}

Future<RecurrenceSelection?> _showCustomRecurrencePicker({
  required BuildContext context,
  required String currentFrequency,
  required int? currentInterval,
}) {
  final unit = _unitForFrequency(currentFrequency);
  final number = currentInterval != null && currentInterval > 0
      ? currentInterval
      : currentFrequency == 'biweekly'
          ? 2
          : 1;
  final picker = _CustomRecurrencePicker(
    initialUnit: unit,
    initialNumber: number,
  );
  return showModalBottomSheet<RecurrenceSelection>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => picker,
  );
}

class _CustomRecurrencePicker extends HookWidget {
  static const _maximumWheelNumber = 52;

  final RecurrenceIntervalUnit initialUnit;
  final int initialNumber;
  final VoidCallback? onCancel;
  final ValueChanged<RecurrenceSelection>? onDone;

  const _CustomRecurrencePicker({
    required this.initialUnit,
    required this.initialNumber,
    this.onCancel,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final selectedUnit = useState(initialUnit);
    final selectedNumber = useState(
      initialNumber.clamp(1, _maximumWheelNumber).toInt(),
    );
    final numbers =
        List<int>.generate(_maximumWheelNumber, (index) => index + 1);
    final numberController = useMemoized(
      () => FixedExtentScrollController(
        initialItem: numbers.indexOf(selectedNumber.value),
      ),
      const [],
    );
    final unitController = useMemoized(
      () => FixedExtentScrollController(initialItem: initialUnit.index),
      const [],
    );

    useEffect(() => numberController.dispose, [numberController]);
    useEffect(() => unitController.dispose, [unitController]);

    void selectUnit(int index) {
      final nextUnit = RecurrenceIntervalUnit.values[index];
      selectedUnit.value = nextUnit;
      final clampedNumber = clampRecurrenceInterval(
        selectedNumber.value,
        nextUnit,
      ).clamp(1, _maximumWheelNumber).toInt();
      selectedNumber.value = clampedNumber;
      numberController.animateToItem(
        clampedNumber - 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }

    Widget buildNumberWheel() {
      final wheel = PlatformInfo.isIOS
          ? CupertinoPicker(
              scrollController: numberController,
              itemExtent: 44,
              onSelectedItemChanged: (index) {
                selectedNumber.value = numbers[index];
              },
              children: numbers
                  .map((number) => Center(child: Text('$number')))
                  .toList(),
            )
          : ListWheelScrollView.useDelegate(
              controller: numberController,
              itemExtent: 44,
              onSelectedItemChanged: (index) {
                selectedNumber.value = numbers[index];
              },
              childDelegate: ListWheelChildListDelegate(
                children: numbers
                    .map((number) => Center(child: Text('$number')))
                    .toList(),
              ),
            );
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: wheel,
      );
    }

    Widget buildUnitWheel() {
      final labels = RecurrenceIntervalUnit.values
          .map((unit) =>
              Center(child: Text(_capitalizedUnitLabel(context, unit))))
          .toList();
      return PlatformInfo.isIOS
          ? CupertinoPicker(
              scrollController: unitController,
              itemExtent: 44,
              onSelectedItemChanged: selectUnit,
              children: labels,
            )
          : ListWheelScrollView.useDelegate(
              controller: unitController,
              itemExtent: 44,
              onSelectedItemChanged: selectUnit,
              childDelegate: ListWheelChildListDelegate(
                children: labels,
              ),
            );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final intervalLabel = Text(
      _intervalLabel(context, selectedUnit.value, selectedNumber.value),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.foreground,
            fontWeight: FontWeight.w600,
          ),
    );
    final cancelButton = TextButton(
      onPressed: onCancel ?? () => Navigator.pop(context),
      child: Text(context.l10n.cancel),
    );
    final doneButton = TextButton(
      onPressed: () {
        final selection = recurrenceSelectionFromCustomInterval(
          unit: selectedUnit.value,
          number: selectedNumber.value,
        );
        final callback = onDone;
        if (callback != null) {
          callback(selection);
        } else {
          Navigator.pop(context, selection);
        }
      },
      child: Text(context.l10n.done),
    );
    final usesLargeTextLayout = MediaQuery.textScalerOf(context).scale(16) > 20;
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: usesLargeTextLayout
                    ? Column(
                        key: const ValueKey('large-text-picker-header'),
                        children: [
                          Row(
                            children: [
                              cancelButton,
                              const Spacer(),
                              doneButton,
                            ],
                          ),
                          intervalLabel,
                        ],
                      )
                    : Row(
                        key: const ValueKey('picker-header'),
                        children: [
                          cancelButton,
                          Expanded(child: intervalLabel),
                          doneButton,
                        ],
                      ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildNumberWheel()),
                  Expanded(child: buildUnitWheel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

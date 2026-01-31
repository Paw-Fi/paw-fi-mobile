import 'package:flutter/material.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';

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
    const RecurrenceSelection(frequency: 'yearly'),
  ];

  String keyOf(RecurrenceSelection s) {
    final i = s.interval;
    return i == null ? s.frequency : '${s.frequency}:$i';
  }

  final values = options.map(keyOf).toList();
  final currentKey = (currentInterval != null && currentInterval > 1)
      ? '$currentFrequency:$currentInterval'
      : currentFrequency;
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
      return formatRecurrenceSelectionLabel(
        context,
        frequency: freq,
        interval: interval,
      );
    },
    initial: initial,
  );

  if (selectedKey == null) return null;

  final parts = selectedKey.split(':');
  final freq = parts.first;
  final interval = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
  return RecurrenceSelection(frequency: freq, interval: interval);
}

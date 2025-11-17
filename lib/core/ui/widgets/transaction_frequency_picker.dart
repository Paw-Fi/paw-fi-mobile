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
  final initial = values.contains(currentFrequency) ? currentFrequency : values.first;

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

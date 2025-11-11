import 'package:flutter/material.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';

/// Frequency option for recurring transactions
class FrequencyOption {
  final String value;
  final String label;

  const FrequencyOption({
    required this.value,
    required this.label,
  });
}

/// Default frequency options for recurring transactions
const List<FrequencyOption> defaultFrequencyOptions = [
  FrequencyOption(value: 'daily', label: 'Daily'),
  FrequencyOption(value: 'weekly', label: 'Weekly'),
  FrequencyOption(value: 'biweekly', label: 'Every 2 Weeks'),
  FrequencyOption(value: 'monthly', label: 'Monthly'),
  FrequencyOption(value: 'yearly', label: 'Yearly'),
];

/// Shows a frequency picker for recurring transactions
/// 
/// This is a low-level widget that only handles showing the frequency
/// selection UI and returning the selected frequency. It has no knowledge
/// of what will be done with the selected frequency.
/// 
/// [context] - BuildContext for showing the modal
/// [currentFrequency] - Currently selected frequency value (e.g., 'monthly')
/// [frequencies] - Optional list of frequency options (defaults to defaultFrequencyOptions)
/// 
/// Returns the selected frequency value or null if cancelled
Future<String?> showFrequencyPicker({
  required BuildContext context,
  required String currentFrequency,
  List<FrequencyOption>? frequencies,
}) async {
  final options = frequencies ?? defaultFrequencyOptions;
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

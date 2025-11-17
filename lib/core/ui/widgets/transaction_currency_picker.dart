import 'package:flutter/material.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/features/utils/currency.dart';

/// Shows a currency picker for selecting transaction currency
/// 
/// This is a low-level widget that only handles showing the currency
/// selection UI and returning the selected currency code. It has no
/// knowledge of what will be done with the selected currency.
/// 
/// [context] - BuildContext for showing the modal
/// [currentCurrency] - Currently selected currency code (e.g., 'USD')
/// 
/// Returns the selected currency code or null if cancelled
Future<String?> showCurrencyPicker({
  required BuildContext context,
  required String currentCurrency,
}) async {
  final options = getAvailableCurrencyOptions();
  final codes = options.keys.toList()..sort();
  final current = currentCurrency.toUpperCase();
  final initial = codes.contains(current) ? current : codes.first;

  return await showTransactionSelectionSheet<String>(
    context: context,
    items: codes,
    getLabel: (code) => '$code  ${options[code]}',
    initial: initial,
  );
}

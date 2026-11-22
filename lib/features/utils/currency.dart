import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

import 'currency_codes.dart';
export 'currency_codes.dart';

String getCurrencySymbol(UserContact? contact) {
  return resolveCurrencySymbol(contact?.preferredCurrency);
}

Map<String, String> getAvailableCurrencyOptions() {
  return Map.unmodifiable(currencyOptions);
}

/// Formats a monetary amount with smart decimal handling:
/// - Whole numbers show without decimals (e.g., 50.00 → "50")
/// - Numbers with cents show 2 decimals (e.g., 50.25 → "50.25")
///
/// Examples:
/// - formatAmount(50.0) → "50"
/// - formatAmount(50.5) → "50.50"
/// - formatAmount(50.25) → "50.25"
/// - formatAmount(0.0) → "0"
String formatAmount(double amount) {
  final roundedAmount = (amount * 100).round() / 100;

  // Check if the rounded amount is a whole number.
  if (roundedAmount == roundedAmount.truncate()) {
    // No decimal places needed
    return roundedAmount.truncate().toString();
  } else {
    // Show 2 decimal places
    return roundedAmount.toStringAsFixed(2);
  }
}

String _formatAmountWithGrouping(double amount) {
  final roundedAmount = (amount * 100).round() / 100;
  final normalizedAmount = roundedAmount == 0 ? 0.0 : roundedAmount;
  final hasFraction = normalizedAmount != normalizedAmount.truncateToDouble();

  try {
    final formatter = NumberFormat.decimalPattern();
    formatter
      ..minimumFractionDigits = hasFraction ? 2 : 0
      ..maximumFractionDigits = hasFraction ? 2 : 0;
    return formatter.format(normalizedAmount);
  } catch (_) {
    return formatAmount(amount);
  }
}

/// Formats a monetary amount with currency symbol and smart decimal handling
///
/// Examples:
/// - formatCurrency(50.0, 'USD') → "$50"
/// - formatCurrency(50.25, 'USD') → "$50.25"
/// - formatCurrency(1000.5, 'EUR') → "€1,000.50"
String formatCurrency(
  double amount,
  String? currencyCode, {
  BuildContext? context,
}) {
  final symbol = resolveCurrencySymbol(currencyCode);
  final formattedAmount = context == null
      ? _formatAmountWithGrouping(amount)
      : formatLocalizedNumber(context, amount);
  return '$symbol$formattedAmount';
}

/// Compact currency labels for charts; use [formatCurrency] in exact tooltips.
String formatCompactCurrency(
  double amount,
  String? currencyCode, {
  BuildContext? context,
}) {
  final formattedAmount = context == null
      ? formatCompactNumber(amount)
      : formatLocalizedCompactNumber(context, amount);
  return '${resolveCurrencySymbol(currencyCode)}$formattedAmount';
}

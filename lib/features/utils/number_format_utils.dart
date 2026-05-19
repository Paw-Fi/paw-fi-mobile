import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';

import 'package:moneko/core/utils/intl_locale.dart';

String formatLocalizedNumber(BuildContext context, num value) {
  // Use the current Flutter Locale instead of the AppLocalizations instance
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
  final localeName = intlSafeLocaleName(locale);
  final roundedValue = _roundToTwoDecimals(value);
  final hasFraction = roundedValue != roundedValue.truncateToDouble();

  try {
    final formatter = NumberFormat.decimalPattern(localeName);
    formatter
      ..minimumFractionDigits = hasFraction ? 2 : 0
      ..maximumFractionDigits = hasFraction ? 2 : 0;
    return formatter.format(roundedValue);
  } catch (_) {
    // Fallback to default locale if a specific one is not available
    final formatter = NumberFormat.decimalPattern();
    formatter
      ..minimumFractionDigits = hasFraction ? 2 : 0
      ..maximumFractionDigits = hasFraction ? 2 : 0;
    return formatter.format(roundedValue);
  }
}

double _roundToTwoDecimals(num value) => (value * 100).round() / 100;

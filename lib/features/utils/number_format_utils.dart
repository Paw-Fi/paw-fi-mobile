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

/// Short chart notation using the locale's units (K, 万, 만, etc.).
/// This rounds the label only; financial totals and tooltip values stay exact.
String formatCompactNumber(num value, {Locale locale = const Locale('en')}) {
  final normalizedValue = value == 0 ? 0 : value;
  final isSmallValue = normalizedValue.abs() < 1000;
  NumberFormat formatter;
  try {
    final localeName = intlSafeLocaleName(locale);
    formatter = isSmallValue
        ? NumberFormat.decimalPattern(localeName)
        : NumberFormat.compact(locale: localeName);
  } on ArgumentError {
    formatter = isSmallValue
        ? NumberFormat.decimalPattern('en')
        : NumberFormat.compact(locale: 'en');
  }
  formatter
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = isSmallValue ? 2 : 1;

  // CLDR leaves German thousands unshortened. Use the familiar native chart
  // abbreviation, and carry rounded 1000-thousand values into the million unit.
  if (formatter.locale.split('_').first == 'de' &&
      normalizedValue.abs() >= 1000 &&
      normalizedValue.abs() < 1000000) {
    final thousands = (normalizedValue / 100).round() / 10;
    if (thousands.abs() >= 1000) return formatter.format(thousands * 1000);
    final decimal = NumberFormat.decimalPattern(formatter.locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 1;
    return '${decimal.format(thousands)}\u00a0Tsd.';
  }
  return formatter.format(normalizedValue);
}

String formatLocalizedCompactNumber(BuildContext context, num value) =>
    formatCompactNumber(value,
        locale: Localizations.maybeLocaleOf(context) ?? const Locale('en'));

double _roundToTwoDecimals(num value) => (value * 100).round() / 100;

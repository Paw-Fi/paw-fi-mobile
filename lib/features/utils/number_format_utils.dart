import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';

import 'package:moneko/core/utils/intl_locale.dart';

String formatLocalizedNumber(BuildContext context, num value) {
  // Use the current Flutter Locale instead of the AppLocalizations instance
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
  final localeName = intlSafeLocaleName(locale);

  try {
    final formatter = NumberFormat.decimalPattern(localeName);
    return formatter.format(value);
  } catch (_) {
    // Fallback to default locale if a specific one is not available
    return NumberFormat.decimalPattern().format(value);
  }
}

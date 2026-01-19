import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';

String formatLocalizedNumber(BuildContext context, num value) {
  // Use the current Flutter Locale instead of the AppLocalizations instance
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
  String language = locale.languageCode.toLowerCase();
  String country = (locale.countryCode ?? '').toUpperCase();

  // Handle packed codes like "zh_tw" or "zh-tw" coming from languageCode
  if (language.contains('_') || language.contains('-')) {
    final parts = language.split(RegExp(r'[_-]'));
    language = parts[0];
    if (parts.length > 1 && country.isEmpty) {
      country = parts[1].toUpperCase();
    }
  }

  // Map app-specific codes to canonical intl locales
  // kr → ko_KR, zh/zh_tw → zh or zh_TW
  if (language == 'kr') {
    language = 'ko';
    if (country.isEmpty) {
      country = 'KR';
    }
  }

  if (language == 'zh' && country == 'TW') {
    country = 'TW';
  }

  final localeName = country.isEmpty ? language : '${language}_$country';

  try {
    final formatter = NumberFormat.decimalPattern(localeName);
    return formatter.format(value);
  } catch (_) {
    // Fallback to default locale if a specific one is not available
    return NumberFormat.decimalPattern().format(value);
  }
}

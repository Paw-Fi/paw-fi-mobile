import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats a date with localized month names and proper format for the user's language.
///
/// Examples:
/// - English:  "Dec 11" or "Dec 11, 2024"
/// - Chinese:  "12月11日" or "2024年12月11日"
/// - Spanish:  "11 dic" or "11 dic 2024"
String formatLocalizedDate(
  BuildContext context,
  DateTime date, {
  bool includeYear = false,
}) {
  final locale = Localizations.localeOf(context);

  // Normalize language code for special cases (e.g. custom locales)
  final languageCode = _normalizeLanguageCode(locale.languageCode.toLowerCase());
  final intlLocale = _resolveIntlLocale(locale, languageCode);

  try {
    // Use DateFormat with locale for automatic month name localization
    final pattern = includeYear
        ? _getDatePatternWithYear(languageCode)
        : _getDatePatternWithoutYear(languageCode);

    return DateFormat(pattern, intlLocale).format(date);
  } catch (e) {
    debugPrint('Locale-specific date formatting failed: $e');

    try {
      // Fallback to just the normalized language code (no country)
      final pattern = includeYear
          ? _getDatePatternWithYear(languageCode)
          : _getDatePatternWithoutYear(languageCode);

      return DateFormat(pattern, languageCode).format(date);
    } catch (e2) {
      debugPrint('Generic date formatting failed: $e2');

      // Ultimate fallback: manual formatting
      return _manualFormatDate(date, languageCode, includeYear);
    }
  }
}

/// Formats just the month name localized for the user's language.
///
/// Examples (abbreviated):
/// - English: "Dec"
/// - German: "Dez"
/// - Chinese: "12月"
/// - Korean: "12월"
String formatLocalizedMonth(
  BuildContext context,
  DateTime date, {
  bool abbreviated = true,
}) {
  final locale = Localizations.localeOf(context);
  final languageCode = _normalizeLanguageCode(locale.languageCode.toLowerCase());
  final intlLocale = _resolveIntlLocale(locale, languageCode);

  final pattern = _getMonthPattern(languageCode, abbreviated);

  try {
    return DateFormat(pattern, intlLocale).format(date);
  } catch (e) {
    try {
      return DateFormat(pattern, languageCode).format(date);
    } catch (_) {
      return _manualFormatMonth(date, languageCode, abbreviated);
    }
  }
}

String _getMonthPattern(String languageCode, bool abbreviated) {
  switch (languageCode) {
    // East Asian styles prefer numeric month with marker
    case 'zh':
    case 'ja':
      return 'M月';
    case 'ko':
      return 'M월';
    default:
      return abbreviated ? 'MMM' : 'MMMM';
  }
}

String _manualFormatMonth(DateTime date, String languageCode, bool abbreviated) {
  // English abbreviations/full names as ultimate fallback
  const monthAbbr = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const monthFull = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  switch (languageCode) {
    case 'zh':
    case 'ja':
      return '${date.month}月';
    case 'ko':
      return '${date.month}월';
    default:
      return abbreviated ? monthAbbr[date.month - 1] : monthFull[date.month - 1];
  }
}

/// Normalize non-standard language codes to ones supported by intl.
///
/// - "pks" is a custom code in your app but content is Urdu,
///   so map it to "ur" for date formatting.
String _normalizeLanguageCode(String languageCode) {
  switch (languageCode) {
    case 'pks':
      return 'ur';
    default:
      return languageCode;
  }
}

/// Build the locale string used by intl, preserving country code
/// but using the normalized language code.
String _resolveIntlLocale(Locale locale, String normalizedLanguageCode) {
  final countryCode = locale.countryCode;
  if (countryCode == null || countryCode.isEmpty) {
    return normalizedLanguageCode;
  }
  return '${normalizedLanguageCode}_$countryCode';
}

/// Get date pattern with year for different languages.
String _getDatePatternWithYear(String languageCode) {
  switch (languageCode) {
    // Chinese, Japanese, Korean - Year Month Day
    case 'zh':
      return 'yyyy年M月d日'; // 2024年12月11日
    case 'ja':
      return 'yyyy年M月d日'; // 2024年12月11日
    case 'ko':
      return 'yyyy년 M월 d일'; // 2024년 12월 11일

    // Most European-style DMY (Day Month Year with abbreviated month)
    case 'es':
    case 'fr':
    case 'it':
    case 'pt':
    case 'de':
    case 'nl':
    case 'sv':
    case 'no':
    case 'da':
    case 'ru':
    case 'pl':
    case 'cs':
    case 'sk':
    case 'vi': // added
    case 'uk': // added
      return 'd MMM yyyy'; // 11 dic 2024, 11 déc 2024, etc.

    // Arabic-script and related - Day Month Year
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      return 'd MMM yyyy';

    // English and default - Month Day, Year
    case 'en':
    default:
      return 'MMM d, yyyy'; // Dec 11, 2024
  }
}

/// Get date pattern without year for different languages.
String _getDatePatternWithoutYear(String languageCode) {
  switch (languageCode) {
    // Chinese, Japanese, Korean - Month Day
    case 'zh':
      return 'M月d日'; // 12月11日
    case 'ja':
      return 'M月d日'; // 12月11日
    case 'ko':
      return 'M월 d일'; // 12월 11일

    // Most European-style DMY - Day Month
    case 'es':
    case 'fr':
    case 'it':
    case 'pt':
    case 'de':
    case 'nl':
    case 'sv':
    case 'no':
    case 'da':
    case 'ru':
    case 'pl':
    case 'cs':
    case 'sk':
    case 'vi': // added
    case 'uk': // added
      return 'd MMM'; // 11 dic, 11 déc, etc.

    // Arabic-script and related - Day Month
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      return 'd MMM';

    // English and default - Month Day
    case 'en':
    default:
      return 'MMM d'; // Dec 11
  }
}

/// Manual fallback date formatting when DateFormat fails completely.
///
/// Uses English month abbreviations as a last resort. This should be rare.
String _manualFormatDate(
  DateTime date,
  String languageCode,
  bool includeYear,
) {
  // Month abbreviations fallback (English only as ultimate fallback)
  const monthAbbr = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  switch (languageCode) {
    case 'zh':
    case 'ja':
    case 'ko':
      if (includeYear) {
        return '${date.year}年${date.month}月${date.day}日';
      } else {
        return '${date.month}月${date.day}日';
      }

    // Treat these as Day Month (English month abbr as last fallback)
    case 'es':
    case 'fr':
    case 'it':
    case 'pt':
    case 'de':
    case 'nl':
    case 'sv':
    case 'no':
    case 'da':
    case 'ru':
    case 'pl':
    case 'cs':
    case 'sk':
    case 'vi':
    case 'uk':
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      if (includeYear) {
        return '${date.day} ${monthAbbr[date.month - 1]} ${date.year}';
      } else {
        return '${date.day} ${monthAbbr[date.month - 1]}';
      }

    // English and default - Month Day
    case 'en':
    default:
      if (includeYear) {
        return '${monthAbbr[date.month - 1]} ${date.day}, ${date.year}';
      } else {
        return '${monthAbbr[date.month - 1]} ${date.day}';
      }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Formats a date with localized month names and proper format for the user's language
/// 
/// Examples:
/// - English: "Dec 11" or "Dec 11, 2024"
/// - Chinese: "12月11日" or "2024年12月11日"
/// - Spanish: "11 dic" or "11 dic 2024"
String formatLocalizedDate(BuildContext context, DateTime date, {bool includeYear = false}) {
  final locale = Localizations.localeOf(context);
  final languageCode = locale.languageCode.toLowerCase();
  
  try {
    // Use DateFormat with locale for automatic month name localization
    String pattern;
    
    if (includeYear) {
      // Pattern with year
      pattern = _getDatePatternWithYear(languageCode);
    } else {
      // Pattern without year
      pattern = _getDatePatternWithoutYear(languageCode);
    }
    
    return DateFormat(pattern, locale.toString()).format(date);
  } catch (e) {
    debugPrint('Locale-specific date formatting failed: $e');
    
    try {
      // Fallback to locale without country code
      String pattern;
      if (includeYear) {
        pattern = _getDatePatternWithYear(languageCode);
      } else {
        pattern = _getDatePatternWithoutYear(languageCode);
      }
      return DateFormat(pattern, languageCode).format(date);
    } catch (e2) {
      debugPrint('Generic date formatting failed: $e2');
      
      // Ultimate fallback: manual formatting
      return _manualFormatDate(date, languageCode, includeYear);
    }
  }
}

/// Get date pattern with year for different languages
String _getDatePatternWithYear(String languageCode) {
  switch (languageCode) {
    // Chinese, Japanese, Korean - Year Month Day
    case 'zh':
      return 'yyyy年M月d日'; // 2024年12月11日
    case 'ja':
      return 'yyyy年M月d日'; // 2024年12月11日
    case 'ko':
      return 'yyyy년 M월 d일'; // 2024년 12월 11일
    
    // Most European languages - Day Month Year (abbreviated month)
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
      return 'd MMM yyyy'; // 11 dic 2024, 11 déc 2024, etc.
    
    // Arabic and related - Day Month Year
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      return 'd MMM yyyy';
    
    // English and similar - Month Day, Year
    case 'en':
    default:
      return 'MMM d, yyyy'; // Dec 11, 2024
  }
}

/// Get date pattern without year for different languages
String _getDatePatternWithoutYear(String languageCode) {
  switch (languageCode) {
    // Chinese, Japanese, Korean - Month Day
    case 'zh':
      return 'M月d日'; // 12月11日
    case 'ja':
      return 'M月d日'; // 12月11日
    case 'ko':
      return 'M월 d일'; // 12월 11일
    
    // Most European languages - Day Month (abbreviated)
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
      return 'd MMM'; // 11 dic, 11 déc, etc.
    
    // Arabic and related - Day Month
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      return 'd MMM';
    
    // English and similar - Month Day
    case 'en':
    default:
      return 'MMM d'; // Dec 11
  }
}

/// Manual fallback date formatting when DateFormat fails
String _manualFormatDate(DateTime date, String languageCode, bool includeYear) {
  // Month abbreviations fallback (English only as ultimate fallback)
  const monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  switch (languageCode) {
    case 'zh':
    case 'ja':
    case 'ko':
      if (includeYear) {
        return '${date.year}年${date.month}月${date.day}日';
      } else {
        return '${date.month}月${date.day}日';
      }
    
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
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      if (includeYear) {
        return '${date.day} ${monthAbbr[date.month - 1]} ${date.year}';
      } else {
        return '${date.day} ${monthAbbr[date.month - 1]}';
      }
    
    case 'en':
    default:
      if (includeYear) {
        return '${monthAbbr[date.month - 1]} ${date.day}, ${date.year}';
      } else {
        return '${monthAbbr[date.month - 1]} ${date.day}';
      }
  }
}

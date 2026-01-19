import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Fallback localization delegate for unsupported locales
/// Provides English-based Material and Cupertino localizations
/// for locales that don't have built-in support (like ur)
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    // Support all locales, providing English fallback
    return true;
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Always return English localizations as fallback
    return DefaultMaterialLocalizations.load(const Locale('en', 'US'));
  }

  @override
  bool shouldReload(LocalizationsDelegate<MaterialLocalizations> old) {
    return false;
  }
}

class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    // Support all locales, providing English fallback
    return true;
  }

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    // Always return English localizations as fallback
    return DefaultCupertinoLocalizations.load(const Locale('en', 'US'));
  }

  @override
  bool shouldReload(LocalizationsDelegate<CupertinoLocalizations> old) {
    return false;
  }
}

/// Custom localization resolution callback
/// Returns the locale if supported, otherwise returns a fallback
Locale? _localeResolutionCallback(
    Locale? locale, Iterable<Locale> supportedLocales) {
  if (locale == null) {
    return supportedLocales.first;
  }

  // 1) Exact match: language + (optional) country
  for (final supported in supportedLocales) {
    if (supported.languageCode == locale.languageCode &&
        (supported.countryCode == null ||
            supported.countryCode == locale.countryCode)) {
      return supported;
    }
  }

  // 2) Language-only match
  final languageOnly = supportedLocales.firstWhere(
    (l) => l.languageCode == locale.languageCode,
    orElse: () => const Locale('@@__no_match__@@'),
  );
  if (languageOnly.languageCode != '@@__no_match__@@') {
    return languageOnly;
  }

  // 3) Common alias fixes (map device language to our supported set)
  // e.g., device uses 'ko' but our bundle is 'kr'
  final aliasMap = <String, String>{
    'ko': 'kr',
  };
  final alias = aliasMap[locale.languageCode];
  if (alias != null) {
    final aliasMatch = supportedLocales.firstWhere(
      (l) => l.languageCode == alias,
      orElse: () => const Locale('@@__no_alias__@@'),
    );
    if (aliasMatch.languageCode != '@@__no_alias__@@') {
      return aliasMatch;
    }
  }

  // 4) Default to English to ensure AppLocalizations is always present
  final english = supportedLocales.firstWhere(
    (l) => l.languageCode == 'en',
    orElse: () => supportedLocales.first,
  );
  return english;
}

/// Get the locale resolution callback for the app
LocaleResolutionCallback get localeResolutionCallback =>
    _localeResolutionCallback;

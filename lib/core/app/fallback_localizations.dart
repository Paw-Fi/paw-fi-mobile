import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Fallback localization delegate for unsupported locales
/// Provides English-based Material and Cupertino localizations
/// for locales that don't have built-in support (like pks)
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
Locale? _localeResolutionCallback(Locale? locale, Iterable<Locale> supportedLocales) {
  if (locale == null) {
    return supportedLocales.first;
  }
  
  // Check if the locale is directly supported
  for (final supportedLocale in supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode &&
        (supportedLocale.countryCode == null || 
         supportedLocale.countryCode == locale.countryCode)) {
      return locale;
    }
  }
  
  // For unsupported locales like 'pks', return the locale anyway
  // Our fallback delegates will handle the Material/Cupertino localizations
  return locale;
}

/// Get the locale resolution callback for the app
LocaleResolutionCallback get localeResolutionCallback => _localeResolutionCallback;

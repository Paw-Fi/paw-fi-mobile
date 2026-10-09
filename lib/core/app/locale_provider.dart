import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/utils/intl_locale.dart';

const localePreferenceStorageKey = 'moneko_locale';

Locale normalizeAppLocale(Locale locale) {
  final lc = locale.languageCode.toLowerCase();
  final cc = (locale.countryCode ?? '').toUpperCase();
  if (lc == 'cn') {
    return const Locale('zh');
  }
  if (lc == 'kr') {
    return const Locale('ko');
  }
  if (lc == 'zh' && cc.isEmpty) {
    return const Locale('zh');
  }
  return Locale(lc, cc.isEmpty ? null : cc);
}

Locale resolveSupportedAppLocale(
  Locale? locale, {
  Iterable<Locale> supportedLocales = AppLocalizations.supportedLocales,
}) {
  locale ??= ui.PlatformDispatcher.instance.locale;

  final normalized = normalizeAppLocale(locale);

  for (final supported in supportedLocales) {
    if (supported.languageCode == normalized.languageCode &&
        supported.countryCode == normalized.countryCode) {
      return supported;
    }
  }

  for (final supported in supportedLocales) {
    if (supported.languageCode == normalized.languageCode &&
        supported.countryCode == null) {
      return supported;
    }
  }

  for (final supported in supportedLocales) {
    if (supported.languageCode == normalized.languageCode) {
      return supported;
    }
  }

  const aliasMap = <String, String>{'kr': 'ko'};
  final alias = aliasMap[normalized.languageCode];
  if (alias != null) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == alias) {
        return supported;
      }
    }
  }

  for (final supported in supportedLocales) {
    if (supported.languageCode == 'en') {
      return supported;
    }
  }

  return supportedLocales.first;
}

Locale currentDeviceLocale() =>
    resolveSupportedAppLocale(ui.PlatformDispatcher.instance.locale);

/// Preserves compatible regional formats and falls back to the supported UI
/// locale when intl has no date/number data for the requested language.
Future<void> initializeAppDateFormatting(Locale? locale) {
  final requestedLocale = locale ?? ui.PlatformDispatcher.instance.locale;
  final requestedName = intlSafeLocaleName(requestedLocale);
  final fallbackName =
      intlSafeLocaleName(resolveSupportedAppLocale(requestedLocale));
  // The bundled initializer loads every locale without validating its argument.
  final initialization = initializeDateFormatting();
  final localeName = intl.Intl.verifiedLocale(
        requestedName,
        (name) =>
            intl.DateFormat.localeExists(name) &&
            numberFormatSymbols.containsKey(name),
        onFailure: (_) => fallbackName,
      ) ??
      fallbackName;
  intl.Intl.defaultLocale = localeName;
  return initialization;
}

Locale _resolveLocalePreference(Locale locale) {
  final normalized = normalizeAppLocale(locale);
  final supported = resolveSupportedAppLocale(normalized);
  // Generated localizations accept regional variants of supported languages.
  return normalized.languageCode == supported.languageCode
      ? normalized
      : supported;
}

String? preferredLanguageCodeFromLocale(Locale? locale) {
  if (locale == null) return null;
  final languageCode =
      normalizeAppLocale(locale).languageCode.trim().toLowerCase();
  if (languageCode.isEmpty) return null;
  if (languageCode == 'cn') return 'zh';
  if (languageCode == 'kr') return 'ko';
  return languageCode;
}

Future<Locale?> loadStoredLocalePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(localePreferenceStorageKey);
  if (value == null || value.isEmpty || value == 'system') {
    return null;
  }
  final parts = value.split('_');
  final loaded =
      parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  return _resolveLocalePreference(loaded);
}

Future<Locale> resolveEffectiveAppLocale() async {
  final storedLocale = await loadStoredLocalePreference();
  return storedLocale ?? currentDeviceLocale();
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final loadedLocale = await loadStoredLocalePreference();
    if (loadedLocale == null) {
      state = null; // system default
      _syncIntlDefaultLocale(null);
      return;
    }
    state = loadedLocale;
    _syncIntlDefaultLocale(loadedLocale);
  }

  Future<void> setSystem() async {
    state = null;
    _syncIntlDefaultLocale(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localePreferenceStorageKey, 'system');
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = _resolveLocalePreference(locale);
    state = normalized;
    _syncIntlDefaultLocale(normalized);
    final prefs = await SharedPreferences.getInstance();
    final code =
        normalized.countryCode != null && normalized.countryCode!.isNotEmpty
            ? '${normalized.languageCode}_${normalized.countryCode}'
            : normalized.languageCode;
    await prefs.setString(localePreferenceStorageKey, code);
  }

  void _syncIntlDefaultLocale(Locale? locale) {
    try {
      initializeAppDateFormatting(locale).catchError((_) {});
    } catch (_) {
      // Never crash during locale sync
    }
  }
}

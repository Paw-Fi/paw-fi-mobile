import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/utils/intl_locale.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  static const _key = 'moneko_locale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.isEmpty || value == 'system') {
      state = null; // system default
      return;
    }
    // value format: language[_COUNTRY]
    final parts = value.split('_');
    Locale loaded =
        parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    final normalized = _normalize(loaded);
    state = normalized;
    _syncIntlDefaultLocale(normalized);
  }

  Future<void> setSystem() async {
    state = null;
    _syncIntlDefaultLocale(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'system');
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = _normalize(locale);
    state = normalized;
    _syncIntlDefaultLocale(normalized);
    final prefs = await SharedPreferences.getInstance();
    final code =
        normalized.countryCode != null && normalized.countryCode!.isNotEmpty
            ? '${normalized.languageCode}_${normalized.countryCode}'
            : normalized.languageCode;
    await prefs.setString(_key, code);
  }

  void _syncIntlDefaultLocale(Locale? locale) {
    try {
      if (locale == null) {
        // System default — reset to en_US as safe fallback;
        // main.dart will re-set from device locale on next startup.
        intl.Intl.defaultLocale = 'en_US';
        return;
      }
      final safe = intlSafeLocaleName(locale);
      intl.Intl.defaultLocale = safe;
      initializeDateFormatting(safe, null).catchError((_) {});
    } catch (_) {
      // Never crash during locale sync
    }
  }

  Locale _normalize(Locale locale) {
    final lc = locale.languageCode.toLowerCase();
    final cc = (locale.countryCode ?? '').toUpperCase();
    // Map legacy/incorrect codes to proper BCP-47
    if (lc == 'cn') {
      // Use generic Chinese locale by default
      return const Locale('zh');
    }
    if (lc == 'zh' && (cc.isEmpty)) {
      // Keep generic zh when no region specified
      return const Locale('zh');
    }
    return Locale(lc, cc.isEmpty ? null : cc);
  }
}

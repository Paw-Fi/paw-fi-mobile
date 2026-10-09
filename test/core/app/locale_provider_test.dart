import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2026, 10, 7);
  String? previousDefaultLocale;

  setUp(() async {
    previousDefaultLocale = Intl.defaultLocale;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  void expectDashboardFormattingWorks() {
    // These are the two formatting paths reported by Crashlytics.
    expect(formatDateForInterval(date, 'daily'), isNotEmpty);
    expect(formatDateForInterval(date, 'monthly'), isNotEmpty);
    expect(DateFormat.E().format(date), isNotEmpty);
    expect(NumberFormat.decimalPattern().format(1234.5), isNotEmpty);
  }

  for (final locale in [
    const Locale('yue', 'HK'),
    const Locale('yue'),
    const Locale('xx', 'YY'),
  ]) {
    test('startup formatting resolves unsupported device locale $locale',
        () async {
      Intl.defaultLocale = locale.toString();
      await initializeAppDateFormatting(locale);

      expect(Intl.defaultLocale, 'en');
      expect(formatDateForInterval(date, 'daily'), '7');
      expectDashboardFormattingWorks();
    });
  }

  for (final locale in AppLocalizations.supportedLocales) {
    test('startup formatting preserves supported app locale $locale', () async {
      await initializeAppDateFormatting(locale);

      expect(Intl.defaultLocale, locale.toString());
      expectDashboardFormattingWorks();
      expect(DateFormat.yMMMMd().locale, locale.toString());
    });
  }

  test('legacy Korean preference still resolves to supported Korean', () async {
    await initializeAppDateFormatting(const Locale('kr'));
    expect(Intl.defaultLocale, 'ko');
    expectDashboardFormattingWorks();
  });

  for (final locale in [
    const Locale('en', 'GB'),
    const Locale('fr', 'CA'),
    const Locale('pt', 'BR'),
  ]) {
    test('startup preserves compatible regional formatting for $locale',
        () async {
      await initializeAppDateFormatting(locale);

      expect(Intl.defaultLocale, locale.toString());
      expectDashboardFormattingWorks();
    });
  }

  test('British English date order survives startup and preference reload',
      () async {
    SharedPreferences.setMockInitialValues({
      localePreferenceStorageKey: 'en_GB',
    });
    await initializeAppDateFormatting(const Locale('en', 'GB'));
    final notifier = LocaleNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    expect(notifier.state, const Locale('en', 'GB'));
    expect(Intl.defaultLocale, 'en_GB');
    expect(DateFormat.yMd().format(date), '07/10/2026');
  });

  for (final preference in [null, 'system']) {
    test('system preference $preference repairs unsupported default locale',
        () async {
      SharedPreferences.setMockInitialValues({
        if (preference != null) localePreferenceStorageKey: preference,
      });
      Intl.defaultLocale = 'yue_HK';
      final notifier = LocaleNotifier();
      addTearDown(notifier.dispose);
      await pumpEventQueue();

      expect(notifier.state, isNull);
      expect(Intl.defaultLocale, isNot('yue_HK'));
      expectDashboardFormattingWorks();
    });
  }

  test('unsupported stored locale resolves before publishing UI and intl state',
      () async {
    SharedPreferences.setMockInitialValues({
      localePreferenceStorageKey: 'yue_HK',
    });
    final notifier = LocaleNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    expect(notifier.state, const Locale('en'));
    expect(await resolveEffectiveAppLocale(), const Locale('en'));
    expect(Intl.defaultLocale, 'en');
    expectDashboardFormattingWorks();
  });

  test('unsupported explicit locale uses the existing English fallback',
      () async {
    final notifier = LocaleNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    await notifier.setLocale(const Locale('yue', 'HK'));

    expect(notifier.state, const Locale('en'));
    expect(Intl.defaultLocale, 'en');
    expectDashboardFormattingWorks();
  });

  test('returning to system mode keeps formatting safe', () async {
    final notifier = LocaleNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    final systemIntlLocale = Intl.defaultLocale;
    await notifier.setLocale(const Locale('zh', 'TW'));
    expect(Intl.defaultLocale, 'zh_TW');
    await notifier.setSystem();

    expect(notifier.state, isNull);
    expect(Intl.defaultLocale, systemIntlLocale);
    expectDashboardFormattingWorks();
  });
}

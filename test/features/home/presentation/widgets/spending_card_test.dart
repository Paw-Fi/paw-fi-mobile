import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/spending_daily_overview_provider.dart';
import 'package:moneko/features/home/presentation/widgets/spending_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

ExpenseEntry _entry(String id,
        {DateTime? date,
        int cents = 42000,
        String currency = 'EUR',
        int? multiplier,
        bool finality = true,
        String type = 'expense'}) =>
    ExpenseEntry(
        id: id,
        date: date ?? DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        amountCents: cents,
        currency: currency,
        type: type,
        analyticsSpendingMultiplier: multiplier,
        analyticsIsFinal: finality);

Widget _card(List<ExpenseEntry> entries,
    {SpendingDailyOverview? overview,
    bool dark = false,
    double width = 390,
    double scale = 1,
    Locale locale = const Locale('en'),
    String currency = 'EUR',
    List<String>? currencies,
    CurrencyRateTable? rates,
    Key? cardKey}) {
  final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
  return MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
        data: MediaQueryData(
            disableAnimations: true, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: width,
                    child: SpendingCard(
                      key: cardKey,
                      colorScheme: theme.colorScheme,
                      expenses: entries,
                      contact: null,
                      dateFilter: DateRangeFilter.custom,
                      referenceNow: DateTime(2026, 5, 10),
                      customStartDate: DateTime(2026, 5),
                      customEndDate: DateTime(2026, 5, 31),
                      selectedCurrency: currency,
                      selectedCurrencies: currencies,
                      currencyRates: rates,
                      overview: overview,
                    ))))),
  );
}

void main() {
  testWidgets(
      'same-ID occurrence hydration invalidates the cached chart reporting date',
      (tester) async {
    final legacy = _entry('one');
    await tester
        .pumpWidget(_card([legacy], cardKey: const ValueKey('stable-date')));
    await tester.pump(const Duration(milliseconds: 900));
    final before = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .single
        .spots
        .map((spot) => spot.y)
        .toList();
    await tester.pumpWidget(_card([
      legacy.copyWith(
          parentRecurringId: 'series',
          scheduledOccurrenceDate: DateTime(2026, 5, 5))
    ], cardKey: const ValueKey('stable-date')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('€42/day'), findsOneWidget);
    expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .map((spot) => spot.y)
            .toList(),
        isNot(equals(before)),
        reason: 'date-only recurrence enrichment must replace the old curve');
  });
  testWidgets(
      'daily average and comparison replace the activity count and total',
      (tester) async {
    final entries = [_entry('one')];
    await tester.pumpWidget(_card(entries,
        overview: SpendingDailyOverview(
            dailyAverage: 42,
            transactions: entries,
            previousAverage: const AsyncData(45.6))));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('€42/day'), findsOneWidget);
    expect(find.text('8% from last month'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.text('SPENDING ACTIVITY'), findsNothing);
    expect(find.text('€420'), findsNothing);
    expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .last
            .y,
        420);
  });

  testWidgets('remounting cached daily spending never flashes a zero',
      (tester) async {
    final entries = [_entry('one')];
    await tester.pumpWidget(_card(entries, cardKey: const ValueKey('first')));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('€42/day'), findsOneWidget);
    await tester.pumpWidget(_card(entries, cardKey: const ValueKey('second')));
    expect(find.text('€42/day'), findsOneWidget);
    expect(find.text('€0/day'), findsNothing);
  });

  testWidgets('create edit and delete update the real elapsed-day average',
      (tester) async {
    await tester
        .pumpWidget(_card([_entry('one')], cardKey: const ValueKey('stable')));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('€42/day'), findsOneWidget);
    await tester.pumpWidget(_card([_entry('one', cents: 84000)],
        cardKey: const ValueKey('stable')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('€84/day'), findsOneWidget);
    await tester.pumpWidget(_card([], cardKey: const ValueKey('stable')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('€0/day'), findsOneWidget);
  });

  testWidgets(
      'refund income finality currency and period eligibility remain correct',
      (tester) async {
    await tester.pumpWidget(_card([
      _entry('spend', cents: 44000),
      _entry('refund', cents: 2000, multiplier: -1),
      _entry('income', type: 'income'),
      _entry('transfer:one', multiplier: 0),
      _entry('pending', finality: false),
      _entry('usd', currency: 'USD'),
      _entry('prior', date: DateTime(2026, 4, 30)),
    ]));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('€42/day'), findsOneWidget);
  });

  testWidgets(
      'selected native currencies convert without losing the breakdown action',
      (tester) async {
    await tester.pumpWidget(_card([
      _entry('eur', cents: 10000),
      _entry('usd', cents: 10000, currency: 'USD')
    ],
        currencies: [
          'EUR',
          'USD'
        ],
        rates: const CurrencyRateTable(
            baseCurrency: 'USD',
            rates: {'USD': 1, 'EUR': .5},
            isStale: false)));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('€15/day'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .single
            .spots
            .last
            .y,
        150);
  });

  for (final previous in [null, 0.0, -5.0]) {
    testWidgets(
        'unavailable comparison $previous never shows a fake zero percent',
        (tester) async {
      final entries = [_entry('one')];
      await tester.pumpWidget(_card(entries,
          overview: previous == null
              ? null
              : SpendingDailyOverview(
                  dailyAverage: 42,
                  transactions: entries,
                  previousAverage: AsyncData(previous))));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('€42/day'), findsOneWidget);
      expect(find.text('No previous-month comparison'), findsOneWidget);
      expect(find.text('0% from last month'), findsNothing);
    });
  }

  testWidgets(
      'a comparison read failure or loading does not blank current daily spending',
      (tester) async {
    final entries = [_entry('one')];
    for (final previous in [
      const AsyncLoading<double>(),
      AsyncError<double>(StateError('offline'), StackTrace.current)
    ]) {
      await tester.pumpWidget(_card(entries,
          overview: SpendingDailyOverview(
              dailyAverage: 42,
              transactions: entries,
              previousAverage: previous)));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('€42/day'), findsOneWidget);
      expect(find.text('0% from last month'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'increased and unchanged spending have honest comparison indicators',
      (tester) async {
    final entries = [_entry('one')];
    await tester.pumpWidget(_card(entries,
        overview: SpendingDailyOverview(
            dailyAverage: 42,
            transactions: entries,
            previousAverage: const AsyncData(35))));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('20% from last month'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    await tester.pumpWidget(_card(entries,
        overview: SpendingDailyOverview(
            dailyAverage: 42,
            transactions: entries,
            previousAverage: const AsyncData(42))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0% from last month'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final locale in [
      const Locale('en'),
      const Locale('de'),
      const Locale('ur')
    ]) {
      testWidgets(
          'daily header is responsive in ${dark ? 'dark' : 'light'} $locale',
          (tester) async {
        await tester.pumpWidget(_card([_entry('one')],
            dark: dark, locale: locale, width: 280, scale: 2));
        await tester.pump(const Duration(milliseconds: 900));
        final localization =
            AppLocalizations.of(tester.element(find.byType(SpendingCard)))!;
        expect(
            find.text(localization.spendingDailyPerDay('€42')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

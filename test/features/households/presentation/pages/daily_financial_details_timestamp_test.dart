import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/pages/daily_financial_details_page.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

class _Analytics extends AnalyticsNotifier {
  _Analytics(super.ref, String timezone) {
    setTimezone(timezone);
  }

  void setTimezone(String timezone) {
    state = AnalyticsData(
      contact: UserContact(
        id: 'contact-1',
        userId: 'user-1',
        verified: true,
        preferredTimezone: timezone,
      ),
      hasLoadedOnce: true,
    );
  }
}

class _Recurring extends RecurringTransactionsNotifier {
  _Recurring(super.ref, super.householdId) {
    state = RecurringTransactionsState(
      data: const AsyncData([]),
      hasLoadedOnce: true,
    );
  }
}

void main() {
  for (final timezone in ['America/Asuncion', 'UTC-03:00']) {
    testWidgets('daily Spanish tiles preserve actual clocks for $timezone',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fixtures = [
        ('Monte Libano Foodplaza', 3000000, '2026-10-14T00:45:30Z'),
        ('Farmacenter Hiper Lu', 1744200, '2026-10-14T00:40:09Z'),
        ('ASADITOS BRASILIA', 1000000, '2026-10-13T21:56:24Z'),
        ('Paloma Scappini Bake S', 3000000, '2026-10-13T15:24:27Z'),
      ];
      final transactions = fixtures.map((fixture) {
        return ExpenseEntry.fromJson({
          'id': fixture.$1,
          'date': formatDateOnlyYmd(today),
          'created_at': fixture.$3,
          'amount_cents': fixture.$2,
          'currency': 'PYG',
          'type': 'expense',
          'category': 'groceries',
          'raw_text': fixture.$1,
        });
      }).toList();
      final container = ProviderContainer(overrides: [
        analyticsProvider.overrideWith((ref) => _Analytics(ref, timezone)),
        homeFilterProvider.overrideWith(
            (ref) => HomeFilterNotifier()..setSelectedCurrency('PYG')),
        currencyRateTableProvider.overrideWith((ref) async =>
            const CurrencyRateTable(baseCurrency: 'USD', rates: {'PYG': 7000})),
        dashboardCalendarTransactionsProvider
            .overrideWith((ref, query) async => transactions),
        recurringTransactionsProvider
            .overrideWith((ref, id) => _Recurring(ref, id)),
        recurringOccurrenceProjectionResolutionProvider.overrideWith(
            (ref, query) => const RecurringOccurrenceProjectionResolution()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: DailyFinancialDetailsPage(
            date: today,
            transactions: transactions,
            recurringTransactions: const [],
            currency: 'PYG',
            userId: 'user-1',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      void expectClocks(String preferredTimezone) {
        final tiles = tester
            .widgetList<TransactionListTile>(find.byType(TransactionListTile))
            .toList();
        expect(tiles, hasLength(4));
        for (var index = 0; index < tiles.length; index++) {
          final transaction = transactions[index];
          final expected = toEffectiveWallTime(
            utcOrLocalInstant: transaction.createdAt,
            preferredTimezone: preferredTimezone,
          );
          expect(tiles[index].date!.hour, expected.hour);
          expect(tiles[index].date!.minute, expected.minute);
          expect(tiles[index].date!.second, expected.second);
          expect(
              formatDateOnlyYmd(tiles[index].date!), formatDateOnlyYmd(today));
          expect(tiles[index].amount, transaction.amount);
          expect(tiles[index].currency, 'PYG');
          expect(tiles[index].onTap, isNotNull);
          expect(find.text('Hoy, ${DateFormat.jm('es').format(expected)}'),
              findsOneWidget);
        }
      }

      expectClocks(timezone);
      (container.read(analyticsProvider.notifier) as _Analytics)
          .setTimezone('UTC+02:00');
      await tester.pumpAndSettle();
      expectClocks('UTC+02:00');
      expect(tester.takeException(), isNull);
    });
  }
}

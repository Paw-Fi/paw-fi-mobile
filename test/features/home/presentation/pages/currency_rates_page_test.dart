import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/pages/currency_rates_page.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PlusSubscription extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => Subscription(
        id: 'subscription',
        userId: 'user',
        plan: 'lifetime',
        status: 'active',
        createdAt: DateTime(2026),
      );
}

void main() {
  testWidgets('last currency reorders and footer stays outside draggable rows',
      (tester) async {
    const codes = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];
    SharedPreferences.setMockInitialValues({
      'currency_rates_shown_currencies': codes,
      'currency_rates_ordered_currencies': codes,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        subscriptionNotifierProvider.overrideWith(_PlusSubscription.new),
        selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
        currencyRateTableProvider
            .overrideWith((ref) async => const CurrencyRateTable(
                  baseCurrency: 'USD',
                  rates: {
                    'USD': 1,
                    'EUR': 0.9,
                    'GBP': 0.8,
                    'JPY': 150,
                    'CAD': 1.4,
                    'AUD': 1.5
                  },
                )),
        currencyRateRepositoryProvider
            .overrideWith((ref) => throw StateError('No network in test')),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CurrencyRatesPage(),
      ),
    ));
    await tester.pumpAndSettle();
    final list =
        tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    expect(list.itemCount, 6);
    expect(list.footer?.key, const ValueKey('updated_time_footer'));
    final lastRow = find.byKey(const ValueKey('AUD'));
    await tester.ensureVisible(lastRow);
    final gesture = await tester.startGesture(tester.getCenter(lastRow));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getTopLeft(find.byKey(const ValueKey('USD'))) +
        const Offset(100, 2));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('currency_rates_ordered_currencies'),
        ['USD', 'AUD', 'EUR', 'GBP', 'JPY', 'CAD']);
    expect(tester.takeException(), isNull);
  });
}

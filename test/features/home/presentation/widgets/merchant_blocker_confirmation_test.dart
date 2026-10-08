import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/pages/merchant_selection_page.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'owner@example.com');
}

class _PausedDrainer extends MobileOutboxDrainer {
  _PausedDrainer() : super(() async => throw StateError('offline fixture'));
  @override
  Future<int> drain({int maxMutations = 20}) async => 0;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(), detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/rest/v1/')) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('merchant-user-search')) {
          final body = jsonDecode(request.body) as Map;
          return http.Response(
              jsonEncode(body['action'] == 'search'
                  ? {
                      'success': true,
                      'candidates': [
                        {
                          'name': 'Confirmed',
                          'domain': 'example.com',
                          'source': 'logo_dev'
                        }
                      ]
                    }
                  : {
                      'success': true,
                      'merchant': {
                        'id': 'merchant-1',
                        'canonical_name': 'Confirmed',
                        'domain': 'example.com'
                      }
                    }),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'success': false}), 503,
            headers: {'content-type': 'application/json'});
      }),
    );
  });

  for (final income in [false, true]) {
    for (final edit in ['none', 'custom', 'identity', 'dismiss']) {
      testWidgets(
          'confirmation income=$income merchant edit=$edit clears only explicit correction',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final database = MonekoDatabase.inMemory();
        final container = ProviderContainer(overrides: [
          authProvider.overrideWith(_Auth.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          appUserContactProvider.overrideWithValue(null),
          localDatabaseProvider.overrideWith((ref) async => database),
          mobileOutboxDrainerProvider.overrideWith((ref) => _PausedDrainer()),
          preloadedUserHouseholdsProvider('owner').overrideWith((ref) => []),
          walletsByCurrencyProvider.overrideWith((ref, query) async => []),
        ]);
        addTearDown(() async {
          container.dispose();
          await database.close();
        });
        final parsed = ParsedExpense(
          isIncome: income,
          amount: 12.34,
          category: income ? 'salary' : 'groceries',
          currency: 'JPY',
          currencySymbol: 'JPY',
          date: DateTime(2026, 10, 3),
          merchant: '原文の相手',
          description: '記録',
          merchantAutoResolutionBlocked: true,
          merchantCandidates: const [
            ParsedMerchantCandidate(name: 'Confirmed', domain: 'example.com')
          ],
        );
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) => Scaffold(
                        body: TextButton(
                      onPressed: () => showUnifiedTransactionSheet(context,
                          newExpense: parsed),
                      child: const Text('Open'),
                    ))),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (edit != 'none') {
          await tester.ensureVisible(find.text('原文の相手'));
          await tester.tap(find.text('原文の相手'));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
              tester.element(find.byType(MerchantSelectionPage)))!;
          if (edit == 'dismiss') {
            await tester.tap(find.byIcon(Icons.close_rounded));
          } else {
            await tester
                .tap(find.text(edit == 'custom' ? '原文の相手' : 'Confirmed').last);
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              await tester.tap(find.text(l10n.done));
            });
            for (var attempt = 0;
                attempt < 100 && find.text(l10n.cancel).evaluate().isEmpty;
                attempt++) {
              await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 20)));
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(find.text(l10n.cancel), findsOneWidget);
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.cancel));
          }
          await tester.pumpAndSettle();
        }
        final blocked = edit == 'none' || edit == 'dismiss';
        expect(
            container
                .read(pendingExpenseProvider)!
                .merchantAutoResolutionBlocked,
            blocked);
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pumpAndSettle();
        final payload =
            jsonDecode((await database.getOutboxMutations()).single.payloadJson)
                as Map;
        final request = payload['requestBody'] as Map;
        expect(
            payload['functionName'], income ? 'save-income' : 'save-expense');
        expect(request.containsKey('merchantAutoResolutionBlocked'), blocked);
        if (blocked) expect(request['merchantAutoResolutionBlocked'], true);
        expect(request['amount'], 12.34);
        expect(request['currency'], 'JPY');
        expect(request['description'], '記録');
        expect(request['merchant'], edit == 'identity' ? null : '原文の相手');
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

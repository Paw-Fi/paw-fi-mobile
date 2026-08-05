import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets(
      'fresh hydration never exposes the stale pairwise settlement balance',
      (tester) async {
    var pairwiseReads = 0;
    final hydration = Completer<List<SettlementPaymentRecord>>();
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD'],
      pendingPaymentsFuture: hydration.future,
      onPairwiseRead: () => pairwiseReads += 1,
      balances: const [
        SettlementPairwiseBalance(
          otherUserId: 'alex',
          currency: 'USD',
          splitToCents: 1000,
          splitFromCents: 0,
          paidToCents: 0,
          paidFromCents: 0,
          netCents: 1000,
        ),
      ],
      splits: [_splitGroup(currency: 'USD', amountCents: 1000)],
    );

    expect(pairwiseReads, 1);
    expect(find.text('\$10'), findsWidgets);

    hydration.complete(const <SettlementPaymentRecord>[]);
    await tester.pumpAndSettle();

    expect(pairwiseReads, 1);
    expect(find.text('\$10'), findsWidgets);
  });

  testWidgets('multi-currency settlement rows display source amounts',
      (tester) async {
    await _pumpSettlementCard(
      tester,
      splits: [
        _splitGroup(currency: 'USD', amountCents: 1000),
        _splitGroup(currency: 'EUR', amountCents: 2000),
        _splitGroup(currency: 'MYR', amountCents: 3000),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('\$10'), findsOneWidget);
    expect(find.text('€20'), findsOneWidget);
    expect(find.text('RM30'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
    expect(find.text('EUR'), findsNothing);
    expect(find.text('MYR'), findsNothing);
    expect(_flagImageFinder('lib/assets/images/flags/us.png'), findsOneWidget);
    expect(
      _flagImageFinder('lib/assets/images/flags/europe.png'),
      findsOneWidget,
    );
    expect(_flagImageFinder('lib/assets/images/flags/my.png'), findsOneWidget);
  });

  testWidgets('multi-currency summary totals remain in base currency',
      (tester) async {
    await _pumpSettlementCard(
      tester,
      rates: const {'USD': 1, 'EUR': 2, 'MYR': 5},
      splits: [
        _splitGroup(currency: 'USD', amountCents: 1000),
        _splitGroup(currency: 'EUR', amountCents: 2000),
        _splitGroup(currency: 'MYR', amountCents: 3000),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('\$26'), findsOneWidget);
    expect(find.text('€20'), findsOneWidget);
    expect(find.text('RM30'), findsOneWidget);
  });

  testWidgets('single-currency settlement rows do not display flags',
      (tester) async {
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD'],
      balances: const [
        SettlementPairwiseBalance(
          otherUserId: 'alex',
          currency: 'USD',
          splitToCents: 1000,
          splitFromCents: 0,
          paidToCents: 0,
          paidFromCents: 0,
          netCents: 1000,
        ),
      ],
      splits: [
        _splitGroup(currency: 'USD', amountCents: 1000),
      ],
    );

    await tester.pump();

    expect(find.text('\$10'), findsWidgets);
    expect(_flagImageFinder('lib/assets/images/flags/us.png'), findsNothing);
  });

  testWidgets('single-currency path does not load the full settlement overview',
      (tester) async {
    var pairwiseReads = 0;
    var overviewReads = 0;
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD'],
      onPairwiseRead: () => pairwiseReads += 1,
      onOverviewRead: () => overviewReads += 1,
      balances: const [
        SettlementPairwiseBalance(
          otherUserId: 'alex',
          currency: 'USD',
          splitToCents: 1000,
          splitFromCents: 0,
          paidToCents: 0,
          paidFromCents: 0,
          netCents: 1000,
        ),
      ],
      splits: [_splitGroup(currency: 'USD', amountCents: 1000)],
    );

    expect(pairwiseReads, 1);
    expect(overviewReads, 0);
  });

  testWidgets('single-currency RPC failure never uses the legacy calculation',
      (tester) async {
    var overviewReads = 0;
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD'],
      pairwiseError: Exception('optimized RPC unavailable'),
      onOverviewRead: () => overviewReads += 1,
      splits: [_splitGroup(currency: 'USD', amountCents: 1000)],
    );

    await tester.pump();

    expect(overviewReads, 0);
    expect(find.text('\$10'), findsNothing);
    expect(find.textContaining('Error loading dashboard'), findsOneWidget);
  });

  testWidgets(
      'multi-currency payment read failure never shows a partial balance',
      (tester) async {
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD', 'EUR'],
      overviewError: StateError('payments unavailable'),
      splits: [_splitGroup(currency: 'USD', amountCents: 1000)],
    );

    expect(find.text('\$10'), findsNothing);
    expect(find.textContaining('Error loading dashboard'), findsOneWidget);
  });

  testWidgets('new empty shared space still fails closed when RPC fails',
      (tester) async {
    await _pumpSettlementCard(
      tester,
      selectedCurrencies: const ['USD'],
      pairwiseError: Exception('optimized RPC unavailable'),
      splits: const <ExpenseSplitGroup>[],
    );

    await tester.pump();

    expect(find.textContaining('Error loading dashboard'), findsOneWidget);
  });

  testWidgets('optimistic household ID never starts settlement providers',
      (tester) async {
    var pairwiseReads = 0;
    var overviewReads = 0;
    await _pumpSettlementCard(
      tester,
      householdId: 'optimistic-household-1783843926425266',
      selectedCurrencies: const ['USD'],
      onPairwiseRead: () => pairwiseReads += 1,
      onOverviewRead: () => overviewReads += 1,
      splits: const <ExpenseSplitGroup>[],
    );

    expect(pairwiseReads, 0);
    expect(overviewReads, 0);
    expect(find.byType(SettlementSuggestionsCard), findsOneWidget);
  });

  testWidgets('multi-currency path does not issue the unused pairwise RPC',
      (tester) async {
    var pairwiseReads = 0;
    var overviewReads = 0;
    await _pumpSettlementCard(
      tester,
      onPairwiseRead: () => pairwiseReads += 1,
      onOverviewRead: () => overviewReads += 1,
      splits: [
        _splitGroup(currency: 'USD', amountCents: 1000),
        _splitGroup(currency: 'EUR', amountCents: 1000),
      ],
    );

    expect(pairwiseReads, 0);
    expect(overviewReads, 1);
  });

  testWidgets('multi-currency settlement rows avoid narrow layout overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSettlementCard(
      tester,
      members: [
        _member(userId: 'me'),
        _member(
          userId: 'alex',
          userName: 'Alexandria With A Very Long Household Name',
        ),
      ],
      splits: [
        _splitGroup(currency: 'MYR', amountCents: 1234567890),
      ],
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Finder _flagImageFinder(String assetName) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final image = widget.image;
    return image is AssetImage && image.assetName == assetName;
  });
}

Future<void> _pumpSettlementCard(
  WidgetTester tester, {
  required List<ExpenseSplitGroup> splits,
  String householdId = '00000000-0000-0000-0000-000000000001',
  List<HouseholdMember>? members,
  List<String> selectedCurrencies = const ['USD', 'EUR', 'MYR'],
  List<SettlementPairwiseBalance> balances =
      const <SettlementPairwiseBalance>[],
  Map<String, double> rates = const {'USD': 1, 'EUR': 1, 'MYR': 1},
  VoidCallback? onPairwiseRead,
  VoidCallback? onOverviewRead,
  Object? pairwiseError,
  Object? overviewError,
  Future<List<SettlementPaymentRecord>>? pendingPaymentsFuture,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyRateTableProvider.overrideWith(
          (ref) async => CurrencyRateTable(
            baseCurrency: 'USD',
            rates: rates,
            isStale: false,
          ),
        ),
        householdPairwiseSettlementBalancesV2Provider.overrideWith(
          (ref, params) async {
            onPairwiseRead?.call();
            if (pairwiseError != null) {
              throw pairwiseError;
            }
            return balances;
          },
        ),
        settlementOverviewProvider.overrideWith(
          (ref, householdId) {
            onOverviewRead?.call();
            if (overviewError != null) {
              return AsyncValue.error(overviewError, StackTrace.current);
            }
            return AsyncValue.data(
              SettlementOverviewData(
                splits: splits,
                payments: const <SettlementPaymentRecord>[],
              ),
            );
          },
        ),
        pendingHouseholdSettlementPaymentsProvider.overrideWith(
          (ref, householdId) {
            if (pendingPaymentsFuture != null) {
              return pendingPaymentsFuture;
            }
            return const <SettlementPaymentRecord>[];
          },
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettlementSuggestionsCard(
            householdId: householdId,
            currency: 'USD',
            selectedCurrencies: selectedCurrencies,
            members:
                members ?? [_member(userId: 'me'), _member(userId: 'alex')],
            currentUserId: 'me',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

HouseholdMember _member({required String userId, String? userName}) {
  final now = DateTime(2026, 1, 1);
  return HouseholdMember(
    id: '$userId-member',
    householdId: '00000000-0000-0000-0000-000000000001',
    userId: userId,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    userName: userName ?? (userId == 'me' ? 'You' : 'Alex'),
  );
}

ExpenseSplitGroup _splitGroup({
  required String currency,
  required int amountCents,
}) {
  final now = DateTime(2026, 1, 1);
  final normalizedCurrency = currency.toUpperCase();
  return ExpenseSplitGroup(
    id: 'group-$normalizedCurrency',
    householdId: '00000000-0000-0000-0000-000000000001',
    expenseId: 'expense-$normalizedCurrency',
    payerUserId: 'alex',
    splitType: SplitType.equal,
    currency: normalizedCurrency,
    totalAmountCents: amountCents,
    createdAt: now,
    updatedAt: now,
    splitLines: [
      ExpenseSplitLine(
        id: 'line-$normalizedCurrency',
        splitGroupId: 'group-$normalizedCurrency',
        userId: 'me',
        amountCents: amountCents,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

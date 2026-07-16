import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/presentation/pages/settlement_calculation_breakdown_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

const _householdId = '00000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('shows both gross directions and their atomic C\$66.11 net',
      (tester) async {
    await _setLargeTestViewport(tester);
    await _pumpPage(tester, (_) async => _reportedCalculation());
    await tester.pump();

    expect(find.text(r'C$66.11'), findsOneWidget);
    expect(find.text(r'C$112.23'), findsOneWidget);
    expect(find.text(r'C$46.12'), findsOneWidget);
    expect(find.text(r'-C$112.23'), findsOneWidget);
    expect(find.text(r'+C$46.12'), findsOneWidget);
    expect(find.text('Wet and dry catfood'), findsOneWidget);
    expect(find.text('groceries'), findsOneWidget);
  });

  testWidgets('zero-net reciprocal rows remain visible in both directions',
      (tester) async {
    await _setLargeTestViewport(tester);
    await _pumpPage(
      tester,
      (_) async => SettlementCalculationV3(
        netCents: 0,
        rows: [
          _row(
            id: 'you-owe',
            direction: SettlementBreakdownDirectionV2.youOwe,
            amountCents: 5000,
          ),
          _row(
            id: 'they-owe',
            direction: SettlementBreakdownDirectionV2.theyOweYou,
            amountCents: 5000,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Nothing to settle'), findsWidgets);
    expect(find.text('you-owe'), findsOneWidget);
    expect(find.text('they-owe'), findsOneWidget);
    expect(find.text(r'-C$50'), findsOneWidget);
    expect(find.text(r'+C$50'), findsOneWidget);
  });

  testWidgets('RPC failure never falls back to legacy FIFO transaction rows',
      (tester) async {
    await _setLargeTestViewport(tester);
    var shouldFail = true;
    await _pumpPage(
      tester,
      (_) async {
        if (shouldFail) throw Exception('RPC unavailable');
        return _reportedCalculation();
      },
      transactions: [_legacyExpense()],
      splits: [_legacySplit()],
    );
    await tester.pump();

    expect(find.text('Error loading data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Legacy FIFO row must not render'), findsNothing);
    expect(
      tester.getSize(find.byType(OutlinedAdaptiveButton)).height,
      greaterThanOrEqualTo(44),
    );

    shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Error loading data'), findsNothing);
    expect(find.text('Wet and dry catfood'), findsOneWidget);
  });

  testWidgets('nonzero net with no rows renders a defensive adjustment',
      (tester) async {
    await _setLargeTestViewport(tester);
    await _pumpPage(
      tester,
      (_) async => SettlementCalculationV3(
        netCents: 6611,
        rows: const <SettlementBreakdownRowV2>[],
      ),
    );
    await tester.pump();

    expect(find.text(r'C$66.11'), findsNWidgets(2));
    expect(find.textContaining('Adjustment'), findsWidgets);
    expect(find.text('No split transactions found'), findsNothing);
  });

  testWidgets(
      'renders carryover outside transaction lists beside both gross directions',
      (tester) async {
    await _setLargeTestViewport(tester);
    await _pumpPage(
      tester,
      (_) async => SettlementCalculationV3(
        netCents: 9111,
        rows: [
          SettlementBreakdownRowV2(
            direction: SettlementBreakdownDirectionV2.youOwe,
            expenseDate: DateTime.utc(2026, 7, 16),
            expenseType: 'legacy_carryover',
            totalAmountCents: 2500,
            remainingAmountCents: 2500,
          ),
          _row(
            id: 'Wet and dry catfood',
            direction: SettlementBreakdownDirectionV2.youOwe,
            amountCents: 11223,
          ),
          _row(
            id: 'groceries',
            direction: SettlementBreakdownDirectionV2.theyOweYou,
            amountCents: 4612,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Balance carried forward'), findsOneWidget);
    expect(
      find.text(
        'Balance from before detailed settlement history was available.',
      ),
      findsOneWidget,
    );
    expect(find.text(r'-C$25'), findsOneWidget);
    expect(find.text('Wet and dry catfood'), findsOneWidget);
    expect(find.text('groceries'), findsOneWidget);
    expect(find.byType(TransactionListTile), findsNWidgets(2));
  });

  testWidgets('refresh retains one complete snapshot until the next is ready',
      (tester) async {
    await _setLargeTestViewport(tester);
    final nextSnapshot = Completer<SettlementCalculationV3>();
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        householdSettlementCalculationV3Provider.overrideWith(
          (ref, params) {
            reads += 1;
            if (reads == 1) {
              return Future.value(
                SettlementCalculationV3(
                  netCents: 1000,
                  rows: [
                    _row(
                      id: 'old-row',
                      direction: SettlementBreakdownDirectionV2.youOwe,
                      amountCents: 1000,
                    ),
                  ],
                ),
              );
            }
            return nextSnapshot.future;
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _testApp(const SettlementCalculationBreakdownPage(
          householdId: _householdId,
          currentUserId: '',
          memberUserId: '',
          memberDisplayName: 'Alex',
          currencyCode: 'CAD',
          netCents: 99999,
        )),
      ),
    );
    await tester.pump();

    expect(find.text(r'C$10'), findsWidgets);
    expect(find.text('old-row'), findsOneWidget);

    container.invalidate(
      householdSettlementCalculationV3Provider(
        SettlementBreakdownV2Params(
          householdId: _householdId,
          memberUserId: '',
          currency: 'CAD',
        ),
      ),
    );
    await tester.pump();

    expect(find.text(r'C$10'), findsWidgets);
    expect(find.text('old-row'), findsOneWidget);
    expect(find.text('new-row'), findsNothing);

    nextSnapshot.complete(
      SettlementCalculationV3(
        netCents: -2500,
        rows: [
          _row(
            id: 'new-row',
            direction: SettlementBreakdownDirectionV2.theyOweYou,
            amountCents: 2500,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text(r'C$25'), findsWidgets);
    expect(find.text('new-row'), findsOneWidget);
    expect(find.text('old-row'), findsNothing);
  });

  testWidgets('large settlement histories lazily build visible rows only',
      (tester) async {
    await _setTestViewport(tester, const Size(390, 700));
    final rows = List.generate(
      500,
      (index) => _row(
        id: 'row-$index',
        direction: SettlementBreakdownDirectionV2.youOwe,
        amountCents: 100,
      ),
    );
    await _pumpPage(
      tester,
      (_) async => SettlementCalculationV3(
        netCents: 50000,
        rows: rows,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TransactionListTile), findsWidgets);
    expect(
      find.byType(TransactionListTile).evaluate().length,
      lessThan(rows.length),
    );
    expect(find.text('row-499'), findsNothing);

    final pageScrollable = find.descendant(
      of: find.byKey(const ValueKey('settlement-breakdown-data')),
      matching: find.byType(Scrollable),
    );
    expect(pageScrollable, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('row-499'),
      600,
      scrollable: pageScrollable,
      maxScrolls: 100,
    );
    expect(find.text('row-499'), findsOneWidget);
  });
}

Future<void> _setLargeTestViewport(WidgetTester tester) async {
  await _setTestViewport(tester, const Size(900, 1400));
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  Future<SettlementCalculationV3> Function(SettlementBreakdownV2Params)
      loader, {
  List<ExpenseEntry> transactions = const <ExpenseEntry>[],
  List<ExpenseSplitGroup> splits = const <ExpenseSplitGroup>[],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        householdSettlementCalculationV3Provider.overrideWith(
          (ref, params) => loader(params),
        ),
      ],
      child: _testApp(
        SettlementCalculationBreakdownPage(
          householdId: _householdId,
          currentUserId: '',
          memberUserId: '',
          memberDisplayName: 'Alex',
          currencyCode: 'CAD',
          transactions: transactions,
          splits: splits,
          paidToCents: 99999,
          paidFromCents: 88888,
          netCents: 77777,
        ),
      ),
    ),
  );
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

SettlementCalculationV3 _reportedCalculation() {
  return SettlementCalculationV3(
    netCents: 6611,
    rows: [
      _row(
        id: 'Wet and dry catfood',
        direction: SettlementBreakdownDirectionV2.youOwe,
        amountCents: 11223,
      ),
      _row(
        id: 'groceries',
        direction: SettlementBreakdownDirectionV2.theyOweYou,
        amountCents: 4612,
      ),
    ],
  );
}

SettlementBreakdownRowV2 _row({
  required String id,
  required SettlementBreakdownDirectionV2 direction,
  required int amountCents,
}) {
  return SettlementBreakdownRowV2(
    direction: direction,
    expenseId: id,
    splitGroupId: 'group-$id',
    splitLineId: 'line-$id',
    expenseDate: DateTime.utc(2026, 7, 16),
    expenseDescription: id,
    expenseCategory: 'Other',
    expenseRawText: id,
    expenseType: 'expense',
    totalAmountCents: amountCents,
    remainingAmountCents: amountCents,
  );
}

ExpenseEntry _legacyExpense() {
  return ExpenseEntry(
    id: 'legacy-expense',
    userId: 'me',
    householdId: _householdId,
    date: DateTime.utc(2026, 7, 16),
    amountCents: 10000,
    currency: 'CAD',
    rawText: 'Legacy FIFO row must not render',
    createdAt: DateTime.utc(2026, 7, 16),
    type: 'expense',
  );
}

ExpenseSplitGroup _legacySplit() {
  final now = DateTime.utc(2026, 7, 16);
  return ExpenseSplitGroup(
    id: 'legacy-group',
    householdId: _householdId,
    expenseId: 'legacy-expense',
    payerUserId: 'alex',
    splitType: SplitType.equal,
    currency: 'CAD',
    totalAmountCents: 10000,
    createdAt: now,
    updatedAt: now,
    splitLines: [
      ExpenseSplitLine(
        id: 'legacy-line',
        splitGroupId: 'legacy-group',
        userId: 'me',
        amountCents: 10000,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'owner@example.com');
}

class _Repository extends Mock implements HouseholdRepository {}

void main() {
  final date = DateTime(2026, 10, 3);
  final household = Household(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Shared Space',
    ownerId: 'owner',
    currency: 'USD',
    autoSplitConfig: const {
      'splitType': 'percentage',
      'memberSplits': [
        {'userId': 'owner', 'percentage': 75},
        {'userId': 'member', 'percentage': 25},
      ],
    },
    createdAt: date,
    updatedAt: date,
  );
  final members = [
    for (final id in ['owner', 'member'])
      HouseholdMember(
        id: id,
        householdId: household.id,
        userId: id,
        userName: id,
        role: HouseholdRole.member,
        joinedAt: date,
        createdAt: date,
        updatedAt: date,
      ),
  ];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
      httpClient: MockClient((_) async => http.Response('[]', 200,
          headers: {'content-type': 'application/json'})),
    );
  });

  for (final scenario in [
    (
      amount: 0.0,
      selectionRetained: true,
      outcome: 'success',
      type: SplitType.percentage
    ),
    (
      amount: 100.0,
      selectionRetained: true,
      outcome: 'success',
      type: SplitType.percentage
    ),
    (
      amount: 0.0,
      selectionRetained: false,
      outcome: 'success',
      type: SplitType.percentage
    ),
    (
      amount: 0.0,
      selectionRetained: true,
      outcome: 'failure',
      type: SplitType.percentage
    ),
    (
      amount: 0.0,
      selectionRetained: true,
      outcome: 'empty',
      type: SplitType.percentage
    ),
    (
      amount: 0.0,
      selectionRetained: true,
      outcome: 'success',
      type: SplitType.shares
    ),
    (
      amount: 100.0,
      selectionRetained: true,
      outcome: 'success',
      type: SplitType.shares
    ),
  ]) {
    final initialAmount = scenario.amount;
    testWidgets('selected shared Space split loading $scenario',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_household_id:owner': household.id,
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = _Repository();
      final configuredHousehold = household.copyWith(autoSplitConfig: {
        'splitType': scenario.type.name,
        'memberSplits': scenario.type == SplitType.shares
            ? [
                {'userId': 'owner', 'shares': 3},
                {'userId': 'member', 'shares': 1},
              ]
            : household.autoSplitConfig!['memberSplits'],
      });
      final response = Completer<List<HouseholdMember>>();
      when(() => repository.getUserHouseholds('owner'))
          .thenAnswer((_) async => [configuredHousehold]);
      when(() => repository.getHouseholdMembers(household.id))
          .thenAnswer((_) => response.future);
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(preferences),
        householdRepositoryProvider.overrideWithValue(repository),
        preloadedUserHouseholdsProvider('owner')
            .overrideWith((ref) => [configuredHousehold]),
        householdScopeProvider.overrideWithValue(HouseholdScope(
          viewMode: ViewMode.household,
          selected: SelectedHouseholdState(
              householdId: household.id, household: configuredHousehold),
          portfolioHouseholdIds: const {},
        )),
        walletsByCurrencyProvider.overrideWith((ref, query) async => []),
      ]);
      addTearDown(container.dispose);
      // Reopening the sheet can retain a valid sharing selection.
      if (scenario.selectionRetained) {
        container.read(selectedHouseholdForSharingProvider.notifier).state =
            household.id;
      }
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showUnifiedTransactionSheet(context,
                    newExpense: ParsedExpense(
                      amount: initialAmount,
                      category: 'other',
                      currency: 'USD',
                      currencySymbol: '\$',
                      date: date,
                    )),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => repository.getHouseholdMembers(household.id)).called(1);
      expect(find.byType(GroupSplitEditorSection), findsNothing);

      if (scenario.outcome == 'failure') {
        response.completeError(StateError('member read failed'));
      } else {
        response.complete(scenario.outcome == 'empty' ? [] : members);
      }
      await tester.pumpAndSettle();
      if (scenario.outcome != 'success') {
        expect(find.byType(GroupSplitEditorSection), findsNothing);
        if (scenario.outcome == 'failure') {
          expect(find.textContaining('member read failed'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        return;
      }
      final section = tester.widget<GroupSplitEditorSection>(
          find.byType(GroupSplitEditorSection));
      expect(section.members, members);
      expect(section.selectedPayerUserId, 'owner');
      expect(section.initialSplitType, scenario.type);
      final dropdowns = tester.widgetList<DropdownButton<String>>(
          find.byType(DropdownButton<String>));
      expect(dropdowns, hasLength(1));
      expect(dropdowns.single.value, 'owner');
      expect(find.text('Space'), findsOneWidget);

      if (initialAmount == 0) {
        final pending = container.read(pendingExpenseProvider)!;
        container.read(pendingExpenseProvider.notifier).state =
            pending.copyWith(amount: 100);
        await tester.pumpAndSettle();
      }
      final updated = tester.widget<GroupSplitEditorSection>(
          find.byType(GroupSplitEditorSection));
      final splits = updated.initialSplits!;
      expect(updated.initialSplitType, scenario.type);
      if (scenario.type == SplitType.percentage) {
        expect(splits.map((split) => split.percentage), [75, 25]);
      } else {
        expect(splits.map((split) => split.shares), [3, 1]);
      }
      await tester.drag(
          find.byType(CustomScrollView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      for (final label in ['Amount', 'Percent', 'Share']) {
        final option = find.text(label);
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        final editor = tester.widget<GroupSplitEditorSection>(
            find.byType(GroupSplitEditorSection));
        expect(
            editor.initialSplitType,
            switch (label) {
              'Amount' => SplitType.amount,
              'Percent' => SplitType.percentage,
              _ => SplitType.shares,
            });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _FakeSplitRequest extends Fake implements SplitRequest {}

HouseholdMember _member(String id) {
  final now = DateTime(2026);
  return HouseholdMember(
    id: id,
    householdId: 'h1',
    userId: id,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    userName: 'Hanna',
  );
}

SharedBudget _budget(String id) {
  final now = DateTime(2026);
  return SharedBudget(
    id: id,
    householdId: 'h1',
    name: 'Groceries',
    period: BudgetPeriod.monthly,
    currency: 'USD',
    amountCents: 10000,
    warnThreshold: 0.8,
    alertThreshold: 1.0,
    isActive: true,
    budgetType: BudgetType.household,
    countSplitPortionOnly: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(HouseholdRole.member);
    registerFallbackValue(_FakeSplitRequest());
  });

  group('household refresh notifiers', () {
    late _MockHouseholdRepository repository;

    setUp(() {
      repository = _MockHouseholdRepository();
      when(() => repository.getUserHouseholds(any()))
          .thenAnswer((_) async => const <Household>[]);
      when(() => repository.getHousehold(any())).thenAnswer((_) async => null);
      when(
        () => repository.createHousehold(
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          coverImageUrl: any(named: 'coverImageUrl'),
          themeColor: any(named: 'themeColor'),
          isPortfolio: any(named: 'isPortfolio'),
        ),
      ).thenThrow(UnimplementedError());
      when(
        () => repository.updateHousehold(
          householdId: any(named: 'householdId'),
          name: any(named: 'name'),
          coverImageUrl: any(named: 'coverImageUrl'),
          themeColor: any(named: 'themeColor'),
          isPortfolio: any(named: 'isPortfolio'),
          autoSplitEnabled: any(named: 'autoSplitEnabled'),
          autoSplitConfig: any(named: 'autoSplitConfig'),
          updateAutoSplitConfig: any(named: 'updateAutoSplitConfig'),
        ),
      ).thenThrow(UnimplementedError());
      when(() => repository.deleteHousehold(any()))
          .thenThrow(UnimplementedError());
      when(() => repository.removeMember(any())).thenAnswer((_) async {});
      when(() => repository.updateMemberRole(any(), any()))
          .thenAnswer((_) async {});
      when(() => repository.leaveHousehold(any())).thenAnswer((_) async {});
      when(() => repository.getHouseholdInvites(any()))
          .thenAnswer((_) async => const <HouseholdInvite>[]);
      when(
        () => repository.createInvite(
          householdId: any(named: 'householdId'),
          invitedEmail: any(named: 'invitedEmail'),
          personalMessage: any(named: 'personalMessage'),
          inviterName: any(named: 'inviterName'),
          householdName: any(named: 'householdName'),
          expiresInDays: any(named: 'expiresInDays'),
        ),
      ).thenThrow(UnimplementedError());
      when(() => repository.validateInvite(any()))
          .thenThrow(UnimplementedError());
      when(() => repository.acceptInvite(any()))
          .thenThrow(UnimplementedError());
      when(
        () => repository.revokeInvite(
          inviteId: any(named: 'inviteId'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.getHouseholdSplits(
          householdId: any(named: 'householdId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => const <ExpenseSplitGroup>[]);
      when(() => repository.computeSplit(any()))
          .thenThrow(UnimplementedError());
      when(
        () => repository.createBudget(
          householdId: any(named: 'householdId'),
          name: any(named: 'name'),
          period: any(named: 'period'),
          currency: any(named: 'currency'),
          amountCents: any(named: 'amountCents'),
          warnThreshold: any(named: 'warnThreshold'),
          alertThreshold: any(named: 'alertThreshold'),
          budgetType: any(named: 'budgetType'),
          countSplitPortionOnly: any(named: 'countSplitPortionOnly'),
        ),
      ).thenThrow(UnimplementedError());
      when(
        () => repository.updateBudget(
          budgetId: any(named: 'budgetId'),
          name: any(named: 'name'),
          amountCents: any(named: 'amountCents'),
          warnThreshold: any(named: 'warnThreshold'),
          alertThreshold: any(named: 'alertThreshold'),
          isActive: any(named: 'isActive'),
        ),
      ).thenThrow(UnimplementedError());
      when(() => repository.deleteBudget(any())).thenAnswer((_) async {});
      when(
        () => repository.getSharingPreferences(
          userId: any(named: 'userId'),
          householdId: any(named: 'householdId'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => repository.updateSharingPreferences(
          userId: any(named: 'userId'),
          householdId: any(named: 'householdId'),
          defaultTransactionShareScope:
              any(named: 'defaultTransactionShareScope'),
          defaultAccountShareScope: any(named: 'defaultAccountShareScope'),
          perCategoryOverrides: any(named: 'perCategoryOverrides'),
          enableNudges: any(named: 'enableNudges'),
          nudgeQuietHoursStart: any(named: 'nudgeQuietHoursStart'),
          nudgeQuietHoursEnd: any(named: 'nudgeQuietHoursEnd'),
        ),
      ).thenThrow(UnimplementedError());
      when(
        () => repository.getHouseholdSummary(
          householdId: any(named: 'householdId'),
          currency: any(named: 'currency'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(UnimplementedError());
      when(() => repository.watchHouseholdMembers(any())).thenReturn(null);
      when(() => repository.watchHouseholdInvites(any())).thenReturn(null);
      when(() => repository.watchHouseholdBudgets(any())).thenReturn(null);
    });

    test('members refresh keeps the previous value visible while loading',
        () async {
      final initialMembers = [_member('u2')];
      when(() => repository.getHouseholdMembers('h1'))
          .thenAnswer((_) async => initialMembers);

      final notifier = HouseholdMembersNotifier(repository, 'h1');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.state.valueOrNull, initialMembers);

      final refreshCompleter = Completer<List<HouseholdMember>>();
      when(() => repository.getHouseholdMembers('h1'))
          .thenAnswer((_) => refreshCompleter.future);

      final refresh = notifier.load();

      expect(notifier.state.valueOrNull, initialMembers);

      final refreshedMembers = [_member('u3')];
      refreshCompleter.complete(refreshedMembers);
      await refresh;

      expect(notifier.state.valueOrNull, refreshedMembers);
    });

    test('budgets refresh keeps the previous value visible while loading',
        () async {
      final initialBudgets = [_budget('b1')];
      when(() => repository.getHouseholdBudgets('h1'))
          .thenAnswer((_) async => initialBudgets);

      final notifier = HouseholdBudgetsNotifier(repository, 'h1');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.state.valueOrNull, initialBudgets);

      final refreshCompleter = Completer<List<SharedBudget>>();
      when(() => repository.getHouseholdBudgets('h1'))
          .thenAnswer((_) => refreshCompleter.future);

      final refresh = notifier.load();

      expect(notifier.state.valueOrNull, initialBudgets);

      final refreshedBudgets = [_budget('b2')];
      refreshCompleter.complete(refreshedBudgets);
      await refresh;

      expect(notifier.state.valueOrNull, refreshedBudgets);
    });
  });
}

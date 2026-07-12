import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void main() {
  group('HouseholdScope', () {
    test(
        'defaults to personal when in household mode without a selected household',
        () {
      const scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(),
        portfolioHouseholdIds: {},
      );

      expect(scope.activeAccountType, ActiveWalletType.personal);
      expect(scope.activeAccountHouseholdId, isNull);
      expect(scope.isHouseholdView, isFalse);
      expect(scope.isPersonalView, isTrue);
    });

    test('treats selected portfolio household as a personal-view account', () {
      const scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(householdId: 'h1'),
        portfolioHouseholdIds: {'h1'},
      );

      expect(scope.activeAccountType, ActiveWalletType.portfolio);
      expect(scope.activeAccountHouseholdId, 'h1');
      expect(scope.isHouseholdView, isFalse);
      expect(scope.isPersonalView, isTrue);
    });

    test('treats selected non-portfolio household as household view', () {
      const scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(householdId: 'h2'),
        portfolioHouseholdIds: {},
      );

      expect(scope.activeAccountType, ActiveWalletType.household);
      expect(scope.activeAccountHouseholdId, 'h2');
      expect(scope.isHouseholdView, isTrue);
      expect(scope.isPersonalView, isFalse);
    });

    test('never treats an optimistic household ID as shared scope', () {
      const scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(
          householdId: 'optimistic-household-1783843926425266',
        ),
        portfolioHouseholdIds: {},
      );

      expect(scope.activeAccountType, ActiveWalletType.personal);
      expect(scope.activeAccountHouseholdId, isNull);
      expect(scope.isHouseholdView, isFalse);
      expect(scope.isPersonalView, isTrue);
    });

    test(
        'selected portfolio metadata wins before the household list catches up',
        () {
      final privateSpace = Household(
        id: 'private-space',
        name: 'Private Space',
        ownerId: 'user-1',
        currency: 'EUR',
        isPortfolio: true,
        createdAt: DateTime(2026, 7, 11),
        updatedAt: DateTime(2026, 7, 11),
      );
      final scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: SelectedHouseholdState(
          householdId: 'private-space',
          household: privateSpace,
        ),
        portfolioHouseholdIds: {},
      );

      expect(scope.isPortfolioSelected, isTrue);
      expect(scope.activeAccountType, ActiveWalletType.portfolio);
      expect(scope.activeAccountHouseholdId, 'private-space');
      expect(scope.isHouseholdView, isFalse);
      expect(scope.isPersonalView, isTrue);
    });

    test('canonical private metadata replaces a stale cached shared object',
        () {
      final now = DateTime(2026, 7, 12);
      final stale = Household(
        id: 'ce1aabf8-90b1-41d1-9fe6-a4188b36a27f',
        name: 'Private Space',
        ownerId: 'user-1',
        currency: 'EUR',
        isPortfolio: false,
        createdAt: now,
        updatedAt: now,
      );
      final canonical = stale.copyWith(isPortfolio: true);

      final selection = canonicalizeHouseholdSelection(
        SelectedHouseholdState(householdId: stale.id, household: stale),
        [canonical],
      );
      final scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: selection,
        portfolioHouseholdIds: {canonical.id},
      );

      expect(selection.household, canonical);
      expect(scope.activeAccountType, ActiveWalletType.portfolio);
      expect(scope.isPersonalView, isTrue);
      expect(scope.isHouseholdView, isFalse);
    });

    test(
        'personal view mode forces personal scope even if a household is selected',
        () {
      const scope = HouseholdScope(
        viewMode: ViewMode.personal,
        selected: SelectedHouseholdState(householdId: 'h3'),
        portfolioHouseholdIds: {},
      );

      expect(scope.activeAccountType, ActiveWalletType.personal);
      expect(scope.activeAccountHouseholdId, isNull);
      expect(scope.isPersonalView, isTrue);
    });
  });
}

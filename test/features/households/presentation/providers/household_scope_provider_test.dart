import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
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

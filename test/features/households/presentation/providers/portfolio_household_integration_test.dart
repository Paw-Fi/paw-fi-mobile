import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void main() {
  group('Portfolio Household Integration Tests', () {
    test('Portfolio household is identified correctly by is_portfolio flag',
        () {
      final now = DateTime.now();

      // Create a portfolio household
      final portfolioHousehold = Household(
        id: 'portfolio_1',
        name: 'My Investment Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true, // This is the key flag
        createdAt: now,
        updatedAt: now,
      );

      // Create a regular household
      final regularHousehold = Household(
        id: 'household_1',
        name: 'Family Budget',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(portfolioHousehold.isPortfolio, true);
      expect(regularHousehold.isPortfolio, false);
    });

    test('Portfolio households are included in portfolioHouseholdIds set', () {
      final now = DateTime.now();

      final households = [
        Household(
          id: 'portfolio_1',
          name: 'Investment Portfolio',
          ownerId: 'test_user_1',
          currency: 'USD',
          isPortfolio: true,
          createdAt: now,
          updatedAt: now,
        ),
        Household(
          id: 'portfolio_2',
          name: 'Crypto Portfolio',
          ownerId: 'test_user_1',
          currency: 'USD',
          isPortfolio: true,
          createdAt: now,
          updatedAt: now,
        ),
        Household(
          id: 'household_1',
          name: 'Family Budget',
          ownerId: 'test_user_1',
          currency: 'USD',
          isPortfolio: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Manually construct household scope for testing
      final portfolioIds =
          households.where((h) => h.isPortfolio).map((h) => h.id).toSet();

      expect(portfolioIds, {'portfolio_1', 'portfolio_2'});
      expect(portfolioIds.contains('household_1'), false);
    });

    test('isPortfolioId correctly identifies portfolio households', () {
      final now = DateTime.now();

      final households = [
        Household(
          id: 'portfolio_1',
          name: 'Investment Portfolio',
          ownerId: 'test_user_1',
          currency: 'USD',
          isPortfolio: true,
          createdAt: now,
          updatedAt: now,
        ),
        Household(
          id: 'household_1',
          name: 'Family Budget',
          ownerId: 'test_user_1',
          currency: 'USD',
          isPortfolio: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final portfolioIds =
          households.where((h) => h.isPortfolio).map((h) => h.id).toSet();

      // Test isPortfolioId logic
      expect(portfolioIds.contains('portfolio_1'), true);
      expect(portfolioIds.contains('household_1'), false);
      expect(portfolioIds.contains('non_existent'), false);
      expect(portfolioIds.contains(null), false);
    });

    test('isHouseholdView returns false when portfolio is selected', () {
      final now = DateTime.now();

      // Create household scope with portfolio selected
      final portfolioHousehold = Household(
        id: 'portfolio_1',
        name: 'Investment Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: now,
        updatedAt: now,
      );

      final selectedState = SelectedHouseholdState(
        householdId: 'portfolio_1',
        household: portfolioHousehold,
      );

      final scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: selectedState,
        portfolioHouseholdIds: {'portfolio_1'},
      );

      // Even though viewMode is household, isHouseholdView should be false for portfolio
      expect(scope.isHouseholdView, false);
      expect(scope.isPersonalView, true);
      expect(scope.isPortfolioSelected, true);
    });

    test('isHouseholdView returns true when true household is selected', () {
      final now = DateTime.now();

      final regularHousehold = Household(
        id: 'household_1',
        name: 'Family Budget',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: false,
        createdAt: now,
        updatedAt: now,
      );

      final selectedState = SelectedHouseholdState(
        householdId: 'household_1',
        household: regularHousehold,
      );

      final scope = HouseholdScope(
        viewMode: ViewMode.household,
        selected: selectedState,
        portfolioHouseholdIds: {},
      );

      expect(scope.isHouseholdView, true);
      expect(scope.isPersonalView, false);
      expect(scope.isPortfolioSelected, false);
    });

    test('isPersonalView returns true in personal mode', () {
      final selectedState = SelectedHouseholdState(
        householdId: null,
        household: null,
      );

      final scope = HouseholdScope(
        viewMode: ViewMode.personal,
        selected: selectedState,
        portfolioHouseholdIds: {},
      );

      expect(scope.isPersonalView, true);
      expect(scope.isHouseholdView, false);
    });

    test('Portfolio household fromJson includes is_portfolio field', () {
      final json = {
        'id': 'portfolio_1',
        'name': 'Investment Portfolio',
        'owner_id': 'test_user_1',
        'currency': 'USD',
        'is_portfolio': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final household = Household.fromJson(json);

      expect(household.id, 'portfolio_1');
      expect(household.isPortfolio, true);
    });

    test(
        'Portfolio household fromJson defaults is_portfolio to false when missing',
        () {
      final json = {
        'id': 'household_1',
        'name': 'Family Budget',
        'owner_id': 'test_user_1',
        'currency': 'USD',
        // is_portfolio is missing
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final household = Household.fromJson(json);

      expect(household.id, 'household_1');
      expect(household.isPortfolio, false);
    });

    test('Portfolio household toJson includes is_portfolio field', () {
      final now = DateTime(2024, 1, 1);

      final household = Household(
        id: 'portfolio_1',
        name: 'Investment Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = household.toJson();

      expect(json['is_portfolio'], true);
    });

    test('Portfolio household copyWith preserves is_portfolio flag', () {
      final now = DateTime(2024, 1, 1);

      final original = Household(
        id: 'portfolio_1',
        name: 'Investment Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Updated Portfolio Name');

      expect(updated.isPortfolio, true);
      expect(updated.name, 'Updated Portfolio Name');
    });

    test('Portfolio household copyWith can change is_portfolio flag', () {
      final now = DateTime(2024, 1, 1);

      final original = Household(
        id: 'portfolio_1',
        name: 'Investment Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(isPortfolio: false);

      expect(updated.isPortfolio, false);
      expect(updated.name, 'Investment Portfolio');
    });

    test('Portfolio household equality includes is_portfolio flag', () {
      final now = DateTime(2024, 1, 1);

      final household1 = Household(
        id: 'portfolio_1',
        name: 'Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: now,
        updatedAt: now,
      );

      final household2 = Household(
        id: 'portfolio_1',
        name: 'Portfolio',
        ownerId: 'test_user_1',
        currency: 'USD',
        isPortfolio: false, // Different flag
        createdAt: now,
        updatedAt: now,
      );

      expect(household1, isNot(equals(household2)));
      expect(household1.hashCode, isNot(equals(household2.hashCode)));
    });
  });
}

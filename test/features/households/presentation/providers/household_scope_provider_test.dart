import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

class _GuestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: '', email: '');
}

class _SignedInAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: '');
}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _LoadingHouseholdsNotifier extends UserHouseholdsNotifier {
  _LoadingHouseholdsNotifier(HouseholdRepository repository, String userId,
      Ref ref)
      : super(repository, userId, ref);

  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('householdScopeProvider', () {
    test('guest preview resolves an unselected default mode to Personal',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_GuestAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        previewModeProvider.overrideWith(
            (ref) => PreviewModeNotifier(initiallyActive: true)),
      ]);
      addTearDown(container.dispose);

      final scope = container.read(householdScopeProvider);
      expect(container.read(viewModeProvider).mode, ViewMode.household);
      expect(container.read(selectedHouseholdProvider).householdId, isNull);
      expect(scope.viewMode, ViewMode.personal);
      expect(scope.activeAccountType, ActiveWalletType.personal);
      expect(scope.activeAccountHouseholdId, isNull);
      expect(prefs.getString('moneko_view_mode'), isNull);

      container.read(previewModeProvider.notifier).disable();
      final liveScope = container.read(householdScopeProvider);
      expect(liveScope.viewMode, ViewMode.household);
      expect(liveScope.portfolioHouseholdIds, isEmpty);
    });

    for (final household in PreviewMockData.households) {
      test('guest preview resolves selected mock Space ${household.id}',
          () async {
        SharedPreferences.setMockInitialValues({
          'selected_household_id': household.id,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(overrides: [
          authProvider.overrideWith(_GuestAuth.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
          previewModeProvider.overrideWith(
              (ref) => PreviewModeNotifier(initiallyActive: true)),
        ]);
        addTearDown(container.dispose);
        final subscription =
            container.listen(householdScopeProvider, (_, __) {});
        addTearDown(subscription.close);

        await container.read(selectedHouseholdProvider.notifier).initialize();

        final scope = container.read(householdScopeProvider);
        expect(scope.viewMode, ViewMode.household);
        expect(scope.selectedHouseholdId, household.id);
        expect(scope.selected.household?.isPortfolio, household.isPortfolio);
        expect(
            scope.activeAccountType,
            household.isPortfolio
                ? ActiveWalletType.portfolio
                : ActiveWalletType.household);
        expect(scope.activeAccountHouseholdId, household.id);
      });
    }

    test('authenticated unresolved Space retains household loading mode',
        () async {
      SharedPreferences.setMockInitialValues({
        'selected_household_id:user-1': 'pending-space',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_SignedInAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        previewModeProvider.overrideWith(
            (ref) => PreviewModeNotifier(initiallyActive: false)),
        userHouseholdsProvider.overrideWith(
          (ref, userId) => _LoadingHouseholdsNotifier(
              _MockHouseholdRepository(), userId, ref),
        ),
      ]);
      addTearDown(container.dispose);

      final scope = container.read(householdScopeProvider);
      expect(scope.viewMode, ViewMode.household);
      expect(scope.hasSelectedHousehold, isFalse);
      expect(scope.portfolioHouseholdIds, isEmpty);
      expect(container.read(selectedHouseholdProvider).householdId,
          'pending-space');
    });
  });

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

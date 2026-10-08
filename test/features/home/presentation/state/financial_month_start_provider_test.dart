import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'test@example.com');

  void switchUser() =>
      state = const AppUser(uid: 'user-2', email: 'other@example.com');
}

class _Initialization extends AppInitializationV2 {
  _Initialization(this.initialContact);
  final UserContact? initialContact;

  @override
  AppInitializationState build() => AppInitializationState(
      state: AppInitState.initialized,
      data: InitData(user: initialContact, timestamp: DateTime(2026, 10, 8)));
}

class _Analytics extends AnalyticsNotifier {
  _Analytics(super.ref);

  void setContact(UserContact contact) =>
      state = AnalyticsData(contact: contact, hasLoadedOnce: true);
}

class _Store extends HomePeriodSelectionStore {
  _Store(this.pending);
  final Future<HomePeriodSelectionState?> pending;

  @override
  Future<HomePeriodSelectionState?> load(String userId) => pending;
}

UserContact _contact(int day, {String userId = 'user-1'}) => UserContact(
    id: 'contact-$userId',
    userId: userId,
    verified: true,
    preferredCurrency: 'EUR',
    financialMonthStartDay: day);

ProviderContainer _container({
  UserContact? initializedContact,
  required Future<UserContact?> Function(Ref ref) loadContact,
  Future<HomePeriodSelectionState?>? storedSelection,
}) =>
    ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      analyticsProvider.overrideWith(_Analytics.new),
      appInitializationV2Provider
          .overrideWith(() => _Initialization(initializedContact)),
      dashboardUserContactProvider.overrideWith(loadContact),
      selectedHomeCurrencyCodeProvider.overrideWithValue('EUR'),
      householdScopeProvider.overrideWithValue(const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: {})),
      homePeriodClockProvider.overrideWithValue(() => DateTime(2026, 10, 8)),
      homePeriodSelectionStoreProvider
          .overrideWithValue(_Store(storedSelection ?? Future.value(null))),
      includeUpcomingRecurringInPocketsProvider.overrideWith((ref) => false),
    ]);

void main() {
  test('cached month start avoids a default-cycle request and late replay',
      () async {
    var contactReads = 0;
    final container = _container(
      initializedContact: _contact(2),
      loadContact: (ref) async {
        contactReads++;
        throw StateError('Cached metadata must avoid a contact fetch');
      },
    );
    addTearDown(container.dispose);
    final requests = <BudgetCompanionRequest?>[];
    container.listen(
        budgetCompanionRequestProvider, (_, next) => requests.add(next),
        fireImmediately: true);
    expect(container.read(financialMonthStartDayProvider), 2);
    expect(container.read(budgetCompanionRequestProvider), isNull);
    await container.pump();
    final initial = container.read(budgetCompanionRequestProvider)!;
    expect(initial.query.startDate, DateTime(2026, 10, 2));
    expect(initial.query.endDate, DateTime(2026, 11, 1));
    expect(initial.pocketsScope.normalizedFinancialMonthStartDay, 2);
    final publishedCount = requests.length;
    (container.read(analyticsProvider.notifier) as _Analytics)
        .setContact(_contact(2));
    await container.pump();
    expect(container.read(budgetCompanionRequestProvider), initial);
    expect(requests.length, publishedCount);
    expect(contactReads, 0);

    // A real settings change still selects a distinct correct family.
    (container.read(analyticsProvider.notifier) as _Analytics)
        .setContact(_contact(15));
    await container.pump();
    expect(container.read(budgetCompanionRequestProvider)!.query.startDate,
        DateTime(2026, 9, 15));
    expect(container.read(budgetCompanionRequestProvider)!.pocketsScope,
        isNot(initial.pocketsScope));
  });

  test('waits for contact and saved period before the first scoped request',
      () async {
    final contact = Completer<UserContact?>();
    final selection = Completer<HomePeriodSelectionState?>();
    final container = _container(
        loadContact: (ref) => contact.future,
        storedSelection: selection.future);
    addTearDown(container.dispose);
    container.listen(budgetCompanionRequestProvider, (_, __) {});
    expect(container.read(budgetCompanionRequestProvider), isNull);
    contact.complete(_contact(2));
    await container.pump();
    expect(container.read(financialMonthStartDayProvider), 2);
    expect(container.read(budgetCompanionRequestProvider), isNull);
    selection.complete(HomePeriodSelectionState(
        mode: HomePeriodMode.monthly,
        selectedDate: DateTime(2026, 9, 2),
        isHydrated: true));
    await container.pump();
    expect(container.read(budgetCompanionRequestProvider)!.query.startDate,
        DateTime(2026, 9, 2));
  });

  test('confirmed absent contact uses day one; failed contact shows an error',
      () async {
    final pending = Completer<UserContact?>();
    final container = _container(loadContact: (ref) => pending.future);
    addTearDown(container.dispose);
    container.listen(budgetCompanionDataProvider, (_, __) {});
    expect(
        container.read(budgetCompanionDataProvider).summary.isLoading, isTrue);
    pending.completeError(StateError('offline'));
    await container.pump();
    expect(
        container.read(budgetCompanionDataProvider).summary.hasError, isTrue);
    expect(
        container.read(budgetCompanionDataProvider).summary.isLoading, isFalse);
    final empty = _container(loadContact: (ref) async => null);
    addTearDown(empty.dispose);
    empty.listen(budgetCompanionRequestProvider, (_, __) {});
    await empty.pump();
    expect(empty.read(financialMonthStartDayStateProvider).requireValue, 1);
    expect(empty.read(budgetCompanionRequestProvider)!.query.startDate,
        DateTime(2026, 10));
  });

  test('cached contact remains usable during refresh and offline failure',
      () async {
    final revision = StateProvider((ref) => 0);
    var pending = Completer<UserContact?>();
    final container = _container(loadContact: (ref) {
      ref.watch(revision);
      return pending.future;
    });
    addTearDown(container.dispose);
    final requests = <BudgetCompanionRequest?>[];
    container.listen(
        budgetCompanionRequestProvider, (_, next) => requests.add(next));
    pending.complete(_contact(2));
    await container.pump();
    final initial = container.read(budgetCompanionRequestProvider)!;
    final count = requests.length;
    pending = Completer<UserContact?>();
    container.read(revision.notifier).state++;
    await container.pump();
    expect(
        container.read(financialMonthStartDayStateProvider).isLoading, isTrue);
    expect(container.read(financialMonthStartDayStateProvider).requireValue, 2);
    expect(container.read(budgetCompanionRequestProvider), initial);
    pending.completeError(StateError('offline'));
    await container.pump();
    expect(
        container.read(financialMonthStartDayStateProvider).hasError, isTrue);
    expect(container.read(financialMonthStartDayStateProvider).requireValue, 2);
    expect(container.read(budgetCompanionRequestProvider), initial);
    expect(requests.length, count);
  });

  test('account switch cannot reuse another user calendar preference',
      () async {
    final pending = Completer<UserContact?>();
    final container = _container(
        initializedContact: _contact(2), loadContact: (ref) => pending.future);
    addTearDown(container.dispose);
    container.listen(budgetCompanionRequestProvider, (_, __) {});
    await container.pump();
    expect(
        container.read(budgetCompanionRequestProvider)!.query.userId, 'user-1');
    (container.read(authProvider.notifier) as _Auth).switchUser();
    expect(container.read(budgetCompanionRequestProvider), isNull);
    pending.complete(_contact(15, userId: 'user-2'));
    await container.pump();
    final request = container.read(budgetCompanionRequestProvider)!;
    expect(request.query.userId, 'user-2');
    expect(request.query.startDate, DateTime(2026, 9, 15));
  });

  test('preview preference resolves without initialization or contact reads',
      () {
    final container = ProviderContainer(overrides: [
      previewModeProvider
          .overrideWith((ref) => PreviewModeNotifier(initiallyActive: true)),
      appInitializationV2Provider.overrideWith(
          () => throw StateError('Preview must not initialize live data')),
      dashboardUserContactProvider.overrideWith(
          (ref) => throw StateError('Preview must not fetch contact data')),
    ]);
    addTearDown(container.dispose);
    expect(
        container.read(financialMonthStartDayStateProvider).hasValue, isTrue);
    expect(
        container.read(financialMonthStartDayStateProvider).isLoading, isFalse);
  });
}

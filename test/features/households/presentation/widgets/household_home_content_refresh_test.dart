import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_repository.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

const _householdId = '00000000-0000-0000-0000-000000000001';

class MockAnalyticsNotifier extends AnalyticsNotifier {
  MockAnalyticsNotifier(Ref ref, AnalyticsData data) : super(ref) {
    state = data;
  }
}

class MockAuth extends Auth {
  @override
  AppUser build() {
    return const AppUser(uid: 'u1', email: 'test@example.com');
  }
}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class MockUserHouseholdsNotifier extends UserHouseholdsNotifier {
  MockUserHouseholdsNotifier(
    HouseholdRepository repository,
    String userId,
    Ref ref,
  ) : super(repository, userId, ref);

  Future<List<Household>> build() async {
    return [
      Household(
        id: _householdId,
        name: 'Test Household',
        ownerId: 'u1',
        currency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

class MockHouseholdMembersNotifier extends HouseholdMembersNotifier {
  MockHouseholdMembersNotifier(super.repository, super.householdId);

  Future<List<HouseholdMember>> build() async {
    return [];
  }
}

class MockSelectedHouseholdNotifier extends SelectedHouseholdNotifier {
  MockSelectedHouseholdNotifier(super.ref, super.prefs, super.userId) {
    state = SelectedHouseholdState(
      householdId: _householdId,
      household: Household(
        id: _householdId,
        name: 'Test Household',
        ownerId: 'u1',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
  }

  @override
  Future<void> selectHousehold(String householdId) async {
    state = SelectedHouseholdState(
      householdId: householdId,
      household: Household(
        id: householdId,
        name: 'Test Household',
        ownerId: 'u1',
        currency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      isLoading: false,
    );
  }
}

class MockRecurringTransactionsNotifier extends RecurringTransactionsNotifier {
  MockRecurringTransactionsNotifier(super.ref, super.householdId);

  @override
  Future<void> loadRecurringTransactions(
    String userId, {
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // No-op: keep this provider hermetic in widget tests.
    state = state.copyWith(
      data: const AsyncValue.data(<RecurringTransaction>[]),
      hasLoadedOnce: true,
    );
  }

  Future<RecurringTransactionsState> build() async {
    return RecurringTransactionsState(
      data: const AsyncValue.data(<RecurringTransaction>[]),
      hasLoadedOnce: true,
    );
  }
}

class MockHouseholdDashboardController extends HouseholdDashboardController {
  MockHouseholdDashboardController(super.repo, super.householdId);

  Future<List<DashboardWidgetConfig>> build() async {
    return [
      const DashboardWidgetConfig(
        id: 'spent-by-you',
        type: DashboardWidgetType.householdSpentByYou,
        dateRange: DateRangeFilter.allTime,
        isVisible: true,
        order: 0,
      ),
    ];
  }
}

ExpenseEntry _expense({
  required String id,
  String? userId,
  String? householdId,
  DateTime? date,
  int? amountCents,
  String? category,
  String? rawText,
  DateTime? createdAt,
}) {
  return ExpenseEntry(
    id: id,
    userId: userId ?? 'u1',
    householdId: householdId ?? _householdId,
    date: date ?? DateTime.now(),
    amountCents: amountCents ?? 1000,
    currency: 'USD',
    category: category ?? 'food',
    rawText: rawText ?? 'Test expense',
    createdAt: createdAt ?? DateTime.now(),
    type: 'expense',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'anon',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Ignore: Supabase may already be initialized by another test.
    }
  });

  group('HouseholdHomeContent refresh behavior', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final seededLayout = jsonEncode([
        const DashboardWidgetConfig(
          id: 'spent-by-you',
          type: DashboardWidgetType.householdSpentByYou,
          dateRange: DateRangeFilter.allTime,
          isVisible: true,
          order: 0,
        ).toJson(),
      ]);
      await prefs.setString(
        'household_dashboard_layout_$_householdId',
        seededLayout,
      );

      final dashboardRepo = DashboardRepository(
        prefs,
        SupabaseClient('http://localhost', 'anon'),
      );

      final household = Household(
        id: _householdId,
        name: 'Test Household',
        ownerId: 'u1',
        currency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final householdRepository = _MockHouseholdRepository();
      when(() => householdRepository.getUserHouseholds('u1'))
          .thenAnswer((_) async => [household]);
      when(() => householdRepository.getHouseholdMembers(_householdId))
          .thenAnswer((_) async => const <HouseholdMember>[]);
      when(() => householdRepository.getHouseholdBudgets(_householdId))
          .thenAnswer((_) async => const <SharedBudget>[]);
      when(() => householdRepository.getHouseholdSplits(
            householdId: _householdId,
          )).thenAnswer((_) async => const <ExpenseSplitGroup>[]);

      container = ProviderContainer(
        overrides: [
          userHouseholdsProvider.overrideWith(
            (ref, userId) => MockUserHouseholdsNotifier(
              householdRepository,
              userId,
              ref,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(() => MockAuth()),
          currentUserIdProvider.overrideWithValue('u1'),
          currencyTransactionCountsProvider.overrideWith(
            (ref) => const <String, int>{},
          ),
          householdRepositoryProvider.overrideWithValue(householdRepository),
          dashboardRepositoryFutureProvider
              .overrideWith((ref) async => dashboardRepo),
          analyticsProvider.overrideWith(
            (ref) => MockAnalyticsNotifier(ref, AnalyticsData()),
          ),
          cachedHouseholdExpensesProvider(
            const HouseholdExpensesParams(householdId: _householdId),
          ).overrideWith(
            (ref) async => [_expense(id: 'e1')],
          ),
          selectedHouseholdProvider.overrideWith(
            (ref) => MockSelectedHouseholdNotifier(ref, prefs, 'u1'),
          ),
          recurringTransactionsProvider(_householdId).overrideWith(
            (ref) => MockRecurringTransactionsNotifier(ref, _householdId),
          ),
          householdExpensesProvider(
            const HouseholdExpensesParams(householdId: _householdId),
          ).overrideWith(
            (ref) async => [_expense(id: 'e1')],
          ),
          householdSplitsProvider(
            const HouseholdSplitsParams(householdId: _householdId),
          ).overrideWith(
            (ref) async => const <ExpenseSplitGroup>[],
          ),
          cachedHouseholdSplitsProvider(
            const HouseholdSplitsParams(householdId: _householdId),
          ).overrideWith(
            (ref) async => [],
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets(
      'household home content refreshes dashboard when cache invalidator is called',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HouseholdHomeContent(),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Verify initial content is loaded
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(HouseholdHomeContent), findsOneWidget);

        // Simulate cache invalidation as happens when expense is saved
        container
            .read(cacheInvalidatorProvider)
            .invalidateHouseholdData(_householdId);
        container.invalidate(cachedHouseholdExpensesProvider);
        container.invalidate(cachedHouseholdSplitsProvider);
        container.invalidate(householdDashboardProvider(_householdId));

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The widget should still be present and functional
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(HouseholdHomeContent), findsOneWidget);
      },
    );

    testWidgets(
      'household home content handles expense save invalidation flow',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(),
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HouseholdHomeContent(),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Simulate the exact invalidation sequence from expense_save_providers.dart
        container
            .read(cacheInvalidatorProvider)
            .invalidateHouseholdData(_householdId);
        container.invalidate(householdExpensesProvider);
        container.invalidate(cachedHouseholdExpensesProvider);
        container.invalidate(householdSplitsProvider);
        container.invalidate(cachedHouseholdSplitsProvider);
        container.invalidate(householdBudgetsProvider);
        container.invalidate(householdMembersProvider);
        container.invalidate(pocketsProvider(
          const PocketsScopeParams(
            scope: PocketsScopeType.household,
            householdId: _householdId,
          ),
        ));
        container.invalidate(currencyTransactionCountsProvider);

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Verify the UI remains stable after invalidation
        expect(find.byType(CustomScrollView), findsOneWidget);
      },
    );
  });
}

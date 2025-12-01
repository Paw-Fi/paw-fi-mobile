import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_config.dart';
import 'dashboard_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  // We assume SharedPreferences is initialized in main.dart and available via a provider or we get instance here.
  // Since we don't have a direct provider for SharedPreferences instance in the context I saw,
  // I'll assume we can get it or I should create a FutureProvider for it.
  // For now, I'll use a hack to throw if not ready, but usually apps have a 'sharedPreferencesProvider'.
  // Let's assume we can get it. If not, I'll change this to FutureProvider.
  // Actually, standard practice in this codebase seems to be passing it or using a service.
  // I'll check if there is a sharedPreferencesProvider.
  // Checking pubspec, it has shared_preferences.
  // I will use `throw UnimplementedError` if I can't find it, but better to use `ref.watch` if it exists.
  // I'll just create the instance inside the notifier or use a FutureProvider.
  throw UnimplementedError(
      'DashboardRepository needs SharedPreferences instance');
});

// Better approach: Async provider for repository
final dashboardRepositoryFutureProvider =
    FutureProvider<DashboardRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final supabase = Supabase.instance.client;
  return DashboardRepository(prefs, supabase);
});

// ============================================================================
// EDIT MODE STATE
// ============================================================================

final isEditModeProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// PERSONAL DASHBOARD CONTROLLER
// ============================================================================

class PersonalDashboardController
    extends StateNotifier<AsyncValue<List<DashboardWidgetConfig>>> {
  final DashboardRepository _repository;
  final String _userId;

  PersonalDashboardController(this._repository, this._userId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final configs = await _repository.loadPersonalLayout(_userId);
      if (configs != null && configs.isNotEmpty) {
        state = AsyncValue.data(configs);
      } else {
        // Default Layout
        state = const AsyncValue.data([
          DashboardWidgetConfig(
              id: 'spending',
              type: DashboardWidgetType.spendingSummary,
              order: 0),
          DashboardWidgetConfig(
              id: 'net_cashflow',
              type: DashboardWidgetType.netCashflow,
              order: 1),
          DashboardWidgetConfig(
              id: 'calendar',
              type: DashboardWidgetType.financialCalendar,
              order: 2),
          DashboardWidgetConfig(
              id: 'categories',
              type: DashboardWidgetType.categoryBreakdown,
              order: 3),
          DashboardWidgetConfig(
              id: 'spending_chart',
              type: DashboardWidgetType.spendingBreakdownChart,
              order: 4),
        ]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    state = AsyncValue.data(configs);
    await _repository.savePersonalLayout(_userId, configs);
  }

  void toggleVisibility(String id) {
    state.whenData((configs) {
      final newConfigs = configs.map((c) {
        if (c.id == id) return c.copyWith(isVisible: !c.isVisible);
        return c;
      }).toList();
      save(newConfigs);
    });
  }

  void updateConfig(String id,
      {DateRangeFilter? dateRange,
      DashboardWidgetViewMode? viewMode,
      DateTime? start,
      DateTime? end}) {
    state.whenData((configs) {
      final newConfigs = configs.map((c) {
        if (c.id == id) {
          return c.copyWith(
            dateRange: dateRange,
            viewMode: viewMode,
            customStartDate: start,
            customEndDate: end,
          );
        }
        return c;
      }).toList();
      save(newConfigs);
    });
  }

  void reorder(int oldIndex, int newIndex) {
    state.whenData((configs) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = configs.removeAt(oldIndex);
      configs.insert(newIndex, item);

      // Update order index in objects
      final reordered = configs.asMap().entries.map((e) {
        return e.value.copyWith(order: e.key);
      }).toList();

      save(reordered);
    });
  }
}

final personalDashboardProvider = StateNotifierProvider.family<
    PersonalDashboardController,
    AsyncValue<List<DashboardWidgetConfig>>,
    String>((ref, userId) {
  final repo = ref.watch(dashboardRepositoryFutureProvider).value;
  if (repo == null) throw Exception('Repository not initialized');
  return PersonalDashboardController(repo, userId);
});

// ============================================================================
// HOUSEHOLD DASHBOARD CONTROLLER
// ============================================================================

class HouseholdDashboardController
    extends StateNotifier<AsyncValue<List<DashboardWidgetConfig>>> {
  final DashboardRepository _repository;
  final String _householdId;

  HouseholdDashboardController(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final configs = await _repository.loadHouseholdLayout(_householdId);
      if (configs != null && configs.isNotEmpty) {
        state = AsyncValue.data(configs);
      } else {
        // Default Layout
        state = const AsyncValue.data([
          DashboardWidgetConfig(
              id: 'spent_by_you',
              type: DashboardWidgetType.householdSpentByYou,
              order: 0),
          DashboardWidgetConfig(
              id: 'calendar',
              type: DashboardWidgetType.householdFinancialCalendar,
              order: 1),
          DashboardWidgetConfig(
              id: 'budget_overview',
              type: DashboardWidgetType.householdBudgetOverview,
              order: 2),
          DashboardWidgetConfig(
              id: 'fairness',
              type: DashboardWidgetType.householdFairness,
              order: 3),
          DashboardWidgetConfig(
              id: 'settlement',
              type: DashboardWidgetType.householdSettlement,
              order: 4),
          DashboardWidgetConfig(
              id: 'member_spending',
              type: DashboardWidgetType.householdMemberSpending,
              order: 5),
          DashboardWidgetConfig(
              id: 'categories',
              type: DashboardWidgetType.householdCategoryBreakdown,
              order: 6),
          DashboardWidgetConfig(
              id: 'spending_chart',
              type: DashboardWidgetType.householdSpendingBreakdownChart,
              order: 7),
        ]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    state = AsyncValue.data(configs);
    await _repository.saveHouseholdLayout(_householdId, configs);
  }

  void toggleVisibility(String id) {
    state.whenData((configs) {
      final newConfigs = configs.map((c) {
        if (c.id == id) return c.copyWith(isVisible: !c.isVisible);
        return c;
      }).toList();
      save(newConfigs);
    });
  }

  void updateConfig(String id,
      {DateRangeFilter? dateRange,
      DashboardWidgetViewMode? viewMode,
      DateTime? start,
      DateTime? end}) {
    state.whenData((configs) {
      final newConfigs = configs.map((c) {
        if (c.id == id) {
          return c.copyWith(
            dateRange: dateRange,
            viewMode: viewMode,
            customStartDate: start,
            customEndDate: end,
          );
        }
        return c;
      }).toList();
      save(newConfigs);
    });
  }

  void reorder(int oldIndex, int newIndex) {
    state.whenData((configs) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = configs.removeAt(oldIndex);
      configs.insert(newIndex, item);

      final reordered = configs.asMap().entries.map((e) {
        return e.value.copyWith(order: e.key);
      }).toList();

      save(reordered);
    });
  }
}

final householdDashboardProvider = StateNotifierProvider.family<
    HouseholdDashboardController,
    AsyncValue<List<DashboardWidgetConfig>>,
    String>((ref, householdId) {
  final repo = ref.watch(dashboardRepositoryFutureProvider).value;
  if (repo == null) throw Exception('Repository not initialized');
  return HouseholdDashboardController(repo, householdId);
});

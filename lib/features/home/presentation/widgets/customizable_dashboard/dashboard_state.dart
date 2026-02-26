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
      if (!mounted) return;
      if (configs != null && configs.isNotEmpty) {
        configs.sort((a, b) => a.order.compareTo(b.order));
        // Migration: Ensure all default widgets are present
        final currentTypes = configs.map((c) => c.type).toSet();
        final defaultTypes = [
          DashboardWidgetType.spendingSummary,
          DashboardWidgetType.netCashflow,
          DashboardWidgetType.financialCalendar,
          DashboardWidgetType.recentTransactions,
          DashboardWidgetType.spendingBreakdownChart,
          DashboardWidgetType.whereTheMoneyWent,
        ];

        final missingTypes =
            defaultTypes.where((t) => !currentTypes.contains(t));

        if (missingTypes.isNotEmpty) {
          final maxOrder =
              configs.map((c) => c.order).reduce((a, b) => a > b ? a : b);
          var nextOrder = maxOrder + 1;

          final newConfigs = List<DashboardWidgetConfig>.from(configs);
          for (final type in missingTypes) {
            newConfigs.add(DashboardWidgetConfig(
              id: type.name, // Use type name as ID for new widgets
              type: type,
              order: nextOrder++,
              isVisible: true, // Default to visible so user sees it
            ));
          }
          state = AsyncValue.data(newConfigs);
          // Auto-save the migrated config
          save(newConfigs);
        } else {
          state = AsyncValue.data(configs);
        }
      } else {
        // Default Layout
        if (!mounted) return;
        final defaultConfigs = [
          const DashboardWidgetConfig(
              id: 'spending',
              type: DashboardWidgetType.spendingSummary,
              order: 0),
          const DashboardWidgetConfig(
              id: 'net_cashflow',
              type: DashboardWidgetType.netCashflow,
              order: 1),
          const DashboardWidgetConfig(
              id: 'calendar',
              type: DashboardWidgetType.financialCalendar,
              order: 2),
          const DashboardWidgetConfig(
              id: 'categories',
              type: DashboardWidgetType.recentTransactions,
              order: 3),
          const DashboardWidgetConfig(
              id: 'spending_chart',
              type: DashboardWidgetType.spendingBreakdownChart,
              order: 4),
          const DashboardWidgetConfig(
              id: 'where_the_money_went',
              type: DashboardWidgetType.whereTheMoneyWent,
              order: 5),
        ];
        state = AsyncValue.data(defaultConfigs);
        await _repository.savePersonalLayout(_userId, defaultConfigs);
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    if (!mounted) return;
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
      if (!mounted) return;
      if (configs != null && configs.isNotEmpty) {
        configs.sort((a, b) => a.order.compareTo(b.order));
        // Migration: Ensure all default widgets are present
        final currentTypes = configs.map((c) => c.type).toSet();
        final defaultTypes = [
          DashboardWidgetType.householdSpentByYou,
          DashboardWidgetType.householdFinancialCalendar,
          DashboardWidgetType.householdBudgetOverview,
          DashboardWidgetType.householdFairness,
          DashboardWidgetType.householdSettlement,
          DashboardWidgetType.householdMemberSpending,
          DashboardWidgetType.householdRecentTransactions,
          DashboardWidgetType.householdSpendingBreakdownChart,
          DashboardWidgetType.householdWhereTheMoneyWent,
        ];

        final missingTypes =
            defaultTypes.where((t) => !currentTypes.contains(t));

        if (missingTypes.isNotEmpty) {
          final maxOrder =
              configs.map((c) => c.order).reduce((a, b) => a > b ? a : b);
          var nextOrder = maxOrder + 1;

          final newConfigs = List<DashboardWidgetConfig>.from(configs);
          for (final type in missingTypes) {
            newConfigs.add(DashboardWidgetConfig(
              id: type.name,
              type: type,
              order: nextOrder++,
              isVisible: true,
            ));
          }
          state = AsyncValue.data(newConfigs);
          save(newConfigs);
        } else {
          state = AsyncValue.data(configs);
        }
      } else {
        // Default Layout
        if (!mounted) return;
        final defaultConfigs = [
          const DashboardWidgetConfig(
              id: 'settlement',
              type: DashboardWidgetType.householdSettlement,
              order: 0),
          const DashboardWidgetConfig(
              id: 'member_spending',
              type: DashboardWidgetType.householdMemberSpending,
              order: 1),
          const DashboardWidgetConfig(
              id: 'spent_by_you',
              type: DashboardWidgetType.householdSpentByYou,
              order: 2),
          const DashboardWidgetConfig(
              id: 'calendar',
              type: DashboardWidgetType.householdFinancialCalendar,
              order: 3),
          const DashboardWidgetConfig(
              id: 'budget_overview',
              type: DashboardWidgetType.householdBudgetOverview,
              order: 4),
          const DashboardWidgetConfig(
              id: 'fairness',
              type: DashboardWidgetType.householdFairness,
              order: 5),
          const DashboardWidgetConfig(
              id: 'categories',
              type: DashboardWidgetType.householdRecentTransactions,
              order: 6),
          const DashboardWidgetConfig(
              id: 'spending_chart',
              type: DashboardWidgetType.householdSpendingBreakdownChart,
              order: 7),
          const DashboardWidgetConfig(
              id: 'where_the_money_went',
              type: DashboardWidgetType.householdWhereTheMoneyWent,
              order: 8),
        ];
        state = AsyncValue.data(defaultConfigs);
        await _repository.saveHouseholdLayout(_householdId, defaultConfigs);
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    if (!mounted) return;
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

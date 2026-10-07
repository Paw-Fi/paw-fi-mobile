import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'dashboard_config.dart';
import 'dashboard_layout_defaults.dart';
import 'dashboard_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(sharedPreferencesProvider),
    ref.watch(supabaseClientProvider),
  );
});

// Backward-compatible bridge for consumers that have not migrated to the
// synchronous provider yet. SharedPreferences and Supabase are already
// initialized above the app ProviderScope, so repository construction itself
// must not gate the first Home render on another asynchronous lookup.
final dashboardRepositoryFutureProvider =
    FutureProvider<DashboardRepository>((ref) async {
  final trace = HomeDebugTrace(
    label: 'DashboardRepositoryInit',
    enabled: ref.read(homeDebugLoggingEnabledProvider),
    logSink: ref.read(homeDebugLogSinkProvider),
  );
  trace.mark('init-start');
  final repository = ref.watch(dashboardRepositoryProvider);
  trace.mark('init-success');
  return repository;
});

void _dashboardConfigTrace(
  String label,
  String event, {
  Map<String, Object?> fields = const <String, Object?>{},
}) {
  if (!foundation.kDebugMode) {
    return;
  }

  final entries = fields.entries
      .where((entry) => entry.value != null)
      .map((entry) =>
          '${entry.key}=${entry.value.toString().replaceAll(RegExp(r'\s+'), '_')}')
      .join(' ');
  foundation.debugPrint(
    '[HomeTrace][$label] $event${entries.isEmpty ? '' : ' $entries'}',
  );
}

// ============================================================================
// EDIT MODE STATE
// ============================================================================

final isEditModeProvider = StateProvider<bool>((ref) => false);

bool _dashboardLayoutsMatch(
    List<DashboardWidgetConfig>? saved, List<DashboardWidgetConfig> resolved) {
  if (saved == null) return false;
  return foundation.listEquals(
    saved.map((config) => jsonEncode(config.toJson())).toList(),
    resolved.map((config) => jsonEncode(config.toJson())).toList(),
  );
}

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
    _dashboardConfigTrace('PersonalDashboardConfig', 'load-start',
        fields: {'user': _userId});
    try {
      final saved = await _repository.loadPersonalLayout(_userId);
      if (!mounted) return;
      final configs = resolveDashboardLayout(
        saved,
        isHousehold: false,
        isCustomized: _repository.isPersonalLayoutCustomized(_userId),
      );
      state = AsyncValue.data(configs);
      // Defaults and automatic migrations are not user customization.
      if (!_dashboardLayoutsMatch(saved, configs)) {
        await _repository.savePersonalLayout(_userId, configs);
      }
      _dashboardConfigTrace('PersonalDashboardConfig', 'load-success',
          fields: {'user': _userId, 'widgetCount': configs.length});
    } catch (e, st) {
      if (!mounted) return;
      // A persistence error must not hide an already resolved layout.
      if (!state.hasValue) state = AsyncValue.error(e, st);
      _dashboardConfigTrace('PersonalDashboardConfig', 'load-error',
          fields: {'user': _userId, 'error': e});
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    if (!mounted) return;
    state = AsyncValue.data(configs);
    await _repository.markPersonalLayoutCustomized(_userId);
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
      final reorderedConfigs = List<DashboardWidgetConfig>.from(configs);
      final item = reorderedConfigs.removeAt(oldIndex);
      reorderedConfigs.insert(newIndex, item);

      // Update order index in objects
      final reordered = reorderedConfigs.asMap().entries.map((e) {
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
  final repo = ref.watch(dashboardRepositoryProvider);
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
    _dashboardConfigTrace('HouseholdDashboardConfig', 'load-start',
        fields: {'household': _householdId});
    try {
      final saved = await _repository.loadHouseholdLayout(_householdId);
      if (!mounted) return;
      final configs = resolveDashboardLayout(
        saved,
        isHousehold: true,
        isCustomized: _repository.isHouseholdLayoutCustomized(_householdId),
      );
      state = AsyncValue.data(configs);
      // Defaults and automatic migrations are not user customization.
      if (!_dashboardLayoutsMatch(saved, configs)) {
        await _repository.saveHouseholdLayout(_householdId, configs);
      }
      _dashboardConfigTrace('HouseholdDashboardConfig', 'load-success',
          fields: {'household': _householdId, 'widgetCount': configs.length});
    } catch (e, st) {
      if (!mounted) return;
      // A persistence error must not hide an already resolved layout.
      if (!state.hasValue) state = AsyncValue.error(e, st);
      _dashboardConfigTrace('HouseholdDashboardConfig', 'load-error',
          fields: {'household': _householdId, 'error': e});
    }
  }

  Future<void> save(List<DashboardWidgetConfig> configs) async {
    if (!mounted) return;
    state = AsyncValue.data(configs);
    await _repository.markHouseholdLayoutCustomized(_householdId);
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
      final reorderedConfigs = List<DashboardWidgetConfig>.from(configs);
      final item = reorderedConfigs.removeAt(oldIndex);
      reorderedConfigs.insert(newIndex, item);

      final reordered = reorderedConfigs.asMap().entries.map((e) {
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
  final repo = ref.watch(dashboardRepositoryProvider);
  return HouseholdDashboardController(repo, householdId);
});

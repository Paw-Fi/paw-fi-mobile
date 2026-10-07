import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_layout_defaults.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_repository.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<DashboardWidgetConfig> _layout(List<DashboardWidgetType> types) => types
    .asMap()
    .entries
    .map((entry) => DashboardWidgetConfig(
        id: entry.value.name, type: entry.value, order: entry.key))
    .toList();

List<DashboardWidgetConfig> _legacyPersonal({bool includeUpcoming = true}) =>
    _layout([
      DashboardWidgetType.spendingSummary,
      DashboardWidgetType.netCashflow,
      DashboardWidgetType.financialCalendar,
      DashboardWidgetType.recentTransactions,
      if (includeUpcoming) DashboardWidgetType.upcomingTransactions,
      DashboardWidgetType.spendingBreakdownChart,
      DashboardWidgetType.whereTheMoneyWent,
    ]);

List<DashboardWidgetConfig> _legacyHousehold({bool originalOrder = false}) =>
    _layout([
      if (!originalOrder) ...[
        DashboardWidgetType.householdSettlement,
        DashboardWidgetType.householdMemberSpending,
      ],
      DashboardWidgetType.householdSpentByYou,
      DashboardWidgetType.householdFinancialCalendar,
      DashboardWidgetType.householdBudgetOverview,
      DashboardWidgetType.householdFairness,
      if (originalOrder) ...[
        DashboardWidgetType.householdSettlement,
        DashboardWidgetType.householdMemberSpending,
      ],
      DashboardWidgetType.householdRecentTransactions,
      DashboardWidgetType.householdUpcomingTransactions,
      DashboardWidgetType.householdSpendingBreakdownChart,
      DashboardWidgetType.householdWhereTheMoneyWent,
    ]);

class _MemoryDashboardRepository extends DashboardRepository {
  _MemoryDashboardRepository(SharedPreferences prefs, SupabaseClient client,
      {this.personal, this.household})
      : super(prefs, client);

  List<DashboardWidgetConfig>? personal;
  List<DashboardWidgetConfig>? household;
  int writes = 0;

  @override
  Future<List<DashboardWidgetConfig>?> loadPersonalLayout(
          String userId) async =>
      personal;

  @override
  Future<List<DashboardWidgetConfig>?> loadHouseholdLayout(
          String householdId) async =>
      household;

  @override
  Future<void> savePersonalLayout(
      String userId, List<DashboardWidgetConfig> configs) async {
    writes++;
    personal = List.of(configs);
  }

  @override
  Future<void> saveHouseholdLayout(
      String householdId, List<DashboardWidgetConfig> configs) async {
    writes++;
    household = List.of(configs);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final isHousehold in [false, true]) {
    final calendar = isHousehold
        ? DashboardWidgetType.householdFinancialCalendar
        : DashboardWidgetType.financialCalendar;
    final recent = isHousehold
        ? DashboardWidgetType.householdRecentTransactions
        : DashboardWidgetType.recentTransactions;
    final expectedTypes = isHousehold
        ? const [
            DashboardWidgetType.householdSettlement,
            DashboardWidgetType.householdMemberSpending,
            DashboardWidgetType.householdRecentTransactions,
            DashboardWidgetType.householdBudgetOverview,
            DashboardWidgetType.householdFairness,
            DashboardWidgetType.householdFinancialCalendar,
            DashboardWidgetType.householdUpcomingTransactions,
            DashboardWidgetType.householdSpendingBreakdownChart,
            DashboardWidgetType.householdWhereTheMoneyWent,
          ]
        : const [
            DashboardWidgetType.recentTransactions,
            DashboardWidgetType.financialCalendar,
            DashboardWidgetType.upcomingTransactions,
            DashboardWidgetType.spendingBreakdownChart,
            DashboardWidgetType.whereTheMoneyWent,
          ];
    List<DashboardWidgetConfig> legacy() =>
        isHousehold ? _legacyHousehold() : _legacyPersonal();
    List<DashboardWidgetConfig> resolve(List<DashboardWidgetConfig>? saved,
            {bool customized = false}) =>
        resolveDashboardLayout(saved,
            isHousehold: isHousehold, isCustomized: customized);

    test('$isHousehold new and untouched layouts get swapped expanded calendar',
        () {
      for (final saved in [null, legacy()]) {
        final configs = resolve(saved);
        expect(configs.map((config) => config.type), expectedTypes);
        expect(configs.any((config) => isRetiredDashboardWidget(config.type)),
            isFalse);
        expect(
            configs.singleWhere((config) => config.type == calendar).viewMode,
            DashboardWidgetViewMode.full);
        expect(configs.indexWhere((config) => config.type == recent),
            lessThan(configs.indexWhere((config) => config.type == calendar)));
      }
    });

    test('$isHousehold reordered layouts retain order and collapsed calendar',
        () {
      final saved = legacy();
      final moved = saved.removeLast();
      saved.insert(0, moved);
      final reordered = saved
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(order: entry.key))
          .toList();
      final configs = resolve(reordered);
      expect(
          configs.map((config) => config.type),
          reordered
              .where((config) => !isRetiredDashboardWidget(config.type))
              .map((config) => config.type));
      expect(configs.singleWhere((config) => config.type == calendar).viewMode,
          DashboardWidgetViewMode.wide);
    });

    test('$isHousehold visibility, date and calendar edits protect the layout',
        () {
      for (final changedCalendar in [
        DashboardWidgetViewMode.wide,
        DashboardWidgetViewMode.full,
      ]) {
        final saved = legacy()
            .map((config) => config.type == calendar
                ? config.copyWith(viewMode: changedCalendar)
                : config.type == recent
                    ? config.copyWith(
                        isVisible: false,
                        dateRange: DateRangeFilter.custom,
                        customStartDate: DateTime(2026, 1, 1),
                        customEndDate: DateTime(2026, 1, 31))
                    : config)
            .toList();
        final configs = resolve(saved);
        final recentConfig =
            configs.singleWhere((config) => config.type == recent);
        expect(recentConfig.isVisible, isFalse);
        expect(recentConfig.dateRange, DateRangeFilter.custom);
        expect(recentConfig.customStartDate, DateTime(2026, 1, 1));
        expect(recentConfig.customEndDate, DateTime(2026, 1, 31));
        expect(
            configs.singleWhere((config) => config.type == calendar).viewMode,
            changedCalendar);
        expect(configs.indexWhere((config) => config.type == calendar),
            lessThan(configs.indexWhere((config) => config.type == recent)));
      }
    });

    test('$isHousehold explicit customization protects default-looking order',
        () {
      final configs = resolve(legacy(), customized: true);
      expect(configs.singleWhere((config) => config.type == calendar).viewMode,
          DashboardWidgetViewMode.wide);
      expect(configs.indexWhere((config) => config.type == calendar),
          lessThan(configs.indexWhere((config) => config.type == recent)));
    });

    test('$isHousehold calendar-only edit preserves the original order', () {
      final saved = legacy()
          .map((config) => config.type == calendar
              ? config.copyWith(viewMode: DashboardWidgetViewMode.full)
              : config)
          .toList();
      final configs = resolve(saved);
      expect(configs.indexWhere((config) => config.type == calendar),
          lessThan(configs.indexWhere((config) => config.type == recent)));
      expect(configs.singleWhere((config) => config.type == calendar).viewMode,
          DashboardWidgetViewMode.full);
    });

    test('$isHousehold migration is repeatable and does not mutate saved rows',
        () {
      final saved = legacy();
      final before = saved.map((config) => config.toJson()).toList();
      final first = resolve(saved);
      final second = resolve(first);
      expect(second.map((config) => config.toJson()),
          first.map((config) => config.toJson()));
      expect(saved.map((config) => config.toJson()), before);
    });

    test(
        '$isHousehold controller migration and customization persist separately',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = SupabaseClient('https://example.supabase.co', 'test-key');
      addTearDown(client.dispose);
      final repository = _MemoryDashboardRepository(prefs, client,
          personal: _legacyPersonal(), household: _legacyHousehold());
      final container = ProviderContainer(overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final provider = isHousehold
          ? householdDashboardProvider('space-1')
          : personalDashboardProvider('user-1');
      container.read(provider);
      await Future<void>.delayed(Duration.zero);
      expect(
          container
              .read(provider)
              .requireValue
              .singleWhere((config) => config.type == calendar)
              .viewMode,
          DashboardWidgetViewMode.full);
      expect(repository.writes, 1);
      expect(repository.isPersonalLayoutCustomized('user-1'), isFalse);
      expect(repository.isHouseholdLayoutCustomized('space-1'), isFalse);

      if (isHousehold) {
        container
            .read(householdDashboardProvider('space-1').notifier)
            .updateConfig(calendar.name,
                viewMode: DashboardWidgetViewMode.wide);
      } else {
        container
            .read(personalDashboardProvider('user-1').notifier)
            .updateConfig(calendar.name,
                viewMode: DashboardWidgetViewMode.wide);
      }
      await Future<void>.delayed(Duration.zero);
      expect(
          container
              .read(provider)
              .requireValue
              .singleWhere((config) => config.type == calendar)
              .viewMode,
          DashboardWidgetViewMode.wide);
      expect(
          isHousehold
              ? repository.isHouseholdLayoutCustomized('space-1')
              : repository.isPersonalLayoutCustomized('user-1'),
          isTrue);
      expect(repository.isPersonalLayoutCustomized('other-user'), isFalse);
      expect(repository.isHouseholdLayoutCustomized('other-space'), isFalse);

      final restarted = ProviderContainer(overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(restarted.dispose);
      restarted.read(provider);
      await Future<void>.delayed(Duration.zero);
      expect(
          restarted
              .read(provider)
              .requireValue
              .singleWhere((config) => config.type == calendar)
              .viewMode,
          DashboardWidgetViewMode.wide);
      expect(repository.writes, 2);
    });
  }

  test('personal layouts predating Upcoming are recognized as defaults', () {
    final configs = resolveDashboardLayout(
        _legacyPersonal(includeUpcoming: false),
        isHousehold: false,
        isCustomized: false);
    expect(configs.map((config) => config.type), [
      DashboardWidgetType.recentTransactions,
      DashboardWidgetType.financialCalendar,
      DashboardWidgetType.upcomingTransactions,
      DashboardWidgetType.spendingBreakdownChart,
      DashboardWidgetType.whereTheMoneyWent,
    ]);
    expect(
        configs
            .singleWhere((config) =>
                config.type == DashboardWidgetType.financialCalendar)
            .viewMode,
        DashboardWidgetViewMode.full);
    expect(
        configs.where((config) =>
            config.type == DashboardWidgetType.upcomingTransactions),
        hasLength(1));
  });

  test('original household defaults swap only calendar and recent positions',
      () {
    final configs = resolveDashboardLayout(
        _legacyHousehold(originalOrder: true),
        isHousehold: true,
        isCustomized: false);
    expect(configs.map((config) => config.type), [
      DashboardWidgetType.householdRecentTransactions,
      DashboardWidgetType.householdBudgetOverview,
      DashboardWidgetType.householdFairness,
      DashboardWidgetType.householdSettlement,
      DashboardWidgetType.householdMemberSpending,
      DashboardWidgetType.householdFinancialCalendar,
      DashboardWidgetType.householdUpcomingTransactions,
      DashboardWidgetType.householdSpendingBreakdownChart,
      DashboardWidgetType.householdWhereTheMoneyWent,
    ]);
  });
}

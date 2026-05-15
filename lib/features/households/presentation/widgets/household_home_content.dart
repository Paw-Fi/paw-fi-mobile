import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:skeletonizer/skeletonizer.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/household_onboarding_page.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';

import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/households/presentation/widgets/household_dashboard_lazy_widgets.dart';

/// Household home content that handles loading, empty, and data states
/// Returns Sliver widgets for use in CustomScrollView
class HouseholdHomeContent extends ConsumerStatefulWidget {
  const HouseholdHomeContent({super.key});

  @override
  ConsumerState<HouseholdHomeContent> createState() =>
      _HouseholdHomeContentState();
}

class _HouseholdHomeContentState extends ConsumerState<HouseholdHomeContent> {
  String? _dashboardWarmupKey;
  late final HomeDebugTrace _householdTrace;
  String? _lastHouseholdTraceSignature;
  String? _lastSelectedHouseholdTraceSignature;
  String? _lastRepositoryTraceSignature;
  String? _lastDashboardConfigTraceSignature;
  bool _didLogFirstUsefulPaint = false;

  @override
  void initState() {
    super.initState();
    _householdTrace = HomeDebugTrace(
      label: 'HouseholdHomeContent',
      enabled: ref.read(homeDebugLoggingEnabledProvider),
      logSink: ref.read(homeDebugLogSinkProvider),
    );
    _householdTrace.mark('widget-mounted');
  }

  /// Calculate user's personal share of household expenses
  ///
  /// This method is ONLY used for the "Spent by You" card to show what the current user
  /// personally owes/spent in the household, including split portions from other members.
  ///
  /// ⚠️ IMPORTANT: This is NOT used for category breakdown or pie charts.
  /// Those should show ALL household expenses, not just personal share.
  ///
  /// Calculation logic:
  /// 1. If expense has NO split group (splitGroupId == null):
  ///    - Include full amount if current user created it
  ///    - Example: User logs $10 with no split → User's share = $10
  ///
  /// 2. If expense HAS split group (splitGroupId != null):
  ///    - Look up the split group to find user's allocated share
  ///    - Use the amountCents from the user's split line
  ///    - Example: Other logs $100, splits $50 to user → User's share = $50
  ///
  /// Example calculation:
  /// - User logs $10 expense, splits $0 to others → Returns $10
  /// - Other logs $100 expense, splits $50 to user → Returns $50
  /// - Total "Spent by You" = $60
  /// - Total household = $110 (calculated separately)
  // ignore: unused_element
  List<ExpenseEntry> _personalShareExpenses(
    List<ExpenseEntry> expenses,
    List<ExpenseSplitGroup> splits,
    String currentUserId,
  ) {
    if (expenses.isEmpty) return const <ExpenseEntry>[];

    // If no splits data, return all expenses created by current user with full amounts
    // This handles the case where split data hasn't loaded yet
    if (splits.isEmpty) {
      return expenses.where((e) => e.userId == currentUserId).toList();
    }

    // Create lookup map for quick access to split groups by ID
    final byGroupId = {for (final g in splits) g.id: g};
    final result = <ExpenseEntry>[];

    for (final e in expenses) {
      final gid = e.splitGroupId;

      // CASE 1: Expense has NO split group (not shared)
      // Include full amount if current user created it
      if (gid == null) {
        if (e.userId == currentUserId) {
          result.add(e);
        }
        continue;
      }

      // CASE 2: Expense HAS split group (shared expense)
      // Find the split group and extract user's allocated share
      final group = byGroupId[gid];
      if (group == null) {
        // Split group not found in data, fallback to including full amount if user created it
        if (e.userId == currentUserId) {
          result.add(e);
        }
        continue;
      }

      // Find current user's split line within the group
      final line = (group.splitLines ?? const <ExpenseSplitLine>[])
          .firstWhere((l) => l.userId == currentUserId,
              orElse: () => ExpenseSplitLine(
                    id: '',
                    splitGroupId: '',
                    userId: '',
                    isSettled: false,
                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                  ));

      // User not part of this split, skip this expense
      if (line.userId != currentUserId) continue;

      // Extract user's share amount from split line (in cents)
      final int share = (line.amountCents ?? 0);
      final int shareClamped = share < 0 ? 0 : share; // Clamp negatives to zero

      // Create new expense entry with user's share amount
      result.add(e.copyWith(amountCents: shareClamped));
    }
    return result;
  }

  Future<void> _warmHouseholdDashboard({
    required String userId,
    required Household household,
    required String selectedCurrency,
    required List<DashboardWidgetConfig> configs,
    required DateTime referenceNow,
  }) async {
    if (!mounted) return;

    final warmupTrace = HomeDebugTrace(
      label: 'HouseholdDashboardWarmup',
      enabled: ref.read(homeDebugLoggingEnabledProvider),
      logSink: ref.read(homeDebugLogSinkProvider),
      contextFields: {
        'household': household.id,
        'currency': selectedCurrency,
      },
    );
    warmupTrace.mark('warmup-start', {
      'widgetCount': configs.length,
    });
    final visibleConfigs = configs.where((config) => config.isVisible).toList();

    final summaryParams = <HouseholdSummaryParams>{};
    final calendarQueries = <DashboardScopeQuery>{};
    var needsRecurring = false;
    var needsSplits = false;

    for (final config in visibleConfigs) {
      final range = getDateRangeFromFilter(
        config.dateRange,
        config.customStartDate,
        config.customEndDate,
        now: referenceNow,
      );

      switch (config.type) {
        case DashboardWidgetType.householdSpentByYou:
          needsRecurring = true;
          needsSplits = true;
          calendarQueries.add(
            DashboardScopeQuery(
              userId: userId,
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              startDate: range['from'],
              endDate: range['to'],
            ),
          );
          break;
        case DashboardWidgetType.householdBudgetOverview:
          needsRecurring = true;
          calendarQueries.add(
            DashboardScopeQuery(
              userId: userId,
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              startDate: range['from'],
              endDate: range['to'],
            ),
          );
          summaryParams.add(buildHouseholdSummaryParams(
            household: household,
            selectedCurrency: selectedCurrency,
            config: config,
            referenceNow: referenceNow,
          ));
          break;
        case DashboardWidgetType.householdFairness:
          needsRecurring = true;
          needsSplits = true;
          calendarQueries.add(
            DashboardScopeQuery(
              userId: userId,
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              startDate: range['from'],
              endDate: range['to'],
            ),
          );
          summaryParams.add(buildHouseholdSummaryParams(
            household: household,
            selectedCurrency: selectedCurrency,
            config: config,
            referenceNow: referenceNow,
          ));
          break;
        case DashboardWidgetType.householdSettlement:
          summaryParams.add(buildHouseholdSummaryParams(
            household: household,
            selectedCurrency: selectedCurrency,
            config: config,
            referenceNow: referenceNow,
          ));
          break;
        case DashboardWidgetType.householdMemberSpending:
          needsRecurring = true;
          needsSplits = true;
          calendarQueries.add(
            DashboardScopeQuery(
              userId: userId,
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              startDate: range['from'],
              endDate: range['to'],
            ),
          );
          summaryParams.add(buildHouseholdSummaryParams(
            household: household,
            selectedCurrency: selectedCurrency,
            config: config,
            referenceNow: referenceNow,
          ));
          break;
        case DashboardWidgetType.householdSpendingBreakdownChart:
        case DashboardWidgetType.householdWhereTheMoneyWent:
          needsRecurring = true;
          calendarQueries.add(
            DashboardScopeQuery(
              userId: userId,
              householdId: household.id,
              selectedCurrency: selectedCurrency,
              startDate: range['from'],
              endDate: range['to'],
            ),
          );
          break;
        case DashboardWidgetType.householdFinancialCalendar:
          needsRecurring = true;
          break;
        default:
          break;
      }
    }

    if (needsRecurring) {
      final recurringProvider = recurringTransactionsProvider(household.id);
      final recurringState = ref.read(recurringProvider);
      if (!recurringState.hasLoadedOnce && !recurringState.data.isLoading) {
        warmupTrace.mark('warmup-recurring-start');
        await ref
            .read(recurringProvider.notifier)
            .loadRecurringTransactions(userId);
        if (!mounted) return;
        warmupTrace.mark('warmup-recurring-success');
      }
    }

    if (!mounted) return;
    ref.read(householdMembersProvider(household.id));
    warmupTrace.mark('warmup-members-read');

    final warmupTasks = <Future<void>>[];

    if (needsSplits) {
      warmupTasks.add(() async {
        try {
          warmupTrace.mark('warmup-splits-start');
          if (!mounted) return;
          await ref.read(
            householdSplitsProvider(HouseholdSplitsParams(
              householdId: household.id,
            )).future,
          );
          if (!mounted) return;
          warmupTrace.mark('warmup-splits-success');
        } catch (error) {
          warmupTrace.mark('warmup-splits-error', {'error': error});
        }
      }());
    }

    for (final query in calendarQueries) {
      warmupTasks.add(() async {
        try {
          warmupTrace.mark('warmup-calendar-start', {
            'rangeStart': query.formattedStartDate,
            'rangeEnd': query.formattedEndDate,
          });
          if (!mounted) return;
          await ref.read(dashboardCalendarTransactionsProvider(query).future);
          if (!mounted) return;
          warmupTrace.mark('warmup-calendar-success');
        } catch (error) {
          warmupTrace.mark('warmup-calendar-error', {'error': error});
        }
      }());
    }

    for (final params in summaryParams) {
      warmupTasks.add(() async {
        try {
          warmupTrace.mark('warmup-summary-start', {
            'rangeStart': params.startDate,
            'rangeEnd': params.endDate,
          });
          if (!mounted) return;
          await ref.read(householdSummaryProvider(params).future);
          if (!mounted) return;
          warmupTrace.mark('warmup-summary-success');
        } catch (error) {
          warmupTrace.mark('warmup-summary-error', {'error': error});
        }
      }());
    }

    await Future.wait(warmupTasks);

    warmupTrace.mark('warmup-complete', {
      'summaryCount': summaryParams.length,
    });
  }

  String _buildDashboardWarmupKey({
    required String householdId,
    required String selectedCurrency,
    required List<DashboardWidgetConfig> configs,
  }) {
    final visibleConfigs = configs
        .where((config) => config.isVisible)
        .map((config) => [
              config.id,
              config.type.name,
              config.dateRange.name,
              config.viewMode.name,
              config.customStartDate?.toIso8601String() ?? '',
              config.customEndDate?.toIso8601String() ?? '',
            ].join(':'))
        .toList()
      ..sort();

    return '$householdId|$selectedCurrency|${visibleConfigs.join('|')}';
  }

  void _scheduleDashboardWarmup({
    required String warmupKey,
    required String userId,
    required Household household,
    required String selectedCurrency,
    required List<DashboardWidgetConfig> configs,
    required DateTime referenceNow,
  }) {
    if (_dashboardWarmupKey == warmupKey) return;

    _dashboardWarmupKey = warmupKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_dashboardWarmupKey != warmupKey) return;

      unawaited(_warmHouseholdDashboard(
        userId: userId,
        household: household,
        selectedCurrency: selectedCurrency,
        configs: configs,
        referenceNow: referenceNow,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(currentUserIdProvider);
    final dashboardRefreshSignal = ref.read(dashboardRefreshSignalProvider);

    if (userId == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.userNotLoggedIn,
          context.l10n.pleaseSignInToAccessHouseholdFeatures,
        ),
      );
    }

    final householdsAsync = ref.watch(userHouseholdsProvider(userId));

    final householdsSignature = [
      'user=$userId',
      'loading=${householdsAsync.isLoading}',
      'hasError=${householdsAsync.hasError}',
      'count=${householdsAsync.valueOrNull?.length ?? 0}',
      'refresh=$dashboardRefreshSignal',
    ].join('|');
    if (_lastHouseholdTraceSignature != householdsSignature) {
      _lastHouseholdTraceSignature = householdsSignature;
      _householdTrace.mark('households-async-state', {
        'user': userId,
        'loading': householdsAsync.isLoading,
        'hasError': householdsAsync.hasError,
        'count': householdsAsync.valueOrNull?.length,
        'refreshSignal': dashboardRefreshSignal,
      });
    }

    return householdsAsync.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildLoadingState(colorScheme),
      ),
      error: (error, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.errorLoadingHouseholds,
          error.toString(),
        ),
      ),
      data: (households) {
        if (households.isEmpty) {
          _householdTrace
              .mark('content-blocked', const {'reason': 'no-households'});
          // Show onboarding when user has no households
          // Use SliverToBoxAdapter with LayoutBuilder to provide proper sizing
          return SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height -
                      200, // Account for app bar
                  child: const HouseholdOnboardingPage(),
                );
              },
            ),
          );
        } else {
          // NOTE: Selected household is initialized by app_initialization_provider
          // Just watch the state here - no need to re-initialize
          final selectedState = ref.watch(selectedHouseholdProvider);

          // Determine which household to show
          final selectedId =
              selectedState.householdId ?? selectedState.household?.id;
          final household = selectedId != null
              ? households.firstWhere(
                  (h) => h.id == selectedId,
                  orElse: () => households.first,
                )
              : households.first;

          final selectedHouseholdTraceSignature = [
            'household=${household.id}',
            'selectedId=${selectedId ?? '<none>'}',
          ].join('|');
          if (_lastSelectedHouseholdTraceSignature !=
              selectedHouseholdTraceSignature) {
            _lastSelectedHouseholdTraceSignature =
                selectedHouseholdTraceSignature;
            _householdTrace.mark('selected-household', {
              'household': household.id,
              'selectedId': selectedId,
            });
          }

          // Filters
          final filterState = ref.watch(homeFilterProvider);
          final initUserContact = ref.watch(
              appInitializationV2Provider.select((state) => state.data?.user));
          final rawCurrency =
              (filterState.selectedCurrency?.trim().isNotEmpty == true
                      ? filterState.selectedCurrency!.trim()
                      : (initUserContact?.preferredCurrency
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? initUserContact!.preferredCurrency!.trim()
                          : household.currency))
                  .toUpperCase();
          final selectedCurrency = rawCurrency;
          final timezoneOffsetMinutes = resolveUserTimezoneOffsetMinutes(
              initUserContact?.preferredTimezone);
          final userNow = userNowFromOffsetMinutes(timezoneOffsetMinutes);

          // Data providers with date filtering
          // Note: Individual widgets inside DraggableDashboardList will fetch their own data
          // based on their specific date range configuration.

          final repoAsync = ref.watch(dashboardRepositoryFutureProvider);

          final repositoryTraceSignature = [
            'loading=${repoAsync.isLoading}',
            'hasError=${repoAsync.hasError}',
            'hasValue=${repoAsync.hasValue}',
          ].join('|');
          if (_lastRepositoryTraceSignature != repositoryTraceSignature) {
            _lastRepositoryTraceSignature = repositoryTraceSignature;
            _householdTrace.mark('repository-async-state', {
              'loading': repoAsync.isLoading,
              'hasError': repoAsync.hasError,
              'hasValue': repoAsync.hasValue,
            });
          }

          return repoAsync.when(
            loading: () =>
                SliverToBoxAdapter(child: _buildLoadingState(colorScheme)),
            error: (e, st) => SliverToBoxAdapter(
              child: _buildErrorState(
                colorScheme,
                context.l10n.errorLoadingHouseholds,
                'Repository Error: $e',
              ),
            ),
            data: (_) {
              final dashboardAsync =
                  ref.watch(householdDashboardProvider(household.id));

              final dashboardConfigTraceSignature = [
                'household=${household.id}',
                'loading=${dashboardAsync.isLoading}',
                'hasError=${dashboardAsync.hasError}',
                'hasValue=${dashboardAsync.hasValue}',
                'widgetCount=${dashboardAsync.valueOrNull?.length ?? 0}',
              ].join('|');
              if (_lastDashboardConfigTraceSignature !=
                  dashboardConfigTraceSignature) {
                _lastDashboardConfigTraceSignature =
                    dashboardConfigTraceSignature;
                _householdTrace.mark('dashboard-config-async-state', {
                  'household': household.id,
                  'loading': dashboardAsync.isLoading,
                  'hasError': dashboardAsync.hasError,
                  'hasValue': dashboardAsync.hasValue,
                  'widgetCount': dashboardAsync.valueOrNull?.length,
                });
              }

              return dashboardAsync.when(
                loading: () =>
                    SliverToBoxAdapter(child: _buildLoadingState(colorScheme)),
                error: (e, st) => SliverToBoxAdapter(
                  child: _buildErrorState(
                    colorScheme,
                    context.l10n.errorLoadingHouseholds,
                    e.toString(),
                  ),
                ),
                data: (configs) {
                  final warmupKey = _buildDashboardWarmupKey(
                    householdId: household.id,
                    selectedCurrency:
                        '$selectedCurrency|refresh:$dashboardRefreshSignal',
                    configs: configs,
                  );
                  _scheduleDashboardWarmup(
                    warmupKey: warmupKey,
                    userId: userId,
                    household: household,
                    selectedCurrency: selectedCurrency,
                    configs: configs,
                    referenceNow: userNow,
                  );

                  if (!_didLogFirstUsefulPaint) {
                    _didLogFirstUsefulPaint = true;
                    _householdTrace.mark('first-useful-paint', {
                      'household': household.id,
                      'widgetCount': configs.length,
                      'selectedCurrency': selectedCurrency,
                    });
                  }

                  return DraggableDashboardList(
                    configs: configs,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .reorder(oldIndex, newIndex);
                    },
                    onToggleVisibility: (id) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .toggleVisibility(id);
                    },
                    onUpdateConfig: (id, {dateRange, viewMode, start, end}) {
                      ref
                          .read(
                              householdDashboardProvider(household.id).notifier)
                          .updateConfig(id,
                              dateRange: dateRange,
                              viewMode: viewMode,
                              start: start,
                              end: end);
                    },
                    widgetBuilders: {
                      DashboardWidgetType.householdSpentByYou: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdSpentByYouCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                      DashboardWidgetType.householdFinancialCalendar: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdFinancialCalendarCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                            ),
                          ),
                      DashboardWidgetType.householdBudgetOverview: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdBudgetOverviewCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                      DashboardWidgetType.householdFairness: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdFairnessCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                      DashboardWidgetType.householdSettlement: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdSettlementCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                      DashboardWidgetType.householdMemberSpending: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdMemberSpendingCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                      DashboardWidgetType.householdRecentTransactions: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdRecentTransactionsCard(
                              household: household,
                              selectedCurrency: selectedCurrency,
                            ),
                          ),
                      DashboardWidgetType.householdSpendingBreakdownChart:
                          (context, config) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: LazyHouseholdSpendingBreakdownChartCard(
                                  household: household,
                                  config: config,
                                  selectedCurrency: selectedCurrency,
                                  referenceNow: userNow,
                                ),
                              ),
                      DashboardWidgetType.householdWhereTheMoneyWent: (context,
                              config) =>
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: LazyHouseholdWhereTheMoneyWentCard(
                              household: household,
                              config: config,
                              selectedCurrency: selectedCurrency,
                              referenceNow: userNow,
                            ),
                          ),
                    },
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  /// Skeleton placeholder for the settlement suggestions card
  // ignore: unused_element
  Widget _buildSettlementSkeleton(ColorScheme colorScheme) {
    return Skeletonizer(
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row placeholder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Settlement'),
                SizedBox(
                  width: 80,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Two stat cards row placeholder
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You owe'),
                      SizedBox(height: 4),
                      Text('Amount placeholder'),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are owed'),
                      SizedBox(height: 4),
                      Text('Amount placeholder'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Suggested transfers header placeholder
            Text('Suggested transfers'),
            SizedBox(height: 12),
            // A few suggestion rows
            Text('Suggestion row 1'),
            SizedBox(height: 8),
            Text('Suggestion row 2'),
            SizedBox(height: 8),
            Text('Suggestion row 3'),
          ],
        ),
      ),
    );
  }

  /// Full-page loading state with skeleton
  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Skeletonizer(
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: Container(
        color: colorScheme.appBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Simulated header card
            Card(
              color: colorScheme.cardSurface,
              child: ListTile(
                leading: const CircleAvatar(),
                title: Text(context.l10n.householdNamePlaceholder),
                subtitle: const Text('Summary placeholder'),
              ),
            ),
            const SizedBox(height: 16),
            // A few card placeholders that roughly match the dashboard layout
            Card(
              color: colorScheme.cardSurface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card title placeholder'),
                    SizedBox(height: 8),
                    Text('Primary value placeholder'),
                    SizedBox(height: 4),
                    Text('Secondary text placeholder'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colorScheme.cardSurface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card title placeholder'),
                    SizedBox(height: 8),
                    Text('Primary value placeholder'),
                    SizedBox(height: 4),
                    Text('Secondary text placeholder'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colorScheme.cardSurface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card title placeholder'),
                    SizedBox(height: 8),
                    Text('Primary value placeholder'),
                    SizedBox(height: 4),
                    Text('Secondary text placeholder'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colorScheme.cardSurface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card title placeholder'),
                    SizedBox(height: 8),
                    Text('Primary value placeholder'),
                    SizedBox(height: 4),
                    Text('Secondary text placeholder'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colorScheme.cardSurface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card title placeholder'),
                    SizedBox(height: 8),
                    Text('Primary value placeholder'),
                    SizedBox(height: 4),
                    Text('Secondary text placeholder'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state with retry option
  Widget _buildErrorState(
    ColorScheme colorScheme,
    String title,
    String message,
  ) {
    return Container(
      color: colorScheme.appBackground,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: colorScheme.destructive,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

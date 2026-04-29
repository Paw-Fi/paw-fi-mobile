import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_calculations.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

String _colorToHex(Color color) {
  final r =
      ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final g =
      ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final b =
      ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
}

class WidgetSyncManager extends HookConsumerWidget {
  const WidgetSyncManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    // Watch app initialization state to ensure we don't sync before ready
    final appInitState = ref.watch(appInitializationV2Provider);
    final isAppReady = appInitState.isReady;

    // Watch and manage sync state
    final syncState = ref.watch(widgetSyncStateProvider);
    final syncStateNotifier = ref.read(widgetSyncStateProvider.notifier);

    final analyticsData = ref.watch(analyticsProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final availableCurrencies = ref.watch(availableCurrenciesProvider);
    final widgetSyncVersion = ref.watch(widgetSyncVersionProvider);

    // Ensure configuration options (households + currencies) are always saved
    // for the iOS AppIntent, independent of analytics loading state.
    useEffect(() {
      if (user.uid.isEmpty ||
          householdsAsync.isLoading ||
          householdsAsync.hasError ||
          householdsAsync.valueOrNull == null) {
        return null;
      }

      final households = householdsAsync.valueOrNull!;

      Future<void> syncConfigOptions() async {
        final allSupportedCurrencies = currencyOptions.keys.toList();

        await WidgetService().saveConfigurationOptions(
          households: [
            {'id': 'personal', 'name': 'Personal', 'isPortfolio': false},
            ...households.map(
              (h) => {
                'id': h.id,
                'name': h.name,
                'isPortfolio': h.isPortfolio,
              },
            ),
          ],
          currencies: allSupportedCurrencies,
        );
      }

      syncConfigOptions();
      return null;
    }, [
      householdsAsync.valueOrNull,
    ]);

    // Keep widget sync recoverable if the initial background analytics warm-up
    // was skipped or interrupted during startup.
    useEffect(() {
      if (!isAppReady || user.uid.isEmpty) {
        return null;
      }
      if (analyticsData.hasLoadedOnce == true || analyticsData.isLoading) {
        return null;
      }

      var disposed = false;
      Future<void>(() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (disposed) return;

        final latestAnalytics = ref.read(analyticsProvider);
        if (latestAnalytics.hasLoadedOnce == true ||
            latestAnalytics.isLoading) {
          return;
        }

        await ref.read(analyticsProvider.notifier).loadData(user.uid);
      });

      return () {
        disposed = true;
      };
    }, [
      isAppReady,
      user.uid,
      analyticsData.hasLoadedOnce,
      analyticsData.isLoading,
    ]);

    // Sync ALL scopes (Personal + Households) for Configurable Widgets
    useEffect(() {
      // GUARD 1: App must be fully initialized (has data, not failed)
      if (!isAppReady) {
        debugPrint('🔄 [WidgetSync] Skipping - app not ready yet');
        return null;
      }

      // GUARD 2: User must be authenticated
      if (user.uid.isEmpty) {
        debugPrint('🔄 [WidgetSync] Skipping - no user');
        return null;
      }

      // GUARD 3: Data must be fully loaded
      if (analyticsData.hasLoadedOnce != true ||
          analyticsData.isLoading ||
          householdsAsync.isLoading) {
        debugPrint('🔄 [WidgetSync] Skipping - data still loading');
        return null;
      }

      // GUARD 4: Debounce - don't sync too frequently
      if (!syncState.canSync) {
        debugPrint(
            '🔄 [WidgetSync] Skipping - debounce (last sync ${syncState.lastAttemptTime})');
        return null;
      }

      // GUARD 5: Prevent concurrent syncs
      if (syncState.isSyncing) {
        debugPrint('🔄 [WidgetSync] Skipping - sync already in progress');
        return null;
      }

      final households = householdsAsync.valueOrNull ?? [];
      final allScopes = [
        {'id': 'personal', 'name': 'Personal'},
        ...households.map((h) => {'id': h.id, 'name': h.name}),
      ];

      Future<void> syncAllScopes() async {
        // Mark sync as started
        syncStateNotifier.startSync();

        // Track whether sync completed successfully to ensure proper cleanup
        bool syncSucceeded = false;

        try {
          // Abort immediately if user signed out or session is gone
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null || user.uid.isEmpty) {
            // Don't return - let finally block handle cleanup
            return;
          }

          final timezoneOffsetMinutes = resolveUserTimezoneOffsetMinutes(
            appInitState.data?.user?.preferredTimezone,
          );
          final userNow = userNowFromOffsetMinutes(timezoneOffsetMinutes);
          final widgetRange = buildWidgetThisMonthRange(userNow);
          final currentMonth = widgetRange['from']!;
          final currentRangeEnd = widgetRange['to']!;

          // Fetch Monthly Budgets for all scopes
          final monthStr =
              currentMonth.toIso8601String().substring(0, 10); // YYYY-MM-DD

          Future<List<ExpenseEntry>> loadWidgetTransactionsForScope({
            required String scopeId,
            required String currency,
          }) async {
            Future<List<ExpenseEntry>> loadActualExpenses(
              String? householdId,
            ) async {
              final query = DashboardScopeQuery(
                userId: user.uid,
                householdId: householdId,
                selectedCurrency: currency,
                startDate: currentMonth,
                endDate: currentRangeEnd,
              );
              return ref.read(
                dashboardCalendarTransactionsProvider(query).future,
              );
            }

            Future<List<RecurringTransaction>> loadRecurringTransactions(
              String? householdId,
            ) async {
              final recurringProvider = recurringTransactionsProvider(
                householdId,
              );
              final recurringState = ref.read(recurringProvider);
              if (!recurringState.hasLoadedOnce &&
                  !recurringState.data.isLoading) {
                await ref
                    .read(recurringProvider.notifier)
                    .loadRecurringTransactions(user.uid);
              }
              return ref.read(recurringProvider).data.valueOrNull ??
                  const <RecurringTransaction>[];
            }

            final scopedHouseholdIds = widgetSourceHouseholdIds(
              scopeId: scopeId,
              portfolioHouseholdIds: const <String>{},
            );
            final actualExpenses = <ExpenseEntry>[];
            final recurringTransactions = <RecurringTransaction>[];
            for (final householdId in scopedHouseholdIds) {
              actualExpenses.addAll(await loadActualExpenses(householdId));
              recurringTransactions.addAll(
                await loadRecurringTransactions(householdId),
              );
            }

            return mergeActualExpensesWithProjectedRecurring(
              actualExpenses: actualExpenses,
              recurringTransactions: recurringTransactions,
              rangeStart: currentMonth,
              rangeEnd: currentRangeEnd,
              selectedCurrency: currency,
              includeFutureOccurrences: false,
              now: userNow,
            );
          }

          Future<HouseholdSummary?> loadHouseholdDerivedSummary({
            required String householdId,
            required String currency,
          }) async {
            final params = HouseholdSummaryParams(
              householdId: householdId,
              currency: currency,
              startDate: formatDateOnlyYmd(currentMonth),
              endDate: formatDateOnlyYmd(currentRangeEnd),
            );

            await ref.read(
              cachedHouseholdExpensesProvider(
                HouseholdExpensesParams(householdId: householdId),
              ).future,
            );
            await ref.read(
              cachedHouseholdSplitsProvider(
                HouseholdSplitsParams(householdId: householdId),
              ).future,
            );
            await ref
                .read(householdMembersProvider(householdId).notifier)
                .load();
            await ref
                .read(householdBudgetsProvider(householdId).notifier)
                .load();

            final summaryAsync =
                ref.read(householdDerivedSummaryProvider(params));
            if (summaryAsync.hasError && !summaryAsync.hasValue) {
              throw summaryAsync.error ?? Exception('Failed to load summary');
            }
            return summaryAsync.valueOrNull;
          }

          // Use all supported currencies for configuration
          final allSupportedCurrencies = currencyOptions.keys.toList();

          // Preload personal budgets from the new `budgets` table, scoped the
          // same way as the personal home dashboard: household_id must be null.
          final personalBudgetsByCurrency = <String, double>{};
          final personalBudgetIdsByCurrency = <String, String>{};
          try {
            final budgetsRes = await Supabase.instance.client
                .from('budgets')
                .select(
                    'id,currency,total_budget_cents,period_month,household_id')
                .eq('user_id', user.uid)
                .eq('period_month', monthStr)
                .isFilter('household_id', null);

            final rows =
                (budgetsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
            for (final row in rows) {
              final code = (row['currency'] as String?)?.toUpperCase();
              if (code == null || code.isEmpty) continue;
              final id = row['id'] as String?;
              final cents =
                  (row['total_budget_cents'] as num?)?.toDouble() ?? 0.0;
              final amount = cents / 100.0;
              personalBudgetsByCurrency[code] =
                  (personalBudgetsByCurrency[code] ?? 0.0) + amount;
              if (id != null && id.isNotEmpty) {
                personalBudgetIdsByCurrency[code] = id;
              }
            }
          } catch (e) {
            debugPrint('Error fetching personal budgets for widget: $e');
          }

          // Helper to build per-envelope budget pockets for the personal scope
          // using the same data model as the Pockets page (budgets + envelopes).
          Future<List<WidgetPocketData>> loadPersonalBudgetPockets({
            required String currency,
            required List<ExpenseEntry> scopeExpenses,
          }) async {
            final budgetId = personalBudgetIdsByCurrency[currency];
            final totalBudget = personalBudgetsByCurrency[currency] ?? 0.0;
            if (budgetId == null || totalBudget <= 0) {
              return [];
            }

            try {
              final client = Supabase.instance.client;

              final now = DateTime.now();
              final periodMonth = DateTime(now.year, now.month, 1)
                  .toIso8601String()
                  .substring(0, 10);

              // Fetch envelopes for this budget/currency
              final envelopesRes = await client
                  .from('budget_envelopes')
                  .select('id,name,budget_amount_cents,color,icon')
                  .eq('user_id', user.uid)
                  .eq('currency', currency)
                  .eq('budget_id', budgetId)
                  .order('name');

              final envRows =
                  (envelopesRes as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (envRows.isEmpty) {
                return [];
              }

              final envIds = envRows.map((e) => e['id'] as String).toList();

              final allocationsRes = await client
                  .from('envelope_allocations')
                  .select('envelope_id,amount_cents')
                  .eq('period_month', periodMonth)
                  .inFilter('envelope_id', envIds);
              final allocationRows =
                  (allocationsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
              final allocationCentsByEnvelopeId = <String, int>{
                for (final row in allocationRows)
                  if ((row['envelope_id'] as String?) != null)
                    if (((row['amount_cents'] as num?)?.toInt() ?? 0) > 0)
                      (row['envelope_id'] as String):
                          (row['amount_cents'] as num?)!.toInt(),
              };

              // Category links per envelope
              final categoryLinksRes = await client
                  .from('envelope_category_links')
                  .select('envelope_id,category')
                  .inFilter('envelope_id', envIds);
              final categoryLinksRows =
                  (categoryLinksRes as List?)?.cast<Map<String, dynamic>>() ??
                      [];

              final categoriesByEnvelopeId = <String, List<String>>{};
              for (final row in categoryLinksRows) {
                final envId = row['envelope_id'] as String;
                final category =
                    (row['category'] as String? ?? '').toLowerCase().trim();
                if (category.isEmpty) continue;
                categoriesByEnvelopeId
                    .putIfAbsent(envId, () => <String>[])
                    .add(category);
              }

              // Compute spent per envelope from already-loaded expenses
              final spentById = <String, double>{};
              for (final envId in envIds) {
                final categories = categoriesByEnvelopeId[envId] ?? const [];
                if (categories.isEmpty) {
                  spentById[envId] = 0.0;
                  continue;
                }

                double spent = 0.0;
                for (final e in scopeExpenses) {
                  final cat = (e.category ?? '').toLowerCase();
                  if (categories.contains(cat)) {
                    spent += widgetCentsToAmount(widgetSpentCents(e));
                  }
                }
                spentById[envId] = spent;
              }

              // Build widget pockets mirroring the envelopes view
              final pockets = <WidgetPocketData>[];
              for (final row in envRows) {
                final id = row['id'] as String;
                final name = row['name'] as String? ?? '';
                final rawAmountCents =
                    (row['budget_amount_cents'] as num?)?.toInt();
                final resolvedAmountCents =
                    allocationCentsByEnvelopeId[id] ?? rawAmountCents ?? 0;
                final envelopeBudget = resolvedAmountCents / 100.0;
                final spent = spentById[id] ?? 0.0;
                final color = row['color'] as String? ?? '#7458FF';
                // Icon can be stored as a string name or another type (e.g. int codepoint).
                // Preserve whatever identifier exists by converting to string.
                final dynamic rawIcon = row['icon'];
                final String? icon = rawIcon?.toString();

                pockets.add(
                  WidgetPocketData(
                    name: name,
                    spent: spent,
                    budget: envelopeBudget,
                    color: color,
                    currency: currency,
                    icon: icon,
                  ),
                );
              }

              return pockets;
            } catch (e) {
              debugPrint(
                  'Error loading personal budget pockets for widget: $e');
              return [];
            }
          }

          Future<List<WidgetPocketData>> loadHouseholdBudgetPockets({
            required String householdId,
            required String currency,
            required DateTime monthStart,
            required List<ExpenseEntry> scopeExpenses,
          }) async {
            try {
              final client = Supabase.instance.client;

              final periodMonth =
                  monthStart.toIso8601String().substring(0, 10); // YYYY-MM-DD

              final budgetRow = await client
                  .from('budgets')
                  .select('id,total_budget_cents')
                  .eq('household_id', householdId)
                  .eq('currency', currency)
                  .eq('period_month', periodMonth)
                  .maybeSingle();

              if (budgetRow == null) {
                return [];
              }

              final budgetId = budgetRow['id'] as String?;
              final totalBudget =
                  ((budgetRow['total_budget_cents'] as num?)?.toDouble() ??
                          0.0) /
                      100.0;

              if (budgetId == null || totalBudget <= 0) {
                return [];
              }

              final envelopesRes = await client
                  .from('budget_envelopes')
                  .select('id,name,budget_amount_cents,color,icon')
                  .eq('household_id', householdId)
                  .eq('currency', currency)
                  .eq('budget_id', budgetId)
                  .order('name');

              final envRows =
                  (envelopesRes as List?)?.cast<Map<String, dynamic>>() ?? [];
              if (envRows.isEmpty) {
                return [];
              }

              final envIds = envRows.map((e) => e['id'] as String).toList();

              final allocationsRes = await client
                  .from('envelope_allocations')
                  .select('envelope_id,amount_cents')
                  .eq('period_month', periodMonth)
                  .inFilter('envelope_id', envIds);
              final allocationRows =
                  (allocationsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
              final allocationCentsByEnvelopeId = <String, int>{
                for (final row in allocationRows)
                  if ((row['envelope_id'] as String?) != null)
                    if (((row['amount_cents'] as num?)?.toInt() ?? 0) > 0)
                      (row['envelope_id'] as String):
                          (row['amount_cents'] as num?)!.toInt(),
              };

              final categoryLinksRes = await client
                  .from('envelope_category_links')
                  .select('envelope_id,category')
                  .inFilter('envelope_id', envIds);

              final categoryLinksRows =
                  (categoryLinksRes as List?)?.cast<Map<String, dynamic>>() ??
                      [];

              final categoriesByEnvelopeId = <String, List<String>>{};
              for (final row in categoryLinksRows) {
                final envId = row['envelope_id'] as String;
                final category =
                    (row['category'] as String? ?? '').toLowerCase().trim();
                if (category.isEmpty) continue;
                categoriesByEnvelopeId
                    .putIfAbsent(envId, () => <String>[])
                    .add(category);
              }

              final spentById = <String, double>{};
              for (final envId in envIds) {
                final categories = categoriesByEnvelopeId[envId] ?? const [];
                if (categories.isEmpty) {
                  spentById[envId] = 0.0;
                  continue;
                }

                double spent = 0.0;
                for (final entry in scopeExpenses) {
                  final cat = (entry.category ?? '').toLowerCase().trim();
                  if (categories.contains(cat)) {
                    spent += widgetCentsToAmount(widgetSpentCents(entry));
                  }
                }
                spentById[envId] = spent;
              }

              final pockets = <WidgetPocketData>[];
              for (final row in envRows) {
                final id = row['id'] as String;
                final name = row['name'] as String? ?? '';
                final rawAmountCents =
                    (row['budget_amount_cents'] as num?)?.toInt();
                final resolvedAmountCents =
                    allocationCentsByEnvelopeId[id] ?? rawAmountCents ?? 0;
                final envelopeBudget = resolvedAmountCents / 100.0;
                final spent = spentById[id] ?? 0.0;
                final color = row['color'] as String? ?? '#7458FF';
                final dynamic rawIcon = row['icon'];
                final String? icon = rawIcon?.toString();

                pockets.add(
                  WidgetPocketData(
                    name: name,
                    spent: spent,
                    budget: envelopeBudget,
                    color: color,
                    currency: currency,
                    icon: icon,
                  ),
                );
              }

              return pockets;
            } catch (e) {
              debugPrint(
                  'Error loading household budget pockets for widget: $e');
              return [];
            }
          }

          // Iterate and Sync
          // We sync data for currencies that are either available (have data) OR are major currencies.
          // Syncing ALL 40+ currencies for EVERY household might be too heavy (40 * N writes).
          // Let's sync availableCurrencies + a few defaults if available is empty.
          // The user can select any currency in the widget, but if there is no data,
          // the widget will just show 0/0 if we sync it, or "No Data" if we don't.
          // To ensure the widget works for any selected currency, we should ideally sync all.
          // But let's try to be smart: Sync availableCurrencies + USD + EUR + user's preferred currency.
          // Actually, if we don't sync a currency, the widget (DataLoader.swift) won't find the key
          // and will likely show default/placeholder data or 0.
          // Let's sync ALL supported currencies for now to fully satisfy the requirement "configurable... which currency".
          // If performance is bad, we can optimize.

          if (Supabase.instance.client.auth.currentSession == null) {
            // Session lost - exit loop, finally will handle cleanup
            return;
          }

          for (final scope in allScopes) {
            if (Supabase.instance.client.auth.currentSession == null) {
              // Session lost - exit loop, finally will handle cleanup
              return;
            }
            final scopeId = scope['id']!;

            for (final currency in allSupportedCurrencies) {
              if (Supabase.instance.client.auth.currentSession == null) {
                // Session lost - exit loop, finally will handle cleanup
                return;
              }
              var financialSummary = const WidgetFinancialSummary(
                totalSpent: 0,
                totalBudget: 0,
                remainingBudget: 0,
                progress: 0,
              );
              List<WidgetPocketData> topCategories = [];
              List<WidgetPocketData> budgetPockets = [];

              if (scopeId == 'personal') {
                // --- PERSONAL SCOPE ---
                List<ExpenseEntry> scopeExpenses = [];
                try {
                  scopeExpenses = await loadWidgetTransactionsForScope(
                    scopeId: scopeId,
                    currency: currency,
                  );
                } catch (e) {
                  debugPrint(
                      'Error fetching personal expenses for widget ($currency): $e');
                }

                final totalSpent = widgetCentsToAmount(
                  calculateWidgetSpentCents(scopeExpenses),
                );
                var totalBudget = 0.0;

                // 2. Get Budget
                // Prefer the new monthly `budgets` table (used by Pockets),
                // but fall back to legacy `daily_budgets` data via analytics
                // if nothing exists there.
                final fromBudgetsTable =
                    personalBudgetsByCurrency[currency] ?? 0.0;

                if (fromBudgetsTable > 0) {
                  totalBudget = fromBudgetsTable;
                } else {
                  final allBudgets = analyticsData.allBudgets;
                  final budgetsInRange = allBudgets.where((budget) {
                    final budgetDate = DateTime(
                      budget.date.year,
                      budget.date.month,
                      budget.date.day,
                    );
                    final isMonthMatch = budgetDate.year == userNow.year &&
                        budgetDate.month == userNow.month;
                    final currencyOk =
                        (budget.currency?.toUpperCase() ?? 'USD') == currency;
                    return isMonthMatch && currencyOk;
                  }).toList();

                  if (budgetsInRange.isNotEmpty) {
                    totalBudget =
                        budgetsInRange.fold(0.0, (sum, b) => sum + b.amount);
                  } else {
                    // Find most recent budget before this month
                    DailyBudgetEntry? mostRecentBudget;
                    final firstOfMonth = DateTime(userNow.year, userNow.month, 1);
                    for (final budget in allBudgets.reversed) {
                      final budgetDate = DateTime(
                        budget.date.year,
                        budget.date.month,
                        budget.date.day,
                      );
                      final currencyOk =
                          (budget.currency?.toUpperCase() ?? 'USD') == currency;
                      if (currencyOk && budgetDate.isBefore(firstOfMonth)) {
                        mostRecentBudget = budget;
                        break;
                      }
                    }
                    if (mostRecentBudget != null) {
                      totalBudget = mostRecentBudget.amount;
                    }
                  }
                }

                financialSummary = buildWidgetSummaryFromSpentAndBudget(
                  totalSpent: totalSpent,
                  totalBudget: totalBudget,
                );

                // 3. Budget pockets (envelopes) for this currency/month
                budgetPockets = await loadPersonalBudgetPockets(
                  currency: currency,
                  scopeExpenses: scopeExpenses,
                );

                // 4. Top Categories (for optional category-based widgets)
                final categoryMap = calculateWidgetCategorySpentCents(
                  scopeExpenses,
                );

                topCategories = categoryMap.entries
                    .sorted((a, b) => b.value.compareTo(a.value))
                    .take(4)
                    .map((e) {
                  final color = getCategoryColor(e.key);
                  final hex = _colorToHex(color);
                  return WidgetPocketData(
                    name: e.key,
                    spent: widgetCentsToAmount(e.value),
                    budget: 0,
                    color: hex,
                    currency: currency,
                    // Use the raw category key as an icon identifier so
                    // platform widgets can map it to a native icon.
                    icon: e.key,
                  );
                }).toList();
              } else {
                // --- HOUSEHOLD SCOPE ---
                // CIRCUIT BREAKER: Check if this scope+currency failed recently
                final scopeKey = '$scopeId:$currency';
                if (syncState.isScopeInCooldown(scopeKey)) {
                  debugPrint(
                      '🔄 [WidgetSync] Skipping $scopeKey - in cooldown');
                  continue;
                }

                try {
                  if (Supabase.instance.client.auth.currentSession == null) {
                    // Session lost - exit loop, finally will handle cleanup
                    return;
                  }
                  final scopeExpenses = await loadWidgetTransactionsForScope(
                    scopeId: scopeId,
                    currency: currency,
                  );
                  final summary = await loadHouseholdDerivedSummary(
                    householdId: scopeId,
                    currency: currency,
                  );

                  final totalSpent = widgetCentsToAmount(
                    calculateWidgetSpentCents(scopeExpenses),
                  );

                  financialSummary = buildHouseholdWidgetSummary(
                    totalSpent: totalSpent,
                    budgets: summary?.budgets ?? const <BudgetStatus>[],
                  );

                  budgetPockets = await loadHouseholdBudgetPockets(
                    householdId: scopeId,
                    currency: currency,
                    monthStart: currentMonth,
                    scopeExpenses: scopeExpenses,
                  );

                  final categoryMap = calculateWidgetCategorySpentCents(
                    scopeExpenses,
                  );
                  topCategories = categoryMap.entries
                      .sorted((a, b) => b.value.compareTo(a.value))
                      .take(4)
                      .map((entry) {
                    final color = getCategoryColor(entry.key);
                    final hex = _colorToHex(color);
                    return WidgetPocketData(
                      name: entry.key,
                      spent: widgetCentsToAmount(entry.value),
                      budget: 0,
                      color: hex,
                      currency: currency,
                      icon: entry.key,
                    );
                  }).toList();
                } catch (e) {
                  // Ignore unauthorized errors (logout/expired session) to avoid noisy logs
                  if (e is FunctionException && e.status == 401) {
                    debugPrint(
                        'Widget sync skipped (unauthorized) for scope $scopeId, currency $currency');
                    // Session is invalid - exit loops, finally will handle cleanup
                    return;
                  }

                  // Record failure for circuit breaker
                  syncStateNotifier.recordScopeFailure(scopeId, currency);

                  // Only log if not in startup grace period to reduce noise
                  if (!syncState.isInStartupGracePeriod) {
                    debugPrint(
                        '⚠️ [WidgetSync] Error fetching household summary ($scopeId, $currency): $e');
                  }
                  // Continue to next currency/scope, don't crash
                  continue;
                }
              }

              // Use budget-based pockets when available; otherwise fall back to
              // topCategories so the widget still shows a breakdown instead of
              // an empty state.
              final pocketsForWidget =
                  budgetPockets.isNotEmpty ? budgetPockets : topCategories;

              await WidgetService().updateWidgetDataWithScope(
                scopeId: scopeId,
                currency: currency,
                totalSpent: financialSummary.totalSpent,
                totalBudget: financialSummary.totalBudget,
                remainingBudget: financialSummary.remainingBudget,
                budgetProgress: financialSummary.progress,
                pockets: pocketsForWidget,
              );

              // Save top categories separately for the dedicated widget variant.
              await WidgetService().saveTopCategoriesForScope(
                scopeId: scopeId,
                currency: currency,
                pockets: topCategories,
              );

              // Sync to legacy keys (no suffix) for Personal + Preferred Currency (or USD)
              // This ensures the widget has data before configuration is set
              final preferredCurrency =
                  analyticsData.preferredCurrency ?? 'USD';
              if (scopeId == 'personal' && currency == preferredCurrency) {
                await WidgetService().updateWidgetData(
                  totalSpent: financialSummary.totalSpent,
                  totalBudget: financialSummary.totalBudget,
                  remainingBudget: financialSummary.remainingBudget,
                  budgetProgress: financialSummary.progress,
                  currency: currency,
                  pockets: pocketsForWidget,
                );
              }
            }
          }

          // If we reach here, sync completed successfully
          syncSucceeded = true;
          debugPrint('✅ [WidgetSync] Sync completed successfully');
        } catch (e, stackTrace) {
          // Mark sync as failed explicitly
          debugPrint('❌ [WidgetSync] Sync failed with error: $e');
          debugPrint(stackTrace.toString());
        } finally {
          // ALWAYS ensure sync state is properly reset to avoid deadlock
          if (syncSucceeded) {
            syncStateNotifier.completeSync();
          } else {
            syncStateNotifier.failSync();
          }
        }
      }

      // Delay the sync call to run outside the widget lifecycle
      // to avoid "Modifying a provider inside build/initState" errors
      Future(syncAllScopes);
      return null;
    }, [
      analyticsData.allExpenses,
      analyticsData.allBudgets,
      analyticsData.preferredCurrency,
      householdsAsync.valueOrNull,
      availableCurrencies,
      widgetSyncVersion,
      isAppReady, // Add app ready state as dependency
    ]);

    return const SizedBox.shrink();
  }
}

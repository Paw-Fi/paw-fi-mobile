import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/households/data/services/household_service.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';

String _colorToHex(Color color) {
  final r = ((color.r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final g = ((color.g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  final b = ((color.b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0');
  return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
}

class WidgetSyncManager extends HookConsumerWidget {
  const WidgetSyncManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final analyticsData = ref.watch(analyticsProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final availableCurrencies = ref.watch(availableCurrenciesProvider);
    final widgetSyncVersion = ref.watch(widgetSyncVersionProvider);

    // Ensure configuration options (households + currencies) are always saved
    // for the iOS AppIntent, independent of analytics loading state.
    useEffect(() {
      if (user.uid.isEmpty || householdsAsync.isLoading) {
        return null;
      }

      final households = householdsAsync.valueOrNull ?? [];

      Future<void> syncConfigOptions() async {
        final allSupportedCurrencies = currencyOptions.keys.toList();

        await WidgetService().saveConfigurationOptions(
          households: [
            {'id': 'personal', 'name': 'Personal'},
            ...households.map((h) => {'id': h.id, 'name': h.name}),
          ],
          currencies: allSupportedCurrencies,
        );
      }

      syncConfigOptions();
      return null;
    }, [
      householdsAsync.valueOrNull,
    ]);

    // Sync ALL scopes (Personal + Households) for Configurable Widgets
    useEffect(() {
      if (analyticsData.isLoading ||
          user.uid.isEmpty ||
          householdsAsync.isLoading) {
        return null;
      }

      final households = householdsAsync.valueOrNull ?? [];
      final allScopes = [
        {'id': 'personal', 'name': 'Personal'},
        ...households.map((h) => {'id': h.id, 'name': h.name}),
      ];

      Future<void> syncAllScopes() async {
        // Abort immediately if user signed out or session is gone
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null || user.uid.isEmpty) return;

        final now = DateTime.now();
        final currentMonth = DateTime(now.year, now.month, 1);

        // Fetch Monthly Budgets for all scopes
        final monthStr =
            currentMonth.toIso8601String().substring(0, 10); // YYYY-MM-DD
        final endDateStr = DateTime(now.year, now.month + 1, 0)
            .toIso8601String()
            .substring(0, 10);

        final householdService = HouseholdService(Supabase.instance.client);

        // Use all supported currencies for configuration
        final allSupportedCurrencies = currencyOptions.keys.toList();

        // Preload personal budgets from the new `budgets` table so the widget
        // reflects the same monthly budget as the Pockets page. Fallback to
        // legacy `daily_budgets` data when no entry exists here.
        final personalBudgetsByCurrency = <String, double>{};
        final personalBudgetIdsByCurrency = <String, String>{};
        try {
          final budgetsRes = await Supabase.instance.client
              .from('budgets')
              .select('id,currency,total_budget_cents,period_month,household_id')
              .eq('user_id', user.uid)
              .isFilter('household_id', null)
              .eq('period_month', monthStr);

          final rows = (budgetsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
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

            // Fetch envelopes for this budget/currency
            final envelopesRes = await client
                .from('budget_envelopes')
                .select('id,name,budget_percentage,color,icon')
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

            // Category links per envelope
            final categoryLinksRes = await client
                .from('envelope_category_links')
                .select('envelope_id,category')
                .inFilter('envelope_id', envIds);
            final categoryLinksRows = (categoryLinksRes as List?)
                    ?.cast<Map<String, dynamic>>() ??
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
                  spent += e.amount;
                }
              }
              spentById[envId] = spent;
            }

            // Build widget pockets mirroring the envelopes view
            final pockets = <WidgetPocketData>[];
            for (final row in envRows) {
              final id = row['id'] as String;
              final name = row['name'] as String? ?? '';
              final pct =
                  (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
              final envelopeBudget = totalBudget * (pct / 100.0);
              final spent = spentById[id] ?? 0.0;
              final color = row['color'] as String? ?? '#7458FF';
              // Icon can be stored as a string name or another type (e.g. int codepoint).
              // Preserve whatever identifier exists by converting to string.
              final dynamic rawIcon = row['icon'];
              final String? icon = rawIcon != null ? rawIcon.toString() : null;

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
            debugPrint('Error loading personal budget pockets for widget: $e');
            return [];
          }
        }

        Future<List<WidgetPocketData>> loadHouseholdBudgetPockets({
          required String householdId,
          required String currency,
          required DateTime monthStart,
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
                ((budgetRow['total_budget_cents'] as num?)?.toDouble() ?? 0.0) /
                    100.0;

            if (budgetId == null || totalBudget <= 0) {
              return [];
            }

            final envelopesRes = await client
                .from('budget_envelopes')
                .select('id,name,budget_percentage,color,icon')
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

            final categoryLinksRes = await client
                .from('envelope_category_links')
                .select('envelope_id,category')
                .inFilter('envelope_id', envIds);

            final categoryLinksRows =
                (categoryLinksRes as List?)?.cast<Map<String, dynamic>>() ?? [];

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

            final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

            final expensesRes = await client
                .from('expenses')
                .select(
                    'amount_cents,category,type,household_id,currency,date')
                .eq('household_id', householdId)
                .eq('currency', currency)
                .gte('date', monthStart.toIso8601String())
                .lt('date', monthEnd.toIso8601String());

            final expensesRows =
                (expensesRes as List?)?.cast<Map<String, dynamic>>() ?? [];

            final spentById = <String, double>{};
            for (final envId in envIds) {
              final categories = categoriesByEnvelopeId[envId] ?? const [];
              if (categories.isEmpty) {
                spentById[envId] = 0.0;
                continue;
              }

              double spent = 0.0;
              for (final row in expensesRows) {
                final type = (row['type'] as String?)?.toLowerCase();
                if (type == 'income') continue;
                final cat =
                    (row['category'] as String? ?? '').toLowerCase().trim();
                if (categories.contains(cat)) {
                  final cents = (row['amount_cents'] as num?)?.toDouble() ?? 0.0;
                  spent += cents / 100.0;
                }
              }
              spentById[envId] = spent;
            }

            final pockets = <WidgetPocketData>[];
            for (final row in envRows) {
              final id = row['id'] as String;
              final name = row['name'] as String? ?? '';
              final pct =
                  (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
              final envelopeBudget = totalBudget * (pct / 100.0);
              final spent = spentById[id] ?? 0.0;
              final color = row['color'] as String? ?? '#7458FF';
              final dynamic rawIcon = row['icon'];
              final String? icon = rawIcon != null ? rawIcon.toString() : null;

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
            debugPrint('Error loading household budget pockets for widget: $e');
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

        if (Supabase.instance.client.auth.currentSession == null) return;

        for (final scope in allScopes) {
          if (Supabase.instance.client.auth.currentSession == null) return;
          final scopeId = scope['id']!;

          for (final currency in allSupportedCurrencies) {
            if (Supabase.instance.client.auth.currentSession == null) return;
            double totalSpent = 0.0;
            double totalBudget = 0.0;
            List<WidgetPocketData> topCategories = [];
            List<WidgetPocketData> budgetPockets = [];

            if (scopeId == 'personal') {
              // --- PERSONAL SCOPE ---
              // Use direct expenses query (same as pockets page) so widget
              // amounts always match the Pockets screen, independent of
              // analytics edge-function quirks.

              // Skip currencies without a budget entry to avoid excessive
              // queries for unused currencies.
              if ((personalBudgetsByCurrency[currency] ?? 0.0) <= 0) {
                continue;
              }

              List<Map<String, dynamic>> scopeExpenses = [];
              try {
                var expenseQuery = Supabase.instance.client
                    .from('expenses')
                    .select(
                        'amount_cents,category,type,household_id,currency,date')
                    .eq('user_id', user.uid)
                    .eq('currency', currency)
                    .gte('date', monthStr)
                    .lte('date', endDateStr)
                    .isFilter('household_id', null);

                final expensesRes = await expenseQuery;
                scopeExpenses = (expensesRes as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
              } catch (e) {
                debugPrint(
                    'Error fetching personal expenses for widget ($currency): $e');
              }

              totalSpent = 0.0;
              for (final row in scopeExpenses) {
                final type = (row['type'] as String?)?.toLowerCase();
                if (type == 'income') continue;
                final cents =
                    (row['amount_cents'] as num?)?.toDouble() ?? 0.0;
                totalSpent += cents / 100.0;
              }

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
                  final isMonthMatch = budgetDate.year == now.year &&
                      budgetDate.month == now.month;
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
                  final firstOfMonth = DateTime(now.year, now.month, 1);
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

              // 3. Budget pockets (envelopes) for this currency/month
              budgetPockets = await loadPersonalBudgetPockets(
                currency: currency,
                scopeExpenses: scopeExpenses
                    .map((row) => ExpenseEntry.fromJson({
                          'id': '',
                          'contact_id': null,
                          'user_id': user.uid,
                          'date': row['date'],
                          'amount_cents': row['amount_cents'],
                          'currency': row['currency'],
                          'category': row['category'],
                          'created_at': row['date'],
                          'updated_at': row['date'],
                          'raw_text': null,
                          'receipt_image_url': null,
                          'household_id': row['household_id'],
                          'split_group_id': null,
                          'type': row['type'],
                        }))
                    .toList(),
              );

              // 4. Top Categories (for optional category-based widgets)
              final categoryMap = <String, double>{};
              for (final row in scopeExpenses) {
                final type = (row['type'] as String?)?.toLowerCase();
                if (type == 'income') continue;
                final cents =
                    (row['amount_cents'] as num?)?.toDouble() ?? 0.0;
                final amount = cents / 100.0;
                final cat =
                    (row['category'] as String? ?? 'Uncategorized');
                categoryMap[cat] = (categoryMap[cat] ?? 0) + amount;
              }

              topCategories = categoryMap.entries
                  .sorted((a, b) => b.value.compareTo(a.value))
                  .take(4)
                  .map((e) {
                    final color = getCategoryColor(e.key);
                    final hex = _colorToHex(color);
                    return WidgetPocketData(
                      name: e.key,
                      spent: e.value,
                      budget: 0,
                      color: hex,
                      currency: currency,
                      // Use the raw category key as an icon identifier so
                      // platform widgets can map it to a native icon.
                      icon: e.key,
                    );
                  })
                  .toList();
            } else {
              // --- HOUSEHOLD SCOPE ---
              // Optimization: Only fetch if we suspect there's data?
              // No, we can't know easily.
              // But calling the Edge Function 40 times per household is definitely BAD.
              // The Edge Function `households-summary` likely returns data for a specific currency.
              // If we call it 40 times, it's 40 network requests.
              // We should probably ONLY sync currencies that are "active" for the household.
              // But the user might want to see "0" for a new currency.
              // Compromise: For households, only sync currencies that are in `availableCurrencies` (which comes from AnalyticsData, but that might only be personal?).
              // Wait, `AnalyticsData` in `AnalyticsProvider` fetches `get_analytics` which includes household data if the user is in one?
              // No, `AnalyticsProvider` usually fetches personal data or currently selected household data.
              // `WidgetSyncManager` is trying to sync ALL households.

              // If we skip fetching for a currency, the widget will show old data or 0.
              // Let's restrict household sync to:
              // 1. Currencies present in `availableCurrencies` (which might be incomplete for other households)
              // 2. 'USD', 'EUR', 'GBP' (Common defaults)
              // 3. The household's "primary" currency? (We don't have that info easily here, maybe in Household object?)
              // The `Household` entity has a `currency` field!

              // Let's find the household object
              final household =
                  households.firstWhereOrNull((h) => h.id == scopeId);
              final householdCurrency = household?.currency ?? 'USD';

              // We should definitely sync the household's main currency.
              // And maybe any others that have data?
              // For now, to avoid 40+ API calls, let's only sync the household's default currency + USD/EUR.
              // Or better: The user can only select "Personal" or "Household".
              // If they select "Household", they probably want to see it in the household's currency.
              // If they select a different currency, we might not have data.

              final currenciesToSync = {
                householdCurrency,
                'USD',
                'EUR',
                'GBP',
                ...availableCurrencies
              }.intersection(allSupportedCurrencies.toSet()).toList();

              if (!currenciesToSync.contains(currency)) {
                continue;
              }

              // Use HouseholdService to fetch summary via Edge Function
              try {
                if (Supabase.instance.client.auth.currentSession == null) {
                  return;
                }
                final summaryMap = await householdService.getHouseholdSummary(
                  householdId: scopeId,
                  currency: currency,
                  startDate: monthStr,
                  endDate: endDateStr,
                );
                final summary = HouseholdSummary.fromJson(summaryMap);

                totalSpent = summary.totals.totalExpensesCents / 100.0;

                totalBudget = summary.budgets.fold<double>(
                  0.0,
                  (sum, b) => sum + b.amountCents / 100.0,
                );

                budgetPockets = await loadHouseholdBudgetPockets(
                  householdId: scopeId,
                  currency: currency,
                  monthStart: currentMonth,
                );

                // Top Categories
                topCategories = summary.categoryBreakdown
                    .take(4)
                    .map((cat) {
                          final color = getCategoryColor(cat.category);
                          final hex = _colorToHex(color);
                          return WidgetPocketData(
                            name: cat.category,
                            spent: cat.amountCents / 100.0,
                            budget: 0,
                            color: hex,
                            currency: currency,
                            icon: cat.category,
                          );
                        })
                    .toList();
              } catch (e) {
                // Ignore unauthorized errors (logout/expired session) to avoid noisy logs
                if (e is FunctionException && e.status == 401) {
                  debugPrint(
                      'Widget sync skipped (unauthorized) for scope $scopeId, currency $currency');
                  return;
                }
                debugPrint(
                    'Error fetching household summary for widget ($scopeId, $currency): $e');
                // Continue to next currency/scope, don't crash
                continue;
              }
            }

            // Calculate Progress
            double progress = 0.0;
            if (totalBudget > 0) {
              progress = (totalSpent / totalBudget).clamp(0.0, 1.0);
            }

            // Use budget-based pockets when available; otherwise fall back to
            // topCategories so the widget still shows a breakdown instead of
            // an empty state.
            final pocketsForWidget =
                budgetPockets.isNotEmpty ? budgetPockets : topCategories;

            await WidgetService().updateWidgetDataWithScope(
              scopeId: scopeId,
              currency: currency,
              totalSpent: totalSpent,
              totalBudget: totalBudget,
              budgetProgress: progress,
              pockets: pocketsForWidget,
            );

            // Save top categories separately for the dedicated widget variant.
            if (topCategories.isNotEmpty) {
              await WidgetService().saveTopCategoriesForScope(
                scopeId: scopeId,
                currency: currency,
                pockets: topCategories,
              );
            }

            // Sync to legacy keys (no suffix) for Personal + Preferred Currency (or USD)
            // This ensures the widget has data before configuration is set
            final preferredCurrency = analyticsData.preferredCurrency ?? 'USD';
            if (scopeId == 'personal' && currency == preferredCurrency) {
              await WidgetService().updateWidgetData(
                totalSpent: totalSpent,
                totalBudget: totalBudget,
                currency: currency,
                pockets: pocketsForWidget,
              );
            }
          }
        }
      }

      syncAllScopes();
      return null;
    }, [
      analyticsData.allExpenses,
      analyticsData.allBudgets,
      analyticsData.preferredCurrency,
      householdsAsync.valueOrNull,
      availableCurrencies,
      widgetSyncVersion,
    ]);

    return const SizedBox.shrink();
  }
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void _debugLog(String message) {
  if (foundation.kDebugMode) {
    foundation.debugPrint(message);
  }
}

/// Scope for pockets: personal or household.
enum PocketsScopeType { personal, portfolio, household }

class PocketsScopeParams {
  const PocketsScopeParams({
    required this.scope,
    this.householdId,
    this.periodMonth,
  });

  final PocketsScopeType scope;
  final String? householdId;
  final DateTime? periodMonth;

  @override
  bool operator ==(Object other) {
    return other is PocketsScopeParams &&
        other.scope == scope &&
        other.householdId == householdId &&
        other.periodMonth == periodMonth;
  }

  @override
  int get hashCode => Object.hash(scope, householdId, periodMonth);
}

class PocketsState {
  const PocketsState({
    required this.isLoading,
    this.error,
    required this.saved,
    required this.editing,
    this.budgetId,
    required this.periodMonth,
    required this.previousBudget,
    required this.totalBudget,
    required this.savedTotalBudget,
    required this.unallocatedSpend,
    required this.uncategorized,
    required this.uncategorizedExpenses,
  });

  final bool isLoading;
  final String? error;
  final List<PocketEnvelope> saved;
  final List<PocketEnvelope> editing;
  final String? budgetId;
  final DateTime periodMonth;
  final double previousBudget;
  final double totalBudget;
  final double savedTotalBudget; // Track original budget for change detection
  final double unallocatedSpend;
  final List<UncategorizedCategory> uncategorized;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;

  bool get hasChanges {
    // Check if budget has changed
    if ((totalBudget - savedTotalBudget).abs() > 0.01) {
      _debugLog(
          'hasChanges: true (budget changed from $savedTotalBudget to $totalBudget)');
      return true;
    }

    // Check if pockets have changed
    if (saved.length != editing.length) {
      _debugLog('hasChanges: true (pocket count changed)');
      return true;
    }
    for (var i = 0; i < saved.length; i++) {
      if (saved[i].id != editing[i].id ||
          saved[i].percentage != editing[i].percentage ||
          saved[i].spent != editing[i].spent) {
        _debugLog('hasChanges: true (pocket ${saved[i].name} changed)');
        return true;
      }
    }
    _debugLog('hasChanges: false');
    return false;
  }

  double get totalSpent => editing.fold<double>(0, (sum, p) => sum + p.spent);

  double get totalPercentage =>
      editing.fold<double>(0, (sum, p) => sum + p.percentage);

  PocketsState copyWith({
    bool? isLoading,
    String? error,
    List<PocketEnvelope>? saved,
    List<PocketEnvelope>? editing,
    String? budgetId,
    DateTime? periodMonth,
    double? previousBudget,
    double? totalBudget,
    double? savedTotalBudget,
    double? unallocatedSpend,
    List<UncategorizedCategory>? uncategorized,
    Map<String, List<Map<String, dynamic>>>? uncategorizedExpenses,
    bool clearError = false,
  }) {
    return PocketsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
      editing: editing ?? this.editing,
      budgetId: budgetId ?? this.budgetId,
      periodMonth: periodMonth ?? this.periodMonth,
      previousBudget: previousBudget ?? this.previousBudget,
      totalBudget: totalBudget ?? this.totalBudget,
      savedTotalBudget: savedTotalBudget ?? this.savedTotalBudget,
      unallocatedSpend: unallocatedSpend ?? this.unallocatedSpend,
      uncategorized: uncategorized ?? this.uncategorized,
      uncategorizedExpenses:
          uncategorizedExpenses ?? this.uncategorizedExpenses,
    );
  }

  factory PocketsState.initial() => PocketsState(
        isLoading: true,
        error: null,
        saved: [],
        editing: [],
        budgetId: null,
        periodMonth: DateTime(1970, 1, 1),
        previousBudget: 0,
        totalBudget: 0,
        savedTotalBudget: 0,
        unallocatedSpend: 0,
        uncategorized: [],
        uncategorizedExpenses: {},
      );
}

class UncategorizedCategory {
  const UncategorizedCategory({
    required this.category,
    required this.amount,
  });

  final String category;
  final double amount;
}

class PocketsNotifier extends StateNotifier<PocketsState> {
  PocketsNotifier(this.ref, this.params) : super(PocketsState.initial()) {
    // Auto-load once when the notifier is created.
    // This ensures that:
    // - The first time a pockets provider is watched, data starts loading immediately.
    // - After ref.invalidate(pocketsProvider(...)) creates a new notifier,
    //   pockets are reloaded without relying on widget lifecycle hooks.
    Future.microtask(load);
  }

  final Ref ref;
  final PocketsScopeParams params;

  bool _hasLoadedOnce = false;

  dynamic _applyAccountScopeFilter(
    dynamic query,
    String userId, {
    required PocketsScopeType scope,
    required String? householdId,
  }) {
    return switch (scope) {
      PocketsScopeType.personal =>
        query.eq('user_id', userId).isFilter('household_id', null),
      PocketsScopeType.portfolio =>
        query.eq('user_id', userId).eq('household_id', householdId!),
      PocketsScopeType.household => query.eq('household_id', householdId!),
    };
  }

  /// Public method to trigger data loading. Should be called by the UI
  /// when the pockets page is displayed (not on provider creation).
  ///
  /// This method loads pockets data using the best available currency:
  /// 1. From homeFilterProvider.selectedCurrency (user selection)
  /// 2. From analyticsProvider.preferredCurrency (if loaded)
  /// 3. Fallback to 'USD'
  ///
  /// No polling required - just use what's available.
  Future<void> load() async {
    // Avoid duplicate loads if already loading
    if (state.isLoading && _hasLoadedOnce) return;
    _hasLoadedOnce = true;

    final authUser = ref.read(authProvider);
    if (authUser.isEmpty) {
      _debugLog('[Pockets] No auth user, cannot load');
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: 'Not authenticated');
      return;
    }

    await _load();
  }

  Future<void> _load() async {
    _debugLog(
        '[Pockets] Starting _load for scope: ${params.scope}, month: ${params.periodMonth}');
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authUser = ref.read(authProvider);
      final filter = ref.read(homeFilterProvider);

      final DateTime targetDate;
      if (params.periodMonth != null) {
        targetDate = params.periodMonth!;
      } else {
        final range = getDateRangeFromFilter(
          filter.dateRangeFilter,
          filter.customStartDate,
          filter.customEndDate,
        );
        targetDate = range['to'] ?? DateTime.now();
      }

      final monthStart = DateTime(targetDate.year, targetDate.month, 1);
      final periodMonth = _formatDate(monthStart);
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

      final scopeType = params.scope;
      final isHousehold = scopeType == PocketsScopeType.household;
      final isPortfolio = scopeType == PocketsScopeType.portfolio;
      final householdId = params.householdId;

      if (isHousehold && householdId == null) {
        if (!mounted) return;
        state = PocketsState(
          isLoading: false,
          error: null,
          saved: const [],
          editing: const [],
          budgetId: null,
          periodMonth: monthStart,
          previousBudget: 0,
          totalBudget: 0,
          savedTotalBudget: 0,
          unallocatedSpend: 0,
          uncategorized: const [],
          uncategorizedExpenses: const {},
        );
        return;
      }

      if (isPortfolio && householdId == null) {
        if (!mounted) return;
        state = PocketsState(
          isLoading: false,
          error: 'No portfolio selected for portfolio budget view',
          saved: const [],
          editing: const [],
          budgetId: null,
          periodMonth: monthStart,
          previousBudget: 0,
          totalBudget: 0,
          savedTotalBudget: 0,
          unallocatedSpend: 0,
          uncategorized: const [],
          uncategorizedExpenses: const {},
        );
        return;
      }

      // Resolve initial currency for this scope/month.
      // Must match main_menu_screen.dart / CurrencyDropdownButton behavior:
      // 1. Home filter's selectedCurrency (set by HomePage + currency selector)
      // 2. Analytics preferred currency
      // 3. Fallback to USD
      final analytics = ref.read(analyticsProvider);
      final hasExplicitCurrency = filter.selectedCurrency != null &&
          filter.selectedCurrency!.trim().isNotEmpty;
      final initialCurrency = (filter.selectedCurrency?.toUpperCase() ??
              analytics.preferredCurrency?.toUpperCase() ??
              'USD')
          .toUpperCase();
      var selectedCurrency = initialCurrency;

      _debugLog(
          '[Pockets] Using currency: $selectedCurrency (filter: ${filter.selectedCurrency}, analytics: ${analytics.preferredCurrency}, hasLoaded: ${analytics.hasLoadedOnce})');

      // Fetch or create budget for the current month/scope
      final budgetQueryBase = supabase
          .from('budgets')
          .select('id,total_budget_cents,household_id,user_id,currency')
          .eq('currency', selectedCurrency);

      final scopedBudgetQuery = _applyAccountScopeFilter(
        budgetQueryBase,
        authUser.uid,
        scope: scopeType,
        householdId: householdId,
      );

      final budgetRowQuery = scopedBudgetQuery.eq('period_month', periodMonth);

      Map<String, dynamic>? budgetRow = await budgetRowQuery.maybeSingle();

      // If no budget was found with the selected currency, fall back to any
      // budget for this scope/month (unique constraint is on scope+period).
      if (budgetRow == null && !hasExplicitCurrency) {
        var fallbackBudgetQuery = supabase
            .from('budgets')
            .select('id,total_budget_cents,household_id,user_id,currency')
            .eq('period_month', periodMonth);

        fallbackBudgetQuery = _applyAccountScopeFilter(
          fallbackBudgetQuery,
          authUser.uid,
          scope: scopeType,
          householdId: householdId,
        );

        budgetRow = await fallbackBudgetQuery.limit(1).maybeSingle();

        // As a last resort (legacy rows missing user_id), try any personal row for the period.
        if (budgetRow == null && scopeType == PocketsScopeType.personal) {
          budgetRow = await _findBudgetRowForPeriod(
            periodMonth: periodMonth,
            isHousehold: false,
            householdId: null,
            userId: authUser.uid,
            allowAnyUser: true,
          );
          if (budgetRow != null) {
            _debugLog(
                '[Pockets] Found legacy personal budget without user filter for period $periodMonth');
          }
        }

        if (budgetRow != null) {
          final reusedCurrency =
              (budgetRow['currency'] as String?)?.toUpperCase();
          if (reusedCurrency != null &&
              reusedCurrency.isNotEmpty &&
              reusedCurrency != selectedCurrency) {
            _debugLog(
                '[Pockets] Reused existing budget with currency $reusedCurrency for period $periodMonth (was requesting $selectedCurrency)');
            selectedCurrency = reusedCurrency;
          } else if (reusedCurrency != null) {
            // Keep selectedCurrency in sync with the budget row even if they match,
            // to avoid any casing inconsistencies.
            selectedCurrency = reusedCurrency;
          }
        }
      }

      double previousBudget = 0;
      if (budgetRow == null) {
        // Check most recent previous budget for a reuse suggestion
        final previousBudgetRow = await scopedBudgetQuery
            .lt('period_month', periodMonth)
            .order('period_month', ascending: false)
            .limit(1)
            .maybeSingle();
        previousBudget =
            ((previousBudgetRow?['total_budget_cents'] as num?)?.toDouble() ??
                    0.0) /
                100.0;
      }

      if (budgetRow == null) {
        final insertPayload = <String, dynamic>{
          'user_id': authUser.uid,
          'household_id':
              (scopeType == PocketsScopeType.personal) ? null : householdId,
          'currency': selectedCurrency,
          'period_month': periodMonth,
          'total_budget_cents': 0,
          'updated_at': DateTime.now().toIso8601String(),
        };

        budgetRow = await supabase
            .from('budgets')
            .upsert(insertPayload)
            .select('id,total_budget_cents')
            .maybeSingle();
      }

      final budgetId = budgetRow?['id'] as String?;
      final totalBudget =
          ((budgetRow?['total_budget_cents'] as num?)?.toDouble() ?? 0) / 100.0;

      var baseQuery = supabase
          .from('budget_envelopes')
          .select(
              'id,name,budget_percentage,household_id,currency,icon,color,budget_id')
          .eq('currency', selectedCurrency);

      baseQuery = _applyAccountScopeFilter(
        baseQuery,
        authUser.uid,
        scope: scopeType,
        householdId: householdId,
      );

      final envelopesRes = (budgetId != null
              ? baseQuery.eq('budget_id', budgetId)
              : (isHousehold
                  ? baseQuery.eq('household_id', householdId!)
                  : (isPortfolio
                      ? _applyAccountScopeFilter(
                          supabase
                              .from('budget_envelopes')
                              .select(
                                  'id,name,budget_percentage,household_id,currency,icon,color,budget_id')
                              .eq('currency', selectedCurrency),
                          authUser.uid,
                          scope: scopeType,
                          householdId: householdId,
                        )
                      : _applyAccountScopeFilter(
                          supabase
                              .from('budget_envelopes')
                              .select(
                                  'id,name,budget_percentage,household_id,currency,icon,color,budget_id')
                              .eq('currency', selectedCurrency),
                          authUser.uid,
                          scope: scopeType,
                          householdId: householdId))))
          .order('name');

      final envelopes = await envelopesRes;

      var envRows = (envelopes as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (envRows.isEmpty && budgetId != null) {
        // Legacy rows without budget_id: attach them to the current budget
        final legacyRes = await (scopeType == PocketsScopeType.personal
                ? baseQuery.isFilter('household_id', null)
                : baseQuery.eq('household_id', householdId!))
            .isFilter('budget_id', null)
            .order('name');

        envRows = (legacyRes as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final row in envRows) {
          final legacyId = row['id'] as String?;
          if (legacyId != null) {
            await supabase.from('budget_envelopes').update({
              'budget_id': budgetId,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', legacyId);
          }
        }
      }
      if (envRows.isEmpty) {
        if (!mounted) return;
        state = PocketsState(
          isLoading: false,
          error: null,
          saved: const [],
          editing: const [],
          budgetId: budgetId,
          periodMonth: monthStart,
          previousBudget: previousBudget,
          totalBudget: totalBudget,
          savedTotalBudget: totalBudget,
          unallocatedSpend: 0,
          uncategorized: const [],
          uncategorizedExpenses: const {},
        );
        return;
      }

      final envIds = envRows.map((e) => e['id'] as String).toList();

      // Fetch category links for all envelopes
      final categoryLinksRes = await supabase
          .from('envelope_category_links')
          .select('envelope_id, category')
          .inFilter('envelope_id', envIds);
      final categoryLinksRows =
          (categoryLinksRes as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Fetch fixed allocations for the viewed month (optional per envelope)
      final allocationsRes = await supabase
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

      final categoriesByEnvelopeId = <String, List<String>>{};
      for (final row in categoryLinksRows) {
        final envId = row['envelope_id'] as String;
        final category = (row['category'] as String).toLowerCase();
        categoriesByEnvelopeId.putIfAbsent(envId, () => []).add(category);
      }

      // Fetch all expenses for this month and scope
      var expenseQuery = supabase
          .from('expenses')
          .select('amount_cents,category,type,household_id,currency,date')
          .eq('currency', selectedCurrency)
          .gte('date', monthStart.toIso8601String())
          .lt('date', monthEnd.toIso8601String());

      if (isHousehold) {
        // In household mode, fetch ALL expenses for the household regardless of user
        expenseQuery = expenseQuery.eq('household_id', householdId!);
      } else {
        expenseQuery = _applyAccountScopeFilter(
          expenseQuery,
          authUser.uid,
          scope: scopeType,
          householdId: householdId,
        );
      }

      final expensesRes = await expenseQuery;
      final expensesRows =
          (expensesRes as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Calculate spent per envelope by filtering expenses by category
      final spentById = <String, double>{};
      for (final envId in envIds) {
        final categories = categoriesByEnvelopeId[envId] ?? [];
        if (categories.isEmpty) {
          spentById[envId] = 0.0;
          continue;
        }

        double totalSpent = 0.0;
        for (final expense in expensesRows) {
          final type = (expense['type'] as String?)?.toLowerCase();
          if (type == 'income') continue;

          final expenseCategory =
              (expense['category'] as String? ?? '').toLowerCase();
          if (categories.contains(expenseCategory)) {
            final cents = (expense['amount_cents'] as num?)?.toDouble() ?? 0;
            totalSpent += cents / 100.0;
          }
        }
        spentById[envId] = totalSpent;
      }

      final pockets = envRows.map((row) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '';
        final percentage =
            (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
        final spent = spentById[id] ?? 0;
        final hhId = row['household_id'] as String?;
        final currency = row['currency'] as String? ?? selectedCurrency;

        // Icon can be stored as an int codepoint or a string name in the DB.
        // Use toString() to preserve whatever value is present instead of
        // dropping non-string types to null via a failed cast.
        final dynamic rawIcon = row['icon'];
        final String? icon = rawIcon?.toString();

        final color = row['color'] as String?;
        final bId = row['budget_id'] as String? ?? budgetId;

        return PocketEnvelope(
          id: id,
          name: name,
          percentage: percentage,
          spent: spent,
          currency: currency,
          icon: icon,
          color: color,
          budgetId: bId,
          householdId: hhId,
          allocationCents: allocationCentsByEnvelopeId[id],
          lastUpdated: DateTime.now(),
        );
      }).toList();

      final normalizedPockets = _applyEffectiveLimits(
        _normalizeToHundred(pockets),
        totalBudgetCents: (budgetRow?['total_budget_cents'] as num?)?.toInt() ??
            (totalBudget * 100).round(),
      );

      // Use the already-fetched expenses to compute uncategorized totals
      final expenseTotalsByCategory = <String, double>{};
      final uncategorizedExpensesMap = <String, List<Map<String, dynamic>>>{};
      var totalMonthlySpend = 0.0;
      for (final row in expensesRows) {
        final type = (row['type'] as String?)?.toLowerCase();
        if (type == 'income') continue; // ignore incomes
        final cents = (row['amount_cents'] as num?)?.toDouble() ?? 0;
        final amount = cents / 100.0;
        totalMonthlySpend += amount;
        final rawCategory =
            (row['category'] as String? ?? 'uncategorized').toLowerCase();
        expenseTotalsByCategory.update(
          rawCategory,
          (v) => v + amount,
          ifAbsent: () => amount,
        );
      }

      // Use the already-fetched category links to determine linked categories
      final linkedCategories = categoryLinksRows
          .map((r) => (r['category'] as String?)?.toLowerCase() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();

      final uncategorized = <UncategorizedCategory>[];
      expenseTotalsByCategory.forEach((cat, amount) {
        if (!linkedCategories.contains(cat)) {
          uncategorized.add(UncategorizedCategory(
            category: cat.isEmpty ? 'uncategorized' : cat,
            amount: amount,
          ));
          final key = cat.isEmpty ? 'uncategorized' : cat;
          final matches = expensesRows.where((row) {
            final rowCat =
                (row['category'] as String? ?? 'uncategorized').toLowerCase();
            return rowCat == cat;
          });
          for (final m in matches) {
            uncategorizedExpensesMap
                .putIfAbsent(key, () => <Map<String, dynamic>>[])
                .add(m);
          }
        }
      });

      final totalEnvelopeSpend =
          normalizedPockets.fold<double>(0, (sum, p) => sum + p.spent);

      final unallocatedSpend =
          math.max(0.0, totalMonthlySpend - totalEnvelopeSpend);

      if (!mounted) return;
      state = PocketsState(
        isLoading: false,
        error: null,
        saved: normalizedPockets,
        editing: normalizedPockets.map((p) => p.copyWith()).toList(),
        budgetId: budgetId,
        periodMonth: monthStart,
        previousBudget: previousBudget,
        totalBudget: totalBudget,
        savedTotalBudget: totalBudget, // Initialize saved budget
        unallocatedSpend: unallocatedSpend,
        uncategorized: uncategorized,
        uncategorizedExpenses: uncategorizedExpensesMap,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update total budget - percentages stay the same!
  void updateTotalBudget(double newTotal) {
    if (newTotal < 0) return;
    _debugLog(
        'updateTotalBudget: $newTotal (saved: ${state.savedTotalBudget})');
    final totalBudgetCents = (newTotal * 100).round();
    state = state.copyWith(
      totalBudget: newTotal,
      saved: _applyEffectiveLimits(
        state.saved,
        totalBudgetCents: totalBudgetCents,
      ),
      editing: _applyEffectiveLimits(
        state.editing,
        totalBudgetCents: totalBudgetCents,
      ),
    );
    _debugLog('After update - hasChanges: ${state.hasChanges}');
  }

  /// Update a pocket's percentage allocation
  /// Redistributes the difference proportionally to other pockets
  void updatePocketPercentage(String id, double newPercentage) {
    if (state.editing.isEmpty) return;

    final pockets = [...state.editing];
    final index = pockets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    // Clamp to 0-100
    newPercentage = newPercentage.clamp(0.0, 100.0);

    final currentPercentage = pockets[index].percentage;
    if (currentPercentage == newPercentage) return;

    final delta = newPercentage - currentPercentage;

    // If there's only one pocket, just set it to 100%
    if (pockets.length == 1) {
      pockets[0] = pockets[0].copyWith(percentage: 100.0);
      state = state.copyWith(editing: pockets);
      return;
    }

    // Update the target pocket
    pockets[index] = pockets[index].copyWith(percentage: newPercentage);

    // Calculate sum of other pockets' percentages
    var sumOther = 0.0;
    for (var i = 0; i < pockets.length; i++) {
      if (i != index) sumOther += pockets[i].percentage;
    }

    // Redistribute -delta to other pockets proportionally
    if (sumOther > 0) {
      for (var i = 0; i < pockets.length; i++) {
        if (i != index) {
          final ratio = pockets[i].percentage / sumOther;
          final adjustment = -delta * ratio;
          var newPct = pockets[i].percentage + adjustment;
          // Ensure non-negative
          newPct = math.max(0.0, newPct);
          pockets[i] = pockets[i].copyWith(percentage: newPct);
        }
      }
    } else {
      // All other pockets are 0, distribute remaining equally
      final remaining = 100.0 - newPercentage;
      final othersCount = pockets.length - 1;
      if (othersCount > 0) {
        final perPocket = remaining / othersCount;
        for (var i = 0; i < pockets.length; i++) {
          if (i != index) {
            pockets[i] = pockets[i].copyWith(percentage: perPocket);
          }
        }
      }
    }

    // Normalize to ensure sum = 100
    _normalizePercentages(pockets, index);

    state = state.copyWith(
      editing: _applyEffectiveLimits(
        pockets,
        totalBudgetCents: (state.totalBudget * 100).round(),
      ),
    );
  }

  void reusePreviousBudget(double amount) {
    if (amount <= 0) return;
    state = state.copyWith(totalBudget: amount);
  }

  Future<void> copyPocketsFromMonth(DateTime sourceMonth) async {
    if (state.isLoading) return;
    if (state.editing.isNotEmpty) return;

    final authUser = ref.read(authProvider);
    if (authUser.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    final filter = ref.read(homeFilterProvider);
    final analytics = ref.read(analyticsProvider);
    final selectedCurrency = (filter.selectedCurrency?.toUpperCase() ??
            analytics.preferredCurrency?.toUpperCase() ??
            'USD')
        .toUpperCase();

    final scopeType = params.scope;
    final isScopedToHousehold = scopeType != PocketsScopeType.personal;
    final householdId = params.householdId;

    if (isScopedToHousehold && householdId == null) {
      if (!mounted) return;
      state = state.copyWith(error: 'No household selected');
      return;
    }

    final currentBudgetId = state.budgetId;
    if (currentBudgetId == null || currentBudgetId.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(error: 'Missing current month budget');
      return;
    }

    final sourceMonthStart = DateTime(sourceMonth.year, sourceMonth.month, 1);
    final sourcePeriodMonth = _formatDate(sourceMonthStart);

    final targetMonth = params.periodMonth ?? DateTime.now();
    final targetMonthStart = DateTime(targetMonth.year, targetMonth.month, 1);
    final targetPeriodMonth = _formatDate(targetMonthStart);

    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final baseBudgetQuery = supabase
          .from('budgets')
          .select('id')
          .eq('period_month', sourcePeriodMonth)
          .eq('currency', selectedCurrency);

      final scopedBudgetQuery = _applyAccountScopeFilter(
        baseBudgetQuery,
        authUser.uid,
        scope: scopeType,
        householdId: householdId,
      );

      final sourceBudgetRow = await scopedBudgetQuery.maybeSingle();
      final sourceBudgetId = sourceBudgetRow?['id'] as String?;
      if (sourceBudgetId == null || sourceBudgetId.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: 'No pockets found for the previous month',
        );
        return;
      }

      // Fetch envelopes for the previous month budget
      var envelopesQuery = supabase
          .from('budget_envelopes')
          .select('id,name,budget_percentage,color,icon')
          .eq('currency', selectedCurrency)
          .eq('budget_id', sourceBudgetId);

      envelopesQuery = _applyAccountScopeFilter(
        envelopesQuery,
        authUser.uid,
        scope: scopeType,
        householdId: householdId,
      );

      final envelopesRes = await envelopesQuery.order('name');
      final envRows =
          (envelopesRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (envRows.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: 'No pockets found for the previous month',
        );
        return;
      }

      final sourceEnvIds = envRows
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();

      // Optional fixed allocations for the source month.
      final allocationsRes = await supabase
          .from('envelope_allocations')
          .select('envelope_id,amount_cents')
          .eq('period_month', sourcePeriodMonth)
          .inFilter('envelope_id', sourceEnvIds);
      final allocationsRows =
          (allocationsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      final allocationBySourceEnvId = <String, int>{
        for (final row in allocationsRows)
          if ((row['envelope_id'] as String?) != null)
            (row['envelope_id'] as String):
                (row['amount_cents'] as num?)?.toInt() ?? 0,
      };

      final categoryLinksRes = await supabase
          .from('envelope_category_links')
          .select('envelope_id,category')
          .inFilter('envelope_id', sourceEnvIds);

      final categoryLinksRows =
          (categoryLinksRes as List?)?.cast<Map<String, dynamic>>() ?? [];

      final categoriesByEnvelopeId = <String, List<String>>{};
      for (final row in categoryLinksRows) {
        final envId = row['envelope_id'] as String?;
        final category = (row['category'] as String?)?.toLowerCase().trim();
        if (envId == null || envId.isEmpty) continue;
        if (category == null || category.isEmpty) continue;
        categoriesByEnvelopeId
            .putIfAbsent(envId, () => <String>[])
            .add(category);
      }

      final linksPayload = <Map<String, dynamic>>[];
      for (final row in envRows) {
        final sourceEnvId = row['id'] as String?;
        if (sourceEnvId == null || sourceEnvId.isEmpty) continue;

        final name = row['name'] as String? ?? '';
        final pct = (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
        final color = row['color'] as String?;
        final dynamic rawIcon = row['icon'];
        final String? icon = rawIcon?.toString();

        final insertRes = await supabase
            .from('budget_envelopes')
            .insert(<String, dynamic>{
              'user_id': authUser.uid,
              'budget_id': currentBudgetId,
              'name': name,
              'budget_percentage': pct,
              'household_id':
                  scopeType == PocketsScopeType.personal ? null : householdId,
              'currency': selectedCurrency,
              'color': color,
              'icon': icon,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .maybeSingle();

        final newEnvId = insertRes?['id'] as String?;
        if (newEnvId == null || newEnvId.isEmpty) {
          throw Exception('Failed to copy pocket: $name');
        }

        final sourceAmountCents = allocationBySourceEnvId[sourceEnvId];
        if (sourceAmountCents != null && sourceAmountCents > 0) {
          await supabase.from('envelope_allocations').upsert(
            <String, dynamic>{
              'envelope_id': newEnvId,
              'period_month': targetPeriodMonth,
              'amount_cents': sourceAmountCents,
              'carryover_policy': 'carryover',
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'envelope_id,period_month',
          );
        }

        final categories = categoriesByEnvelopeId[sourceEnvId] ?? const [];
        for (final cat in categories) {
          linksPayload.add(<String, dynamic>{
            'envelope_id': newEnvId,
            'category': cat,
          });
        }
      }

      if (linksPayload.isNotEmpty) {
        await supabase.from('envelope_category_links').insert(linksPayload);
      }

      await _load();

      // Refresh analytics + widgets so other surfaces reflect the copied pockets.
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Ensure all percentages sum to exactly 100
  /// Adjusts other pockets (not the one at excludeIndex) to make up the difference
  void _normalizePercentages(List<PocketEnvelope> pockets, int excludeIndex) {
    var total = pockets.fold<double>(0, (sum, p) => sum + p.percentage);
    var error = 100.0 - total;

    if (error.abs() < _pctStep) return; // Close enough

    // Distribute error to pockets other than excludeIndex
    // Prioritize largest pockets to minimize relative impact
    final indices = List.generate(pockets.length, (i) => i)
        .where((i) => i != excludeIndex)
        .toList();
    indices
        .sort((a, b) => pockets[b].percentage.compareTo(pockets[a].percentage));

    for (final i in indices) {
      if (error.abs() < _pctStep) break;

      final adjustment = error > 0 ? _pctStep : -_pctStep;
      final newPct = pockets[i].percentage + adjustment;

      if (newPct >= 0 && newPct <= 100) {
        pockets[i] = pockets[i].copyWith(percentage: newPct);
        error -= adjustment;
      }
    }
  }

  static const int _pctPrecision = 4;
  static const double _pctStep = 0.0001;
  static const double _pctEpsilon = 0.000001;

  /// Returns a new list normalized so percentages sum to at most 100.
  /// We only scale down when totals exceed 100; otherwise we preserve
  /// user-entered allocations (allowing unallocated budget).
  List<PocketEnvelope> _normalizeToHundred(List<PocketEnvelope> pockets) {
    if (pockets.isEmpty) return [];

    // Clamp individual percentages to valid range
    final clamped = pockets
        .map((p) => p.copyWith(
              percentage: p.percentage.clamp(0.0, 100.0),
            ))
        .toList();

    final total = clamped.fold<double>(0, (sum, p) => sum + p.percentage);
    if (total <= 0) {
      // Keep behavior of distributing evenly when all zero to avoid a stuck UI,
      // but maintain high precision for large budgets.
      final even = 100.0 / clamped.length;
      return clamped.asMap().entries.map((entry) {
        final isLast = entry.key == pockets.length - 1;
        final pct = isLast ? 100 - even * (pockets.length - 1) : even;
        return entry.value.copyWith(
          percentage: double.parse(pct.toStringAsFixed(_pctPrecision)),
        );
      }).toList();
    }

    // If total is already <= 100 (with tiny epsilon), preserve allocations
    if (total <= 100.0 + _pctEpsilon) {
      // If we're very close to 100, snap the last item to eliminate rounding noise
      if ((100.0 - total).abs() <= _pctEpsilon && clamped.length > 1) {
        var remaining = 100.0;
        final snapped = <PocketEnvelope>[];
        for (var i = 0; i < clamped.length; i++) {
          final p = clamped[i];
          final pct = i == clamped.length - 1
              ? remaining
              : double.parse(p.percentage.toStringAsFixed(_pctPrecision));
          remaining =
              double.parse((remaining - pct).toStringAsFixed(_pctPrecision));
          snapped.add(p.copyWith(percentage: pct));
        }
        return snapped;
      }
      return clamped;
    }

    final factor = 100.0 / total;
    var remaining = 100.0;
    final normalized = <PocketEnvelope>[];
    for (var i = 0; i < clamped.length; i++) {
      final p = clamped[i];
      final scaled = (p.percentage * factor).clamp(0.0, 100.0);
      final pct = i == pockets.length - 1
          ? remaining
          : double.parse(scaled.toStringAsFixed(_pctPrecision));
      remaining =
          double.parse((remaining - pct).toStringAsFixed(_pctPrecision));
      normalized.add(p.copyWith(percentage: pct));
    }
    return normalized;
  }

  List<PocketEnvelope> _applyEffectiveLimits(
    List<PocketEnvelope> pockets, {
    required int totalBudgetCents,
  }) {
    if (pockets.isEmpty) return pockets;

    final fixed = <PocketEnvelope>[];
    final percent = <PocketEnvelope>[];

    for (final p in pockets) {
      if (p.allocationCents != null) {
        fixed.add(p);
      } else {
        percent.add(p);
      }
    }

    final fixedSum = fixed.fold<int>(
      0,
      (sum, p) => sum + (p.allocationCents ?? 0),
    );

    final remaining = math.max(0, totalBudgetCents - fixedSum);

    final weights = <String, int>{};
    var weightSum = 0;
    for (final p in percent) {
      // 1/10,000ths of a percent (0.0001%).
      final ppm = (p.percentage * 10000).round().clamp(0, 100 * 10000);
      weights[p.id] = ppm;
      weightSum += ppm;
    }

    final baseCents = <String, int>{};
    final remainders = <String, int>{};
    var distributed = 0;
    if (weightSum > 0 && remaining > 0) {
      for (final p in percent) {
        final w = weights[p.id] ?? 0;
        final numerator = remaining * w;
        final base = numerator ~/ weightSum;
        final rem = numerator % weightSum;
        baseCents[p.id] = base;
        remainders[p.id] = rem;
        distributed += base;
      }
    } else {
      for (final p in percent) {
        baseCents[p.id] = 0;
        remainders[p.id] = 0;
      }
    }

    var leftover = remaining - distributed;
    if (leftover > 0) {
      final idsByRemainder = [...percent.map((p) => p.id)];
      idsByRemainder.sort(
        (a, b) => (remainders[b] ?? 0).compareTo(remainders[a] ?? 0),
      );
      var i = 0;
      while (leftover > 0 && idsByRemainder.isNotEmpty) {
        final id = idsByRemainder[i % idsByRemainder.length];
        baseCents[id] = (baseCents[id] ?? 0) + 1;
        leftover -= 1;
        i += 1;
      }
    }

    return pockets.map((p) {
      final int effective;
      if (p.allocationCents != null) {
        effective = p.allocationCents!;
      } else {
        effective = baseCents[p.id] ?? 0;
      }
      return p.copyWith(effectiveLimitCents: effective);
    }).toList(growable: false);
  }

  Future<void> revertChanges() async {
    if (!mounted) return;
    final restored = state.saved.map((p) => p.copyWith()).toList();
    _debugLog(
        'revertChanges: restoring budget from ${state.totalBudget} to ${state.savedTotalBudget}');
    state = state.copyWith(
      editing: restored,
      totalBudget: state.savedTotalBudget, // Restore original budget
      clearError: true,
    );
  }

  Future<Map<String, dynamic>?> _findBudgetRowForPeriod({
    required String periodMonth,
    required bool isHousehold,
    required String? householdId,
    required String userId,
    String? currency,
    bool allowAnyUser = false,
  }) async {
    var query = supabase
        .from('budgets')
        .select('id,total_budget_cents,household_id,user_id,currency')
        .eq('period_month', periodMonth);

    if (currency != null) {
      query = query.eq('currency', currency);
    }

    if (isHousehold) {
      query = query.eq('household_id', householdId!);
    } else {
      query = _applyAccountScopeFilter(
        query,
        userId,
        scope: params.scope,
        householdId: params.householdId,
      );
    }

    return query.limit(1).maybeSingle();
  }

  bool _isConflictError(Object error) {
    if (error is PostgrestException) {
      return error.code == '23505' || error.code == '409';
    }
    return false;
  }

  Future<void> saveChanges() async {
    if (!mounted) return;
    if (!state.hasChanges) return;
    try {
      final normalizedEditing = _normalizeToHundred(state.editing);
      if (!mounted) return;
      state = state.copyWith(editing: normalizedEditing);

      final authUser = ref.read(authProvider);
      final filter = ref.read(homeFilterProvider);
      final analytics = ref.read(analyticsProvider);
      final selectedCurrency = (filter.selectedCurrency?.toUpperCase() ??
              analytics.preferredCurrency?.toUpperCase() ??
              'USD')
          .toUpperCase();
      // Persist against the month being viewed, not the global filter window
      final viewedMonth = params.periodMonth ?? DateTime.now();
      final monthStart = DateTime(viewedMonth.year, viewedMonth.month, 1);
      final periodMonth = _formatDate(monthStart);
      final scopeType = params.scope;
      final isHousehold = scopeType == PocketsScopeType.household;
      final isScopedToHousehold = scopeType != PocketsScopeType.personal;
      final householdId = params.householdId;

      if (isScopedToHousehold && householdId == null) {
        throw Exception('No household selected for scoped budget save');
      }

      // Persist/update the parent budget first
      final nowIso = DateTime.now().toIso8601String();
      final budgetPayload = <String, dynamic>{
        'user_id': authUser.uid,
        'household_id': isScopedToHousehold ? householdId : null,
        'currency': selectedCurrency,
        'period_month': periodMonth,
        'total_budget_cents': (state.totalBudget * 100).round(),
        'updated_at': nowIso,
      };
      if (state.budgetId != null) {
        budgetPayload['id'] = state.budgetId;
      }

      String? budgetId = state.budgetId;

      // Re-resolve budget id in case state was stale (e.g., mode switch)
      if (budgetId == null) {
        final existing = await _findBudgetRowForPeriod(
          periodMonth: periodMonth,
          isHousehold: isHousehold,
          householdId: householdId,
          userId: authUser.uid,
          currency: null,
        );
        budgetId = existing?['id'] as String?;
        _debugLog(
            '[Pockets] saveChanges resolved existing budgetId: $budgetId');
      }

      // If still null, try legacy personal rows without user filter
      if (budgetId == null && scopeType == PocketsScopeType.personal) {
        final legacyRow = await _findBudgetRowForPeriod(
          periodMonth: periodMonth,
          isHousehold: false,
          householdId: null,
          userId: authUser.uid,
          allowAnyUser: true,
        );
        budgetId = legacyRow?['id'] as String?;
        if (budgetId != null) {
          _debugLog(
              '[Pockets] saveChanges found legacy personal budgetId: $budgetId');
        }
      }

      Future<String?> upsertBudget(String? existingId) async {
        try {
          if (existingId != null) {
            _debugLog(
                '[Pockets] Updating budget $existingId (scope: ${params.scope}, hh: $householdId, month: $periodMonth)');
            await supabase
                .from('budgets')
                .update(budgetPayload..['id'] = existingId)
                .eq('id', existingId);
            _debugLog('[Pockets] Persisted budgetId via update: $existingId');
            return existingId;
          }

          _debugLog(
              '[Pockets] Inserting budget (scope: ${params.scope}, hh: $householdId, month: $periodMonth)');
          final insertRes = await supabase
              .from('budgets')
              .insert(budgetPayload)
              .select('id')
              .maybeSingle();
          return insertRes?['id'] as String?;
        } catch (e) {
          if (_isConflictError(e)) {
            _debugLog(
                '[Pockets] budget upsert conflict, resolving existing row');
            // On conflict, re-query without currency filter; for personal allow legacy rows
            final fallbackRow = await _findBudgetRowForPeriod(
              periodMonth: periodMonth,
              isHousehold: isHousehold,
              householdId: householdId,
              userId: authUser.uid,
              allowAnyUser: scopeType == PocketsScopeType.personal,
            );
            final fallbackId = fallbackRow?['id'] as String?;
            if (fallbackId != null) {
              _debugLog(
                  '[Pockets] Retrying update using budgetId: $fallbackId');
              await supabase
                  .from('budgets')
                  .update(budgetPayload..['id'] = fallbackId)
                  .eq('id', fallbackId);
              return fallbackId;
            }
          }
          rethrow;
        }
      }

      budgetId = await upsertBudget(budgetId);
      _debugLog('[Pockets] Persisted budgetId after saveChanges: $budgetId');

      if (budgetId == null) {
        throw Exception('Unable to persist budget for this period');
      }

      final editing = state.editing;
      for (final p in editing) {
        await supabase.from('budget_envelopes').update(<String, dynamic>{
          'budget_percentage': p.percentage,
          'budget_id': budgetId,
          'household_id': isScopedToHousehold ? householdId : null,
          'currency': selectedCurrency,
          'updated_at': nowIso,
        }).eq('id', p.id);
      }

      // Reload from backend to ensure consistency
      await _load();

      // Also refresh analytics so widgets and summaries reflect updated
      // budgets and envelope allocations (used by WidgetSyncManager).
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);

      // Force widget sync so both budget and top-spending widgets
      // reflect the latest pocket configuration.
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createBudgetFromTemplate({
    required double totalBudget,
    required List<PocketTemplate> pockets,
  }) async {
    if (!mounted) return;

    final authUser = ref.read(authProvider);
    if (authUser.isEmpty) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final filter = ref.read(homeFilterProvider);
      final analytics = ref.read(analyticsProvider);
      final selectedCurrency = (filter.selectedCurrency?.toUpperCase() ??
              analytics.preferredCurrency?.toUpperCase() ??
              'USD')
          .toUpperCase();

      final viewedMonth = params.periodMonth ?? DateTime.now();
      final monthStart = DateTime(viewedMonth.year, viewedMonth.month, 1);
      final periodMonth = _formatDate(monthStart);

      final scopeType = params.scope;
      final isScopedToHousehold = scopeType != PocketsScopeType.personal;
      final householdId = params.householdId;

      if (isScopedToHousehold && householdId == null) {
        throw Exception('No household selected for scoped budget');
      }

      // 1. Upsert Budget
      final nowIso = DateTime.now().toIso8601String();
      final budgetPayload = <String, dynamic>{
        'user_id': authUser.uid,
        'household_id': isScopedToHousehold ? householdId : null,
        'currency': selectedCurrency,
        'period_month': periodMonth,
        'total_budget_cents': (totalBudget * 100).round(),
        'updated_at': nowIso,
      };

      // Check if we already have a budget ID in state or DB
      String? budgetId = state.budgetId;
      if (budgetId == null) {
        final existing = await _findBudgetRowForPeriod(
          periodMonth: periodMonth,
          isHousehold: isScopedToHousehold,
          householdId: householdId,
          userId: authUser.uid,
          currency: null,
        );
        budgetId = existing?['id'] as String?;
      }

      // Use upsert-like logic
      if (budgetId != null) {
        await supabase.from('budgets').update(budgetPayload).eq('id', budgetId);
      } else {
        final res = await supabase
            .from('budgets')
            .insert(budgetPayload)
            .select('id')
            .single();
        budgetId = res['id'] as String;
      }

      // 2. Create Pockets & Links
      final linksPayload = <Map<String, dynamic>>[];

      for (final template in pockets) {
        final insertRes = await supabase
            .from('budget_envelopes')
            .insert(<String, dynamic>{
              'user_id': authUser.uid,
              'budget_id': budgetId,
              'name': template.name,
              'budget_percentage': template.percentage *
                  100, // Convert 0.5 -> 50.0 for DB? Wait, existing logic uses 0-100 float?
              // Checking existing code: 'budget_percentage' seems to be stored as float 0-100 based on clamp(0.0, 100.0) in _normalizeToHundred
              // Yes, Line 545: (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
              // And Line 1178: 'budget_percentage': p.percentage
              // But my PocketTemplate uses 0.0-1.0 (e.g. 0.60).
              // So I must multiply by 100 here.
              'household_id': isScopedToHousehold ? householdId : null,
              'currency': selectedCurrency,
              'color': template.color != null
                  ? '#${template.color!.value.toRadixString(16).padLeft(8, '0').substring(2)}' // Simple hex
                  : null,
              'icon': template.iconName,
              'updated_at': nowIso,
            })
            .select('id')
            .single();

        final newEnvId = insertRes['id'] as String;

        // 3. Prepare Links
        for (final cat in template.suggestedCategories) {
          linksPayload.add({
            'envelope_id': newEnvId,
            'category': cat.toLowerCase(),
          });
        }
      }

      if (linksPayload.isNotEmpty) {
        await supabase.from('envelope_category_links').insert(linksPayload);
      }

      // 4. Refresh
      await _load();
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> assignCategoryToPocket(String pocketId, String category) async {
    try {
      await supabase.from('envelope_category_links').insert({
        'envelope_id': pocketId,
        'category': category.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _load();

      if (!mounted) return;

      // Re-sync widgets so envelope/category changes affect envelope
      // spending and top-spending breakdowns immediately.
      final authUser = ref.read(authProvider);
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }
}

final pocketsProvider = StateNotifierProvider.family<PocketsNotifier,
    PocketsState, PocketsScopeParams>((ref, params) {
  // Ensure we always have the latest selected household id when in household scope
  if (params.scope == PocketsScopeType.household &&
      params.householdId == null) {
    final selected = ref.read(selectedHouseholdProvider);
    return PocketsNotifier(
      ref,
      PocketsScopeParams(
        scope: PocketsScopeType.household,
        householdId: selected.householdId,
      ),
    );
  }
  return PocketsNotifier(ref, params);
});

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

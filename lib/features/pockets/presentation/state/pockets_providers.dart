import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

/// Scope for pockets: personal or household.
enum PocketsScopeType { personal, household }

class PocketsScopeParams {
  const PocketsScopeParams({
    required this.scope,
    this.householdId,
  });

  final PocketsScopeType scope;
  final String? householdId;

  @override
  bool operator ==(Object other) {
    return other is PocketsScopeParams &&
        other.scope == scope &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(scope, householdId);
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
      debugPrint(
          'hasChanges: true (budget changed from $savedTotalBudget to $totalBudget)');
      return true;
    }

    // Check if pockets have changed
    if (saved.length != editing.length) {
      debugPrint('hasChanges: true (pocket count changed)');
      return true;
    }
    for (var i = 0; i < saved.length; i++) {
      if (saved[i].id != editing[i].id ||
          saved[i].percentage != editing[i].percentage ||
          saved[i].spent != editing[i].spent) {
        debugPrint('hasChanges: true (pocket ${saved[i].name} changed)');
        return true;
      }
    }
    debugPrint('hasChanges: false');
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
    _load();
  }

  final Ref ref;
  final PocketsScopeParams params;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authUser = ref.read(authProvider);
      final filter = ref.read(homeFilterProvider);
      final selectedCurrency = filter.selectedCurrency ?? 'USD';
      final range = getDateRangeFromFilter(
        filter.dateRangeFilter,
        filter.customStartDate,
        filter.customEndDate,
      );

      final end = range['to'] ?? DateTime.now();
      final monthStart = DateTime(end.year, end.month, 1);
      final periodMonth = _formatDate(monthStart);
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

      final isHousehold = params.scope == PocketsScopeType.household;
      final householdId = params.householdId;

      if (isHousehold && householdId == null) {
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

      // Fetch or create budget for the current month/scope
      final budgetQuery = supabase
          .from('budgets')
          .select('id,total_budget_cents')
          .eq('user_id', authUser.uid)
          .eq('currency', selectedCurrency);

      final scopedBudgetQuery = isHousehold
          ? budgetQuery.eq('household_id', householdId!)
          : budgetQuery.isFilter('household_id', null);

      Map<String, dynamic>? budgetRow = await scopedBudgetQuery
          .eq('period_month', periodMonth)
          .maybeSingle();

      double previousBudget = 0;
      if (budgetRow == null) {
        // Check most recent previous budget for a reuse suggestion
        final previousBudgetRow = await scopedBudgetQuery
            .lt('period_month', periodMonth)
            .order('period_month', ascending: false)
            .limit(1)
            .maybeSingle();
        previousBudget = ((previousBudgetRow?['total_budget_cents'] as num?)
                    ?.toDouble() ??
                0.0) /
            100.0;
      }

      if (budgetRow == null) {
        final insertPayload = <String, dynamic>{
          'user_id': authUser.uid,
          'household_id': isHousehold ? householdId : null,
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

      final baseQuery = supabase
          .from('budget_envelopes')
          .select(
              'id,name,budget_percentage,household_id,currency,icon,color,budget_id')
          .eq('user_id', authUser.uid)
          .eq('currency', selectedCurrency);

      final envelopesRes = (budgetId != null
              ? baseQuery.eq('budget_id', budgetId)
              : (isHousehold
                  ? baseQuery.eq('household_id', householdId!)
                  : baseQuery.isFilter('household_id', null)))
          .order('name');

      final envelopes = await envelopesRes;

      var envRows = (envelopes as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (envRows.isEmpty && budgetId != null) {
        // Legacy rows without budget_id: attach them to the current budget
        final legacyRes = await (isHousehold
                ? baseQuery.eq('household_id', householdId!)
                : baseQuery.isFilter('household_id', null))
            .isFilter('budget_id', null)
            .order('name');

        envRows = (legacyRes as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final row in envRows) {
          final legacyId = row['id'] as String?;
          if (legacyId != null) {
            await supabase
                .from('budget_envelopes')
                .update({
                  'budget_id': budgetId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', legacyId);
          }
        }
      }
      if (envRows.isEmpty) {
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

      // Load monthly spend per envelope using the helper view
      final spendRes = await supabase
          .from('v_envelope_monthly_spend')
          .select('envelope_id, spent_cents')
          .inFilter('envelope_id', envIds)
          .eq('period_month', periodMonth);
      final spendRows = (spendRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      final spentById = <String, double>{};
      for (final row in spendRows) {
        final id = row['envelope_id'] as String;
        final cents = (row['spent_cents'] as num?)?.toDouble() ?? 0;
        spentById[id] = cents / 100.0;
      }

      final pockets = envRows.map((row) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '';
        final percentage =
            (row['budget_percentage'] as num?)?.toDouble() ?? 0.0;
        final spent = spentById[id] ?? 0;
        final hhId = row['household_id'] as String?;
        final currency = row['currency'] as String? ?? selectedCurrency;
        final icon = row['icon'] as String?;
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
          lastUpdated: DateTime.now(),
        );
      }).toList();

      final normalizedPockets = _normalizeToHundred(pockets);

      // Fetch expenses for this month and scope to compute uncategorized totals
      var expenseQuery = supabase
          .from('expenses')
          .select('amount_cents,category,type,household_id,currency,date')
          .eq('user_id', authUser.uid)
          .eq('currency', selectedCurrency)
          .gte('date', monthStart.toIso8601String())
          .lt('date', monthEnd.toIso8601String());

      if (isHousehold) {
        expenseQuery = expenseQuery.eq('household_id', householdId!);
      } else {
        expenseQuery = expenseQuery.isFilter('household_id', null);
      }

      final expensesRes = await expenseQuery;
      final expensesRows =
          (expensesRes as List?)?.cast<Map<String, dynamic>>() ?? [];

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

      // Fetch linked categories for loaded envelopes
      List<Map<String, dynamic>> linksRows = [];
      if (envIds.isNotEmpty) {
        final linksRes = await supabase
            .from('envelope_category_links')
            .select('envelope_id, category')
            .inFilter('envelope_id', envIds);
        linksRows = (linksRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      }

      final linkedCategories = linksRows
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update total budget - percentages stay the same!
  void updateTotalBudget(double newTotal) {
    if (newTotal < 0) return;
    debugPrint(
        'updateTotalBudget: $newTotal (saved: ${state.savedTotalBudget})');
    state = state.copyWith(totalBudget: newTotal);
    debugPrint('After update - hasChanges: ${state.hasChanges}');
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

    state = state.copyWith(editing: pockets);
  }

  void reusePreviousBudget(double amount) {
    if (amount <= 0) return;
    state = state.copyWith(totalBudget: amount);
  }

  /// Ensure all percentages sum to exactly 100
  /// Adjusts other pockets (not the one at excludeIndex) to make up the difference
  void _normalizePercentages(List<PocketEnvelope> pockets, int excludeIndex) {
    var total = pockets.fold<double>(0, (sum, p) => sum + p.percentage);
    var error = 100.0 - total;

    if (error.abs() < 0.01) return; // Close enough

    // Distribute error to pockets other than excludeIndex
    // Prioritize largest pockets to minimize relative impact
    final indices = List.generate(pockets.length, (i) => i)
        .where((i) => i != excludeIndex)
        .toList();
    indices
        .sort((a, b) => pockets[b].percentage.compareTo(pockets[a].percentage));

    for (final i in indices) {
      if (error.abs() < 0.01) break;

      final adjustment = error > 0 ? 0.01 : -0.01;
      final newPct = pockets[i].percentage + adjustment;

      if (newPct >= 0 && newPct <= 100) {
        pockets[i] = pockets[i].copyWith(percentage: newPct);
        error -= adjustment;
      }
    }
  }

  /// Returns a new list normalized so percentages sum to exactly 100.
  List<PocketEnvelope> _normalizeToHundred(List<PocketEnvelope> pockets) {
    if (pockets.isEmpty) return [];

    final total = pockets.fold<double>(0, (sum, p) => sum + p.percentage);
    if (total <= 0) {
      final even = 100.0 / pockets.length;
      return pockets
          .asMap()
          .entries
          .map((entry) {
            final isLast = entry.key == pockets.length - 1;
            final pct =
                isLast ? 100 - even * (pockets.length - 1) : even;
            return entry.value.copyWith(
              percentage: double.parse(pct.toStringAsFixed(2)),
            );
          })
          .toList();
    }

    final factor = 100.0 / total;
    var remaining = 100.0;
    final normalized = <PocketEnvelope>[];
    for (var i = 0; i < pockets.length; i++) {
      final p = pockets[i];
      final scaled = (p.percentage * factor).clamp(0.0, 100.0);
      final pct = i == pockets.length - 1
          ? remaining
          : double.parse(scaled.toStringAsFixed(2));
      remaining = double.parse((remaining - pct).toStringAsFixed(2));
      normalized.add(p.copyWith(percentage: pct));
    }
    return normalized;
  }

  Future<void> revertChanges() async {
    final restored = state.saved.map((p) => p.copyWith()).toList();
    debugPrint(
        'revertChanges: restoring budget from ${state.totalBudget} to ${state.savedTotalBudget}');
    state = state.copyWith(
      editing: restored,
      totalBudget: state.savedTotalBudget, // Restore original budget
      clearError: true,
    );
  }

  Future<void> saveChanges() async {
    if (!state.hasChanges) return;
    try {
      final normalizedEditing = _normalizeToHundred(state.editing);
      state = state.copyWith(editing: normalizedEditing);

      final authUser = ref.read(authProvider);
      final filter = ref.read(homeFilterProvider);
      final selectedCurrency = filter.selectedCurrency ?? 'USD';
      final range = getDateRangeFromFilter(
        filter.dateRangeFilter,
        filter.customStartDate,
        filter.customEndDate,
      );

      final end = range['to'] ?? DateTime.now();
      final monthStart = DateTime(end.year, end.month, 1);
      final periodMonth = _formatDate(monthStart);
      final isHousehold = params.scope == PocketsScopeType.household;
      final householdId = params.householdId;

      // Persist/update the parent budget first
      final nowIso = DateTime.now().toIso8601String();
      final budgetPayload = <String, dynamic>{
        'user_id': authUser.uid,
        'household_id': isHousehold ? householdId : null,
        'currency': selectedCurrency,
        'period_month': periodMonth,
        'total_budget_cents': (state.totalBudget * 100).round(),
        'updated_at': nowIso,
      };
      if (state.budgetId != null) {
        budgetPayload['id'] = state.budgetId;
      }

      final budgetRes = await supabase
          .from('budgets')
          .upsert(budgetPayload)
          .select('id')
          .maybeSingle();

      final budgetId =
          (budgetRes != null ? budgetRes['id'] as String? : state.budgetId) ??
              state.budgetId;

      if (budgetId == null) {
        throw Exception('Unable to persist budget for this period');
      }

      final editing = state.editing;
      for (final p in editing) {
        await supabase.from('budget_envelopes').update(<String, dynamic>{
          'budget_percentage': p.percentage,
          'budget_id': budgetId,
          'household_id': isHousehold ? householdId : null,
          'currency': selectedCurrency,
          'updated_at': nowIso,
        }).eq('id', p.id);
      }

      // Reload from backend to ensure consistency
      await _load();
    } catch (e) {
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

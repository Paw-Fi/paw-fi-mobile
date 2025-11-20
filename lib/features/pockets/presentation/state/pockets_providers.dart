import 'dart:math' as math;

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
    required this.totalBudget,
    required this.unallocatedSpend,
  });

  final bool isLoading;
  final String? error;
  final List<PocketEnvelope> saved;
  final List<PocketEnvelope> editing;
  final double totalBudget;
  final double unallocatedSpend;

  bool get hasChanges {
    if (saved.length != editing.length) return true;
    for (var i = 0; i < saved.length; i++) {
      if (saved[i].id != editing[i].id ||
          saved[i].percentage != editing[i].percentage ||
          saved[i].spent != editing[i].spent) {
        return true;
      }
    }
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
    double? totalBudget,
    double? unallocatedSpend,
    bool clearError = false,
  }) {
    return PocketsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
      editing: editing ?? this.editing,
      totalBudget: totalBudget ?? this.totalBudget,
      unallocatedSpend: unallocatedSpend ?? this.unallocatedSpend,
    );
  }

  factory PocketsState.initial() => const PocketsState(
        isLoading: true,
        error: null,
        saved: [],
        editing: [],
        totalBudget: 0,
        unallocatedSpend: 0,
      );
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

      final isHousehold = params.scope == PocketsScopeType.household;
      final householdId = params.householdId;

      final baseQuery = supabase
          .from('budget_envelopes')
          .select('id,name,budget_percentage,household_id,currency,icon,color')
          .eq('user_id', authUser.uid)
          .eq('currency', selectedCurrency);

      final envelopesRes = isHousehold
          ? (householdId == null
              ? <Map<String, dynamic>>[]
              : await baseQuery.eq('household_id', householdId).order('name'))
          : await baseQuery.isFilter('household_id', null).order('name');

      final envRows =
          (envelopesRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (envRows.isEmpty) {
        state = PocketsState(
          isLoading: false,
          error: null,
          saved: const [],
          editing: const [],
          totalBudget: 0,
          unallocatedSpend: 0,
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

        return PocketEnvelope(
          id: id,
          name: name,
          percentage: percentage,
          spent: spent,
          currency: currency,
          icon: icon,
          color: color,
          householdId: hhId,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      // Calculate total budget from user preferences or default
      // For now, we'll use a default or fetch from user settings
      // TODO: Store total budget in user preferences
      final totalBudget =
          1000.0; // Default, should be fetched from user settings

      final totalEnvelopeSpend =
          pockets.fold<double>(0, (sum, p) => sum + p.spent);

      // Fetch total monthly spend for the user to calculate unallocated
      final totalMonthlySpend =
          await supabase.rpc<num>('get_monthly_total_spend', params: {
        'p_user_id': authUser.uid,
        'p_currency': selectedCurrency,
        'p_month': periodMonth,
      }).then((val) => val.toDouble());

      final unallocatedSpend =
          math.max(0.0, totalMonthlySpend - totalEnvelopeSpend);

      state = PocketsState(
        isLoading: false,
        error: null,
        saved: pockets,
        editing: pockets.map((p) => p.copyWith()).toList(),
        totalBudget: totalBudget,
        unallocatedSpend: unallocatedSpend,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update total budget - percentages stay the same!
  void updateTotalBudget(double newTotal) {
    if (newTotal < 0) return;
    state = state.copyWith(totalBudget: newTotal);
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

  Future<void> revertChanges() async {
    final restored = state.saved.map((p) => p.copyWith()).toList();
    state = state.copyWith(
      editing: restored,
      clearError: true,
    );
  }

  Future<void> saveChanges() async {
    if (!state.hasChanges) return;
    try {
      final editing = state.editing;
      for (final p in editing) {
        await supabase.from('budget_envelopes').update(<String, dynamic>{
          'budget_percentage': p.percentage,
          'updated_at': DateTime.now().toIso8601String(),
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

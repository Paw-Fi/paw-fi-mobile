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
    required this.explicitIds,
    required this.totalBudget,
    required this.unallocatedSpend,
  });

  final bool isLoading;
  final String? error;
  final List<PocketEnvelope> saved;
  final List<PocketEnvelope> editing;
  final Set<String> explicitIds; // pockets directly adjusted by user
  final double totalBudget;
  final double unallocatedSpend;

  bool get hasChanges {
    if (saved.length != editing.length) return true;
    for (var i = 0; i < saved.length; i++) {
      if (saved[i].id != editing[i].id ||
          saved[i].limit != editing[i].limit ||
          saved[i].spent != editing[i].spent) {
        return true;
      }
    }
    return false;
  }

  double get totalSpent => editing.fold<double>(0, (sum, p) => sum + p.spent);

  PocketsState copyWith({
    bool? isLoading,
    String? error,
    List<PocketEnvelope>? saved,
    List<PocketEnvelope>? editing,
    Set<String>? explicitIds,
    double? totalBudget,
    double? unallocatedSpend,
    bool clearError = false,
  }) {
    return PocketsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
      editing: editing ?? this.editing,
      explicitIds: explicitIds ?? this.explicitIds,
      totalBudget: totalBudget ?? this.totalBudget,
      unallocatedSpend: unallocatedSpend ?? this.unallocatedSpend,
    );
  }

  factory PocketsState.initial() => const PocketsState(
        isLoading: true,
        error: null,
        saved: [],
        editing: [],
        explicitIds: {},
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
          .select('id,name,monthly_target_cents,household_id,currency')
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
          explicitIds: <String>{},
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
        final monthlyTargetCents =
            (row['monthly_target_cents'] as num?)?.toDouble() ?? 0;
        final limit = monthlyTargetCents / 100.0;
        final spent = spentById[id] ?? 0;
        final hhId = row['household_id'] as String?;
        final currency = row['currency'] as String? ?? selectedCurrency;

        return PocketEnvelope(
          id: id,
          name: name,
          limit: limit,
          spent: spent,
          currency: currency,
          householdId: hhId,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      final totalBudget = pockets.fold<double>(0, (sum, p) => sum + p.limit);
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
        explicitIds: <String>{},
        totalBudget: totalBudget,
        unallocatedSpend: unallocatedSpend,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updateTotalBudget(double newTotal) {
    if (newTotal <= 0 || state.editing.isEmpty) return;
    final oldTotal = state.totalBudget == 0 ? newTotal : state.totalBudget;
    final ratio = newTotal / oldTotal;
    final updated =
        state.editing.map((p) => p.copyWith(limit: p.limit * ratio)).toList();
    state = state.copyWith(
      editing: updated,
      totalBudget: newTotal,
    );
  }

  void updatePocketLimit(String id, double newLimit) {
    if (state.editing.isEmpty) return;

    final pockets = [...state.editing];
    final index = pockets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    newLimit = math.max(0, newLimit);

    final explicit = {...state.explicitIds}..add(id);

    pockets[index] = pockets[index].copyWith(limit: newLimit);

    final totalBudget = state.totalBudget;
    if (totalBudget <= 0) {
      final recalculatedTotal =
          pockets.fold<double>(0, (sum, p) => sum + p.limit);
      state = state.copyWith(
        editing: pockets,
        explicitIds: explicit,
        totalBudget: recalculatedTotal,
      );
      return;
    }

    final explicitTotal = pockets
        .where((p) => explicit.contains(p.id))
        .fold<double>(0, (sum, p) => sum + p.limit);

    var remaining = math.max(0, totalBudget - explicitTotal);

    final nonExplicitIndices = <int>[];
    for (var i = 0; i < pockets.length; i++) {
      if (!explicit.contains(pockets[i].id)) {
        nonExplicitIndices.add(i);
      }
    }

    if (nonExplicitIndices.isEmpty) {
      // All pockets are explicit; clamp the last edited pocket if overflow.
      if (explicitTotal > totalBudget) {
        final overflow = explicitTotal - totalBudget;
        final current = pockets[index].limit;
        pockets[index] =
            pockets[index].copyWith(limit: math.max(0, current - overflow));
      }
    } else {
      final perPocket = remaining / nonExplicitIndices.length;
      for (final i in nonExplicitIndices) {
        pockets[i] = pockets[i].copyWith(limit: perPocket);
      }
    }

    state = state.copyWith(
      editing: pockets,
      explicitIds: explicit,
    );
  }

  Future<void> revertChanges() async {
    final restored = state.saved.map((p) => p.copyWith()).toList();
    final totalBudget = restored.fold<double>(0, (sum, p) => sum + p.limit);
    state = state.copyWith(
      editing: restored,
      explicitIds: <String>{},
      totalBudget: totalBudget,
      clearError: true,
    );
  }

  Future<void> saveChanges() async {
    if (!state.hasChanges) return;
    try {
      final editing = state.editing;
      for (final p in editing) {
        final cents = (p.limit * 100).round();
        await supabase.from('budget_envelopes').update(<String, dynamic>{
          'monthly_target_cents': cents,
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

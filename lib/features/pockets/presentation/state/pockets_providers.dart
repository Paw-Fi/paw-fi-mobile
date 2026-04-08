import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

void _debugLog(String message) {
  if (foundation.kDebugMode) {
    foundation.debugPrint(message);
  }
}

// L1 in-memory month cache.
// - Keyed by (user, scope, month, currency) + a couple toggles that affect the
//   computed output.
// - TTL-based freshness with stale-while-revalidate refresh.
// - Explicit invalidation happens via provider disposal (ref.invalidate) and
//   a small set of global signals (auth/push refresh).
typedef _CacheKey = ({
  String userId,
  PocketsScopeType scope,
  String? householdId,
  String periodMonth,
  String currency,
  bool includeUpcomingRecurring,
  bool allowCurrencyFallback,
});

class _PocketsMonthCacheEntry {
  _PocketsMonthCacheEntry({
    required this.state,
    required this.fetchedAt,
    required this.lastAccessAt,
  });

  PocketsState state;
  DateTime fetchedAt;
  DateTime lastAccessAt;
  Future<PocketsState>? inFlight;
}

class _PocketsMonthCache {
  static const _maxEntries = 64;

  final _entries = <_CacheKey, _PocketsMonthCacheEntry>{};

  void clear() => _entries.clear();

  void invalidate(_CacheKey key) => _entries.remove(key);

  void invalidateUser(String userId) {
    if (userId.trim().isEmpty) return;
    _entries.removeWhere((key, _) => key.userId == userId);
  }

  PocketsState? getAny(_CacheKey key, DateTime now) {
    final entry = _entries[key];
    if (entry == null) return null;
    entry.lastAccessAt = now;
    return entry.state;
  }

  bool isFresh(_CacheKey key, DateTime now, DateTime monthStart) {
    final entry = _entries[key];
    if (entry == null) return false;
    return now.difference(entry.fetchedAt) <= _ttlFor(key, monthStart);
  }

  Future<PocketsState>? getInFlight(_CacheKey key) => _entries[key]?.inFlight;

  void setInFlight(_CacheKey key, Future<PocketsState> future, DateTime now) {
    final entry = _entries.putIfAbsent(
      key,
      () => _PocketsMonthCacheEntry(
        state: PocketsState.initial(),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastAccessAt: now,
      ),
    );
    entry.inFlight = future;
    entry.lastAccessAt = now;
  }

  void clearInFlight(_CacheKey key) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.inFlight = null;
  }

  void set(_CacheKey key, PocketsState state, DateTime now) {
    final entry = _entries.putIfAbsent(
      key,
      () => _PocketsMonthCacheEntry(
        state: state,
        fetchedAt: now,
        lastAccessAt: now,
      ),
    );

    entry.state = state;
    entry.fetchedAt = now;
    entry.lastAccessAt = now;
    entry.inFlight = null;

    _evictIfNeeded();
  }

  Duration _ttlFor(_CacheKey key, DateTime monthStart) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    if (monthStart.isAfter(currentMonthStart)) {
      return const Duration(seconds: 20);
    }

    if (monthStart == currentMonthStart) {
      if (key.includeUpcomingRecurring) {
        return const Duration(seconds: 15);
      }
      return const Duration(seconds: 45);
    }

    // Past months are generally stable.
    return const Duration(minutes: 30);
  }

  void _evictIfNeeded() {
    if (_entries.length <= _maxEntries) return;
    final entries = _entries.entries.toList(growable: false);
    entries
        .sort((a, b) => a.value.lastAccessAt.compareTo(b.value.lastAccessAt));

    final overflow = _entries.length - _maxEntries;
    for (var i = 0; i < overflow; i++) {
      _entries.remove(entries[i].key);
    }
  }
}

final _pocketsMonthCache = _PocketsMonthCache();

// Global cache invalidation hooks.
// We keep this provider separate so it can listen once per ProviderContainer.
final _pocketsMonthCacheInvalidationProvider = Provider<void>((ref) {
  // Clear all caches when auth user changes (login/logout).
  ref.listen(authProvider, (previous, next) {
    final prevId = previous?.uid ?? '';
    final nextId = next.uid;
    if (prevId != nextId) {
      _pocketsMonthCache.clear();
    }
  }, fireImmediately: true);

  // Invalidate caches when the active account scope changes (personal/portfolio/household)
  // or when household selection changes. Even though cache keys include these fields,
  // explicit invalidation keeps memory bounded and ensures we don't serve stale data
  // across account switches.
  ref.listen(viewModeProvider, (previous, next) {
    if (previous == null) return;
    if (previous.mode != next.mode) {
      final uid = ref.read(authProvider).uid;
      if (uid.isNotEmpty) {
        _pocketsMonthCache.invalidateUser(uid);
      } else {
        _pocketsMonthCache.clear();
      }
    }
  });

  ref.listen(selectedHouseholdProvider, (previous, next) {
    if (previous == null) return;
    final prevId = previous.householdId ?? previous.household?.id;
    final nextId = next.householdId ?? next.household?.id;
    if (prevId != nextId) {
      final uid = ref.read(authProvider).uid;
      if (uid.isNotEmpty) {
        _pocketsMonthCache.invalidateUser(uid);
      } else {
        _pocketsMonthCache.clear();
      }
    }
  });

  // Push-triggered refreshes (new transactions, sync, etc.).
  ref.listen(transactionsFeedRefreshSignalProvider, (previous, next) {
    if (previous == null) return;
    if (previous != next) {
      final uid = ref.read(authProvider).uid;
      if (uid.isNotEmpty) {
        _pocketsMonthCache.invalidateUser(uid);
      } else {
        _pocketsMonthCache.clear();
      }
    }
  });

  // UI-triggered refreshes (e.g., transaction saves) typically bump this.
  ref.listen(dashboardRefreshSignalProvider, (previous, next) {
    if (previous == null) return;
    if (previous != next) {
      final uid = ref.read(authProvider).uid;
      if (uid.isNotEmpty) {
        _pocketsMonthCache.invalidateUser(uid);
      } else {
        _pocketsMonthCache.clear();
      }
    }
  });
});

@foundation.visibleForTesting
String normalizePocketTemplateName(String name) => name.trim();

@foundation.visibleForTesting
List<Map<String, dynamic>> buildUniqueEnvelopeCategoryLinks({
  required String envelopeId,
  required List<String> categories,
}) {
  final seen = <String>{};
  final payload = <Map<String, dynamic>>[];

  for (final category in categories) {
    final normalized = category.toLowerCase().trim();
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    payload.add({
      'envelope_id': envelopeId,
      'category': normalized,
    });
  }

  return payload;
}

@foundation.visibleForTesting
List<Map<String, dynamic>> resolveEnvelopeRowsForViewedMonth({
  required String? budgetId,
  required List<Map<String, dynamic>> budgetBoundEnvelopeRows,
  required List<Map<String, dynamic>> legacyBudgetlessEnvelopeRows,
}) {
  final normalizedBudgetId = budgetId?.trim();
  if (normalizedBudgetId == null || normalizedBudgetId.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  if (budgetBoundEnvelopeRows.isNotEmpty) {
    return budgetBoundEnvelopeRows;
  }

  return legacyBudgetlessEnvelopeRows;
}

List<int> rebalancePocketBudgetAmounts({
  required List<int> currentAmountsCents,
  required int newTotalBudgetCents,
}) {
  if (currentAmountsCents.isEmpty) {
    return const <int>[];
  }

  final sanitizedTarget = math.max(0, newTotalBudgetCents);
  final sanitizedCurrent = currentAmountsCents
      .map((amount) => math.max(0, amount))
      .toList(growable: false);
  final currentTotal =
      sanitizedCurrent.fold<int>(0, (sum, amount) => sum + amount);

  if (sanitizedTarget == 0) {
    return List<int>.filled(sanitizedCurrent.length, 0, growable: false);
  }

  if (currentTotal == 0) {
    final baseShare = sanitizedTarget ~/ sanitizedCurrent.length;
    final remainder = sanitizedTarget % sanitizedCurrent.length;
    return List<int>.generate(
      sanitizedCurrent.length,
      (index) => baseShare + (index < remainder ? 1 : 0),
      growable: false,
    );
  }

  final scaled = <({int index, int floorAmount, double remainder})>[];
  var assigned = 0;

  for (var index = 0; index < sanitizedCurrent.length; index++) {
    final exact = sanitizedCurrent[index] * sanitizedTarget / currentTotal;
    final floorAmount = exact.floor();
    assigned += floorAmount;
    scaled.add((
      index: index,
      floorAmount: floorAmount,
      remainder: exact - floorAmount,
    ));
  }

  final result =
      scaled.map((entry) => entry.floorAmount).toList(growable: false);
  var remaining = sanitizedTarget - assigned;

  if (remaining > 0) {
    final byRemainder = [...scaled]..sort((a, b) {
        final compareRemainder = b.remainder.compareTo(a.remainder);
        if (compareRemainder != 0) return compareRemainder;
        return a.index.compareTo(b.index);
      });

    for (var i = 0; i < byRemainder.length && remaining > 0; i++) {
      result[byRemainder[i].index] += 1;
      remaining -= 1;
      if (i == byRemainder.length - 1 && remaining > 0) {
        i = -1;
      }
    }
  }

  return result;
}

List<int> rebalanceSiblingPocketBudgetAmounts({
  required List<int> siblingAmountsCents,
  required int targetPocketAmountCents,
  required int totalBudgetCents,
}) {
  if (siblingAmountsCents.isEmpty) {
    return const <int>[];
  }

  final sanitizedTotalBudget = math.max(0, totalBudgetCents);
  final sanitizedTargetPocketAmount =
      targetPocketAmountCents.clamp(0, sanitizedTotalBudget).toInt();
  final sanitizedSiblingAmounts = siblingAmountsCents
      .map((amount) => math.max(0, amount))
      .toList(growable: false);
  final remainingBudgetForSiblings =
      math.max(0, sanitizedTotalBudget - sanitizedTargetPocketAmount);

  return rebalancePocketBudgetAmounts(
    currentAmountsCents: sanitizedSiblingAmounts,
    newTotalBudgetCents: remainingBudgetForSiblings,
  );
}

@foundation.visibleForTesting
PocketsState applyRebalancedBudgetToPocketsState({
  required PocketsState state,
  required double newTotalBudget,
}) {
  final newTotalBudgetCents = (newTotalBudget * 100).round();
  final rebalancedAmounts = rebalancePocketBudgetAmounts(
    currentAmountsCents: state.editing
        .map((pocket) => pocket.budgetAmountCents)
        .toList(growable: false),
    newTotalBudgetCents: newTotalBudgetCents,
  );

  final rebalancedEditing = state.editing.isEmpty
      ? state.editing
      : List<PocketEnvelope>.generate(
          state.editing.length,
          (index) => state.editing[index].copyWith(
            budgetAmountCents: rebalancedAmounts[index],
          ),
          growable: false,
        );

  return state.copyWith(
    totalBudget: newTotalBudgetCents / 100.0,
    editing: rebalancedEditing,
  );
}

/// Scope for pockets: personal or household.
enum PocketsScopeType { personal, portfolio, household }

const includeUpcomingRecurringInPocketsPreferenceKey =
    'include_upcoming_recurring_in_pockets';
// CRITICAL: keep this default ON.
// STRICT REQUIREMENT: pockets must include upcoming recurring expenses by
// default. Reverting this to false hides scheduled bills from pocket spend
// until the user discovers the toggle, which repeatedly gets reported as a
// broken pockets calculation.
const defaultIncludeUpcomingRecurringInPockets = true;

// CRITICAL: this provider is the root recurring toggle for the pockets main
// page, pocket details, and recurring-aware month RPC requests.
// STRICT REQUIREMENT: keep this default-on unless the user explicitly opts
// out, or recurring transactions disappear from pocket calculations again.
final includeUpcomingRecurringInPocketsProvider =
    StateProvider<bool>((ref) => defaultIncludeUpcomingRecurringInPockets);

class PocketsScopeParams {
  const PocketsScopeParams({
    required this.scope,
    this.householdId,
    this.periodMonth,
    this.currency,
    this.isBootstrapCurrency = false,
    this.includeUpcomingRecurring = defaultIncludeUpcomingRecurringInPockets,
  });

  final PocketsScopeType scope;
  final String? householdId;
  final DateTime? periodMonth;
  final String? currency;
  final bool isBootstrapCurrency;
  // CRITICAL: carry this flag through every derived pocket scope.
  // STRICT REQUIREMENT: if a page/provider forgets to forward it, that viewed
  // month falls back to non-recurring pocket math and reintroduces the bug.
  final bool includeUpcomingRecurring;

  @override
  bool operator ==(Object other) {
    return other is PocketsScopeParams &&
        other.scope == scope &&
        other.householdId == householdId &&
        other.periodMonth == periodMonth &&
        other.currency == currency &&
        other.isBootstrapCurrency == isBootstrapCurrency &&
        other.includeUpcomingRecurring == includeUpcomingRecurring;
  }

  @override
  int get hashCode => Object.hash(scope, householdId, periodMonth, currency,
      isBootstrapCurrency, includeUpcomingRecurring);
}

Future<List<RecurringTransaction>> loadScopedRecurringTransactions({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  int limit = 250,
}) async {
  if (scope != PocketsScopeType.personal &&
      (householdId == null || householdId.trim().isEmpty)) {
    return const <RecurringTransaction>[];
  }

  dynamic scopedQuery = supabase
      .from('expenses')
      .select(_recurringExpensesSelectFields)
      .eq('is_recurring', true);

  switch (scope) {
    case PocketsScopeType.personal:
      scopedQuery =
          scopedQuery.eq('user_id', userId).isFilter('household_id', null);
      break;
    case PocketsScopeType.portfolio:
      scopedQuery =
          scopedQuery.eq('user_id', userId).eq('household_id', householdId!);
      break;
    case PocketsScopeType.household:
      scopedQuery = scopedQuery.eq('household_id', householdId!);
      break;
  }

  final rows = await scopedQuery.order('date', ascending: false).limit(limit);
  final enrichedRows = await _enrichRecurringRowsWithSplitPayer(
    rows: rows.cast<Map<String, dynamic>>(),
  );
  final transactions = <RecurringTransaction>[];

  for (final item in enrichedRows) {
    try {
      transactions.add(RecurringTransaction.fromJson(item));
    } catch (error) {
      _debugLog('[Pockets] Failed to parse recurring transaction: $error');
    }
  }

  return transactions;
}

// CRITICAL: keep account_id in this recurring select.
// STRICT REQUIREMENT: wallet-scoped recurring transactions cannot be attached
// back to the correct wallet without account_id, and removing it reintroduces
// the "wallet recurring transactions are missing" regression.
const _recurringExpensesSelectFields =
    'id, date, category, raw_text, breakdown, source, amount_cents, '
    'currency, owner_type, privacy_scope, household_id, is_recurring, '
    'user_id, split_group_id, account_id, recurrence_rule, type, '
    'attachments, created_at, updated_at';

Future<List<Map<String, dynamic>>> _enrichRecurringRowsWithSplitPayer({
  required List<Map<String, dynamic>> rows,
}) async {
  final splitGroupIds = rows
      .map((row) => row['split_group_id'] as String?)
      .where((splitGroupId) => splitGroupId != null && splitGroupId.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList(growable: false);

  if (splitGroupIds.isEmpty) {
    return rows;
  }

  try {
    final splitRows = await supabase
        .from('expense_split_groups')
        .select('id, payer_user_id')
        .inFilter('id', splitGroupIds);

    final splitPayerByGroupId = <String, String>{
      for (final row in splitRows.cast<Map<String, dynamic>>())
        if ((row['id'] as String?) != null &&
            (row['payer_user_id'] as String?) != null)
          (row['id'] as String): (row['payer_user_id'] as String),
    };

    return applySplitPayerToRecurringRows(
      rows: rows,
      splitPayerByGroupId: splitPayerByGroupId,
    );
  } catch (error) {
    _debugLog(
      '[Pockets] Failed to enrich recurring rows with split payer: $error',
    );
    return rows;
  }
}

@foundation.visibleForTesting
List<Map<String, dynamic>> applySplitPayerToRecurringRows({
  required List<Map<String, dynamic>> rows,
  required Map<String, String> splitPayerByGroupId,
}) {
  if (rows.isEmpty || splitPayerByGroupId.isEmpty) {
    return rows;
  }

  return rows.map((row) {
    final splitGroupId = row['split_group_id'] as String?;
    if (splitGroupId == null || splitGroupId.isEmpty) {
      return row;
    }

    final payerUserId = splitPayerByGroupId[splitGroupId];
    if (payerUserId == null || payerUserId.isEmpty) {
      return row;
    }

    final existingPayer = row['payer_user_id'] as String?;
    if (existingPayer != null && existingPayer.isNotEmpty) {
      return row;
    }

    return <String, dynamic>{
      ...row,
      'payer_user_id': payerUserId,
    };
  }).toList(growable: false);
}

Future<List<ExpenseEntry>> loadProjectedPocketMonthExpenses({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  required DateTime monthStart,
  required String selectedCurrency,
  required bool includeUpcomingRecurring,
  required List<ExpenseEntry> actualExpenses,
}) async {
  // CRITICAL: this projection is part of the pocket spend calculation for the
  // selected month, not only the current month.
  // STRICT REQUIREMENT: recurring schedules must be expanded month-by-month so
  // a rule anchored on April 1 still counts inside the April pocket even when
  // the user creates or edits that recurring transaction on April 3.
  if (!includeUpcomingRecurring) {
    return const <ExpenseEntry>[];
  }

  final recurringTransactions = await loadScopedRecurringTransactions(
    userId: userId,
    scope: scope,
    householdId: householdId,
  );
  if (recurringTransactions.isEmpty) {
    return const <ExpenseEntry>[];
  }

  final projectedExpenses =
      projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions
        .where((transaction) => transaction.type.toLowerCase() == 'expense')
        .toList(growable: false),
    // CRITICAL: project for the viewed month, not "from now forward".
    // STRICT REQUIREMENT: this is what fixes the April 1 recurring item still
    // appearing in April even when the recurring rule is created or edited on
    // April 3.
    rangeStart: monthStart,
    rangeEnd: DateTime(monthStart.year, monthStart.month + 1, 0),
    selectedCurrency: selectedCurrency,
  );

  return dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projectedExpenses,
    actualExpenses: actualExpenses,
  );
}

@foundation.visibleForTesting
List<ExpenseEntry> filterPocketActualExpenses(
  Iterable<ExpenseEntry> expenses,
) {
  // CRITICAL: exclude recurring template rows from "actual" spend before
  // merging projected occurrences.
  // STRICT REQUIREMENT: recurring templates are configuration rows, not posted
  // month spend. Keeping them here causes double counting once projected month
  // rows are added on top.
  return expenses
      .where((expense) =>
          !expense.isRecurring &&
          (expense.type ?? 'expense').toLowerCase() != 'income')
      .toList(growable: false);
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
    required this.hasPreviousMonthPockets,
    required this.currency,
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
  final bool hasPreviousMonthPockets;
  final String currency;
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
          saved[i].budgetAmountCents != editing[i].budgetAmountCents ||
          saved[i].spent != editing[i].spent) {
        _debugLog('hasChanges: true (pocket ${saved[i].name} changed)');
        return true;
      }
    }
    _debugLog('hasChanges: false');
    return false;
  }

  double get totalSpent => editing.fold<double>(0, (sum, p) => sum + p.spent);

  PocketsState copyWith({
    bool? isLoading,
    String? error,
    List<PocketEnvelope>? saved,
    List<PocketEnvelope>? editing,
    String? budgetId,
    DateTime? periodMonth,
    double? previousBudget,
    bool? hasPreviousMonthPockets,
    String? currency,
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
      hasPreviousMonthPockets:
          hasPreviousMonthPockets ?? this.hasPreviousMonthPockets,
      currency: currency ?? this.currency,
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
        hasPreviousMonthPockets: false,
        currency: 'USD',
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

  _CacheKey? _lastCacheKey;

  bool _hasLoadedOnce = false;
  bool get _isPreview => ref.read(previewModeProvider).isActive;

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

  // ignore: unused_element
  Future<bool> _hasAnyPocketsForPeriodMonth({
    required String periodMonth,
    required String currency,
    required PocketsScopeType scope,
    required String userId,
    required String? householdId,
  }) async {
    var budgetQuery = supabase
        .from('budgets')
        .select('id')
        .eq('period_month', periodMonth)
        .eq('currency', currency);

    budgetQuery = _applyAccountScopeFilter(
      budgetQuery,
      userId,
      scope: scope,
      householdId: householdId,
    );

    final budgetRow = await budgetQuery.limit(1).maybeSingle();
    final budgetId = budgetRow?['id'] as String?;
    if (budgetId == null || budgetId.isEmpty) return false;

    var envelopeQuery = supabase
        .from('budget_envelopes')
        .select('id')
        .eq('budget_id', budgetId)
        .eq('currency', currency);

    envelopeQuery = _applyAccountScopeFilter(
      envelopeQuery,
      userId,
      scope: scope,
      householdId: householdId,
    );

    final envelopeRow = await envelopeQuery.limit(1).maybeSingle();
    return envelopeRow != null;
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
  Future<void> load({bool bypassCache = false}) async {
    // Avoid duplicate loads if already loading
    if (state.isLoading && _hasLoadedOnce) return;
    _hasLoadedOnce = true;

    final authUser = ref.read(authProvider);
    if (authUser.isEmpty && !_isPreview) {
      _debugLog('[Pockets] No auth user, cannot load');
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: 'Not authenticated');
      return;
    }

    await _load(bypassCache: bypassCache);
  }

  Future<void> _load({bool bypassCache = false}) async {
    _debugLog(
        '[Pockets] Starting _load for scope: ${params.scope}, month: ${params.periodMonth}');
    if (!mounted) return;

    // Ensure global invalidation listeners are registered.
    ref.watch(_pocketsMonthCacheInvalidationProvider);

    if (_isPreview) {
      state = state.copyWith(isLoading: true, clearError: true);
      _applyPreviewState();
      return;
    }

    try {
      final authUser = ref.read(authProvider);
      final periodSelection = ref.read(periodFilterProvider);

      final DateTime targetDate;
      if (params.periodMonth != null) {
        targetDate = params.periodMonth!;
      } else {
        final range = resolvePeriodDateRange(periodSelection);
        targetDate = range.end;
      }

      final monthStart = DateTime(targetDate.year, targetDate.month, 1);
      final periodMonth = _formatDate(monthStart);
      // monthEnd previously used for local expenses queries; kept monthStart only now.

      final scopeType = params.scope;
      final isHousehold = scopeType == PocketsScopeType.household;
      final isPortfolio = scopeType == PocketsScopeType.portfolio;
      final householdId =
          params.householdId ?? (_isPreview ? 'preview-house-1' : null);

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
          hasPreviousMonthPockets: false,
          currency: params.currency ?? 'USD',
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
          hasPreviousMonthPockets: false,
          currency: params.currency ?? 'USD',
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
      final fallbackCurrency = ref.read(selectedHomeCurrencyCodeProvider);
      final requestedCurrency = params.currency?.trim().toUpperCase();
      final allowCurrencyFallback = params.isBootstrapCurrency;
      final initialCurrency =
          (requestedCurrency ?? fallbackCurrency).toUpperCase();
      var selectedCurrency = initialCurrency;

      final cacheKey = (
        userId: authUser.uid,
        scope: scopeType,
        householdId: householdId,
        periodMonth: periodMonth,
        currency: selectedCurrency,
        includeUpcomingRecurring: params.includeUpcomingRecurring,
        allowCurrencyFallback: allowCurrencyFallback,
      );
      _lastCacheKey = cacheKey;

      final now = DateTime.now();
      if (!bypassCache) {
        final cached = _pocketsMonthCache.getAny(cacheKey, now);
        if (cached != null) {
          // Serve cached state immediately.
          if (!mounted) return;
          state = cached.copyWith(isLoading: false, clearError: true);

          // If stale, refresh in the background (deduped per key).
          final isFresh = _pocketsMonthCache.isFresh(cacheKey, now, monthStart);
          if (!isFresh) {
            final existingInFlight = _pocketsMonthCache.getInFlight(cacheKey);
            if (existingInFlight == null) {
              _debugLog(
                  '[Pockets][Cache] Stale cache hit; refreshing in background ($periodMonth/$selectedCurrency)');
              unawaited(
                _refreshFromBackend(
                  cacheKey: cacheKey,
                  monthStart: monthStart,
                  periodMonth: periodMonth,
                  scopeType: scopeType,
                  householdId: householdId,
                  initialCurrency: initialCurrency,
                  allowCurrencyFallback: allowCurrencyFallback,
                  showLoadingIndicator: false,
                ).then((loaded) {
                  if (!mounted) return;
                  // Avoid clobbering local edits.
                  if (state.hasChanges) return;
                  if (_lastCacheKey != cacheKey) return;
                  state = loaded;
                }).catchError((Object error, StackTrace stackTrace) {
                  _debugLog(
                    '[Pockets][Cache] Background refresh failed: $error',
                  );
                }),
              );
            }
          }
          return;
        }
      }

      // No cache (or bypass requested), show loader.
      state = state.copyWith(isLoading: true, clearError: true);

      _debugLog(
          '[Pockets] Using currency: $selectedCurrency (params: ${params.currency}, fallback: $fallbackCurrency, allowFallback: $allowCurrencyFallback)');

      final loadedState = await _refreshFromBackend(
        cacheKey: cacheKey,
        monthStart: monthStart,
        periodMonth: periodMonth,
        scopeType: scopeType,
        householdId: householdId,
        initialCurrency: initialCurrency,
        allowCurrencyFallback: allowCurrencyFallback,
        showLoadingIndicator: true,
      );
      if (!mounted) return;
      state = loadedState;
      return;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  bool _isMissingRpcFunctionError(Object error) {
    if (error is! PostgrestException) return false;
    return error.code == '42883' ||
        error.message.toLowerCase().contains('get_pockets_month_v2');
  }

  Future<Map<String, dynamic>> _fetchPocketsMonthPayload({
    required String userId,
    required PocketsScopeType scopeType,
    required String? householdId,
    required String periodMonth,
    required String selectedCurrency,
    required bool includeUpcomingRecurring,
    required bool allowCurrencyFallback,
  }) async {
    try {
      // CRITICAL: call the recurring-aware v2 pockets RPC here.
      // STRICT REQUIREMENT: switching this back to v1 drops projected recurring
      // month spend from the backend payload used by the main pockets page.
      final response = await supabase.rpc(
        'get_pockets_month_v2',
        params: <String, dynamic>{
          'p_user_id': userId,
          'p_scope': switch (scopeType) {
            PocketsScopeType.personal => 'personal',
            PocketsScopeType.portfolio => 'portfolio',
            PocketsScopeType.household => 'household',
          },
          'p_household_id': householdId,
          'p_period_month': periodMonth,
          'p_currency': selectedCurrency,
          // CRITICAL: the user's recurring-in-pockets preference must reach the
          // RPC layer.
          // STRICT REQUIREMENT: if this flag stops being forwarded, the
          // backend and mobile calculation paths diverge and pockets regress.
          'p_include_projected_recurring': includeUpcomingRecurring,
          'p_allow_currency_fallback': allowCurrencyFallback,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (error) {
      if (_isMissingRpcFunctionError(error)) {
        _debugLog(
          '[Pockets] RPC get_pockets_month_v2 missing; deploy migration 20260408170000_add_recurring_aware_wallets_and_pockets_rpcs.sql',
        );
      }
      rethrow;
    }
  }

  Future<PocketsState> _refreshFromBackend({
    required _CacheKey cacheKey,
    required DateTime monthStart,
    required String periodMonth,
    required PocketsScopeType scopeType,
    required String? householdId,
    required String initialCurrency,
    required bool allowCurrencyFallback,
    required bool showLoadingIndicator,
  }) async {
    final existingInFlight = _pocketsMonthCache.getInFlight(cacheKey);
    if (existingInFlight != null) {
      return existingInFlight;
    }

    Future<PocketsState> doFetch() async {
      final authUser = ref.read(authProvider);
      var selectedCurrency = initialCurrency;

      final payload = await _fetchPocketsMonthPayload(
        userId: authUser.uid,
        scopeType: scopeType,
        householdId: householdId,
        periodMonth: periodMonth,
        selectedCurrency: selectedCurrency,
        includeUpcomingRecurring: cacheKey.includeUpcomingRecurring,
        allowCurrencyFallback: allowCurrencyFallback,
      );
      final budgetRow = payload['budget'] as Map?;
      final budgetId = budgetRow?['id']?.toString();
      final rpcCurrency =
          (payload['selected_currency'] as String?)?.toUpperCase();
      if (rpcCurrency != null && rpcCurrency.isNotEmpty) {
        selectedCurrency = rpcCurrency;
      }

      final hasPreviousMonthPockets =
          payload['has_previous_month_pockets'] == true;
      final previousBudget =
          (payload['previous_budget_cents'] as num?)?.toDouble() ?? 0.0;
      final totalBudget =
          (budgetRow?['total_budget_cents'] as num?)?.toDouble() ?? 0.0;

      final envRows = ((payload['envelopes'] as List?) ?? const [])
          .cast<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      if (envRows.isEmpty) {
        return PocketsState(
          isLoading: false,
          error: null,
          saved: const [],
          editing: const [],
          budgetId: budgetId,
          periodMonth: monthStart,
          previousBudget: previousBudget / 100.0,
          hasPreviousMonthPockets: hasPreviousMonthPockets,
          currency: selectedCurrency,
          totalBudget: totalBudget / 100.0,
          savedTotalBudget: totalBudget / 100.0,
          unallocatedSpend: 0,
          uncategorized: const [],
          uncategorizedExpenses: const {},
        );
      }

      final envIds =
          envRows.map((e) => e['id'] as String).toList(growable: false);

      final allocationRows = ((payload['allocations'] as List?) ?? const [])
          .cast<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final allocationCentsByEnvelopeId = <String, int>{
        for (final row in allocationRows)
          if ((row['envelope_id'] as String?) != null)
            if (((row['amount_cents'] as num?)?.toInt() ?? 0) > 0)
              (row['envelope_id'] as String):
                  (row['amount_cents'] as num?)!.toInt(),
      };

      final categoryLinksRows =
          ((payload['category_links'] as List?) ?? const [])
              .cast<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);

      final categoriesByEnvelopeId = <String, List<String>>{};
      for (final row in categoryLinksRows) {
        final envId = row['envelope_id'] as String;
        final category =
            (row['category'] as String? ?? '').trim().toLowerCase();
        if (category.isEmpty) continue;
        categoriesByEnvelopeId.putIfAbsent(envId, () => []).add(category);
      }

      final actualExpenseRows =
          ((payload['actual_expenses'] as List?) ?? const [])
              .cast<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
      // CRITICAL: treat RPC actual_expenses as persisted rows only.
      // STRICT REQUIREMENT: the recurring month projection is merged below on
      // purpose. Do not mix recurring template rows into actual_expenses or the
      // monthly pocket totals will double count.
      final actualExpenses = actualExpenseRows.map(ExpenseEntry.fromJson);
      final filteredActualExpenses = filterPocketActualExpenses(actualExpenses);
      final projectedRecurringExpenses = await loadProjectedPocketMonthExpenses(
        userId: authUser.uid,
        scope: scopeType,
        householdId: householdId,
        monthStart: monthStart,
        selectedCurrency: selectedCurrency,
        includeUpcomingRecurring: params.includeUpcomingRecurring,
        actualExpenses: filteredActualExpenses,
      );
      // CRITICAL: keep projected recurring expenses in the monthly pocket
      // calculation.
      // STRICT REQUIREMENT: pocket totals/spent amounts must include recurring
      // transactions for every viewed month, otherwise historical pocket
      // balances ignore scheduled bills and the recurring-in-pockets
      // regression returns.
      final monthlyExpenses = <ExpenseEntry>[
        ...filteredActualExpenses,
        ...projectedRecurringExpenses,
      ];
      final monthlyExpenseRows = monthlyExpenses
          .map((expense) => expense.toJson())
          .toList(growable: false);

      final isProjecting = projectedRecurringExpenses.isNotEmpty;
      final spentById = <String, double>{};
      double totalMonthlySpend = 0.0;

      if (isProjecting) {
        // Preserve existing semantics: when projections are included, all spend
        // calculations include both actual + projected expenses.
        for (final expense in monthlyExpenses) {
          totalMonthlySpend += expense.amount;
        }
        for (final envId in envIds) {
          final categories = categoriesByEnvelopeId[envId] ?? const <String>[];
          if (categories.isEmpty) {
            spentById[envId] = 0.0;
            continue;
          }
          var totalSpent = 0.0;
          for (final expense in monthlyExpenses) {
            final expenseCategory =
                (expense.category ?? '').trim().toLowerCase();
            if (categories.contains(expenseCategory)) {
              totalSpent += expense.amount;
            }
          }
          spentById[envId] = totalSpent;
        }
      } else {
        final spentRows = ((payload['spent_by_envelope'] as List?) ?? const [])
            .cast<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        for (final row in spentRows) {
          final envId = row['envelope_id']?.toString();
          if (envId == null || envId.isEmpty) continue;
          spentById[envId] =
              ((row['spent_cents'] as num?)?.toDouble() ?? 0.0) / 100.0;
        }

        // Ensure empty envelopes still get 0 spent.
        for (final envId in envIds) {
          spentById.putIfAbsent(envId, () => 0.0);
        }

        totalMonthlySpend =
            ((payload['total_spend_cents'] as num?)?.toDouble() ?? 0.0) / 100.0;
      }

      final pockets = envRows.map((row) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '';
        final resolvedAmountCents = allocationCentsByEnvelopeId[id] ??
            (row['budget_amount_cents'] as num?)?.toInt() ??
            0;
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
          budgetAmountCents: resolvedAmountCents,
          spent: spent,
          currency: currency,
          icon: icon,
          color: color,
          budgetId: bId,
          householdId: hhId,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      final uncategorized = <UncategorizedCategory>[];
      final uncategorizedExpensesMap = <String, List<Map<String, dynamic>>>{};

      if (isProjecting) {
        // When projecting recurring spend, build uncategorized from the same
        // combined expense list as before.
        final expenseTotalsByCategory = <String, double>{};
        for (final expense in monthlyExpenses) {
          final amount = expense.amount;
          final rawCategory =
              (expense.category ?? 'uncategorized').toLowerCase();
          expenseTotalsByCategory.update(
            rawCategory,
            (v) => v + amount,
            ifAbsent: () => amount,
          );
        }

        final linkedCategories = categoryLinksRows
            .map((r) => ((r['category'] as String?) ?? '').trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toSet();

        expenseTotalsByCategory.forEach((cat, amount) {
          if (!linkedCategories.contains(cat)) {
            final key = cat.isEmpty ? 'uncategorized' : cat;
            uncategorized
                .add(UncategorizedCategory(category: key, amount: amount));
            final matches = monthlyExpenseRows.where((row) {
              final rowCategory =
                  (row['category'] as String? ?? 'uncategorized')
                      .trim()
                      .toLowerCase();
              return rowCategory == cat;
            });
            for (final m in matches) {
              uncategorizedExpensesMap
                  .putIfAbsent(key, () => <Map<String, dynamic>>[])
                  .add(m);
            }
          }
        });
      } else {
        final uncategorizedTotalsRows =
            ((payload['uncategorized_totals'] as List?) ?? const [])
                .cast<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
        for (final row in uncategorizedTotalsRows) {
          final category = (row['category'] as String? ?? 'uncategorized')
              .trim()
              .toLowerCase();
          final amount =
              ((row['amount_cents'] as num?)?.toDouble() ?? 0.0) / 100.0;
          uncategorized
              .add(UncategorizedCategory(category: category, amount: amount));
        }

        final uncategorizedExpenseGroups =
            ((payload['uncategorized_expenses'] as List?) ?? const [])
                .cast<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
        for (final group in uncategorizedExpenseGroups) {
          final category = (group['category'] as String? ?? 'uncategorized')
              .trim()
              .toLowerCase();
          final expenses = ((group['expenses'] as List?) ?? const [])
              .cast<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
          if (expenses.isEmpty) continue;
          uncategorizedExpensesMap[category] = expenses;
        }
      }

      final totalEnvelopeSpend =
          pockets.fold<double>(0, (sum, p) => sum + p.spent);

      final unallocatedSpend =
          math.max(0.0, totalMonthlySpend - totalEnvelopeSpend);

      return PocketsState(
        isLoading: false,
        error: null,
        saved: pockets,
        editing: pockets.map((p) => p.copyWith()).toList(),
        budgetId: budgetId,
        periodMonth: monthStart,
        previousBudget: previousBudget / 100.0,
        hasPreviousMonthPockets: hasPreviousMonthPockets,
        currency: selectedCurrency,
        totalBudget: totalBudget / 100.0,
        savedTotalBudget: totalBudget / 100.0, // Initialize saved budget
        unallocatedSpend: unallocatedSpend,
        uncategorized: uncategorized,
        uncategorizedExpenses: uncategorizedExpensesMap,
      );
    }

    final now = DateTime.now();
    final future = doFetch();
    _pocketsMonthCache.setInFlight(cacheKey, future, now);

    if (showLoadingIndicator && mounted) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final loaded = await future;
      final completedAt = DateTime.now();
      _pocketsMonthCache.set(cacheKey, loaded, completedAt);

      // If the RPC selected a different currency (bootstrap fallback), cache
      // under that effective currency too so subsequent navigations hit.
      if (loaded.currency.toUpperCase() != cacheKey.currency.toUpperCase()) {
        final effectiveKey = (
          userId: cacheKey.userId,
          scope: cacheKey.scope,
          householdId: cacheKey.householdId,
          periodMonth: cacheKey.periodMonth,
          currency: loaded.currency.toUpperCase(),
          includeUpcomingRecurring: cacheKey.includeUpcomingRecurring,
          allowCurrencyFallback: cacheKey.allowCurrencyFallback,
        );
        _pocketsMonthCache.set(effectiveKey, loaded, completedAt);
      }
      return loaded;
    } finally {
      _pocketsMonthCache.clearInFlight(cacheKey);
    }
  }

  void _applyPreviewState() {
    final mockPockets = PreviewMockData.pockets;
    final savedPockets = _clonePockets(mockPockets);
    final editingPockets = _clonePockets(mockPockets);
    final totalBudget = savedPockets.fold<double>(
      0,
      (sum, pocket) => sum + pocket.budgetAmountCents / 100.0,
    );
    final totalSpent =
        savedPockets.fold<double>(0, (sum, pocket) => sum + pocket.spent);
    final now = DateTime.now();

    state = PocketsState(
      isLoading: false,
      error: null,
      saved: savedPockets,
      editing: editingPockets,
      budgetId: 'preview-budget-main',
      periodMonth: DateTime(now.year, now.month, 1),
      previousBudget: totalBudget,
      hasPreviousMonthPockets: true,
      currency:
          PreviewMockData.contact.preferredCurrency?.toUpperCase() ?? 'USD',
      totalBudget: totalBudget,
      savedTotalBudget: totalBudget,
      unallocatedSpend: math.max(totalBudget - totalSpent, 0),
      uncategorized: const [],
      uncategorizedExpenses: const {},
    );
  }

  List<PocketEnvelope> _clonePockets(List<PocketEnvelope> pockets) {
    return pockets
        .map(
          (p) => PocketEnvelope(
            id: p.id,
            name: p.name,
            budgetAmountCents: p.budgetAmountCents,
            spent: p.spent,
            currency: p.currency,
            icon: p.icon,
            color: p.color,
            budgetId: p.budgetId,
            householdId: p.householdId,
            lastUpdated: p.lastUpdated,
          ),
        )
        .toList(growable: false);
  }

  void updateTotalBudget(double newTotal) {
    if (newTotal < 0) return;
    _debugLog(
        'updateTotalBudget: $newTotal (saved: ${state.savedTotalBudget})');
    state = applyRebalancedBudgetToPocketsState(
      state: state,
      newTotalBudget: newTotal,
    );
    _debugLog('After update - hasChanges: ${state.hasChanges}');
  }

  void reusePreviousBudget(double amount) {
    if (amount <= 0) return;
    updateTotalBudget(amount);
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

    final explicitCurrency = params.isBootstrapCurrency
        ? null
        : params.currency?.trim().toUpperCase();
    final filter = ref.read(homeFilterProvider);

    _debugLog(
        '[Pockets][Copy] Starting copyPocketsFromMonth for scope=${params.scope}, householdId=${params.householdId}, targetMonth=${params.periodMonth}');
    _debugLog(
        '[Pockets][Copy] Input sourceMonth=$sourceMonth (will normalize to month start)');

    // Always log the current target budget row so we can detect mismatches
    // (e.g., budget.period_month != targetPeriodMonth, or budget.currency != selected currency).
    try {
      final currentBudgetId = state.budgetId;
      if (currentBudgetId != null && currentBudgetId.isNotEmpty) {
        final row = await supabase
            .from('budgets')
            .select(
                'id,currency,period_month,total_budget_cents,household_id,user_id')
            .eq('id', currentBudgetId)
            .maybeSingle();
        _debugLog(
            '[Pockets][Copy] Target budget row: id=${row?['id']}, period_month=${row?['period_month']}, currency=${row?['currency']}, total_budget_cents=${row?['total_budget_cents']}, household_id=${row?['household_id']}, user_id=${row?['user_id']}');
      }
    } catch (_) {
      // ignore
    }

    // Currency resolution:
    // - If user explicitly selected a currency, use that.
    // - Otherwise, prefer the currently loaded/header currency for reads.
    // - Only fall back to the current budget row if we still have no currency.
    // - Last resort: analytics/"USD".
    final hasExplicitCurrency =
        explicitCurrency != null && explicitCurrency.isNotEmpty;

    var effectiveCurrency = state.currency.trim().toUpperCase();
    if (effectiveCurrency.isEmpty) {
      effectiveCurrency = explicitCurrency ?? '';
    }
    if (effectiveCurrency.isEmpty) {
      effectiveCurrency = ref.read(selectedHomeCurrencyCodeProvider);
    }

    if (!hasExplicitCurrency && effectiveCurrency.trim().isEmpty) {
      try {
        final currentBudgetId = state.budgetId;
        if (currentBudgetId != null && currentBudgetId.isNotEmpty) {
          final row = await supabase
              .from('budgets')
              .select(
                  'id,currency,period_month,total_budget_cents,household_id,user_id')
              .eq('id', currentBudgetId)
              .maybeSingle();
          final c = (row?['currency'] as String?)?.toUpperCase().trim();
          if (c != null && c.isNotEmpty) {
            effectiveCurrency = c;
          }
          _debugLog(
              '[Pockets][Copy] Current budget row: id=${row?['id']}, period_month=${row?['period_month']}, currency=${row?['currency']}, total_budget_cents=${row?['total_budget_cents']}, household_id=${row?['household_id']}, user_id=${row?['user_id']}');
        }
      } catch (_) {
        // ignore
      }
    }
    if (effectiveCurrency.trim().isEmpty) {
      final analytics = ref.read(analyticsProvider);
      effectiveCurrency =
          (analytics.preferredCurrency?.toUpperCase().trim() ?? 'USD');
    }

    _debugLog(
        '[Pockets][Copy] Currency resolution: filter.selectedCurrency=${filter.selectedCurrency}, hasExplicitCurrency=$hasExplicitCurrency, effectiveCurrency=$effectiveCurrency');

    final scopeType = params.scope;
    final isScopedToHousehold = scopeType != PocketsScopeType.personal;
    final householdId = params.householdId;

    if (isScopedToHousehold && householdId == null) {
      if (!mounted) return;
      state = state.copyWith(error: 'No household selected');
      return;
    }

    final sourceMonthStart = DateTime(sourceMonth.year, sourceMonth.month, 1);
    final sourcePeriodMonth = _formatDate(sourceMonthStart);

    final targetMonth = params.periodMonth ?? DateTime.now();
    final targetMonthStart = DateTime(targetMonth.year, targetMonth.month, 1);
    final targetPeriodMonth = _formatDate(targetMonthStart);

    var currentBudgetId = state.budgetId?.trim();
    if (currentBudgetId == null || currentBudgetId.isEmpty) {
      final existingTargetBudget = await _findBudgetRowForPeriod(
        periodMonth: targetPeriodMonth,
        isHousehold: isScopedToHousehold,
        householdId: householdId,
        userId: authUser.uid,
        currency: effectiveCurrency,
      );
      currentBudgetId = (existingTargetBudget?['id'] as String?)?.trim();
    }

    _debugLog(
        '[Pockets][Copy] targetPeriodMonth=$targetPeriodMonth (budgetId=$currentBudgetId), sourcePeriodMonth=$sourcePeriodMonth');

    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final nowIso = DateTime.now().toIso8601String();

      // Debug: list candidate budgets for the source period for this user/scope.
      // This helps detect currency mismatches (e.g., source pockets exist in EUR but effectiveCurrency is USD).
      try {
        var candidates = supabase
            .from('budgets')
            .select(
                'id,period_month,currency,total_budget_cents,household_id,user_id')
            .eq('period_month', sourcePeriodMonth);
        candidates = _applyAccountScopeFilter(
          candidates,
          authUser.uid,
          scope: scopeType,
          householdId: householdId,
        );
        final rows =
            await candidates.order('updated_at', ascending: false).limit(10);
        final list = (rows as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final summary = list
            .map((r) =>
                '{id=${r['id']}, currency=${r['currency']}, total=${r['total_budget_cents']}}')
            .toList();
        _debugLog(
            '[Pockets][Copy] Source-month budget candidates (up to 10): $summary');

        for (final r in list) {
          final bid = r['id'] as String?;
          if (bid == null || bid.isEmpty) continue;
          try {
            final env = await supabase
                .from('budget_envelopes')
                .select('id,name,currency,budget_amount_cents')
                .eq('budget_id', bid)
                .order('name')
                .limit(20);
            final envRows =
                (env as List?)?.cast<Map<String, dynamic>>() ?? const [];
            final sample = envRows
                .take(8)
                .map((e) =>
                    '{name=${e['name']}, currency=${e['currency']}, amount=${e['budget_amount_cents']}}')
                .toList();
            _debugLog(
                '[Pockets][Copy] Candidate budget $bid envelopes: count=${envRows.length}, sample=$sample');
          } catch (_) {
            // ignore
          }
        }
      } catch (_) {
        // ignore
      }

      final baseBudgetQuery = supabase
          .from('budgets')
          .select('id,total_budget_cents')
          .eq('period_month', sourcePeriodMonth)
          .eq('currency', effectiveCurrency);

      final scopedBudgetQuery = _applyAccountScopeFilter(
        baseBudgetQuery,
        authUser.uid,
        scope: scopeType,
        householdId: householdId,
      );

      final sourceBudgetRow = await scopedBudgetQuery.maybeSingle();
      final sourceBudgetId = sourceBudgetRow?['id'] as String?;
      final sourceTotalBudgetCents =
          (sourceBudgetRow?['total_budget_cents'] as num?)?.toInt() ?? 0;

      _debugLog(
          '[Pockets][Copy] Selected source budget: id=$sourceBudgetId, total_budget_cents=$sourceTotalBudgetCents, currency=$effectiveCurrency');
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
          .select('id,name,budget_amount_cents,color,icon')
          .eq('currency', effectiveCurrency)
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

      _debugLog(
          '[Pockets][Copy] Source envelopes fetched: count=${envRows.length}');
      if (envRows.isNotEmpty) {
        final sample = envRows
            .take(8)
            .map((r) =>
                '{name=${r['name']}, budget_amount_cents=${r['budget_amount_cents']}, id=${r['id']}}')
            .toList();
        _debugLog('[Pockets][Copy] Source envelope sample: $sample');
      }
      if (envRows.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: 'No pockets found for the previous month',
        );
        return;
      }

      if (currentBudgetId == null || currentBudgetId.isEmpty) {
        final budgetPayload = <String, dynamic>{
          'user_id': authUser.uid,
          'household_id': isScopedToHousehold ? householdId : null,
          'currency': effectiveCurrency,
          'period_month': targetPeriodMonth,
          'total_budget_cents': sourceTotalBudgetCents > 0
              ? sourceTotalBudgetCents
              : (state.totalBudget * 100).round(),
          'updated_at': nowIso,
        };

        try {
          final insertRes = await supabase
              .from('budgets')
              .insert(budgetPayload)
              .select('id')
              .maybeSingle();
          currentBudgetId = (insertRes?['id'] as String?)?.trim();
        } catch (error) {
          if (!_isConflictError(error)) {
            rethrow;
          }

          final existingTargetBudget = await _findBudgetRowForPeriod(
            periodMonth: targetPeriodMonth,
            isHousehold: isScopedToHousehold,
            householdId: householdId,
            userId: authUser.uid,
            currency: effectiveCurrency,
          );
          currentBudgetId = (existingTargetBudget?['id'] as String?)?.trim();
        }

        if (currentBudgetId == null || currentBudgetId.isEmpty) {
          throw Exception('Unable to prepare current month budget');
        }
      }

      // If the user hasn't set this month's total budget yet, reuse last month's.
      if (state.totalBudget <= 0 && sourceTotalBudgetCents > 0) {
        _debugLog(
            '[Pockets][Copy] Updating current budget total to match source: ${state.totalBudget} -> ${sourceTotalBudgetCents / 100.0}');
        await supabase.from('budgets').update(<String, dynamic>{
          'total_budget_cents': sourceTotalBudgetCents,
          'updated_at': nowIso,
        }).eq('id', currentBudgetId);
      }

      final sourceEnvIds = envRows
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();

      final allocationsRes = await supabase
          .from('envelope_allocations')
          .select('envelope_id,amount_cents')
          .eq('period_month', sourcePeriodMonth)
          .inFilter('envelope_id', sourceEnvIds);
      final allocationRows =
          (allocationsRes as List?)?.cast<Map<String, dynamic>>() ?? [];
      final allocationCentsByEnvelopeId = <String, int>{
        for (final row in allocationRows)
          if ((row['envelope_id'] as String?) != null)
            if (((row['amount_cents'] as num?)?.toInt() ?? 0) > 0)
              (row['envelope_id'] as String):
                  (row['amount_cents'] as num?)!.toInt(),
      };

      _debugLog(
          '[Pockets][Copy] Source allocations fetched: count=${allocationRows.length}, nonZeroCount=${allocationCentsByEnvelopeId.length}');

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
      var insertedCount = 0;
      for (final row in envRows) {
        final sourceEnvId = row['id'] as String?;
        if (sourceEnvId == null || sourceEnvId.isEmpty) continue;

        final name = row['name'] as String? ?? '';
        final amountCents = allocationCentsByEnvelopeId[sourceEnvId] ??
            (row['budget_amount_cents'] as num?)?.toInt() ??
            0;
        final color = row['color'] as String?;
        final dynamic rawIcon = row['icon'];
        final String? icon = rawIcon?.toString();

        final insertRes = await supabase
            .from('budget_envelopes')
            .insert(<String, dynamic>{
              'user_id': authUser.uid,
              'budget_id': currentBudgetId,
              'name': name,
              'budget_amount_cents': amountCents,
              'household_id':
                  scopeType == PocketsScopeType.personal ? null : householdId,
              'currency': effectiveCurrency,
              'color': color,
              'icon': icon,
              'updated_at': nowIso,
            })
            .select('id')
            .maybeSingle();

        final newEnvId = insertRes?['id'] as String?;
        if (newEnvId == null || newEnvId.isEmpty) {
          throw Exception('Failed to copy pocket: $name');
        }

        insertedCount += 1;

        if (amountCents > 0) {
          await supabase.from('envelope_allocations').upsert(
            <String, dynamic>{
              'envelope_id': newEnvId,
              'period_month': targetPeriodMonth,
              'amount_cents': amountCents,
              'carryover_policy': 'carryover',
              'updated_at': nowIso,
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

      _debugLog(
          '[Pockets][Copy] Completed inserts: insertedEnvelopes=$insertedCount, insertedCategoryLinks=${linksPayload.length}');

      await _load(bypassCache: true);

      _debugLog(
          '[Pockets][Copy] Reload complete: totalBudget=${state.totalBudget}, pockets=${state.editing.length}, periodMonth=${state.periodMonth}');

      // Refresh analytics + widgets so other surfaces reflect the copied pockets.
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.getUserFriendlyMessage(e));
    }
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
    } else if (allowAnyUser) {
      query = query.isFilter('household_id', null);
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

  String _resolveWriteCurrency() {
    final explicitCurrency = params.isBootstrapCurrency
        ? null
        : params.currency?.trim().toUpperCase();
    if (explicitCurrency != null && explicitCurrency.isNotEmpty) {
      return explicitCurrency;
    }

    final loadedCurrency = state.currency.trim().toUpperCase();
    if (loadedCurrency.isNotEmpty) {
      return loadedCurrency;
    }

    final filter = ref.read(homeFilterProvider);
    final analytics = ref.read(analyticsProvider);
    return (filter.selectedCurrency?.trim().toUpperCase() ??
            analytics.preferredCurrency?.trim().toUpperCase() ??
            'USD')
        .toUpperCase();
  }

  Future<void> saveChanges() async {
    if (!mounted) return;
    if (!state.hasChanges) return;
    if (_isPreview) {
      _showPreviewModeToast();
      return;
    }
    try {
      final authUser = ref.read(authProvider);
      final selectedCurrency = _resolveWriteCurrency();
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
          currency: selectedCurrency,
        );
        budgetId = existing?['id'] as String?;
        _debugLog(
            '[Pockets] saveChanges resolved existing budgetId: $budgetId');

        if (budgetId == null) {
          final existingAnyCurrency = await _findBudgetRowForPeriod(
            periodMonth: periodMonth,
            isHousehold: isHousehold,
            householdId: householdId,
            userId: authUser.uid,
            currency: null,
          );
          budgetId = existingAnyCurrency?['id'] as String?;
        }
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
              currency: selectedCurrency,
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

            final fallbackAnyCurrencyRow = await _findBudgetRowForPeriod(
              periodMonth: periodMonth,
              isHousehold: isHousehold,
              householdId: householdId,
              userId: authUser.uid,
              currency: null,
              allowAnyUser: scopeType == PocketsScopeType.personal,
            );
            final fallbackAnyCurrencyId =
                fallbackAnyCurrencyRow?['id'] as String?;
            if (fallbackAnyCurrencyId != null) {
              await supabase
                  .from('budgets')
                  .update(budgetPayload..['id'] = fallbackAnyCurrencyId)
                  .eq('id', fallbackAnyCurrencyId);
              return fallbackAnyCurrencyId;
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
          'budget_amount_cents': p.budgetAmountCents,
          'budget_id': budgetId,
          'household_id': isScopedToHousehold ? householdId : null,
          'currency': selectedCurrency,
          'updated_at': nowIso,
        }).eq('id', p.id);

        await supabase.from('envelope_allocations').upsert(
          <String, dynamic>{
            'envelope_id': p.id,
            'period_month': periodMonth,
            'amount_cents': p.budgetAmountCents,
            'carryover_policy': 'carryover',
            'updated_at': nowIso,
          },
          onConflict: 'envelope_id,period_month',
        );
      }

      // Reload from backend to ensure consistency
      await _load(bypassCache: true);

      // Also refresh analytics so widgets and summaries reflect updated
      // budgets and envelope allocations (used by WidgetSyncManager).
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);

      // Force widget sync so both budget and top-spending widgets
      // reflect the latest pocket configuration.
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> createBudgetFromTemplate({
    required double totalBudget,
    required List<PocketTemplate> pockets,
  }) async {
    if (!mounted) return;
    if (_isPreview) {
      _showPreviewModeToast();
      return;
    }

    final authUser = ref.read(authProvider);
    if (authUser.isEmpty) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final selectedCurrency = _resolveWriteCurrency();

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

      // Always resolve the budget row for this exact month/scope/currency.
      // This avoids reusing a stale budget id from another currency selection.
      final existing = await _findBudgetRowForPeriod(
        periodMonth: periodMonth,
        isHousehold: isScopedToHousehold,
        householdId: householdId,
        userId: authUser.uid,
        currency: selectedCurrency,
      );
      String? budgetId = existing?['id'] as String?;

      // Use upsert-like logic
      if (budgetId != null) {
        await supabase.from('budgets').update(budgetPayload).eq('id', budgetId);
      } else {
        try {
          final res = await supabase
              .from('budgets')
              .insert(budgetPayload)
              .select('id')
              .single();
          budgetId = res['id'] as String;
        } catch (e) {
          if (_isConflictError(e)) {
            _debugLog(
                '[Pockets] Budget insert conflict in createBudgetFromTemplate, fetching existing row');
            final existing = await _findBudgetRowForPeriod(
              periodMonth: periodMonth,
              isHousehold: isScopedToHousehold,
              householdId: householdId,
              userId: authUser.uid,
              currency: selectedCurrency,
            );
            budgetId = existing?['id'] as String?;
            if (budgetId != null) {
              await supabase
                  .from('budgets')
                  .update(budgetPayload)
                  .eq('id', budgetId);
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      // 2. Create Pockets & Links
      final linksPayload = <Map<String, dynamic>>[];

      for (final template in pockets) {
        final amountCents = (totalBudget * template.weight * 100).round();
        final envelopeName = normalizePocketTemplateName(template.name);
        final insertRes = await supabase
            .from('budget_envelopes')
            .upsert(
              <String, dynamic>{
                'user_id': authUser.uid,
                'budget_id': budgetId,
                'name': envelopeName,
                'budget_amount_cents': amountCents,
                'household_id': isScopedToHousehold ? householdId : null,
                'currency': selectedCurrency,
                'color': template.color != null
                    ? '#${(template.color!.r * 255).round().toRadixString(16).padLeft(2, '0')}${(template.color!.g * 255).round().toRadixString(16).padLeft(2, '0')}${(template.color!.b * 255).round().toRadixString(16).padLeft(2, '0')}'
                    : null,
                'icon': template.iconName,
                'updated_at': nowIso,
              },
              onConflict: 'budget_id,name',
            )
            .select('id')
            .single();

        final newEnvId = insertRes['id'] as String;

        await supabase.from('envelope_allocations').upsert(
          <String, dynamic>{
            'envelope_id': newEnvId,
            'period_month': periodMonth,
            'amount_cents': amountCents,
            'carryover_policy': 'carryover',
            'updated_at': nowIso,
          },
          onConflict: 'envelope_id,period_month',
        );

        // 3. Prepare Links
        linksPayload.addAll(buildUniqueEnvelopeCategoryLinks(
          envelopeId: newEnvId,
          categories: template.suggestedCategories,
        ));
      }

      if (linksPayload.isNotEmpty) {
        await supabase.from('envelope_category_links').upsert(
              linksPayload,
              onConflict: 'envelope_id,category',
            );
      }

      // 4. Refresh
      await _load(bypassCache: true);
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.getUserFriendlyMessage(e));
      rethrow;
    }
  }

  Future<void> assignCategoryToPocket(String pocketId, String category) async {
    if (_isPreview) {
      _showPreviewModeToast();
      return;
    }
    try {
      await supabase.from('envelope_category_links').insert({
        'envelope_id': pocketId,
        'category': category.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _load(bypassCache: true);

      if (!mounted) return;

      // Re-sync widgets so envelope/category changes affect envelope
      // spending and top-spending breakdowns immediately.
      final authUser = ref.read(authProvider);
      ref.read(analyticsProvider.notifier).refresh(authUser.uid);
      ref.read(widgetSyncVersionProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void _showPreviewModeToast() {
    if (!mounted) return;
  }

  @override
  void dispose() {
    // If this provider instance was invalidated/disposed, we treat that as an
    // explicit invalidation signal and drop any cached month snapshot.
    final key = _lastCacheKey;
    if (key != null) {
      _pocketsMonthCache.invalidate(key);
    }
    super.dispose();
  }
}

final pocketsProvider = StateNotifierProvider.family<PocketsNotifier,
    PocketsState, PocketsScopeParams>((ref, params) {
  // If this provider is invalidated (e.g., pull-to-refresh), drop the cached
  // snapshot so the new notifier performs a true refetch.
  ref.onDispose(() {
    final authUserId = ref.read(authProvider).uid;
    if (authUserId.isEmpty) return;

    final month = params.periodMonth ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month, 1);
    final periodMonth = _formatDate(monthStart);
    final currency =
        (params.currency ?? ref.read(selectedHomeCurrencyCodeProvider) ?? '')
            .trim()
            .toUpperCase();

    final key = (
      userId: authUserId,
      scope: params.scope,
      householdId: params.householdId,
      periodMonth: periodMonth,
      currency: currency.isEmpty ? 'USD' : currency,
      includeUpcomingRecurring: params.includeUpcomingRecurring,
      allowCurrencyFallback: params.isBootstrapCurrency,
    );
    _pocketsMonthCache.invalidate(key);
  });

  // Ensure we always have the latest selected household id when in household scope
  if (params.scope == PocketsScopeType.household &&
      params.householdId == null) {
    final selected = ref.read(selectedHouseholdProvider);
    return PocketsNotifier(
      ref,
      PocketsScopeParams(
        scope: PocketsScopeType.household,
        householdId: selected.householdId,
        periodMonth: params.periodMonth,
        currency: params.currency,
        isBootstrapCurrency: params.isBootstrapCurrency,
        includeUpcomingRecurring: params.includeUpcomingRecurring,
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

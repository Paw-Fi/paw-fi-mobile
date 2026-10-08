import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/currency_summary.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';

import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final dashboardUserContactProvider =
    FutureProvider.autoDispose<UserContact?>((ref) async {
  ref.watch(dashboardRefreshSignalProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return PreviewMockData.contact;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return null;
  }

  final cachedContact = ref
      .watch(appInitializationV2Provider.select((state) => state.data?.user));
  if (cachedContact != null && cachedContact.userId == userId) {
    return cachedContact;
  }

  final response = await supabase
      .from('user_contacts')
      .select(
          'id,user_id,phone_e164,verified,preferred_currency,preferred_timezone,financial_month_start_day')
      .eq('user_id', userId)
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) {
    return null;
  }

  return UserContact.fromJson(Map<String, dynamic>.from(response));
});

final dashboardPersonalBudgetsProvider =
    FutureProvider.autoDispose<List<DailyBudgetEntry>>((ref) async {
  ref.watch(dashboardRefreshSignalProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return const <DailyBudgetEntry>[];
  }

  final contact = await ref.watch(dashboardUserContactProvider.future);
  final contactId = contact?.id;
  if (contactId == null || contactId.isEmpty) {
    return const <DailyBudgetEntry>[];
  }

  ref.watch(dashboardCacheInvalidationProvider);
  final bypassPersistedCache =
      ref.read(dashboardPersistedCacheBypassCountProvider) > 0;
  final cacheKey = dashboardBudgetsCacheKey(contactId: contactId);
  final sessionCached =
      readDashboardSessionCache<List<DailyBudgetEntry>>(cacheKey);
  if (sessionCached != null &&
      DateTime.now().difference(sessionCached.cachedAt) <=
          dashboardBudgetsCacheTtl) {
    return sessionCached.value;
  }

  if (!bypassPersistedCache) {
    final persistedPayload = readDashboardPersistedCache(ref, cacheKey);
    final statePayload = persistedPayload == null
        ? null
        : readDashboardStatePayload(persistedPayload);
    final cachedAt = persistedPayload == null
        ? null
        : readDashboardCachedAt(persistedPayload);
    if (statePayload != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) <= dashboardBudgetsCacheTtl) {
      final budgets = ((statePayload['items'] as List?) ?? const [])
          .cast<Map>()
          .map((row) =>
              DailyBudgetEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      writeDashboardSessionCache(cacheKey, budgets);
      return budgets;
    }
  }

  final response = await supabase
      .from('daily_budgets')
      .select('id,contact_id,date,amount_cents,currency')
      .eq('contact_id', contactId)
      .limit(5000)
      .order('date', ascending: true);

  final budgets = (response as List)
      .map((row) =>
          DailyBudgetEntry.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);
  writeDashboardSessionCache(cacheKey, budgets);
  unawaited(writeDashboardPersistedCache(ref, cacheKey, {
    'cached_at': DateTime.now().toIso8601String(),
    'state': {
      'items': budgets.map((item) => item.toJson()).toList(growable: false),
    },
  }));

  return budgets;
});

final dashboardActiveScopeBudgetsProvider =
    FutureProvider.autoDispose<List<DailyBudgetEntry>>((ref) async {
  final scope = ref.watch(householdScopeProvider);
  if (scope.activeAccountType != ActiveWalletType.personal) {
    return const <DailyBudgetEntry>[];
  }
  return ref.watch(dashboardPersonalBudgetsProvider.future);
});

final dashboardSelectedHomeCurrencyCodeProvider = Provider<String>((ref) {
  final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;
  final normalized = selectedCurrency?.trim().toUpperCase();
  if (normalized != null && normalized.isNotEmpty) {
    return normalized;
  }

  final preferred = ref
      .watch(dashboardUserContactProvider)
      .valueOrNull
      ?.preferredCurrency
      ?.trim()
      .toUpperCase();
  if (preferred != null && preferred.isNotEmpty) {
    return preferred;
  }

  return 'USD';
});

final dashboardHasLoggedTransactionsProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(dashboardRefreshSignalProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return true;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return false;
  }

  try {
    final database = await ref.read(localDatabaseProvider.future);
    final localRows = await database.getRecentTransactions(
      userId: userId,
      householdId: null,
      limit: 1,
    );
    if (localRows.isNotEmpty) {
      return true;
    }
  } catch (_) {
    // Local cache is an optimization here; keep the checklist resilient when
    // the DB is unavailable in tests or early app startup.
  }

  try {
    final response = await supabase.rpc(
      'get_dashboard_user_activity_v1',
      params: <String, dynamic>{
        'p_user_id': userId,
      },
    );
    final payload = Map<String, dynamic>.from(response as Map);
    return payload['has_logged_transactions'] == true;
  } catch (_) {
    return false;
  }
});

final dashboardCurrencySummariesRefreshSignalProvider =
    StateProvider<int>((ref) => 0);

final _currencySummariesRefreshGenerationByKey = <String, int>{};
final _currencyCountsRefreshGenerationByKey = <String, int>{};

final dashboardCurrencySummariesProvider =
    FutureProvider.autoDispose<List<CurrencySummary>>((ref) async {
  final refreshGeneration =
      ref.watch(dashboardCurrencySummariesRefreshSignalProvider);
  ref.watch(dashboardRefreshSignalProvider);
  ref.watch(dashboardCacheInvalidationProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    final budgetTotals = <String, double>{};
    for (final budget in PreviewMockData.budgets) {
      final code = (budget.currency ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;
      budgetTotals[code] = (budgetTotals[code] ?? 0) + budget.amount;
    }
    final rollup = <String, CurrencySummary>{};
    for (final entry in PreviewMockData.expenses.where((e) => !e.isRecurring)) {
      final code = (entry.currency ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;
      final existing = rollup[code];
      rollup[code] = CurrencySummary(
        currencyCode: code,
        totalExpenses: (existing?.totalExpenses ?? 0) + entry.spendingEffect,
        totalIncome: (existing?.totalIncome ?? 0) +
            (entry.countsTowardIncome ? entry.amount.abs() : 0),
        totalBudget: budgetTotals[code] ?? 0,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    final previewSummaries = rollup.values.toList(growable: false);

    return previewSummaries;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return const <CurrencySummary>[];
  }

  final scope = ref.watch(householdScopeProvider);
  final activeHouseholdId = scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
  final cacheKey = dashboardCurrencySummariesCacheKey(
    userId: userId,
    householdId: activeHouseholdId,
  );
  final shouldBypassCache = refreshGeneration > 0 &&
      _currencySummariesRefreshGenerationByKey[cacheKey] != refreshGeneration;

  final cachedFallback = _readCachedCurrencySummaries(ref, cacheKey);
  if (!shouldBypassCache && cachedFallback != null) {
    return cachedFallback;
  }

  try {
    final budgetsFuture = scope.activeAccountType == ActiveWalletType.personal
        ? ref.watch(dashboardPersonalBudgetsProvider.future)
        : Future<List<DailyBudgetEntry>>.value(const <DailyBudgetEntry>[]);
    final results = await Future.wait<dynamic>([
      supabase.rpc(
        'get_dashboard_currency_summaries_v1',
        params: <String, dynamic>{
          'p_user_id': userId,
          'p_household_id': activeHouseholdId,
        },
      ),
      budgetsFuture,
    ]);
    final response = results[0];
    final budgets = results[1] as List<DailyBudgetEntry>;
    final budgetTotals = <String, double>{};
    if (scope.activeAccountType == ActiveWalletType.personal) {
      for (final budget in budgets) {
        final code = (budget.currency ?? '').trim().toUpperCase();
        if (code.isEmpty) continue;
        budgetTotals[code] = (budgetTotals[code] ?? 0) + budget.amount;
      }
    }

    final rows = (response as List? ?? const []).cast<Map>();

    final summaries = rows.map((row) {
      final code = (row['currency'] as String? ?? '').toUpperCase();
      return CurrencySummary(
        currencyCode: code,
        totalExpenses: _centsToDouble(row['expense_total_cents']),
        totalIncome: _centsToDouble(row['income_total_cents']),
        totalBudget: budgetTotals[code] ?? 0,
        transactionCount: (row['transaction_count'] as num?)?.toInt() ?? 0,
      );
    }).toList(growable: false);

    writeDashboardSessionCache(cacheKey, summaries);
    _currencySummariesRefreshGenerationByKey[cacheKey] = refreshGeneration;
    unawaited(writeDashboardPersistedCache(ref, cacheKey, {
      'cached_at': DateTime.now().toIso8601String(),
      'state': {
        'items':
            summaries.map(_currencySummaryToCacheJson).toList(growable: false),
      },
    }));

    return summaries;
  } catch (error) {
    if (cachedFallback != null) {
      return cachedFallback;
    }
    rethrow;
  }
});

final dashboardCurrencyTransactionCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final refreshGeneration =
      ref.watch(dashboardCurrencySummariesRefreshSignalProvider);
  ref.watch(dashboardRefreshSignalProvider);
  ref.watch(dashboardCacheInvalidationProvider);

  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    final counts = <String, int>{};
    for (final entry in PreviewMockData.expenses.where((e) => !e.isRecurring)) {
      final code = (entry.currency ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }

    return counts;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return const <String, int>{};
  }

  final scope = ref.watch(householdScopeProvider);
  final activeHouseholdId = scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
  final cacheKey = dashboardCurrencyTransactionCountsCacheKey(
    userId: userId,
    householdId: activeHouseholdId,
  );
  final shouldBypassCache = refreshGeneration > 0 &&
      _currencyCountsRefreshGenerationByKey[cacheKey] != refreshGeneration;
  final cachedFallback = _readCachedCurrencyTransactionCounts(ref, cacheKey);
  if (!shouldBypassCache && cachedFallback != null) {
    return cachedFallback;
  }

  try {
    final counts = await _fetchDashboardCurrencyTransactionCounts(
      userId: userId,
      householdId: activeHouseholdId,
      usePersonalScope: scope.activeAccountType == ActiveWalletType.personal,
    );

    writeDashboardSessionCache(cacheKey, counts);
    _currencyCountsRefreshGenerationByKey[cacheKey] = refreshGeneration;
    unawaited(writeDashboardPersistedCache(ref, cacheKey, {
      'cached_at': DateTime.now().toIso8601String(),
      'state': {'counts': counts},
    }));

    return counts;
  } catch (error) {
    if (cachedFallback != null) {
      return cachedFallback;
    }
    rethrow;
  }
});

Future<Map<String, int>> _fetchDashboardCurrencyTransactionCounts({
  required String userId,
  required String? householdId,
  required bool usePersonalScope,
}) async {
  // This provider is opened with the currency selector rather than the Home
  // critical path. Preserve its existing PostgREST-capped row semantics: an
  // unordered capped sample cannot be grouped in a new RPC with a factual
  // guarantee that the same physical rows were selected.
  dynamic query =
      supabase.from('expenses').select('currency').isFilter('deleted_at', null);
  if (usePersonalScope) {
    query = query.eq('user_id', userId).isFilter('household_id', null);
  } else {
    query = query.eq('household_id', householdId);
  }
  final response = await query.limit(10000);
  final counts = <String, int>{};
  for (final row in (response as List? ?? const []).cast<Map>()) {
    final code = (row['currency'] as String? ?? '').trim().toUpperCase();
    if (code.isEmpty) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }
  return counts;
}

final dashboardCurrencySummaryTransactionCountsProvider =
    Provider.autoDispose<Map<String, int>>((ref) {
  final summaries = ref.watch(dashboardCurrencySummariesProvider).valueOrNull ??
      const <CurrencySummary>[];
  final counts = {
    for (final summary in summaries)
      summary.currencyCode: summary.transactionCount,
  };

  return counts;
});

double _centsToDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble() / 100;
  return (num.tryParse(value.toString()) ?? 0).toDouble() / 100;
}

List<CurrencySummary>? _readCachedCurrencySummaries(Ref ref, String cacheKey) {
  final sessionCached =
      readDashboardSessionCache<List<CurrencySummary>>(cacheKey);
  if (sessionCached != null &&
      DateTime.now().difference(sessionCached.cachedAt) <=
          dashboardCurrencySummariesCacheTtl) {
    return sessionCached.value;
  }

  final bypassPersistedCache =
      ref.read(dashboardPersistedCacheBypassCountProvider) > 0;
  if (bypassPersistedCache) {
    return null;
  }

  final persistedPayload = readDashboardPersistedCache(ref, cacheKey);
  final statePayload = persistedPayload == null
      ? null
      : readDashboardStatePayload(persistedPayload);
  final cachedAt =
      persistedPayload == null ? null : readDashboardCachedAt(persistedPayload);
  if (statePayload == null ||
      cachedAt == null ||
      DateTime.now().difference(cachedAt) >
          dashboardCurrencySummariesCacheTtl) {
    return null;
  }

  final summaries = ((statePayload['items'] as List?) ?? const [])
      .whereType<Map>()
      .map((row) => _currencySummaryFromCacheJson(
            Map<String, dynamic>.from(row),
          ))
      .toList(growable: false);
  writeDashboardSessionCache(cacheKey, summaries);

  return summaries;
}

Map<String, int>? _readCachedCurrencyTransactionCounts(
  Ref ref,
  String cacheKey,
) {
  final sessionCached = readDashboardSessionCache<Map<String, int>>(cacheKey);
  if (sessionCached != null &&
      DateTime.now().difference(sessionCached.cachedAt) <=
          dashboardCurrencyTransactionCountsCacheTtl) {
    return sessionCached.value;
  }

  final bypassPersistedCache =
      ref.read(dashboardPersistedCacheBypassCountProvider) > 0;
  if (bypassPersistedCache) {
    return null;
  }

  final persistedPayload = readDashboardPersistedCache(ref, cacheKey);
  final statePayload = persistedPayload == null
      ? null
      : readDashboardStatePayload(persistedPayload);
  final cachedAt =
      persistedPayload == null ? null : readDashboardCachedAt(persistedPayload);
  if (statePayload == null ||
      cachedAt == null ||
      DateTime.now().difference(cachedAt) >
          dashboardCurrencyTransactionCountsCacheTtl) {
    return null;
  }

  final rawCounts = statePayload['counts'];
  if (rawCounts is! Map) {
    return null;
  }

  final counts = <String, int>{
    for (final entry in rawCounts.entries)
      entry.key.toString().trim().toUpperCase():
          (entry.value is num ? (entry.value as num).toInt() : 0),
  }..removeWhere((key, value) => key.isEmpty);
  writeDashboardSessionCache(cacheKey, counts);

  return counts;
}

Map<String, dynamic> _currencySummaryToCacheJson(CurrencySummary summary) {
  return {
    'currency_code': summary.currencyCode,
    'total_expenses': summary.totalExpenses,
    'total_income': summary.totalIncome,
    'total_budget': summary.totalBudget,
    'transaction_count': summary.transactionCount,
  };
}

CurrencySummary _currencySummaryFromCacheJson(Map<String, dynamic> json) {
  return CurrencySummary(
    currencyCode: (json['currency_code'] as String? ?? '').toUpperCase(),
    totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0,
    totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0,
    totalBudget: (json['total_budget'] as num?)?.toDouble() ?? 0,
    transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
  );
}

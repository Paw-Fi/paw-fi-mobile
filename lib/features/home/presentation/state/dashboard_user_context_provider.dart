import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/currency_summary.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final dashboardUserContactProvider =
    FutureProvider.autoDispose<UserContact?>((ref) async {
  final trace = HomeDebugTrace(
    label: 'DashboardUserContact',
    enabled: ref.read(homeDebugLoggingEnabledProvider),
    logSink: ref.read(homeDebugLogSinkProvider),
  );
  ref.watch(dashboardRefreshSignalProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    trace.mark('preview-hit');
    return PreviewMockData.contact;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    trace.mark('load-skipped', const {'reason': 'empty-user'});
    return null;
  }

  final cachedContact = ref
      .watch(appInitializationV2Provider.select((state) => state.data?.user));
  if (cachedContact != null) {
    trace.mark('cache-hit', {'user': userId});
    return cachedContact;
  }

  trace.mark('load-start', {'user': userId});

  final response = await supabase
      .from('user_contacts')
      .select(
          'id,user_id,phone_e164,verified,preferred_currency,preferred_timezone')
      .eq('user_id', userId)
      .order('updated_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) {
    trace.mark('load-success', const {'hasContact': false});
    return null;
  }
  trace.mark('load-success', const {'hasContact': true});
  return UserContact.fromJson(Map<String, dynamic>.from(response));
});

final dashboardPersonalBudgetsProvider =
    FutureProvider.autoDispose<List<DailyBudgetEntry>>((ref) async {
  final trace = HomeDebugTrace(
    label: 'DashboardPersonalBudgets',
    enabled: ref.read(homeDebugLoggingEnabledProvider),
    logSink: ref.read(homeDebugLogSinkProvider),
  );
  ref.watch(dashboardRefreshSignalProvider);
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    trace.mark('preview-hit');
    return const <DailyBudgetEntry>[];
  }

  final contact = await ref.watch(dashboardUserContactProvider.future);
  final contactId = contact?.id;
  if (contactId == null || contactId.isEmpty) {
    trace.mark('load-skipped', const {'reason': 'missing-contact'});
    return const <DailyBudgetEntry>[];
  }

  trace.mark('load-start', {'contactId': contactId});

  ref.watch(dashboardCacheInvalidationProvider);
  final bypassPersistedCache =
      ref.watch(dashboardPersistedCacheBypassCountProvider) > 0;
  final cacheKey = dashboardBudgetsCacheKey(contactId: contactId);
  final sessionCached =
      readDashboardSessionCache<List<DailyBudgetEntry>>(cacheKey);
  if (sessionCached != null &&
      DateTime.now().difference(sessionCached.cachedAt) <=
          dashboardBudgetsCacheTtl) {
    trace.mark('session-cache-hit', {'count': sessionCached.value.length});
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
      trace.mark('persisted-cache-hit', {'count': budgets.length});
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
  trace.mark('load-success', {'count': budgets.length});
  return budgets;
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

  final response = await supabase.rpc(
    'get_dashboard_user_activity_v1',
    params: <String, dynamic>{
      'p_user_id': userId,
    },
  );
  final payload = Map<String, dynamic>.from(response as Map);
  return payload['has_logged_transactions'] == true;
});

final dashboardCurrencySummariesRefreshSignalProvider =
    StateProvider<int>((ref) => 0);

final _currencySummariesRefreshGenerationByKey = <String, int>{};
final _currencyCountsRefreshGenerationByKey = <String, int>{};

void _debugCurrencySummaries(String message) {
  if (foundation.kDebugMode) {
    foundation.debugPrint('[CurrencySelector][Summaries] $message');
  }
}

String _summaryCountsDebug(Iterable<CurrencySummary> summaries) {
  final counts = <String, int>{
    for (final summary in summaries)
      summary.currencyCode: summary.transactionCount,
  };
  return counts.toString();
}

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
      final isIncome = (entry.type ?? 'expense').toLowerCase() == 'income';
      rollup[code] = CurrencySummary(
        currencyCode: code,
        totalExpenses: (existing?.totalExpenses ?? 0) +
            (isIncome ? 0 : entry.amount.abs()),
        totalIncome:
            (existing?.totalIncome ?? 0) + (isIncome ? entry.amount.abs() : 0),
        totalBudget: budgetTotals[code] ?? 0,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    final previewSummaries = rollup.values.toList(growable: false);
    _debugCurrencySummaries(
      'preview summaries=${previewSummaries.length} counts=${_summaryCountsDebug(previewSummaries)}',
    );
    return previewSummaries;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    _debugCurrencySummaries('skip fetch: empty user id');
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
  _debugCurrencySummaries(
    'start user=$userId scope=${scope.activeAccountType.name} household=${activeHouseholdId ?? '<personal>'} refreshGeneration=$refreshGeneration cacheKey=$cacheKey bypass=$shouldBypassCache',
  );
  final cachedFallback = _readCachedCurrencySummaries(ref, cacheKey);
  if (!shouldBypassCache && cachedFallback != null) {
    _debugCurrencySummaries(
      'cache-hit key=$cacheKey summaries=${cachedFallback.length} counts=${_summaryCountsDebug(cachedFallback)}',
    );
    return cachedFallback;
  }

  try {
    _debugCurrencySummaries(
      'rpc-start p_user_id=$userId p_household_id=${activeHouseholdId ?? '<null>'}',
    );
    final response = await supabase.rpc(
      'get_dashboard_currency_summaries_v1',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_household_id': activeHouseholdId,
      },
    );

    final budgets = await ref.watch(dashboardPersonalBudgetsProvider.future);
    final budgetTotals = <String, double>{};
    if (scope.activeAccountType == ActiveWalletType.personal) {
      for (final budget in budgets) {
        final code = (budget.currency ?? '').trim().toUpperCase();
        if (code.isEmpty) continue;
        budgetTotals[code] = (budgetTotals[code] ?? 0) + budget.amount;
      }
    }

    final rows = (response as List? ?? const []).cast<Map>();
    _debugCurrencySummaries(
      'rpc-raw rows=${rows.length} raw=${rows.take(8).map((row) => Map<String, dynamic>.from(row)).toList(growable: false)}',
    );
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
    _debugCurrencySummaries(
      'rpc-success key=$cacheKey summaries=${summaries.length} counts=${_summaryCountsDebug(summaries)}',
    );
    return summaries;
  } catch (error, stackTrace) {
    _debugCurrencySummaries(
      'rpc-error key=$cacheKey error=$error stack=$stackTrace',
    );
    if (cachedFallback != null) {
      _debugCurrencySummaries(
        'fallback-cache key=$cacheKey summaries=${cachedFallback.length} counts=${_summaryCountsDebug(cachedFallback)}',
      );
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
    _debugCurrencySummaries('direct-counts preview counts=$counts');
    return counts;
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    _debugCurrencySummaries('direct-counts skip fetch: empty user id');
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
    _debugCurrencySummaries(
      'direct-counts cache-hit key=$cacheKey counts=$cachedFallback',
    );
    return cachedFallback;
  }

  try {
    _debugCurrencySummaries(
      'direct-counts query-start user=$userId scope=${scope.activeAccountType.name} household=${activeHouseholdId ?? '<personal>'} key=$cacheKey bypass=$shouldBypassCache',
    );

    dynamic query = supabase
        .from('expenses')
        .select('currency,household_id,user_id,is_recurring,type,deleted_at')
        .isFilter('deleted_at', null);
    if (scope.activeAccountType == ActiveWalletType.personal) {
      query = query.eq('user_id', userId).isFilter('household_id', null);
    } else {
      query = query.eq('household_id', activeHouseholdId);
    }

    final response = await query.limit(10000);
    final rows = (response as List? ?? const []).cast<Map>();
    final counts = <String, int>{};
    for (final row in rows) {
      final code = (row['currency'] as String? ?? '').trim().toUpperCase();
      if (code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }

    writeDashboardSessionCache(cacheKey, counts);
    _currencyCountsRefreshGenerationByKey[cacheKey] = refreshGeneration;
    unawaited(writeDashboardPersistedCache(ref, cacheKey, {
      'cached_at': DateTime.now().toIso8601String(),
      'state': {'counts': counts},
    }));
    _debugCurrencySummaries(
      'direct-counts query-success key=$cacheKey rows=${rows.length} counts=$counts sample=${rows.take(8).map((row) => Map<String, dynamic>.from(row)).toList(growable: false)}',
    );
    return counts;
  } catch (error, stackTrace) {
    _debugCurrencySummaries(
      'direct-counts query-error key=$cacheKey error=$error stack=$stackTrace',
    );
    if (cachedFallback != null) {
      _debugCurrencySummaries(
        'direct-counts fallback-cache key=$cacheKey counts=$cachedFallback',
      );
      return cachedFallback;
    }
    rethrow;
  }
});

final dashboardCurrencySummaryTransactionCountsProvider =
    Provider.autoDispose<Map<String, int>>((ref) {
  final summaries = ref.watch(dashboardCurrencySummariesProvider).valueOrNull ??
      const <CurrencySummary>[];
  final counts = {
    for (final summary in summaries)
      summary.currencyCode: summary.transactionCount,
  };
  _debugCurrencySummaries(
    'summary-derived-counts summaries=${summaries.length} counts=$counts',
  );
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
    _debugCurrencySummaries(
      'session-cache-read key=$cacheKey age=${DateTime.now().difference(sessionCached.cachedAt).inSeconds}s count=${sessionCached.value.length}',
    );
    return sessionCached.value;
  }

  final bypassPersistedCache =
      ref.watch(dashboardPersistedCacheBypassCountProvider) > 0;
  if (bypassPersistedCache) {
    _debugCurrencySummaries('persisted-cache-skip key=$cacheKey bypass=true');
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
    _debugCurrencySummaries(
      'persisted-cache-miss key=$cacheKey hasState=${statePayload != null} cachedAt=${cachedAt?.toIso8601String() ?? '<none>'}',
    );
    return null;
  }

  final summaries = ((statePayload['items'] as List?) ?? const [])
      .whereType<Map>()
      .map((row) => _currencySummaryFromCacheJson(
            Map<String, dynamic>.from(row),
          ))
      .toList(growable: false);
  writeDashboardSessionCache(cacheKey, summaries);
  _debugCurrencySummaries(
    'persisted-cache-read key=$cacheKey age=${DateTime.now().difference(cachedAt).inSeconds}s summaries=${summaries.length} counts=${_summaryCountsDebug(summaries)}',
  );
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
    _debugCurrencySummaries(
      'direct-counts session-cache-read key=$cacheKey age=${DateTime.now().difference(sessionCached.cachedAt).inSeconds}s counts=${sessionCached.value}',
    );
    return sessionCached.value;
  }

  final bypassPersistedCache =
      ref.watch(dashboardPersistedCacheBypassCountProvider) > 0;
  if (bypassPersistedCache) {
    _debugCurrencySummaries(
      'direct-counts persisted-cache-skip key=$cacheKey bypass=true',
    );
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
    _debugCurrencySummaries(
      'direct-counts persisted-cache-miss key=$cacheKey hasState=${statePayload != null} cachedAt=${cachedAt?.toIso8601String() ?? '<none>'}',
    );
    return null;
  }

  final rawCounts = statePayload['counts'];
  if (rawCounts is! Map) {
    _debugCurrencySummaries(
      'direct-counts persisted-cache-invalid key=$cacheKey raw=$rawCounts',
    );
    return null;
  }

  final counts = <String, int>{
    for (final entry in rawCounts.entries)
      entry.key.toString().trim().toUpperCase():
          (entry.value is num ? (entry.value as num).toInt() : 0),
  }..removeWhere((key, value) => key.isEmpty);
  writeDashboardSessionCache(cacheKey, counts);
  _debugCurrencySummaries(
    'direct-counts persisted-cache-read key=$cacheKey age=${DateTime.now().difference(cachedAt).inSeconds}s counts=$counts',
  );
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

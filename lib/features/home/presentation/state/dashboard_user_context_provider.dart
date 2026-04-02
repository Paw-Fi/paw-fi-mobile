import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/currency_summary.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
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

  final response = await supabase
      .from('user_contacts')
      .select(
          'id,user_id,phone_e164,verified,preferred_currency,preferred_timezone')
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

  final response = await supabase
      .from('daily_budgets')
      .select('id,contact_id,date,amount_cents,currency')
      .eq('contact_id', contactId)
      .limit(5000)
      .order('date', ascending: true);

  return (response as List)
      .map((row) =>
          DailyBudgetEntry.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);
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

final dashboardCurrencySummariesProvider =
    FutureProvider.autoDispose<List<CurrencySummary>>((ref) async {
  ref.watch(dashboardRefreshSignalProvider);
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
    return rollup.values.toList(growable: false);
  }

  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) {
    return const <CurrencySummary>[];
  }

  final scope = ref.watch(householdScopeProvider);
  final response = await supabase.rpc(
    'get_dashboard_currency_summaries_v1',
    params: <String, dynamic>{
      'p_user_id': userId,
      'p_household_id': scope.activeAccountType == ActiveAccountType.personal
          ? null
          : scope.activeAccountHouseholdId,
    },
  );

  final budgets = await ref.watch(dashboardPersonalBudgetsProvider.future);
  final budgetTotals = <String, double>{};
  if (scope.activeAccountType == ActiveAccountType.personal) {
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

  return summaries;
});

final dashboardCurrencyTransactionCountsProvider =
    Provider.autoDispose<Map<String, int>>((ref) {
  final summaries = ref.watch(dashboardCurrencySummariesProvider).valueOrNull ??
      const <CurrencySummary>[];
  return {
    for (final summary in summaries)
      summary.currencyCode: summary.transactionCount,
  };
});

double _centsToDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble() / 100;
  return (num.tryParse(value.toString()) ?? 0).toDouble() / 100;
}

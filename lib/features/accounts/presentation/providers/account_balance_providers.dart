import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final scopedAccountSummaryProvider = Provider<Map<String, int>>((ref) {
  final accounts = ref.watch(scopedAccountsProvider).valueOrNull ?? const [];
  final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
  final allExpenses = ref.watch(analyticsProvider).allExpenses;
  final scope = ref.watch(householdScopeProvider);

  final defaultAccountId = _resolveDefaultAccountId(accounts);
  final balances = <String, int>{
    for (final account in accounts) account.id: account.openingBalanceCents,
  };
  var totalGoalCents = 0;
  for (final account in accounts) {
    totalGoalCents += account.goalAmountCents ?? 0;
  }

  for (final expense in allExpenses) {
    if (expense.isRecurring) continue;
    if (!_isInActiveScope(expense, scope)) continue;
    if (!_isInSelectedCurrency(expense, currencyCode)) continue;

    final accountId = _resolveTransactionAccountId(
      transaction: expense,
      defaultAccountId: defaultAccountId,
    );
    if (accountId == null || !balances.containsKey(accountId)) continue;

    final amountCents = (expense.amount.abs() * 100).round();
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    final current = balances[accountId] ?? 0;
    balances[accountId] =
        isIncome ? current + amountCents : current - amountCents;
  }

  var totalBalanceCents = 0;
  for (final value in balances.values) {
    totalBalanceCents += value;
  }

  return {
    'totalBalanceCents': totalBalanceCents,
    'totalGoalCents': totalGoalCents,
    'count': accounts.length,
  };
});

final accountTransfersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return const [];
});

String? _resolveDefaultAccountId(List<AccountEntity> accounts) {
  for (final account in accounts) {
    if (account.isDefault && !account.isArchived) {
      return account.id;
    }
  }
  for (final account in accounts) {
    if (account.isSystem &&
        account.name.trim().toLowerCase() == 'spending' &&
        !account.isArchived) {
      return account.id;
    }
  }
  return accounts.isNotEmpty ? accounts.first.id : null;
}

String? _resolveTransactionAccountId({
  required ExpenseEntry transaction,
  required String? defaultAccountId,
}) {
  final raw = transaction.accountId?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return defaultAccountId;
}

bool _isInSelectedCurrency(ExpenseEntry expense, String currencyCode) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == currencyCode;
}

bool _isInActiveScope(ExpenseEntry expense, HouseholdScope scope) {
  final householdId = expense.householdId;
  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      return householdId == null || householdId.isEmpty;
    case ActiveAccountType.portfolio:
      final selected = scope.activeAccountHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
    case ActiveAccountType.household:
      final selected = scope.selectedHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
  }
}

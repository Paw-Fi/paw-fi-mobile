import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final scopedWalletSummaryProvider = Provider<Map<String, int>>((ref) {
  final wallets = ref.watch(scopedWalletSummaryProvider).valueOrNull ?? const [];
  final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
  final allExpenses = ref.watch(analyticsProvider).allExpenses;
  final scope = ref.watch(householdScopeProvider);

  final defaultAccountId = _resolveDefaultAccountId(wallets);
  final balances = <String, int>{
    for (final wallet in wallets) wallet.id: wallet.openingBalanceCents,
  };
  var totalGoalCents = 0;
  for (final wallet in wallets) {
totalGoalCents += (wallet.goalAmountCents ?? 0) as int;
  }

  for (final expense in allExpenses) {
    if (expense.isRecurring) continue;
    if (!_isInActiveScope(expense, scope)) continue;
    if (!_isInSelectedCurrency(expense, currencyCode)) continue;

    final accountId = _resolveTransactionWalletId(
      transaction: expense,
      defaultWalletId: defaultAccountId,
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
    'count': wallets.length,
  };
});

final accountTransfersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return const [];
});

String? _resolveDefaultAccountId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault && !wallet.isArchived) {
      return wallet.id;
    }
  }
  for (final wallet in wallets) {
    if (wallet.isSystem &&
        wallet.name.trim().toLowerCase() == 'spending' &&
        !wallet.isArchived) {
      return wallet.id;
    }
  }
  return wallets.isNotEmpty ? wallets.first.id : null;
}

String? _resolveTransactionWalletId({
  required ExpenseEntry transaction,
  required String? defaultWalletId,
}) {
  final raw = transaction.walletId?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return defaultWalletId;
}

bool _isInSelectedCurrency(ExpenseEntry expense, String currencyCode) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == currencyCode;
}

bool _isInActiveScope(ExpenseEntry expense, HouseholdScope scope) {
  final householdId = expense.householdId;
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return householdId == null || householdId.isEmpty;
    case ActiveWalletType.portfolio:
      final selected = scope.activeAccountHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
    case ActiveWalletType.household:
      final selected = scope.selectedHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
  }
}

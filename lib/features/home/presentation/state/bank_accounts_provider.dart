import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final bankAccountsProvider =
    FutureProvider.autoDispose<List<BankAccount>>((ref) async {
  final user = ref.watch(authProvider);
  final scope = ref.watch(householdScopeProvider);
  ref.watch(bankSyncResultProvider);
  if (user.uid.isEmpty) return const [];

  final allAccounts = await _fetchBankAccounts();

  List<BankAccount> scoped;
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      scoped = allAccounts
          .where((account) =>
              account.connectionHouseholdId == null ||
              account.connectionHouseholdId!.isEmpty)
          .toList();
      break;
    case ActiveWalletType.household:
    case ActiveWalletType.portfolio:
      final householdId = scope.activeAccountHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        scoped = [];
      } else {
        scoped = allAccounts
            .where((account) => account.connectionHouseholdId == householdId)
            .toList();
      }
      break;
  }

  scoped.removeWhere((account) => account.connectionStatus == 'disabled');
  scoped.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return scoped;
});

/// All visible accounts, intentionally unfiltered by the currently selected
/// wallet/household scope. This is used by the connection-management surface,
/// whose connection list is also intentionally unscoped.
final allVisibleBankAccountsProvider =
    FutureProvider.autoDispose<List<BankAccount>>((ref) async {
  final user = ref.watch(authProvider);
  ref.watch(bankSyncResultProvider);
  if (user.uid.isEmpty) return const [];

  final accounts = await _fetchBankAccounts();
  accounts.removeWhere((account) => account.connectionStatus == 'disabled');
  accounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return accounts;
});

Future<List<BankAccount>> _fetchBankAccounts() async {
  final response = await supabase.rpc('list_mobile_bank_accounts');
  final rows = (response as List?)?.cast<Map<String, dynamic>>() ?? const [];
  return rows.map(BankAccount.fromJson).toList();
}

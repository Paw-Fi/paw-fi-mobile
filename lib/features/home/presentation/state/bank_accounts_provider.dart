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

  final response = await supabase
      .from('bank_accounts')
      .select('*, bank_connections(household_id,status,provider)')
      .eq('user_id', user.uid);

  final rows = (response as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final allAccounts = rows.map(BankAccount.fromJson).toList();

  List<BankAccount> scoped;
  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      scoped = allAccounts
          .where((account) =>
              account.connectionHouseholdId == null ||
              account.connectionHouseholdId!.isEmpty)
          .toList();
      break;
    case ActiveAccountType.household:
    case ActiveAccountType.portfolio:
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

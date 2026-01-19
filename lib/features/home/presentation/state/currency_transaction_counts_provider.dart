import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

/// Returns a map of `CURRENCY_CODE -> transactionCount` for the current user.
///
/// Notes:
/// - Counts are computed from the `expenses` table and include both expenses and
///   income rows (since both live in that table).
/// - This mirrors the query previously implemented inside
///   `currency_selector_modal.dart`, but moved to a provider so the UI remains
///   reactive and consistent with the app's data flow.
final currencyTransactionCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final authState = ref.watch(authProvider);
  final scope = ref.watch(householdScopeProvider);
  final userId = authState.uid;
  if (userId.isEmpty) return const <String, int>{};

  var query = supabase
      .from('expenses')
      .select('currency')
      .eq('user_id', userId)
      .not('currency', 'is', null);

  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      // Personal mode should include entries where household_id is null/empty.
      query = query.or('household_id.is.null,household_id.eq.');
      break;
    case ActiveAccountType.household:
    case ActiveAccountType.portfolio:
      final householdId = scope.activeAccountHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return const <String, int>{};
      }
      query = query.eq('household_id', householdId);
      break;
  }

  final response = await query.limit(5000);
  final rows = (response as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final counts = <String, int>{};

  for (final row in rows) {
    final code = (row['currency'] as String?)?.toUpperCase();
    if (code == null || code.isEmpty) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }

  return counts;
});

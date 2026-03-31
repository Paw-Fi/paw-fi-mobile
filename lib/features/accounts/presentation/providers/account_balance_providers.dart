import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';

final scopedAccountSummaryProvider = Provider<Map<String, int>>((ref) {
  final accounts = ref.watch(scopedAccountsProvider).valueOrNull ?? const [];
  var totalBalanceCents = 0;
  var totalGoalCents = 0;

  for (final account in accounts) {
    totalBalanceCents += account.currentBalanceCents;
    totalGoalCents += account.goalAmountCents ?? 0;
  }

  return {
    'totalBalanceCents': totalBalanceCents,
    'totalGoalCents': totalGoalCents,
    'count': accounts.length,
  };
});

final accountTransfersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  // Transfer history is not surfaced in v1 list payload.
  return const [];
});

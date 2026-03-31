import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

final accountScopeHouseholdIdProvider = Provider<String?>((ref) {
  final scope = ref.watch(householdScopeProvider);
  return scope.activeAccountType == ActiveAccountType.personal
      ? null
      : scope.activeAccountHouseholdId;
});

final scopedAccountsProvider = FutureProvider<List<AccountEntity>>((ref) async {
  final householdId = ref.watch(accountScopeHouseholdIdProvider);
  final response = await supabase.functions.invoke(
    'list-accounts',
    body: {
      if (householdId != null) 'householdId': householdId,
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    final message = payload?['error']?.toString() ?? 'Failed to load accounts';
    throw Exception(message);
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(AccountEntity.fromJson)
      .toList(growable: false);
});

final defaultScopedAccountProvider = Provider<AccountEntity?>((ref) {
  final accounts = ref.watch(scopedAccountsProvider).valueOrNull ?? const [];
  for (final account in accounts) {
    if (account.isDefault) return account;
  }
  return accounts.isNotEmpty ? accounts.first : null;
});

final accountByIdProvider = Provider.family<AccountEntity?, String>((ref, id) {
  final accounts = ref.watch(scopedAccountsProvider).valueOrNull ?? const [];
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
});

class AccountActions {
  const AccountActions(this.ref);

  final Ref ref;

  Future<void> createAccount({
    required String name,
    required String icon,
    required String color,
    int openingBalanceCents = 0,
    int? goalAmountCents,
    bool isDefault = false,
  }) async {
    final householdId = ref.read(accountScopeHouseholdIdProvider);
    final response = await supabase.functions.invoke(
      'save-account',
      body: {
        'name': name,
        'icon': icon,
        'color': color,
        'openingBalanceCents': openingBalanceCents,
        'goalAmountCents': goalAmountCents,
        'isDefault': isDefault,
        if (householdId != null) 'householdId': householdId,
      },
    );
    _throwIfFailed(response.data, 'Failed to create account');
    _invalidateAll();
  }

  Future<void> updateAccount({
    required String accountId,
    String? name,
    String? icon,
    String? color,
    int? goalAmountCents,
    bool includeGoalAmount = false,
    bool? isDefault,
  }) async {
    final response = await supabase.functions.invoke(
      'update-account',
      body: {
        'accountId': accountId,
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (includeGoalAmount || goalAmountCents != null)
          'goalAmountCents': goalAmountCents,
        if (isDefault != null) 'isDefault': isDefault,
      },
    );
    _throwIfFailed(response.data, 'Failed to update account');
    _invalidateAll();
  }

  Future<void> archiveAccount(String accountId) async {
    final response = await supabase.functions.invoke(
      'archive-account',
      body: {'accountId': accountId},
    );
    _throwIfFailed(response.data, 'Failed to archive account');
    _invalidateAll();
  }

  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    required String currency,
    required DateTime date,
    String? note,
  }) async {
    final response = await supabase.functions.invoke(
      'create-account-transfer',
      body: {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents,
        'currency': currency,
        'date': formatDateOnlyYmd(date),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    _throwIfFailed(response.data, 'Failed to create transfer');
    _invalidateAll();
  }

  Future<void> updateBalance({
    required String accountId,
    required int targetBalanceCents,
    String? note,
  }) async {
    final response = await supabase.functions.invoke(
      'update-account-balance',
      body: {
        'accountId': accountId,
        'targetBalanceCents': targetBalanceCents,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    _throwIfFailed(response.data, 'Failed to update account balance');
    _invalidateAll();
  }

  void _throwIfFailed(dynamic data, String fallback) {
    if (data is Map<String, dynamic> && data['success'] == true) {
      return;
    }
    final message = data is Map<String, dynamic>
        ? data['error']?.toString() ?? fallback
        : fallback;
    throw Exception(message);
  }

  void _invalidateAll() {
    ref.invalidate(scopedAccountsProvider);
    ref.invalidate(analyticsProvider);
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(recurringTransactionsProvider);
  }
}

final accountActionsProvider = Provider<AccountActions>((ref) {
  return AccountActions(ref);
});

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

final walletScopeHouseholdIdProvider = Provider<String?>((ref) {
  final scope = ref.watch(householdScopeProvider);
  return scope.activeAccountType == ActiveWalletType.personal
      ? null
      : scope.activeAccountHouseholdId;
});

final walletsByHouseholdIdProvider =
    FutureProvider.family<List<WalletEntity>, String?>(
        (ref, householdId) async {
  final response = await supabase.functions.invoke(
    'list-accounts',
    body: {
      if (householdId != null && householdId.trim().isNotEmpty)
        'householdId': householdId,
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    final message = payload?['error']?.toString() ?? 'Failed to load wallets';
    throw Exception(message);
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(WalletEntity.fromJson)
      .toList(growable: false);
});

final optimisticScopedAccountsOverridesProvider =
    StateProvider<Map<String, WalletEntity>>((ref) => const {});

List<WalletEntity> _mergeOptimisticAccounts(
  List<WalletEntity> baseWallets,
  Map<String, WalletEntity> optimisticOverrides,
) {
  if (optimisticOverrides.isEmpty) {
    return baseWallets;
  }

  if (baseWallets.isEmpty) {
    return optimisticOverrides.values.toList(growable: false);
  }

  final merged = baseWallets
      .map((wallet) => optimisticOverrides[wallet.id] ?? wallet)
      .toList(growable: true);

  final existingIds = merged.map((wallet) => wallet.id).toSet();
  for (final optimistic in optimisticOverrides.values) {
    if (!existingIds.contains(optimistic.id)) {
      merged.add(optimistic);
    }
  }

  return merged;
}

final archivedScopedAccountsProvider =
    FutureProvider<List<WalletEntity>>((ref) async {
  final householdId = ref.watch(walletScopeHouseholdIdProvider);
  final response = await supabase.functions.invoke(
    'list-accounts',
    body: {
      'includeArchived': true,
      if (householdId != null) 'householdId': householdId,
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    final message = payload?['error']?.toString() ?? 'Failed to load accwalletsounts';
    throw Exception(message);
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(WalletEntity.fromJson)
      .where((wallet) => wallet.isArchived)
      .toList(growable: false);
});

final scopedWalletsProvider = FutureProvider<List<WalletEntity>>((ref) async {
  final householdId = ref.watch(walletScopeHouseholdIdProvider);
  return ref.watch(walletsByHouseholdIdProvider(householdId).future);
});

final effectiveScopeWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final baseAccounts =
      ref.watch(scopedWalletsProvider).valueOrNull ?? const [];
  final optimisticOverrides =
      ref.watch(optimisticScopedAccountsOverridesProvider);
  return _mergeOptimisticAccounts(baseAccounts, optimisticOverrides);
});

final defaultScopedAccountProvider = Provider<WalletEntity?>((ref) {
  final wallets = ref.watch(effectiveScopeWalletsProvider);
  for (final wallet in wallets) {
    if (wallet.isDefault) return wallet;
  }
  return wallets.isNotEmpty ? wallets.first : null;
});

final walletByIdProvider = Provider.family<WalletEntity?, String>((ref, id) {
  final wallets = ref.watch(effectiveScopeWalletsProvider);
  for (final wallet in wallets) {
    if (wallet.id == id) return wallet;
  }
  return null;
});

final serverWalletByIdProvider =
    Provider.family<WalletEntity?, String>((ref, id) {
  final accounts = ref.watch(scopedWalletsProvider).valueOrNull ?? const [];
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
});

class WalletActions {
  const WalletActions(this.ref);

  final Ref ref;

  void setOptimisticWallet(WalletEntity account) {
    debugPrint(
      '[Accounts][Optimistic] set accountId=${account.id} name=${account.name} color=${account.color} opening=${account.openingBalanceCents}',
    );
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state = {
      ...overrides,
      account.id: account,
    };
  }

  void clearOptimisticWallet(String accountId) {
    debugPrint('[Accounts][Optimistic] clear accountId=$accountId');
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    if (!overrides.containsKey(accountId)) {
      return;
    }
    final nextOverrides = <String, WalletEntity>{...overrides}
      ..remove(accountId);
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state =
        nextOverrides;
  }

  void reconcileOptimisticAccountWithServer(WalletEntity serverAccount) {
    final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
    final optimistic = overrides[serverAccount.id];
    if (optimistic == null) {
      return;
    }

    final isSynced = optimistic.name == serverAccount.name &&
        optimistic.icon == serverAccount.icon &&
        optimistic.color == serverAccount.color &&
        optimistic.openingBalanceCents == serverAccount.openingBalanceCents &&
        optimistic.goalAmountCents == serverAccount.goalAmountCents &&
        optimistic.isDefault == serverAccount.isDefault;

    if (!isSynced) {
      return;
    }

    debugPrint(
      '[Accounts][Optimistic] reconcile success accountId=${serverAccount.id}; clearing override',
    );
    clearOptimisticWallet(serverAccount.id);
  }

  void refreshAccountData() {
    _invalidateAll();
  }

  Future<void> createAccount({
    required String name,
    required String icon,
    required String color,
    int openingBalanceCents = 0,
    int? goalAmountCents,
    bool isDefault = false,
  }) async {
    final householdId = ref.read(walletScopeHouseholdIdProvider);
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
    _throwIfFailed(response.data, 'Failed to create wallet');
    _invalidateAll();
  }

  Future<void> updateAccount({
    required String walletId,
    String? name,
    String? icon,
    String? color,
    int? goalAmountCents,
    bool includeGoalAmount = false,
    bool? isDefault,
    bool invalidate = true,
  }) async {
    debugPrint(
      '[Accounts][Update] start accountId=$walletId name=$name icon=$icon color=$color goal=$goalAmountCents includeGoal=$includeGoalAmount isDefault=$isDefault invalidate=$invalidate',
    );
    final response = await supabase.functions.invoke(
      'update-account',
      body: {
        'accountId': walletId,
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (includeGoalAmount || goalAmountCents != null)
          'goalAmountCents': goalAmountCents,
        if (isDefault != null) 'isDefault': isDefault,
      },
    );
    _throwIfFailed(response.data, 'Failed to update wallet');
    debugPrint('[Accounts][Update] success accountId=$walletId');
    if (invalidate) {
      _invalidateAll();
    }
  }

  Future<void> archiveAccount(String accountId) async {
    final response = await supabase.functions.invoke(
      'archive-account',
      body: {'accountId': accountId},
    );
    _throwIfFailed(response.data, 'Failed to archive wallet');
    _invalidateAll();
  }

  Future<void> restoreAccount(String accountId) async {
    final response = await supabase.functions.invoke(
      'restore-account',
      body: {'accountId': accountId},
    );
    _throwIfFailed(response.data, 'Failed to restore wallet');
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
    required String walletId,
    required int targetBalanceCents,
    String? note,
    bool invalidate = true,
  }) async {
    debugPrint(
      '[Accounts][Balance] start accountId=$walletId targetBalanceCents=$targetBalanceCents invalidate=$invalidate',
    );
    final response = await supabase.functions.invoke(
      'update-account-balance',
      body: {
        'accountId': walletId,
        'targetBalanceCents': targetBalanceCents,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    _throwIfFailed(response.data, 'Failed to update account balance');
    debugPrint('[Accounts][Balance] success accountId=$walletId');
    if (invalidate) {
      _invalidateAll();
    }
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
    final overridesCountBefore =
        ref.read(optimisticScopedAccountsOverridesProvider).length;
    debugPrint(
      '[Accounts][Invalidate] start optimisticOverridesBefore=$overridesCountBefore',
    );
    ref.invalidate(walletsByHouseholdIdProvider);
    ref.invalidate(scopedWalletsProvider);
    ref.invalidate(archivedScopedAccountsProvider);
    final userId = ref.read(authProvider).uid;
    if (userId.isNotEmpty) {
      debugPrint(
          '[Accounts][Invalidate] trigger analytics reload userId=$userId');
      unawaited(
        ref.read(analyticsProvider.notifier).loadData(
              userId,
              forceReload: true,
            ),
      );
    }
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(recurringTransactionsProvider);
    debugPrint('[Accounts][Invalidate] done');
  }
}

final walletActionsProvider = Provider<WalletActions>((ref) {
  return WalletActions(ref);
});

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

typedef SiriTransactionDefaultsSnapshot = ({
  String userId,
  String currency,
  String spaceId,
  bool isPortfolio,
  String? accountId,
  bool walletsReady,
});

final _canonicalWalletId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Uses the same selection sources as HomeHeaderSliver and WalletsPage.
/// Drawer-specific AI targets and Apple Pay automation settings are separate.
final siriTransactionDefaultsProvider =
    Provider<SiriTransactionDefaultsSnapshot?>((ref) {
  final userId = ref.watch(authProvider).uid;
  if (userId.isEmpty || ref.watch(previewModeProvider).isActive) return null;

  // Do not replace a persisted selection with the bootstrap USD fallback.
  final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;
  if ((selectedCurrency == null || selectedCurrency.trim().isEmpty) &&
      ref.watch(appPreferredCurrencyProvider) == null) {
    return null;
  }
  final currency = ref.watch(selectedHomeCurrencyCodeProvider);
  final scope = ref.watch(householdScopeProvider);
  if (scope.viewMode == ViewMode.household && scope.isPersonalAccount) {
    // Space membership/selection is still hydrating; keep the saved snapshot.
    return null;
  }
  final householdId = scope.activeAccountHouseholdId;
  final wallets = ref.watch(scopedWalletsProvider);
  final wallet = ref.watch(defaultScopedAccountProvider);
  final accountId = wallet != null &&
          !wallet.isArchived &&
          wallet.householdId == householdId &&
          (householdId != null || wallet.userId == userId) &&
          wallet.currency.trim().toUpperCase() == currency &&
          _canonicalWalletId.hasMatch(wallet.id)
      ? wallet.id
      : null;

  return (
    userId: userId,
    currency: currency,
    spaceId: householdId ?? 'personal',
    isPortfolio: scope.isPortfolioAccount,
    accountId: accountId,
    walletsReady: wallets.hasValue,
  );
});

/// Mounted by MainShell's always-present WidgetSyncManager, independently of
/// analytics loading and whether the user has installed a home-screen widget.
final iosSiriTransactionDefaultsSyncProvider =
    Provider.autoDispose<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  ref.listen(siriTransactionDefaultsProvider, (previous, next) {
    if (next == null || previous == next) return;
    unawaited(SiriShortcutAuthService.instance.syncTransactionDefaults({
      'version': 1,
      'userId': next.userId,
      'currency': next.currency,
      'spaceId': next.spaceId,
      'isPortfolio': next.isPortfolio,
      'accountId': next.accountId,
      'walletsReady': next.walletsReady,
    }).catchError((Object error) {
      debugPrint('[Siri] Selection defaults could not sync: $error');
    }));
  }, fireImmediately: true);
});

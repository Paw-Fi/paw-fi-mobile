import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Currency and month are deliberately absent: filtering must retain the order.
typedef WalletOrderScope = ({
  String userId,
  String? householdId,
  bool isPreview,
});

String walletOrderStorageKey(WalletOrderScope scope) =>
    'wallet_accounts_order_v2:${jsonEncode([
          scope.userId,
          scope.householdId,
          scope.isPreview
        ])}';

class WalletOrderStore {
  WalletOrderStore(this.preferences);

  final SharedPreferences preferences;

  List<String> load(WalletOrderScope scope) =>
      preferences.getStringList(walletOrderStorageKey(scope)) ?? const [];

  Future<void> save(WalletOrderScope scope, List<String> ids) async {
    if (!await preferences.setStringList(walletOrderStorageKey(scope), ids)) {
      await preferences.reload();
      throw StateError('Wallet order could not be saved locally');
    }
  }
}

final walletOrderStoreProvider = Provider<WalletOrderStore>(
    (ref) => WalletOrderStore(ref.watch(sharedPreferencesProvider)));

/// Keep hidden wallet slots, replacing only the visible subset being reordered.
List<String> mergeVisibleWalletOrder(
  List<String> savedIds,
  List<String> visibleIds,
) {
  final visible = visibleIds.toSet();
  final complete = [...savedIds.toSet()];
  complete.addAll(visibleIds.where((id) => !complete.contains(id)));
  var index = 0;
  return [
    for (final id in complete)
      if (visible.contains(id)) visibleIds[index++] else id,
  ];
}

List<T> applyWalletOrder<T>(
  List<T> wallets,
  List<String> savedIds,
  String Function(T) idOf,
) {
  final byId = {for (final wallet in wallets) idOf(wallet): wallet};
  return [
    for (final id in savedIds)
      if (byId.containsKey(id)) byId.remove(id)!,
    // New wallets follow the input order after saved wallets.
    ...byId.values,
  ];
}

class WalletOrderNotifier extends StateNotifier<List<String>> {
  WalletOrderNotifier(this.scope, this.store)
      : super(List.unmodifiable(store.load(scope))) {
    _confirmed = state;
  }

  final WalletOrderScope scope;
  final WalletOrderStore store;
  late List<String> _confirmed;
  Future<void> _writeTail = Future.value();
  int _revision = 0;

  Future<void> reorder(List<String> visibleIds) {
    final next = List<String>.unmodifiable(
      mergeVisibleWalletOrder(state, visibleIds),
    );
    final revision = ++_revision;
    state = next;
    final write = _writeTail.then((_) async {
      try {
        await store.save(scope, next);
        _confirmed = next;
      } catch (_) {
        if (mounted && revision == _revision) state = _confirmed;
        rethrow;
      }
    });
    // Serialize writes, but a failed write must not block the next reorder.
    _writeTail = write.catchError((Object _) {});
    return write;
  }
}

final walletOrderProvider = StateNotifierProvider.family<WalletOrderNotifier,
    List<String>, WalletOrderScope>((ref, scope) {
  return WalletOrderNotifier(scope, ref.watch(walletOrderStoreProvider));
});

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final iosWalletCaptureSyncRevisionProvider = StateProvider<int>((ref) => 0);
final iosWalletCaptureAuthProvider =
    Provider<GoTrueClient>((ref) => supabase.auth);

/// Mount with MainShell. Native captures have their own durable queue, so the
/// SQLite outbox's retry timer cannot wake them after a transient failure.
final iosWalletCaptureSyncProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return (_) async {};
  }
  final service = SiriShortcutAuthService.instance;
  var disposed = false;
  var checkingPending = false;

  final subscription = service.walletCapturesSynced.listen((userId) {
    if (disposed || ref.read(authProvider).uid != userId) return;
    ref.read(iosWalletCaptureSyncRevisionProvider.notifier).state += 1;
  });

  Future<void> drain(String userId) async {
    if (disposed ||
        ref.read(authProvider).uid != userId ||
        ref.read(previewModeProvider).isActive ||
        ref.read(userFinancialCacheCleanupInProgressProvider)) {
      return;
    }
    await service.syncPendingWalletCapturesWithCurrentSession(
      auth: ref.read(iosWalletCaptureAuthProvider),
      supabaseUrl: Constants.supabaseUrl,
      supabaseAnonKey: Constants.supabaseAnon,
      userId: userId,
    );
  }

  final timer = Timer.periodic(networkReachabilityCheckInterval, (_) async {
    if (disposed ||
        checkingPending ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ref.read(networkReachabilityProvider).valueOrNull == false) {
      return;
    }
    final userId = ref.read(authProvider).uid;
    if (userId.isEmpty) return;
    checkingPending = true;
    try {
      final status = await service.getStatus();
      if (!disposed &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (status['pendingWalletCaptures'] as num? ?? 0) > 0) {
        await drain(userId);
      }
    } catch (error) {
      debugPrint('[WalletCapture] Pending sync will retry: $error');
    } finally {
      checkingPending = false;
    }
  });

  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(subscription.cancel());
  });
  return drain;
});

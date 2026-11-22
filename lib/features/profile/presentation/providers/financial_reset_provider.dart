import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/profile/data/financial_reset.dart';

final financialResetProvider = Provider((ref) => FinancialReset(
      database: () {
        if (ref.read(localDatabaseProvider).hasError) {
          ref.invalidate(localDatabaseProvider);
        }
        return ref.read(localDatabaseProvider.future);
      },
      rpc: (name, params) =>
          ref.read(supabaseClientProvider).rpc(name, params: params),
    ));

final resetActorGuardProvider = Provider((ref) => (String id) =>
    id.isNotEmpty &&
    ref.read(authProvider).uid == id &&
    ref.read(supabaseClientProvider).auth.currentUser?.id == id);

final resetCleanupProvider =
    Provider((ref) => (String id, void Function() guard) async {
          guard();
          await ref.read(appLockControllerProvider.notifier).clearForRecovery();
          guard();
          final initialization = ref.read(appInitializationV2Provider.notifier);
          await initialization.onLogout(guard: guard);
          guard();
          await ref
              .read(userFinancialCacheCleanupProvider)
              .clearForFinancialDataReset(userId: id, guard: guard);
          guard();
          initialization.reset();
          ref.invalidate(incomeSummaryProvider);
          ref.invalidate(incomeListProvider);
          ref.invalidate(goalsListProvider);
          ref.invalidate(goalSummaryProvider);
          ref.invalidate(subscriptionManagementProvider);
        });

enum ResetRecovery { ready, otherAccount, pending, cleaning, failed, completed }

/// Mounted by App, not a page. Poll only while an existing request is pending;
/// a transport or local failure leaves the checkpoint behind for Retry.
final resetRecoveryProvider =
    StreamProvider.autoDispose.family<ResetRecovery, String>((ref, id) async* {
  var alive = true;
  ref.onDispose(() => alive = false);
  final service = ref.watch(financialResetProvider);
  final ownsActor = ref.watch(resetActorGuardProvider);
  final cleanup = ref.watch(resetCleanupProvider);
  final db = await service.database().timeout(service.timeout);
  final owner = db.activeResetOwner;
  if (owner != null && owner != id) {
    yield ResetRecovery.otherAccount;
    return;
  }
  final saved = await service.saved(id);
  if (saved == null) {
    yield ResetRecovery.ready;
    return;
  }
  if (saved.status == ResetStatus.failed) {
    yield ResetRecovery.failed;
    return;
  }
  yield saved.status == ResetStatus.completed
      ? ResetRecovery.cleaning
      : ResetRecovery.pending;
  while (alive) {
    final job = await service.run(
        userId: id,
        isCurrent: () => alive && ownsActor(id),
        cleanup: (guard) => cleanup(id, guard));
    if (!alive) return;
    if (job?.status != ResetStatus.pending) {
      yield job == null
          ? ResetRecovery.ready
          : job.status == ResetStatus.failed
              ? ResetRecovery.failed
              : ResetRecovery.completed;
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

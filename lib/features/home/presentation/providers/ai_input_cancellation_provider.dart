import 'dart:convert';
import 'dart:developer' as developer;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/data/repositories/ai_input_capture_repository.dart';
import 'package:moneko/features/home/presentation/providers/ai_input_capture_provider.dart';
import 'package:moneko/features/home/presentation/services/ai_background_execution.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

final aiInputCancellationProvider =
    Provider<AiInputCancellation>((ref) => AiInputCancellation(ref));

/// Recovery barrier shared by foreground capture resume and financial replay.
/// Native records contain only actor/capture/attempt IDs, never source content.
class AiInputCancellation {
  AiInputCancellation(this.ref);
  final Ref ref;
  Future<void> _tail = Future.value();

  Future<void> reconcile() {
    // A caller arriving during a read needs a fresh journal snapshot; sharing
    // that earlier read could admit a Stop recorded while it was in flight.
    final next = _tail.then((_) => _reconcile());
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _reconcile() async {
    final bridge = ref.read(aiExecutionBridgeProvider);
    for (final stop in await bridge.pendingStops()) {
      final id = stop['id'] as String;
      final captureId = stop['captureId'] as String;
      final userId = stop['userId'] as String;
      ref.read(aiBackgroundExecutionProvider).stopAttempt(id);
      final database = await ref.read(localDatabaseProvider.future);
      final sources = (await database.getOutboxMutations())
          .where((m) =>
              m.entityType == 'ai_input' &&
              m.entityId == captureId &&
              AiInputCapture(m).userId == userId &&
              AiInputCapture(m).payload['executionId'] == id)
          .toList();
      final removed = await database.stopAiInput(
          userId: userId, captureId: captureId, executionId: id);
      if (sources.isNotEmpty && ref.read(authProvider).uid == userId) {
        final cancelled = (await database.getOutboxMutations()).where((m) =>
            m.entityType == 'transaction' &&
            m.status == 'cancelled' &&
            (jsonDecode(m.payloadJson) as Map)['aiCaptureId'] == captureId);
        for (final mutation in cancelled) {
          ref
              .read(householdOptimisticExpensesProvider.notifier)
              .removeExpenseByIdAcrossHouseholds(mutation.entityId);
          ref
              .read(householdOptimisticSplitsProvider.notifier)
              .removeSplitByExpenseIdAcrossHouseholds(mutation.entityId);
        }
        await ref
            .read(analyticsProvider.notifier)
            .reconcileOptimisticTransactionsFromLocalCache(userId);
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state++;
        ref.read(dashboardRefreshSignalProvider.notifier).state++;
      }
      // Commit authority first. Cleanup may be retried without resurrecting work.
      for (final mutation in removed) {
        await deleteQueuedReceiptIfUnused(database, mutation,
            Map<String, dynamic>.from(jsonDecode(mutation.payloadJson) as Map));
      }
      for (final source in sources) {
        try {
          final repository =
              await ref.read(aiInputCaptureRepositoryProvider.future);
          await repository.removeMaterializedMedia(AiInputCapture(source));
        } catch (error, stack) {
          developer.log('Could not clean stopped AI capture media',
              name: 'AiInputCancellation', error: error, stackTrace: stack);
        }
      }
      await bridge.acknowledgeStop(id);
    }
  }
}

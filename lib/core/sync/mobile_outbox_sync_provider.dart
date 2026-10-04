import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/sync/household_settlement_outbox_dispatcher.dart';
import 'package:moneko/features/households/data/services/shared_budget_identity.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:moneko/core/ui/notifications/app_mutation_error_provider.dart';
import 'package:moneko/core/utils/image_compressor.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show widgetSyncVersionProvider;
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/utils/pending_settlement_payment.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart'
    show recurringTransactionsProvider;
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';
import 'package:moneko/features/pockets/data/pocket_month_mutation_service.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_feed_entries.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final mobileOutboxSupabaseClientProvider = Provider<SupabaseClient>(
  (ref) => supabase,
);

final mobileOutboxSyncCoordinatorProvider =
    FutureProvider<SyncCoordinator>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return SyncCoordinator(
    database: database,
    dispatchMutation: (mutation) =>
        _dispatchMobileMutation(ref, database, mutation),
    onMutationCancelled: (mutation, _) =>
        _handleCancelledMobileMutation(ref, database, mutation),
    onMutationNeedsReview: (mutation, _) async {
      if (mutation.entityType != 'pockets_month' &&
          mutation.entityType != 'pocket_category') {
        return;
      }
      ref.read(appMutationErrorProvider.notifier).state = AppMutationErrorEvent(
        id: mutation.clientMutationId,
        feature: 'pockets',
      );
      ref.read(pocketsRefreshSignalProvider.notifier).state++;
    },
  );
});

bool _isMobileOutboxDrainScheduled = false;
bool _mobileOutboxDrainRequested = false;
Future<int>? _mobileOutboxDrainInFlight;

final mobileOutboxDrainerProvider = Provider<MobileOutboxDrainer>(
  (ref) {
    ref.watch(authProvider.select((auth) => auth.uid));
    final drainer = MobileOutboxDrainer(
      () => ref.read(mobileOutboxSyncCoordinatorProvider.future),
    );
    ref.onDispose(drainer.dispose);
    return drainer;
  },
);

class MobileOutboxDrainer {
  MobileOutboxDrainer(this._readCoordinator, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Future<SyncCoordinator> Function() _readCoordinator;
  final DateTime Function() _now;
  Timer? _retryTimer;
  bool _disposed = false;

  Future<int> drain({int maxMutations = 20}) async {
    if (_disposed) return 0;
    _retryTimer?.cancel();
    final result = await _drainMobileOutboxWithReader(
      _readCoordinator,
      maxMutations: maxMutations,
    );
    if (_disposed) return result;
    final coordinator = await _readCoordinator();
    final mutations = await coordinator.database.getOutboxMutations();
    if (_disposed) return result;
    _retryTimer?.cancel();
    final delay = resolveNextMobileOutboxRetryDelay(mutations, now: _now());
    if (delay != null) {
      // A deferred dependency can leave a queued row immediately eligible.
      // Keep its retries bounded instead of spinning a zero-delay timer.
      _retryTimer =
          Timer(delay > Duration.zero ? delay : const Duration(seconds: 1), () {
        unawaited(
            drain(maxMutations: maxMutations).catchError((Object _) => 0));
      });
    }
    return result;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
  }
}

Duration? resolveNextMobileOutboxRetryDelay(
  Iterable<LocalMutationOutboxData> mutations, {
  required DateTime now,
}) {
  DateTime? nextRetryAt;
  for (final mutation in mutations) {
    final DateTime? retryAfter;
    if (mutation.status == localMutationStatusSyncing) {
      retryAfter = mutation.updatedAt.add(localMutationSyncLease);
    } else if (mutation.status == localMutationStatusQueued ||
        mutation.status == localMutationStatusFailed) {
      retryAfter = mutation.retryAfter;
    } else {
      continue;
    }

    if (retryAfter == null || !retryAfter.isAfter(now)) {
      return Duration.zero;
    }
    if (nextRetryAt == null || retryAfter.isBefore(nextRetryAt)) {
      nextRetryAt = retryAfter;
    }
  }

  if (nextRetryAt == null) return null;
  return nextRetryAt.difference(now);
}

String? pocketEnvelopeReplayConflictTarget(String envelopeId) {
  return envelopeId.startsWith('optimistic-') ? 'budget_id,name' : null;
}

void scheduleMobileOutboxDrain(
  ProviderContainer container, {
  int maxMutations = 20,
  Duration initialDelay = Duration.zero,
}) {
  if (_isMobileOutboxDrainScheduled) {
    _mobileOutboxDrainRequested = true;
    return;
  }
  _isMobileOutboxDrainScheduled = true;

  Future<void>(() async {
    try {
      if (initialDelay > Duration.zero) {
        await Future<void>.delayed(initialDelay);
      }

      await _drainMobileOutboxWithContainer(
        container,
        maxMutations: maxMutations,
      );
    } catch (_) {
      // Main shell lifecycle sync remains the fallback if the container is
      // disposed or the local database/provider graph is unavailable.
    } finally {
      _isMobileOutboxDrainScheduled = false;
      if (_mobileOutboxDrainRequested) {
        _mobileOutboxDrainRequested = false;
        scheduleMobileOutboxDrain(container, maxMutations: maxMutations);
      }
    }
  });
}

Future<int> drainMobileOutbox(Ref ref, {int maxMutations = 20}) async {
  return ref
      .read(mobileOutboxDrainerProvider)
      .drain(maxMutations: maxMutations);
}

Future<int> _drainMobileOutboxWithContainer(
  ProviderContainer container, {
  required int maxMutations,
}) {
  return container.read(mobileOutboxDrainerProvider).drain(
        maxMutations: maxMutations,
      );
}

Future<int> _drainMobileOutboxWithReader(
  Future<SyncCoordinator> Function() readCoordinator, {
  required int maxMutations,
}) {
  final inFlight = _mobileOutboxDrainInFlight;
  if (inFlight != null) return inFlight;

  final run = () async {
    try {
      final coordinator = await readCoordinator();
      return await coordinator.drainOutbox(maxMutations: maxMutations);
    } finally {
      _mobileOutboxDrainInFlight = null;
    }
  }();
  _mobileOutboxDrainInFlight = run;
  return run;
}

Future<void> _dispatchMobileMutation(
  Ref ref,
  MonekoDatabase database,
  LocalMutationOutboxData mutation,
) async {
  final payload = _decodePayload(mutation.payloadJson);

  switch (mutation.operation) {
    case localHouseholdSettlementMutationOperation:
      if (!isDurableHouseholdSettlementMutation(mutation)) {
        throw StateError('Settlement operation has the wrong entity type');
      }
      await dispatchHouseholdSettlementMutation(
        ref.read(mobileOutboxSupabaseClientProvider),
        mutation,
        payload,
      );
      final settlementPayload =
          LocalHouseholdSettlementMutationPayload.fromJson(payload);
      final optimisticPayment = pendingSettlementPaymentRecord(
        currentUserId: ref.read(authProvider).uid,
        memberUserId: settlementPayload.memberUserId,
        mode: settlementPayload.mode,
        amountCents: settlementPayload.amountCents,
        currency: settlementPayload.currency,
      );
      if (optimisticPayment != null) {
        ref
            .read(optimisticSettlementPaymentsProvider.notifier)
            .removePayment(mutation.entityId, optimisticPayment);
      }
      ref.invalidate(
        pendingHouseholdSettlementPaymentsProvider(mutation.entityId),
      );
      ref
          .read(householdRemoteMutationRefreshSignalProvider(
            mutation.entityId,
          ).notifier)
          .state += 1;
      ref.invalidate(householdPairwiseSettlementBalancesV2Provider);
      ref.invalidate(householdSettlementCalculationV3Provider);
      return;
    case 'create':
      final requestBody = await _requestBodyWithQueuedReceipt(
        _mapValue(payload['requestBody']),
        payload,
      );
      final responseBody = await _invokeMutationFunction(
        payload['functionName']?.toString(),
        requestBody,
        isAiCapture: payload['aiCaptureId'] is String,
      );
      if (mutation.entityType == 'transaction') {
        final savedPayload = _extractSavedEntryPayload(responseBody);
        if (savedPayload == null) {
          throw StateError(
            'Transaction create sync succeeded without a saved transaction payload',
          );
        }
        final queuedTransaction = _mapValue(payload['transaction']);
        final queuedEntry = queuedTransaction == null
            ? null
            : ExpenseEntry.fromJson(queuedTransaction);
        final parsedSavedEntry = ExpenseEntry.fromJson(savedPayload);
        final matchingQueuedMerchantDomain =
            parsedSavedEntry.merchantId != null &&
                    parsedSavedEntry.merchantId == queuedEntry?.merchantId
                ? queuedEntry?.merchantDomain
                : null;
        final matchingQueuedMerchantLogoUrl =
            parsedSavedEntry.merchantId != null &&
                    parsedSavedEntry.merchantId == queuedEntry?.merchantId
                ? queuedEntry?.merchantLogoUrl
                : null;
        final savedEntry = parsedSavedEntry.copyWith(
          merchantDomain:
              parsedSavedEntry.merchantDomain ?? matchingQueuedMerchantDomain,
          merchantLogoUrl:
              parsedSavedEntry.merchantLogoUrl ?? matchingQueuedMerchantLogoUrl,
          clientRecordId: mutation.entityId,
          clientMutationId: mutation.clientMutationId,
          idempotencyKey:
              _metadataFromPayload(payload)['idempotencyKey']?.toString() ??
                  mutation.clientMutationId,
        );
        final reconciledEntry = await database.replaceOptimisticTransaction(
          optimisticId: mutation.entityId,
          savedEntry: savedEntry,
          clientMutationId: mutation.clientMutationId,
        );
        if (reconciledEntry != null) {
          reconcileSyncedHouseholdTransactionOverlays(
            expensesNotifier:
                ref.read(householdOptimisticExpensesProvider.notifier),
            splitsNotifier:
                ref.read(householdOptimisticSplitsProvider.notifier),
            optimisticId: mutation.entityId,
            optimisticHouseholdId:
                queuedTransaction?['household_id']?.toString() ??
                    queuedTransaction?['householdId']?.toString(),
            savedEntry: reconciledEntry,
          );
        }
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
        ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
        _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      }
      await deleteQueuedReceiptIfUnused(database, mutation, payload);
      return;
    case 'analyze_ai_input':
      // Analysis needs the foreground clarification UI and the full Home save contract.
      // Holding this row also lets financial mutations behind it continue syncing.
      await database.holdAiInputForForeground(mutation);
      return;
    case 'invoke_function':
      final functionName = payload['functionName']?.toString();
      final requestBody = _mapValue(payload['requestBody']);
      final transferId = requestBody?['transferId']?.toString();
      if ((functionName == 'update-wallet-transfer' ||
              functionName == 'delete-wallet-transfer') &&
          transferId?.startsWith('optimistic-transfer-') == true) {
        throw const DeferredLocalMutationException();
      }
      final responseBody = await _invokeMutationFunction(
        functionName,
        requestBody,
      );
      if (mutation.entityType == 'wallet') {
        await _reconcileSyncedWalletMutation(
          ref,
          database,
          mutation,
          payload,
          responseBody,
        );
      }
      return;
    case 'save_pockets_month':
      await _savePocketsMonth(payload, mutation, database);
      return;
    case 'save_scenario_history':
      await _saveScenarioHistory(payload);
      return;
    case 'delete_scenario_history':
      await _deleteScenarioHistory(payload);
      return;
    case 'assign_pocket_category':
      // This is an additive, idempotent link, never a month replacement.
      // RLS checks the envelope and the server trigger advances its revision.
      try {
        await _assignPocketCategory(payload);
      } catch (error) {
        if (isTerminalPocketDatabaseError(error)) {
          throw NonRetryableLocalMutationException(error.toString());
        }
        rethrow;
      }
      return;
    case 'save_shared_budget':
      await _saveSharedBudget(payload);
      return;
    case 'save_category_remap':
      await _saveCategoryRemap(payload);
      return;
    case 'delete_category_remap':
      await _deleteCategoryRemap(payload);
      return;
    case 'update_transaction':
      final responseBody = await _invokeMutationFunction('update-expense', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'expenseId': payload['expenseId'] ?? mutation.entityId,
        'updates': _mapValue(payload['updates']) ?? const <String, dynamic>{},
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        ...?_mapValue(payload['extraBody']),
      });
      final savedPayload = _extractSavedEntryPayload(responseBody);
      if (savedPayload == null) {
        throw StateError(
          'Transaction update sync succeeded without a saved transaction payload',
        );
      }
      await database.markOptimisticTransactionUpdateSynced(
        entry: ExpenseEntry.fromJson(savedPayload),
        clientMutationId: mutation.clientMutationId,
      );
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    case 'batch_update_transaction':
      final responseBody = await _invokeMutationFunction(
        'update-transactions-batch',
        {
          ..._metadataFromPayload(payload),
          'transactionIds': payload['transactionIds'],
          'householdId': payload['householdId'],
          'currencies': payload['currencies'],
          'updates': _mapValue(payload['updates']) ?? const <String, dynamic>{},
          'descriptorsById': payload['descriptorsById'],
        },
      );
      final responseData = responseBody['data'];
      if (responseData is! List) {
        throw StateError(
            'Batch transaction update sync succeeded without rows');
      }
      final entries = responseData
          .whereType<Map>()
          .map((entry) =>
              ExpenseEntry.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
      if (!batchTransactionResponseMatchesRequest(
        payload['transactionIds'],
        entries.map((entry) => entry.id),
      )) {
        throw StateError(
            'Batch transaction update sync returned incomplete rows');
      }
      await database.markOptimisticTransactionBatchUpdateSynced(
        entries: entries,
        clientMutationId: mutation.clientMutationId,
      );
      ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      return;
    case 'skip_recurring_occurrence':
      await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      await database.markOptimisticTransactionMetadataSynced(
        clientMutationId: mutation.clientMutationId,
      );
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    case 'delete_transaction':
      await _invokeMutationFunction('delete-expense', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'expenseIds': payload['expenseIds'] ?? mutation.entityId,
      });
      await database.markOptimisticTransactionDeleteSynced(
        clientMutationId: mutation.clientMutationId,
      );
      // A synced tombstone remains as a short-lived cache guard, but it is no
      // longer a local financial overlay. Re-evaluate mounted settlement
      // surfaces against the authoritative server snapshot immediately.
      ref.invalidate(householdPendingDeletedExpenseIdsProvider);
      ref.invalidate(householdPairwiseSettlementBalancesV2Provider);
      ref.invalidate(householdSettlementCalculationV3Provider);
      ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      return;
    case 'delete_recurring_template':
      await _invokeMutationFunction('delete-recurring-template', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'recurringId': payload['recurringId'] ?? mutation.entityId,
      });
      await database.markOptimisticTransactionDeleteSynced(
        clientMutationId: mutation.clientMutationId,
      );
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    case 'update_recurring_occurrence':
      final responseBody = await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      final savedPayload = _extractRecurringOccurrenceTransaction(responseBody);
      if (savedPayload == null) {
        throw StateError(
          'Recurring occurrence update sync succeeded without a transaction payload',
        );
      }
      await database.markOptimisticTransactionUpdateSynced(
        entry: ExpenseEntry.fromJson(savedPayload),
        clientMutationId: mutation.clientMutationId,
      );
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    case 'unconfirm_recurring_occurrence':
      await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      await database.markOptimisticTransactionDeleteSynced(
        clientMutationId: mutation.clientMutationId,
      );
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    case localRecurringOccurrenceConfirmationMutationOperation:
      final responseBody = await _invokeRecurringOccurrenceConfirmation(
        _mapValue(payload['requestBody']),
        functionName: payload['functionName']?.toString(),
      );
      final savedPayload = _extractRecurringOccurrenceTransaction(responseBody);
      if (savedPayload == null) {
        throw StateError(
          'Recurring occurrence sync succeeded without an actual transaction payload',
        );
      }
      final reconciledEntry = await database.replaceOptimisticTransaction(
        optimisticId: mutation.entityId,
        savedEntry: ExpenseEntry.fromJson(savedPayload).copyWith(
          clientRecordId: mutation.entityId,
          clientMutationId: mutation.clientMutationId,
          idempotencyKey:
              _metadataFromPayload(payload)['idempotencyKey']?.toString() ??
                  mutation.clientMutationId,
        ),
        clientMutationId: mutation.clientMutationId,
      );
      if (reconciledEntry != null) {
        ref
            .read(householdOptimisticSplitsProvider.notifier)
            .rebindSplitExpenseId(
              fromExpenseId: mutation.entityId,
              toExpenseId: reconciledEntry.id,
              canonicalSplitGroupId: reconciledEntry.splitGroupId,
            );
      }
      _commitRecurringOptimisticMutation(ref, mutation.clientMutationId);
      return;
    default:
      throw UnsupportedError(
          'Unsupported local mutation: ${mutation.operation}');
  }
}

void _commitRecurringOptimisticMutation(Ref ref, String mutationId) {
  ref
      .read(recurringSeriesOptimisticProvider.notifier)
      .commitMutation(mutationId);
  ref
      .read(recurringOccurrenceOptimisticProvider.notifier)
      .commitMutation(mutationId);
  _publishRecurringMutationSurfaces(ref);
}

void _publishRecurringMutationSurfaces(Ref ref) {
  ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
  ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
  ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
  ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
  ref.read(widgetSyncVersionProvider.notifier).state += 1;
  ref.invalidate(pocketsProvider);
  ref.invalidate(pocketDetailsProvider);
  ref.invalidate(currencyTransactionCountsProvider);
}

Future<void> _reconcileSyncedWalletMutation(
  Ref ref,
  MonekoDatabase database,
  LocalMutationOutboxData mutation,
  Map<String, dynamic> payload,
  Map<String, dynamic> responseBody,
) async {
  if (payload['functionName'] == 'create-wallet-transfer') {
    final savedTransfer = _mapValue(responseBody['data']);
    if (savedTransfer == null) {
      throw StateError('Transfer sync succeeded without a saved transfer');
    }
    await database.replaceOptimisticWalletTransfer(
      optimisticIds: walletTransferFeedEntryIds(mutation.entityId),
      savedEntries: buildWalletTransferFeedEntries(
        transferJson: savedTransfer,
        fallbackUserId: ref.read(authProvider).uid,
      ),
      clientMutationId: mutation.clientMutationId,
    );
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
  } else if (payload['functionName'] == 'update-wallet-transfer') {
    final savedTransfer = _mapValue(responseBody['data']);
    if (savedTransfer == null) {
      throw StateError(
          'Transfer update sync succeeded without a saved transfer');
    }
    await database.markOptimisticWalletTransferMutationSynced(
      clientMutationId: mutation.clientMutationId,
      isDelete: false,
      savedEntries: buildWalletTransferFeedEntries(
        transferJson: savedTransfer,
        fallbackUserId: ref.read(authProvider).uid,
      ),
    );
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
  } else if (payload['functionName'] == 'delete-wallet-transfer') {
    await database.markOptimisticWalletTransferMutationSynced(
      clientMutationId: mutation.clientMutationId,
      isDelete: true,
    );
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
  }
  final walletIds = _walletIdsForMutation(
    mutation,
    payload,
    responseBody: responseBody,
  );
  await _clearWalletOptimisticState(ref, walletIds);
}

Future<void> _handleCancelledMobileMutation(
  Ref ref,
  MonekoDatabase database,
  LocalMutationOutboxData mutation,
) async {
  if (mutation.entityType == 'pockets_month') {
    final currentMutations = await database.getOutboxMutations();
    if (!cancelledPocketMutationStillOwnsOutbox(
      mutation,
      currentMutations,
    )) {
      return;
    }
    final payload = _decodePayload(mutation.payloadJson);
    final userId = payload['userId']?.toString() ?? '';
    final restoreResult = await restorePocketsRollbackSnapshot(
      payload,
      database: database,
      mutation: mutation,
    );
    if (restoreResult == PocketsRollbackRestoreResult.stale) return;
    if (restoreResult == PocketsRollbackRestoreResult.unavailable &&
        userId.isNotEmpty) {
      await clearPocketsCachesForUser(ref, userId: userId);
    }
    ref.invalidate(pocketsProvider);
    ref.invalidate(pocketDetailsProvider);
    ref.read(pocketsRefreshSignalProvider.notifier).state += 1;
    ref.read(widgetSyncVersionProvider.notifier).state += 1;
    ref.read(appMutationErrorProvider.notifier).state = AppMutationErrorEvent(
      id: mutation.clientMutationId,
      feature: 'pockets',
    );
    return;
  }
  if (mutation.entityType != 'wallet') {
    await database.markTransactionMutationExhausted(mutation: mutation);
    await deleteQueuedReceiptIfUnused(
      database,
      mutation,
      _decodePayload(mutation.payloadJson),
    );
    ref
        .read(recurringSeriesOptimisticProvider.notifier)
        .rollbackMutation(mutation.clientMutationId);
    ref
        .read(recurringOccurrenceOptimisticProvider.notifier)
        .rollbackMutation(mutation.clientMutationId);
    ref
        .read(householdOptimisticSplitsProvider.notifier)
        .removeSplitByExpenseIdAcrossHouseholds(mutation.entityId);
    if (mutation.operation.contains('recurring')) {
      // Skip updates the mounted recurring notifier before it is queued. Once
      // a terminal failure restores SQLite, reload that scope from the
      // restored local-first source so the skipped occurrence cannot linger.
      ref.invalidate(recurringTransactionsProvider);
    }
    _publishRecurringMutationSurfaces(ref);
    ref.read(appMutationErrorProvider.notifier).state = AppMutationErrorEvent(
      id: mutation.clientMutationId,
      feature: mutation.operation.contains('recurring')
          ? 'recurring'
          : 'transaction',
    );
    return;
  }
  final payload = _decodePayload(mutation.payloadJson);
  if (payload['functionName'] == 'create-wallet-transfer') {
    await database.rollbackOptimisticWalletTransfer(
      optimisticIds: walletTransferFeedEntryIds(mutation.entityId),
      clientMutationId: mutation.clientMutationId,
      error: mutation.lastError ?? 'Transfer sync failed',
    );
    await database.cancelPendingWalletTransferDependencies(
      transferId: mutation.entityId,
      error: mutation.lastError ?? 'Transfer create failed',
    );
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
  } else if (payload['functionName'] == 'update-wallet-transfer' ||
      payload['functionName'] == 'delete-wallet-transfer') {
    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: _walletTransferOriginalEntries(payload),
      clientMutationId: mutation.clientMutationId,
      isDelete: payload['functionName'] == 'delete-wallet-transfer',
      error: mutation.lastError ?? 'Transfer sync failed',
    );
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
  }
  await _clearWalletOptimisticState(
    ref,
    _walletIdsForMutation(mutation, payload),
  );
}

bool cancelledPocketMutationStillOwnsOutbox(
  LocalMutationOutboxData cancelledMutation,
  Iterable<LocalMutationOutboxData> currentMutations,
) {
  return cancelledMutation.entityType == 'pockets_month' &&
      currentMutations.any(
        (current) =>
            current.clientMutationId == cancelledMutation.clientMutationId &&
            current.payloadJson == cancelledMutation.payloadJson &&
            current.status == localMutationStatusCancelled,
      );
}

bool batchTransactionResponseMatchesRequest(
  Object? requestedIds,
  Iterable<String> returnedIds,
) {
  if (requestedIds is! List) return false;
  final requested = requestedIds
      .map((id) => id?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  final returned = returnedIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  return requested.length == requestedIds.length &&
      requested.length == requested.toSet().length &&
      returned.length == returned.toSet().length &&
      requested.toSet().containsAll(returned) &&
      returned.toSet().containsAll(requested);
}

List<ExpenseEntry> _walletTransferOriginalEntries(
    Map<String, dynamic> payload) {
  final entries = payload['originalEntries'];
  if (entries is! List) return const [];
  return entries
      .whereType<Map>()
      .map((entry) => ExpenseEntry.fromJson(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
}

Set<String> _walletIdsForMutation(
  LocalMutationOutboxData mutation,
  Map<String, dynamic> payload, {
  Map<String, dynamic>? responseBody,
}) {
  final requestBody = _mapValue(payload['requestBody']);
  final walletIds = <String>{mutation.entityId};
  final affectedWalletIds = payload['affectedWalletIds'];
  if (affectedWalletIds is List) {
    for (final value in affectedWalletIds) {
      final id = value?.toString().trim();
      if (id != null && id.isNotEmpty) walletIds.add(id);
    }
  }
  for (final key in const ['accountId', 'fromAccountId', 'toAccountId']) {
    final id = requestBody?[key]?.toString().trim();
    if (id != null && id.isNotEmpty) walletIds.add(id);
  }
  final savedWallet = _mapValue(responseBody?['data']);
  final savedWalletId = savedWallet?['id']?.toString().trim();
  if (savedWalletId != null && savedWalletId.isNotEmpty) {
    walletIds.add(savedWalletId);
  }
  return walletIds;
}

Future<void> _clearWalletOptimisticState(
  Ref ref,
  Set<String> walletIds,
) async {
  final overrides = ref.read(optimisticScopedAccountsOverridesProvider);
  if (overrides.isNotEmpty) {
    final nextOverrides = Map.of(overrides)
      ..removeWhere((id, _) => walletIds.contains(id));
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state =
        nextOverrides;
  }

  final userId = ref.read(authProvider).uid;
  if (userId.isNotEmpty) {
    await clearAllWalletsCachesForUser(ref, userId: userId);
  }
  ref.invalidate(scopedWalletsProvider);
  ref.invalidate(archivedScopedAccountsProvider);
  ref.invalidate(walletsPageStateProvider);
}

Future<void> _saveScenarioHistory(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString();
  final question = payload['question']?.toString();
  final answer = payload['answer']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for scenario history sync');
  }
  if (question == null || question.isEmpty) {
    throw ArgumentError('Missing question for scenario history sync');
  }
  if (answer == null || answer.isEmpty) {
    throw ArgumentError('Missing answer for scenario history sync');
  }
  await supabase.from('ai_scenario_history').insert({
    'user_id': userId,
    'household_id': payload['householdId'],
    'question': question,
    'answer': answer,
    'target_date': payload['targetDate'],
    'currency': payload['currency'],
    'mode': payload['mode']?.toString() ?? 'personal',
  });
}

Future<void> _deleteScenarioHistory(Map<String, dynamic> payload) async {
  final scenarioId = payload['scenarioId']?.toString();
  if (scenarioId == null || scenarioId.isEmpty) {
    throw ArgumentError('Missing scenarioId for scenario history delete sync');
  }
  await supabase.from('ai_scenario_history').delete().eq('id', scenarioId);
}

Future<void> _saveCategoryRemap(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString().trim();
  final transactionType = payload['transactionType']?.toString().trim();
  final fromCategory = payload['fromCategory']?.toString().trim();
  final toCategory = payload['toCategory']?.toString().trim();
  if (userId == null ||
      userId.isEmpty ||
      transactionType == null ||
      (transactionType != 'expense' && transactionType != 'income') ||
      fromCategory == null ||
      fromCategory.isEmpty ||
      toCategory == null ||
      toCategory.isEmpty) {
    throw ArgumentError('Invalid category remap payload');
  }

  final localUseCount =
      (payload['useCount'] is num) ? (payload['useCount'] as num).toInt() : 1;
  var nextUseCount = localUseCount < 1 ? 1 : localUseCount;
  try {
    final existing = await supabase
        .from('user_category_remaps')
        .select('use_count')
        .eq('user_id', userId)
        .eq('transaction_type', transactionType)
        .eq('from_category_name', fromCategory)
        .maybeSingle();
    final existingUseCount = existing?['use_count'];
    if (existingUseCount is num && existingUseCount >= nextUseCount) {
      nextUseCount = existingUseCount.toInt() + 1;
    }
  } catch (_) {
    // Keep the local count when the pre-read fails; the upsert below remains
    // idempotent and will retry from the outbox if Supabase is unavailable.
  }

  await supabase.from('user_category_remaps').upsert(
    <String, dynamic>{
      'user_id': userId,
      'transaction_type': transactionType,
      'from_category_name': fromCategory,
      'to_category_name': toCategory,
      'use_count': nextUseCount,
      'last_used_at': payload['lastUsedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    },
    onConflict: 'user_id,transaction_type,from_category_name',
  );
}

Future<void> _deleteCategoryRemap(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString().trim();
  final transactionType = payload['transactionType']?.toString().trim();
  final fromCategory = payload['fromCategory']?.toString().trim();
  if (userId == null ||
      userId.isEmpty ||
      transactionType == null ||
      (transactionType != 'expense' && transactionType != 'income') ||
      fromCategory == null ||
      fromCategory.isEmpty) {
    throw ArgumentError('Invalid category remap delete payload');
  }

  await supabase
      .from('user_category_remaps')
      .delete()
      .eq('user_id', userId)
      .eq('transaction_type', transactionType)
      .eq('from_category_name', fromCategory);
}

Future<Map<String, dynamic>> _invokeMutationFunction(
  String? functionName,
  Map<String, dynamic>? body, {
  bool isAiCapture = false,
}) async {
  if (functionName == null || functionName.isEmpty) {
    throw ArgumentError('Missing mutation function name');
  }
  if (body == null || body.isEmpty) {
    throw ArgumentError('Missing mutation payload for $functionName');
  }

  final isRecurringOccurrenceMutation = switch (functionName) {
    'confirm-recurring-occurrence' ||
    'save-recurring-occurrence-override' ||
    'skip-recurring-occurrence' ||
    'update-recurring-occurrence' ||
    'unconfirm-recurring-occurrence' =>
      true,
    _ => false,
  };
  Map<String, dynamic>? responseBody;
  try {
    final response = await supabase.functions.invoke(functionName, body: body);
    responseBody = _mapValue(response.data);
  } on FunctionException catch (error) {
    // The SDK throws for non-2xx responses before the domain code is checked.
    // Preserve retry semantics for auth, throttling, transport and server errors.
    final details = _mapValue(error.details);
    final code = details?['code']?.toString() ?? '';
    if (isAiCapture && isTerminalAiCaptureStatus(error.status)) {
      throw NonRetryableLocalMutationException(
        details?['error']?.toString() ?? '$functionName failed',
      );
    }
    if (!isRecurringOccurrenceMutation ||
        (error.status != 400 && error.status != 403) ||
        !_isTerminalRecurringOccurrenceCode(code)) {
      rethrow;
    }
    throw NonRetryableLocalMutationException(
      details?['error']?.toString() ?? '$functionName failed',
    );
  }
  if (responseBody == null || responseBody['success'] != true) {
    final code = responseBody?['code']?.toString() ?? '';
    final status = responseBody?['status'];
    if (isAiCapture && status is int && isTerminalAiCaptureStatus(status)) {
      throw NonRetryableLocalMutationException(
        responseBody?['error']?.toString() ?? '$functionName failed',
      );
    }
    if (isRecurringOccurrenceMutation &&
        _isTerminalRecurringOccurrenceCode(code)) {
      throw NonRetryableLocalMutationException(
        responseBody?['error']?.toString() ?? '$functionName failed',
      );
    }
    throw Exception(
      responseBody?['error']?.toString() ?? '$functionName failed',
    );
  }
  return responseBody;
}

bool _isTerminalRecurringOccurrenceCode(String code) =>
    code == 'VALIDATION_ERROR' ||
    (code.startsWith('OCCURRENCE_') && code != 'OCCURRENCE_FAILED');

Future<Map<String, dynamic>> _invokeRecurringOccurrenceConfirmation(
    Map<String, dynamic>? body,
    {String? functionName}) async {
  if (body == null || body.isEmpty) {
    throw ArgumentError('Missing recurring occurrence confirmation payload');
  }
  return _invokeMutationFunction(
    functionName ?? 'confirm-recurring-occurrence',
    body,
  );
}

Future<Map<String, dynamic>?> _requestBodyWithQueuedReceipt(
  Map<String, dynamic>? requestBody,
  Map<String, dynamic> payload,
) async {
  if (requestBody == null) return null;
  final localReceiptImagePath = payload['localReceiptImagePath']?.toString();
  if (localReceiptImagePath == null || localReceiptImagePath.isEmpty) {
    return requestBody;
  }
  if (requestBody['receiptImageUrl'] != null) return requestBody;

  final userId =
      requestBody['userId']?.toString() ?? payload['userId']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for queued receipt upload');
  }
  final receiptUrl = await _uploadQueuedReceiptImage(
    localReceiptImagePath,
    userId,
    storageKey: payload['clientMutationId']?.toString() ??
        payload['idempotencyKey']?.toString(),
  );
  return <String, dynamic>{
    ...requestBody,
    'receiptImageUrl': receiptUrl,
  };
}

bool isTerminalAiCaptureStatus(int status) =>
    status >= 400 &&
    status < 500 &&
    !const {401, 408, 425, 429}.contains(status);

Future<void> deleteQueuedReceiptIfUnused(MonekoDatabase database,
    LocalMutationOutboxData mutation, Map<String, dynamic> payload) async {
  final path = payload['localReceiptImagePath'];
  if (path is! String || path.isEmpty) {
    return;
  }
  if (await database.hasOtherPendingReceiptReference(
      path: path,
      clientMutationId: mutation.clientMutationId,
      expectedPayloadJson: mutation.payloadJson)) {
    return;
  }
  await _deleteQueuedLocalFile(path);
}

Future<void> _deleteQueuedLocalFile(Object? path) async {
  final value = path?.toString().trim();
  if (value == null || value.isEmpty) return;

  try {
    final file = File(value);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

Future<String> _uploadQueuedReceiptImage(
  String localImagePath,
  String userId, {
  String? storageKey,
}) async {
  final imageFile = File(localImagePath);
  if (!await imageFile.exists()) {
    throw FileSystemException(
        'Queued receipt image is missing', localImagePath);
  }

  final compressedBytes = await ImageCompressor.compressFile(
    imageFile,
    config: ImageCompressConfig.receipt,
  );
  if (!StorageConfig.isValidFileSize(compressedBytes.length)) {
    throw Exception(
      'Receipt image too large (${StorageConfig.getFileSizeString(compressedBytes.length)}). Max is ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
    );
  }
  final safeStorageKey = storageKey
      ?.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .trim();
  final fileName = safeStorageKey != null && safeStorageKey.isNotEmpty
      ? '$safeStorageKey.jpg'
      : '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final path = 'receipts/$userId/$fileName';
  final response = await supabase.storage.from('expense-receipts').uploadBinary(
        path,
        compressedBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '31536000',
          upsert: true,
        ),
      );
  if (response.isEmpty) {
    throw StateError('Queued receipt upload failed');
  }
  return supabase.storage.from('expense-receipts').getPublicUrl(path);
}

Map<String, dynamic>? _extractSavedEntryPayload(Map<String, dynamic> data) {
  final saved = data['data'] ?? data['expense'] ?? data['income'];
  if (saved is Map<String, dynamic>) return saved;
  if (saved is Map) return Map<String, dynamic>.from(saved);
  return null;
}

Map<String, dynamic>? _extractRecurringOccurrenceTransaction(
  Map<String, dynamic> response,
) {
  final data = _mapValue(response['data']);
  final transaction = _mapValue(data?['transaction']);
  if (transaction == null) return null;
  final splitGroupId = data?['split_group_id']?.toString().trim();
  return <String, dynamic>{
    ...transaction,
    if (splitGroupId != null && splitGroupId.isNotEmpty)
      'split_group_id': splitGroupId,
  };
}

Map<String, dynamic> _decodePayload(String payloadJson) {
  final decoded = jsonDecode(payloadJson);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Mutation payload is not a JSON object');
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

Map<String, dynamic> _metadataFromPayload(Map<String, dynamic> payload) {
  return {
    if (payload['clientRecordId'] != null)
      'clientRecordId': payload['clientRecordId'],
    if (payload['clientMutationId'] != null)
      'clientMutationId': payload['clientMutationId'],
    if (payload['idempotencyKey'] != null)
      'idempotencyKey': payload['idempotencyKey'],
  };
}

Future<void> _savePocketsMonth(
  Map<String, dynamic> payload,
  LocalMutationOutboxData mutation,
  MonekoDatabase database,
) async {
  final userId = payload['userId']?.toString();
  final scope = payload['scope']?.toString() ?? 'personal';
  final householdId = payload['householdId']?.toString();
  final rawPeriodMonth = payload['periodMonth']?.toString();
  final currency = payload['currency']?.toString();
  final expectedRevision = (payload['expectedServerRevision'] as num?)?.toInt();
  final revision = payload['mutationRevision']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for pockets sync');
  }
  if (rawPeriodMonth == null || rawPeriodMonth.isEmpty) {
    throw ArgumentError('Missing periodMonth for pockets sync');
  }
  final parsedPeriodMonth = DateTime.tryParse(rawPeriodMonth);
  if (parsedPeriodMonth == null) {
    throw ArgumentError('Invalid periodMonth for pockets sync');
  }
  if (currency == null || currency.isEmpty) {
    throw ArgumentError('Missing currency for pockets sync');
  }
  if (revision == null || revision.isEmpty || expectedRevision == null) {
    throw const ManualReviewLocalMutationException(
      'This saved Pocket plan needs a fresh server read before reapplying.',
    );
  }
  final periodMonth = DateTime(
    parsedPeriodMonth.year,
    parsedPeriodMonth.month,
    1,
  ).toIso8601String().substring(0, 10);
  try {
    final result = await savePocketMonthSnapshot(
      userId: userId,
      scope: scope,
      householdId: householdId,
      periodMonth: periodMonth,
      currency: currency,
      expectedRevision: expectedRevision,
      mutationId: '${mutation.clientMutationId}:$revision',
      snapshot: payload,
    );
    await reconcilePocketsMonthWriteResult(
        database: database, completed: mutation, result: result);
  } on PocketMonthWriteRejected catch (error) {
    throw NonRetryableLocalMutationException(error.toString());
  } on PocketMonthRevisionConflict catch (error) {
    throw ManualReviewLocalMutationException(pocketMonthReviewError(error));
  } on PocketMonthRevisionUnavailable catch (error) {
    throw ManualReviewLocalMutationException(pocketMonthReviewError(error));
  } on PocketMonthRevisionResponseError catch (error) {
    // The server may have applied the idempotent snapshot before returning an
    // incomplete acknowledgement. Stop automatic replay and reconcile from a
    // fresh Pocket read instead of reporting success or rolling back blindly.
    throw ManualReviewLocalMutationException(pocketMonthReviewError(error));
  }
}

Future<void> _assignPocketCategory(Map<String, dynamic> payload) async {
  final pocketId = payload['pocketId']?.toString();
  final category = payload['category']?.toString().trim().toLowerCase();
  if (pocketId == null || pocketId.isEmpty) {
    throw ArgumentError('Missing pocketId for pocket category sync');
  }
  if (category == null || category.isEmpty) {
    throw ArgumentError('Missing category for pocket category sync');
  }
  await supabase.from('envelope_category_links').upsert(
    {
      'envelope_id': pocketId,
      'category': category,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    },
    onConflict: 'envelope_id,category',
  );
}

Future<void> _saveSharedBudget(Map<String, dynamic> payload) async {
  final householdId = payload['householdId']?.toString();
  final name = payload['name']?.toString();
  final period = payload['period']?.toString();
  final currency = payload['currency']?.toString();
  final amountCents = (payload['amountCents'] as num?)?.toInt();
  if (householdId == null || householdId.isEmpty) {
    throw ArgumentError('Missing householdId for shared budget sync');
  }
  if (name == null || name.isEmpty) {
    throw ArgumentError('Missing name for shared budget sync');
  }
  if (period == null || period.isEmpty) {
    throw ArgumentError('Missing period for shared budget sync');
  }
  if (currency == null || currency.isEmpty) {
    throw ArgumentError('Missing currency for shared budget sync');
  }
  if (amountCents == null) {
    throw ArgumentError('Missing amountCents for shared budget sync');
  }

  final budgetType = payload['budgetType']?.toString() ?? 'household';
  final currentUserId = supabase.auth.currentUser?.id;
  final actorUserId = payload['userId']?.toString();
  if (actorUserId != null && actorUserId != currentUserId) {
    throw const DeferredLocalMutationException();
  }
  if (budgetType == 'personal' && currentUserId == null) {
    throw StateError('A signed-in user is required to sync a personal budget');
  }
  final scopeFilters = sharedBudgetIdentityFilters(
    householdId: householdId,
    budgetType: budgetType,
    userId: currentUserId,
  );
  final existingQuery = supabase.from('shared_budgets').select('id');
  var scopedQuery = existingQuery;
  for (final entry in scopeFilters.entries) {
    scopedQuery = scopedQuery.eq(entry.key, entry.value);
  }
  final existing = await scopedQuery
      .eq('currency', currency)
      .eq('period', period)
      .eq('is_active', true)
      .maybeSingle();

  final updates = <String, dynamic>{
    'name': name,
    'amount_cents': amountCents,
    'warn_threshold': (payload['warnThreshold'] as num?)?.toDouble() ?? 0.8,
    'alert_threshold': (payload['alertThreshold'] as num?)?.toDouble() ?? 1.0,
    'count_split_portion_only': payload['countSplitPortionOnly'] == true,
  };

  if (existing != null && existing['id'] != null) {
    var updateQuery = supabase
        .from('shared_budgets')
        .update(updates)
        .eq('id', existing['id'] as String);
    for (final entry in scopeFilters.entries) {
      updateQuery = updateQuery.eq(entry.key, entry.value);
    }
    await updateQuery;
    return;
  }

  await supabase.from('shared_budgets').insert({
    'household_id': householdId,
    'period': period,
    'currency': currency,
    'budget_type': budgetType,
    if (budgetType == 'personal') 'user_id': currentUserId,
    'is_active': true,
    ...updates,
  });
}

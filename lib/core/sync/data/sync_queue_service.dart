import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../local_database/app_database.dart';
import '../../util/logger.dart';
import '../domain/sync_status.dart';
import 'transaction_sync_function_mapper.dart';

typedef DateTimeFactory = DateTime Function();

abstract class SyncQueueProcessor {
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  });
}

abstract class SyncRemoteClient {
  Future<SyncRemoteResult> pushOperation(SyncOpRecord operation);
}

class SyncRemoteResult {
  const SyncRemoteResult({
    this.serverId,
    this.serverUpdatedAt,
  });

  final String? serverId;
  final String? serverUpdatedAt;
}

class SupabaseSyncRemoteClient implements SyncRemoteClient {
  const SupabaseSyncRemoteClient(this.supabase);

  final SupabaseClient supabase;

  @override
  Future<SyncRemoteResult> pushOperation(SyncOpRecord operation) async {
    final request = _buildFunctionRequest(operation);
    final response = await supabase.functions.invoke(
      request.functionName,
      body: request.body,
    );

    if (response.status >= 400) {
      throw Exception('Sync failed with status ${response.status}');
    }

    final data = response.data;
    if (data is Map && data['success'] == false) {
      final message = data['error']?.toString().trim();
      throw Exception(
        message == null || message.isEmpty ? 'Sync operation failed' : message,
      );
    }

    return _remoteResultFromResponseData(data);
  }

  TransactionSyncFunctionRequest _buildFunctionRequest(
    SyncOpRecord operation,
  ) {
    final payload = jsonDecode(operation.payloadJson);
    if (payload is! Map) {
      throw const FormatException('Sync payload must be a JSON object');
    }
    final payloadMap = Map<String, dynamic>.from(payload);
    if (operation.aggregateType == 'transaction' &&
        operation.operationType == 'create') {
      return mapTransactionCreateSyncRequest(payloadMap);
    }

    return TransactionSyncFunctionRequest(
      functionName: 'sync-operation',
      body: {
        'operationId': operation.id,
        'aggregateType': operation.aggregateType,
        'aggregateLocalId': operation.aggregateLocalId,
        'operationType': operation.operationType,
        'idempotencyKey': operation.idempotencyKey,
        'payload': payloadMap,
      },
    );
  }

  static SyncRemoteResult _remoteResultFromResponseData(Object? data) {
    if (data is! Map) {
      return const SyncRemoteResult();
    }

    final root = Map<String, dynamic>.from(data);
    final nested = root['data'];
    final row = nested is Map ? Map<String, dynamic>.from(nested) : root;
    final serverId = row['id']?.toString().trim();
    final serverUpdatedAt =
        (row['updated_at'] ?? row['server_updated_at'])?.toString().trim();

    return SyncRemoteResult(
      serverId: serverId == null || serverId.isEmpty ? null : serverId,
      serverUpdatedAt: serverUpdatedAt == null || serverUpdatedAt.isEmpty
          ? null
          : serverUpdatedAt,
    );
  }
}

class SyncQueueProcessResult {
  const SyncQueueProcessResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
  });

  final int processed;
  final int succeeded;
  final int failed;
}

class SyncQueueService implements SyncQueueProcessor {
  SyncQueueService({
    required this.database,
    required this.remoteClient,
    DateTimeFactory? clock,
  }) : clock = clock ?? DateTime.now;

  final AppDatabase database;
  final SyncRemoteClient remoteClient;
  final DateTimeFactory clock;

  @override
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  }) async {
    final startedAt = _nowIso();
    final pending = await database.pendingSyncOps(
      nowIso: startedAt,
      limit: limit,
    );

    appLog(
      'Processing sync queue count=${pending.length}',
      name: 'SyncQueueService',
    );

    var succeeded = 0;
    var failed = 0;

    for (final operation in pending) {
      appLog(
        'Syncing operation id=${operation.id} '
        'aggregate=${operation.aggregateType}:${operation.aggregateLocalId} '
        'attempt=${operation.attemptCount}',
        name: 'SyncQueueService',
      );
      await _markSyncing(operation, startedAt);

      try {
        final remoteResult = await remoteClient.pushOperation(operation);
        final completedAt = _nowIso();
        await _markSynced(operation, remoteResult, completedAt);
        appLog(
          'Synced operation id=${operation.id} serverId=${remoteResult.serverId}',
          name: 'SyncQueueService',
        );
        succeeded += 1;
      } catch (error) {
        final failedAt = _nowIso();
        final nextAttempt = operation.attemptCount + 1;
        final nextRetryAt = _formatIso(
          clock().toUtc().add(_retryDelayForAttempt(nextAttempt)),
        );
        await _markFailed(
          operation,
          attemptCount: nextAttempt,
          lastError: _errorMessage(error),
          nextRetryAt: nextRetryAt,
          failedAt: failedAt,
        );
        appLog(
          'Sync failed operation id=${operation.id}: ${_errorMessage(error)}',
          name: 'SyncQueueService',
          error: error,
        );
        failed += 1;
      }
    }

    return SyncQueueProcessResult(
      processed: pending.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Future<void> _markSyncing(SyncOpRecord operation, String startedAt) async {
    await database.transaction(() async {
      await database.markSyncOpSyncing(
        id: operation.id,
        updatedAt: startedAt,
        startedAt: startedAt,
      );
      await _updateAggregateStatus(
        operation,
        status: SyncStatus.syncing,
        updatedAt: startedAt,
      );
    });
  }

  Future<void> _markSynced(
    SyncOpRecord operation,
    SyncRemoteResult remoteResult,
    String completedAt,
  ) async {
    await database.transaction(() async {
      await database.markSyncOpSynced(
        id: operation.id,
        updatedAt: completedAt,
        completedAt: completedAt,
        aggregateServerId: remoteResult.serverId,
      );
      if (operation.aggregateType == 'transaction') {
        await database.markLocalTransactionSynced(
          id: operation.aggregateLocalId,
          serverId: remoteResult.serverId,
          serverUpdatedAt: remoteResult.serverUpdatedAt,
          updatedAt: completedAt,
        );
      } else {
        await _updateAggregateStatus(
          operation,
          status: SyncStatus.synced,
          updatedAt: completedAt,
        );
      }
    });
  }

  Future<void> _markFailed(
    SyncOpRecord operation, {
    required int attemptCount,
    required String lastError,
    required String nextRetryAt,
    required String failedAt,
  }) async {
    await database.transaction(() async {
      await database.markSyncOpFailed(
        id: operation.id,
        attemptCount: attemptCount,
        lastError: lastError,
        nextRetryAt: nextRetryAt,
        updatedAt: failedAt,
      );
      await _updateAggregateStatus(
        operation,
        status: SyncStatus.failed,
        updatedAt: failedAt,
        lastSyncError: lastError,
      );
    });
  }

  Future<void> _updateAggregateStatus(
    SyncOpRecord operation, {
    required SyncStatus status,
    required String updatedAt,
    String? lastSyncError,
  }) async {
    if (operation.aggregateType != 'transaction') {
      return;
    }

    await database.updateLocalTransactionSyncStatus(
      id: operation.aggregateLocalId,
      syncStatus: status.name,
      updatedAt: updatedAt,
      lastSyncError: lastSyncError,
    );
  }

  String _nowIso() => _formatIso(clock().toUtc());

  static String _formatIso(DateTime value) => value.toUtc().toIso8601String();

  static String _errorMessage(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? 'Unknown sync error' : message;
  }

  static Duration _retryDelayForAttempt(int attemptCount) {
    var seconds = 2;
    for (var i = 1; i < attemptCount; i += 1) {
      seconds *= 2;
    }
    if (seconds > 300) {
      seconds = 300;
    }
    return Duration(seconds: seconds);
  }
}

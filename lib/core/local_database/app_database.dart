import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {
          await customStatement(_createLocalTransactionsTable);
          await customStatement(_createSyncOpsTable);
          await customStatement(_createLocalTransactionsUserDateIndex);
          await customStatement(_createLocalTransactionsWalletDateIndex);
          await customStatement(_createSyncOpsStatusIndex);
          await customStatement(_createSyncOpsAggregateIndex);
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  Future<int> insertLocalTransaction({
    required String id,
    String? serverId,
    required String clientMutationId,
    required String userId,
    String? householdId,
    String? walletId,
    String? bankAccountId,
    String? contactId,
    String? splitGroupId,
    required String type,
    required int amountCents,
    required String currency,
    String? baseCurrency,
    int? normalizedAmountCents,
    double? fxRate,
    String? category,
    String? merchant,
    String? rawText,
    String? description,
    required String breakdownJson,
    required String dateYmd,
    required String createdAt,
    required String updatedAt,
    String? serverCreatedAt,
    String? serverUpdatedAt,
    String? deletedAt,
    required String captureSource,
    double? confidenceScore,
    required String syncStatus,
    required String reviewReasonsJson,
    int localRevision = 1,
    int? serverRevision,
    int? baseServerRevision,
    String? receiptLocalPath,
    String? receiptImageUrl,
    String? providerTransactionId,
    String? provider,
    bool isRecurring = false,
    String? recurrenceRuleJson,
    String? payerUserId,
    bool isPortfolio = false,
    String? lastSyncError,
  }) {
    return customInsert(
      _insertLocalTransaction,
      variables: [
        Variable.withString(id),
        Variable<String>(serverId),
        Variable.withString(clientMutationId),
        Variable.withString(userId),
        Variable<String>(householdId),
        Variable<String>(walletId),
        Variable<String>(bankAccountId),
        Variable<String>(contactId),
        Variable<String>(splitGroupId),
        Variable.withString(type),
        Variable.withInt(amountCents),
        Variable.withString(currency),
        Variable<String>(baseCurrency),
        Variable<int>(normalizedAmountCents),
        Variable<double>(fxRate),
        Variable<String>(category),
        Variable<String>(merchant),
        Variable<String>(rawText),
        Variable<String>(description),
        Variable.withString(breakdownJson),
        Variable.withString(dateYmd),
        Variable.withString(createdAt),
        Variable.withString(updatedAt),
        Variable<String>(serverCreatedAt),
        Variable<String>(serverUpdatedAt),
        Variable<String>(deletedAt),
        Variable.withString(captureSource),
        Variable<double>(confidenceScore),
        Variable.withString(syncStatus),
        Variable.withString(reviewReasonsJson),
        Variable.withInt(localRevision),
        Variable<int>(serverRevision),
        Variable<int>(baseServerRevision),
        Variable<String>(receiptLocalPath),
        Variable<String>(receiptImageUrl),
        Variable<String>(providerTransactionId),
        Variable<String>(provider),
        Variable.withBool(isRecurring),
        Variable<String>(recurrenceRuleJson),
        Variable<String>(payerUserId),
        Variable.withBool(isPortfolio),
        Variable<String>(lastSyncError),
      ],
    );
  }

  Future<int> insertSyncOp({
    required String id,
    required String aggregateType,
    required String aggregateLocalId,
    String? aggregateServerId,
    required String operationType,
    required String status,
    required String payloadJson,
    required String idempotencyKey,
    int attemptCount = 0,
    String? lastError,
    String? nextRetryAt,
    required String createdAt,
    required String updatedAt,
    String? startedAt,
    String? completedAt,
  }) {
    return customInsert(
      _insertSyncOp,
      variables: [
        Variable.withString(id),
        Variable.withString(aggregateType),
        Variable.withString(aggregateLocalId),
        Variable<String>(aggregateServerId),
        Variable.withString(operationType),
        Variable.withString(status),
        Variable.withString(payloadJson),
        Variable.withString(idempotencyKey),
        Variable.withInt(attemptCount),
        Variable<String>(lastError),
        Variable<String>(nextRetryAt),
        Variable.withString(createdAt),
        Variable.withString(updatedAt),
        Variable<String>(startedAt),
        Variable<String>(completedAt),
      ],
    );
  }

  Future<LocalTransactionRecord> localTransactionById(String id) async {
    final row = await customSelect(
      'SELECT * FROM local_transactions WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
    ).getSingle();
    return LocalTransactionRecord.fromRow(row);
  }

  Future<List<LocalTransactionRecord>> recentLocalTransactions({
    required String userId,
    String? householdId,
    String? currency,
    int limit = 5,
  }) async {
    if (limit <= 0) {
      return const [];
    }

    final where = <String>[
      'user_id = ?',
      'deleted_at IS NULL',
    ];
    final variables = <Variable>[
      Variable.withString(userId),
    ];

    final normalizedHouseholdId = householdId?.trim();
    if (normalizedHouseholdId == null || normalizedHouseholdId.isEmpty) {
      where.add("(household_id IS NULL OR household_id = '')");
    } else {
      where.add('household_id = ?');
      variables.add(Variable.withString(normalizedHouseholdId));
    }

    final normalizedCurrency = currency?.trim().toUpperCase();
    if (normalizedCurrency != null && normalizedCurrency.isNotEmpty) {
      where.add('UPPER(currency) = ?');
      variables.add(Variable.withString(normalizedCurrency));
    }

    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      '''
      SELECT * FROM local_transactions
      WHERE ${where.join(' AND ')}
      ORDER BY date_ymd DESC, created_at DESC
      LIMIT ?
      ''',
      variables: variables,
    ).get();
    return rows.map(LocalTransactionRecord.fromRow).toList(growable: false);
  }

  Future<List<LocalTransactionRecord>> localTransactions({
    required String userId,
    String? householdId,
    String? currency,
    int limit = 500,
  }) async {
    if (limit <= 0) {
      return const [];
    }

    final where = <String>[
      'user_id = ?',
      'deleted_at IS NULL',
    ];
    final variables = <Variable>[
      Variable.withString(userId),
    ];

    final normalizedHouseholdId = householdId?.trim();
    if (normalizedHouseholdId == null || normalizedHouseholdId.isEmpty) {
      where.add("(household_id IS NULL OR household_id = '')");
    } else {
      where.add('household_id = ?');
      variables.add(Variable.withString(normalizedHouseholdId));
    }

    final normalizedCurrency = currency?.trim().toUpperCase();
    if (normalizedCurrency != null && normalizedCurrency.isNotEmpty) {
      where.add('UPPER(currency) = ?');
      variables.add(Variable.withString(normalizedCurrency));
    }

    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      '''
      SELECT * FROM local_transactions
      WHERE ${where.join(' AND ')}
      ORDER BY date_ymd DESC, created_at DESC
      LIMIT ?
      ''',
      variables: variables,
    ).get();
    return rows.map(LocalTransactionRecord.fromRow).toList(growable: false);
  }

  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  }) async {
    if (limit <= 0) {
      return const [];
    }

    final where = <String>[
      'user_id = ?',
      'deleted_at IS NULL',
      'sync_status = ?',
    ];
    final variables = <Variable>[
      Variable.withString(userId),
      Variable.withString('needsReview'),
    ];

    final normalizedHouseholdId = householdId?.trim();
    if (normalizedHouseholdId == null || normalizedHouseholdId.isEmpty) {
      where.add("(household_id IS NULL OR household_id = '')");
    } else {
      where.add('household_id = ?');
      variables.add(Variable.withString(normalizedHouseholdId));
    }
    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      '''
      SELECT * FROM local_transactions
      WHERE ${where.join(' AND ')}
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      variables: variables,
    ).get();
    return rows.map(LocalTransactionRecord.fromRow).toList(growable: false);
  }

  Future<SyncOpRecord> syncOpForAggregate(String aggregateLocalId) async {
    final row = await customSelect(
      'SELECT * FROM sync_ops WHERE aggregate_local_id = ? LIMIT 1',
      variables: [Variable.withString(aggregateLocalId)],
    ).getSingle();
    return SyncOpRecord.fromRow(row);
  }

  Future<List<SyncOpRecord>> pendingSyncOps({
    required String nowIso,
    int limit = 20,
  }) async {
    final rows = await customSelect(
      '''
      SELECT * FROM sync_ops
      WHERE status IN (?, ?)
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      variables: [
        Variable.withString('localOnly'),
        Variable.withString('failed'),
        Variable.withString(nowIso),
        Variable.withInt(limit),
      ],
    ).get();
    return rows.map(SyncOpRecord.fromRow).toList(growable: false);
  }

  Future<int> markSyncOpSyncing({
    required String id,
    required String updatedAt,
    required String startedAt,
  }) {
    return customUpdate(
      '''
      UPDATE sync_ops
      SET status = ?,
          updated_at = ?,
          started_at = ?,
          last_error = NULL
      WHERE id = ?
      ''',
      variables: [
        Variable.withString('syncing'),
        Variable.withString(updatedAt),
        Variable.withString(startedAt),
        Variable.withString(id),
      ],
    );
  }

  Future<int> markSyncOpSynced({
    required String id,
    required String updatedAt,
    required String completedAt,
    String? aggregateServerId,
  }) {
    return customUpdate(
      '''
      UPDATE sync_ops
      SET status = ?,
          updated_at = ?,
          completed_at = ?,
          aggregate_server_id = COALESCE(?, aggregate_server_id),
          last_error = NULL,
          next_retry_at = NULL
      WHERE id = ?
      ''',
      variables: [
        Variable.withString('synced'),
        Variable.withString(updatedAt),
        Variable.withString(completedAt),
        Variable<String>(aggregateServerId),
        Variable.withString(id),
      ],
    );
  }

  Future<int> markSyncOpFailed({
    required String id,
    required int attemptCount,
    required String lastError,
    required String nextRetryAt,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE sync_ops
      SET status = ?,
          attempt_count = ?,
          last_error = ?,
          next_retry_at = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      variables: [
        Variable.withString('failed'),
        Variable.withInt(attemptCount),
        Variable.withString(lastError),
        Variable.withString(nextRetryAt),
        Variable.withString(updatedAt),
        Variable.withString(id),
      ],
    );
  }

  Future<int> updateLocalTransactionSyncStatus({
    required String id,
    required String syncStatus,
    required String updatedAt,
    String? lastSyncError,
  }) {
    return customUpdate(
      '''
      UPDATE local_transactions
      SET sync_status = ?,
          updated_at = ?,
          last_sync_error = ?
      WHERE id = ?
      ''',
      variables: [
        Variable.withString(syncStatus),
        Variable.withString(updatedAt),
        Variable<String>(lastSyncError),
        Variable.withString(id),
      ],
    );
  }

  Future<int> markLocalTransactionSynced({
    required String id,
    required String? serverId,
    required String? serverUpdatedAt,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE local_transactions
      SET sync_status = ?,
          server_id = COALESCE(?, server_id),
          server_updated_at = COALESCE(?, server_updated_at),
          updated_at = ?,
          last_sync_error = NULL
      WHERE id = ?
      ''',
      variables: [
        Variable.withString('synced'),
        Variable<String>(serverId),
        Variable<String>(serverUpdatedAt),
        Variable.withString(updatedAt),
        Variable.withString(id),
      ],
    );
  }

  Future<int> markLocalTransactionReadyForSync({
    required String id,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE local_transactions
      SET sync_status = ?,
          review_reasons_json = ?,
          updated_at = ?,
          last_sync_error = NULL
      WHERE id = ?
      ''',
      variables: [
        Variable.withString('localOnly'),
        Variable.withString('[]'),
        Variable.withString(updatedAt),
        Variable.withString(id),
      ],
    );
  }

  Future<int> markSyncOpReadyForSync({
    required String aggregateLocalId,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE sync_ops
      SET status = ?,
          updated_at = ?,
          last_error = NULL,
          next_retry_at = NULL
      WHERE aggregate_type = ?
        AND aggregate_local_id = ?
      ''',
      variables: [
        Variable.withString('localOnly'),
        Variable.withString(updatedAt),
        Variable.withString('transaction'),
        Variable.withString(aggregateLocalId),
      ],
    );
  }

  Future<int> updateLocalTransactionReviewCategory({
    required String id,
    required String category,
    required String reviewReasonsJson,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE local_transactions
      SET category = ?,
          review_reasons_json = ?,
          updated_at = ?,
          last_sync_error = NULL
      WHERE id = ?
      ''',
      variables: [
        Variable.withString(category),
        Variable.withString(reviewReasonsJson),
        Variable.withString(updatedAt),
        Variable.withString(id),
      ],
    );
  }

  Future<int> updateSyncOpPayloadForAggregate({
    required String aggregateLocalId,
    required String payloadJson,
    required String updatedAt,
  }) {
    return customUpdate(
      '''
      UPDATE sync_ops
      SET payload_json = ?,
          updated_at = ?,
          last_error = NULL
      WHERE aggregate_type = ?
        AND aggregate_local_id = ?
      ''',
      variables: [
        Variable.withString(payloadJson),
        Variable.withString(updatedAt),
        Variable.withString('transaction'),
        Variable.withString(aggregateLocalId),
      ],
    );
  }
}

class LocalTransactionRecord {
  const LocalTransactionRecord({
    required this.id,
    required this.serverId,
    required this.clientMutationId,
    required this.userId,
    required this.householdId,
    required this.walletId,
    required this.bankAccountId,
    required this.contactId,
    required this.splitGroupId,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.category,
    required this.merchant,
    required this.rawText,
    required this.description,
    required this.breakdownJson,
    required this.dateYmd,
    required this.createdAt,
    required this.updatedAt,
    required this.captureSource,
    required this.syncStatus,
    required this.reviewReasonsJson,
    required this.receiptImageUrl,
    required this.isRecurring,
    required this.lastSyncError,
  });

  factory LocalTransactionRecord.fromRow(QueryRow row) {
    return LocalTransactionRecord(
      id: row.read<String>('id'),
      serverId: row.readNullable<String>('server_id'),
      clientMutationId: row.read<String>('client_mutation_id'),
      userId: row.read<String>('user_id'),
      householdId: row.readNullable<String>('household_id'),
      walletId: row.readNullable<String>('wallet_id'),
      bankAccountId: row.readNullable<String>('bank_account_id'),
      contactId: row.readNullable<String>('contact_id'),
      splitGroupId: row.readNullable<String>('split_group_id'),
      type: row.read<String>('type'),
      amountCents: row.read<int>('amount_cents'),
      currency: row.read<String>('currency'),
      category: row.readNullable<String>('category'),
      merchant: row.readNullable<String>('merchant'),
      rawText: row.readNullable<String>('raw_text'),
      description: row.readNullable<String>('description'),
      breakdownJson: row.read<String>('breakdown_json'),
      dateYmd: row.read<String>('date_ymd'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
      captureSource: row.read<String>('capture_source'),
      syncStatus: row.read<String>('sync_status'),
      reviewReasonsJson: row.read<String>('review_reasons_json'),
      receiptImageUrl: row.readNullable<String>('receipt_image_url'),
      isRecurring: row.read<int>('is_recurring') != 0,
      lastSyncError: row.readNullable<String>('last_sync_error'),
    );
  }

  final String id;
  final String? serverId;
  final String clientMutationId;
  final String userId;
  final String? householdId;
  final String? walletId;
  final String? bankAccountId;
  final String? contactId;
  final String? splitGroupId;
  final String type;
  final int amountCents;
  final String currency;
  final String? category;
  final String? merchant;
  final String? rawText;
  final String? description;
  final String breakdownJson;
  final String dateYmd;
  final String createdAt;
  final String updatedAt;
  final String captureSource;
  final String syncStatus;
  final String reviewReasonsJson;
  final String? receiptImageUrl;
  final bool isRecurring;
  final String? lastSyncError;
}

class SyncOpRecord {
  const SyncOpRecord({
    required this.id,
    required this.aggregateType,
    required this.aggregateLocalId,
    required this.operationType,
    required this.status,
    required this.payloadJson,
    required this.idempotencyKey,
    required this.attemptCount,
    required this.lastError,
    required this.nextRetryAt,
    required this.startedAt,
    required this.completedAt,
  });

  factory SyncOpRecord.fromRow(QueryRow row) {
    return SyncOpRecord(
      id: row.read<String>('id'),
      aggregateType: row.read<String>('aggregate_type'),
      aggregateLocalId: row.read<String>('aggregate_local_id'),
      operationType: row.read<String>('operation_type'),
      status: row.read<String>('status'),
      payloadJson: row.read<String>('payload_json'),
      idempotencyKey: row.read<String>('idempotency_key'),
      attemptCount: row.read<int>('attempt_count'),
      lastError: row.readNullable<String>('last_error'),
      nextRetryAt: row.readNullable<String>('next_retry_at'),
      startedAt: row.readNullable<String>('started_at'),
      completedAt: row.readNullable<String>('completed_at'),
    );
  }

  final String id;
  final String aggregateType;
  final String aggregateLocalId;
  final String operationType;
  final String status;
  final String payloadJson;
  final String idempotencyKey;
  final int attemptCount;
  final String? lastError;
  final String? nextRetryAt;
  final String? startedAt;
  final String? completedAt;
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'moneko_local',
    native: const DriftNativeOptions(shareAcrossIsolates: true),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

const _createLocalTransactionsTable = '''
CREATE TABLE local_transactions (
  id TEXT NOT NULL PRIMARY KEY,
  server_id TEXT UNIQUE,
  client_mutation_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  household_id TEXT,
  wallet_id TEXT,
  bank_account_id TEXT,
  contact_id TEXT,
  split_group_id TEXT,
  type TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL,
  base_currency TEXT,
  normalized_amount_cents INTEGER,
  fx_rate REAL,
  category TEXT,
  merchant TEXT,
  raw_text TEXT,
  description TEXT,
  breakdown_json TEXT NOT NULL,
  date_ymd TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  server_created_at TEXT,
  server_updated_at TEXT,
  deleted_at TEXT,
  capture_source TEXT NOT NULL,
  confidence_score REAL,
  sync_status TEXT NOT NULL,
  review_reasons_json TEXT NOT NULL,
  local_revision INTEGER NOT NULL DEFAULT 1,
  server_revision INTEGER,
  base_server_revision INTEGER,
  receipt_local_path TEXT,
  receipt_image_url TEXT,
  provider_transaction_id TEXT,
  provider TEXT,
  is_recurring INTEGER NOT NULL DEFAULT 0,
  recurrence_rule_json TEXT,
  payer_user_id TEXT,
  is_portfolio INTEGER NOT NULL DEFAULT 0,
  last_sync_error TEXT
)
''';

const _createSyncOpsTable = '''
CREATE TABLE sync_ops (
  id TEXT NOT NULL PRIMARY KEY,
  aggregate_type TEXT NOT NULL,
  aggregate_local_id TEXT NOT NULL,
  aggregate_server_id TEXT,
  operation_type TEXT NOT NULL,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  next_retry_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  started_at TEXT,
  completed_at TEXT
)
''';

const _createLocalTransactionsUserDateIndex =
    'CREATE INDEX local_transactions_user_date_idx '
    'ON local_transactions (user_id, date_ymd)';

const _createLocalTransactionsWalletDateIndex =
    'CREATE INDEX local_transactions_wallet_date_idx '
    'ON local_transactions (wallet_id, date_ymd)';

const _createSyncOpsStatusIndex =
    'CREATE INDEX sync_ops_status_idx ON sync_ops (status, next_retry_at)';

const _createSyncOpsAggregateIndex = 'CREATE INDEX sync_ops_aggregate_idx '
    'ON sync_ops (aggregate_type, aggregate_local_id)';

const _insertLocalTransaction = '''
INSERT INTO local_transactions (
  id,
  server_id,
  client_mutation_id,
  user_id,
  household_id,
  wallet_id,
  bank_account_id,
  contact_id,
  split_group_id,
  type,
  amount_cents,
  currency,
  base_currency,
  normalized_amount_cents,
  fx_rate,
  category,
  merchant,
  raw_text,
  description,
  breakdown_json,
  date_ymd,
  created_at,
  updated_at,
  server_created_at,
  server_updated_at,
  deleted_at,
  capture_source,
  confidence_score,
  sync_status,
  review_reasons_json,
  local_revision,
  server_revision,
  base_server_revision,
  receipt_local_path,
  receipt_image_url,
  provider_transaction_id,
  provider,
  is_recurring,
  recurrence_rule_json,
  payer_user_id,
  is_portfolio,
  last_sync_error
) VALUES (
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
  ?, ?
)
''';

const _insertSyncOp = '''
INSERT INTO sync_ops (
  id,
  aggregate_type,
  aggregate_local_id,
  aggregate_server_id,
  operation_type,
  status,
  payload_json,
  idempotency_key,
  attempt_count,
  last_error,
  next_retry_at,
  created_at,
  updated_at,
  started_at,
  completed_at
) VALUES (
  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
)
''';

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/util/logger.dart';
import '../../../core/local_database/app_database.dart';
import '../../../core/sync/domain/sync_operation_type.dart';
import '../../../core/sync/domain/sync_status.dart';
import '../domain/transaction_command.dart';
import '../domain/transaction_repository.dart';

typedef DateTimeFactory = DateTime Function();
typedef StringFactory = String Function();

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required this.database,
    DateTimeFactory? clock,
    StringFactory? idFactory,
    StringFactory? mutationIdFactory,
    StringFactory? syncOpIdFactory,
  })  : clock = clock ?? DateTime.now,
        idFactory = idFactory ?? _uuid,
        mutationIdFactory = mutationIdFactory ?? _uuid,
        syncOpIdFactory = syncOpIdFactory ?? _uuid;

  final AppDatabase database;
  final DateTimeFactory clock;
  final StringFactory idFactory;
  final StringFactory mutationIdFactory;
  final StringFactory syncOpIdFactory;

  @override
  Future<String> createLocalTransaction(
    CreateTransactionCommand command,
  ) async {
    _validate(command);

    final transactionId = idFactory();
    final mutationId = mutationIdFactory();
    final syncOpId = syncOpIdFactory();
    final now = clock().toUtc();
    final nowIso = now.toIso8601String();
    final syncStatus = command.reviewReasons.isEmpty
        ? SyncStatus.localOnly
        : SyncStatus.needsReview;

    final syncPayload = jsonEncode(_toSyncPayload(
      command: command,
      transactionId: transactionId,
      mutationId: mutationId,
      createdAt: nowIso,
      updatedAt: nowIso,
      syncStatus: syncStatus,
    ));

    await database.transaction(() async {
      await database.insertLocalTransaction(
        id: transactionId,
        clientMutationId: mutationId,
        userId: command.userId,
        householdId: command.householdId,
        walletId: command.walletId,
        bankAccountId: command.bankAccountId,
        contactId: command.contactId,
        splitGroupId: command.splitGroupId,
        type: command.type.name,
        amountCents: command.amountCents,
        currency: command.currency.toUpperCase(),
        category: command.category,
        merchant: command.merchant,
        rawText: command.rawText,
        description: command.description,
        breakdownJson: jsonEncode(command.breakdown),
        dateYmd: _formatDateYmd(command.date),
        createdAt: nowIso,
        updatedAt: nowIso,
        captureSource: command.captureSource.name,
        confidenceScore: command.confidenceScore,
        syncStatus: syncStatus.name,
        reviewReasonsJson: jsonEncode(command.reviewReasons),
        receiptLocalPath: command.receiptLocalPath,
        receiptImageUrl: command.receiptImageUrl,
        providerTransactionId: command.providerTransactionId,
        provider: command.provider,
        isRecurring: command.isRecurring,
        recurrenceRuleJson: command.recurrenceRule == null
            ? null
            : jsonEncode(command.recurrenceRule),
        payerUserId: command.payerUserId,
        isPortfolio: command.isPortfolio,
      );
      await database.insertSyncOp(
        id: syncOpId,
        aggregateType: 'transaction',
        aggregateLocalId: transactionId,
        operationType: SyncOperationType.create.name,
        status: syncStatus.name,
        payloadJson: syncPayload,
        idempotencyKey: mutationId,
        createdAt: nowIso,
        updatedAt: nowIso,
      );
    });

    appLog(
      'Queued local transaction id=$transactionId '
      'status=${syncStatus.name} '
      'capture=${command.captureSource.name} '
      'hasWallet=${command.walletId != null} '
      'hasHousehold=${command.householdId != null} '
      'reviewReasons=${command.reviewReasons}',
      name: 'TransactionRepository',
    );

    return transactionId;
  }

  @override
  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  }) {
    return database.needsReviewTransactions(
      userId: userId,
      householdId: householdId,
      limit: limit,
    );
  }

  @override
  Future<void> markTransactionReviewed(String transactionId) async {
    final nowIso = clock().toUtc().toIso8601String();
    await database.transaction(() async {
      await database.markLocalTransactionReadyForSync(
        id: transactionId,
        updatedAt: nowIso,
      );
      await database.markSyncOpReadyForSync(
        aggregateLocalId: transactionId,
        updatedAt: nowIso,
      );
    });
  }

  @override
  Future<void> updateReviewCategory({
    required String transactionId,
    required String category,
  }) async {
    final normalizedCategory = category.trim().toLowerCase();
    if (normalizedCategory.isEmpty) {
      throw ArgumentError.value(category, 'category', 'must not be empty');
    }

    final transaction = await database.localTransactionById(transactionId);
    final nextReviewReasons = _decodeStringList(transaction.reviewReasonsJson)
        .where((reason) => reason != 'missingCategory')
        .toList(growable: false);
    final reviewReasonsJson = jsonEncode(nextReviewReasons);
    final syncOp = await database.syncOpForAggregate(transactionId);
    final payload = _decodeSyncPayload(syncOp.payloadJson)
      ..['category'] = normalizedCategory
      ..['reviewReasons'] = nextReviewReasons;
    final nowIso = clock().toUtc().toIso8601String();

    await database.transaction(() async {
      await database.updateLocalTransactionReviewCategory(
        id: transactionId,
        category: normalizedCategory,
        reviewReasonsJson: reviewReasonsJson,
        updatedAt: nowIso,
      );
      await database.updateSyncOpPayloadForAggregate(
        aggregateLocalId: transactionId,
        payloadJson: jsonEncode(payload),
        updatedAt: nowIso,
      );
    });
  }

  static void _validate(CreateTransactionCommand command) {
    if (command.userId.trim().isEmpty) {
      throw ArgumentError.value(command.userId, 'userId', 'must not be empty');
    }
    final walletId = command.walletId;
    if (walletId != null && walletId.trim().isEmpty) {
      throw ArgumentError.value(walletId, 'walletId', 'must not be empty');
    }
    if (command.amountCents <= 0) {
      throw ArgumentError.value(
        command.amountCents,
        'amountCents',
        'must be positive',
      );
    }
    if (command.currency.trim().length != 3) {
      throw ArgumentError.value(
        command.currency,
        'currency',
        'must be an ISO 4217 code',
      );
    }
    final confidenceScore = command.confidenceScore;
    if (confidenceScore != null &&
        (confidenceScore < 0 || confidenceScore > 1)) {
      throw ArgumentError.value(
        confidenceScore,
        'confidenceScore',
        'must be between 0 and 1',
      );
    }
  }

  static Map<String, Object?> _toSyncPayload({
    required CreateTransactionCommand command,
    required String transactionId,
    required String mutationId,
    required String createdAt,
    required String updatedAt,
    required SyncStatus syncStatus,
  }) {
    return {
      'localId': transactionId,
      'clientMutationId': mutationId,
      'userId': command.userId,
      'householdId': command.householdId,
      'walletId': command.walletId,
      'bankAccountId': command.bankAccountId,
      'contactId': command.contactId,
      'splitGroupId': command.splitGroupId,
      'type': command.type.name,
      'amountCents': command.amountCents,
      'currency': command.currency.toUpperCase(),
      'category': command.category,
      'merchant': command.merchant,
      'rawText': command.rawText,
      'description': command.description,
      'breakdown': command.breakdown,
      'dateYmd': _formatDateYmd(command.date),
      'captureSource': command.captureSource.name,
      'confidenceScore': command.confidenceScore,
      'syncStatus': syncStatus.name,
      'reviewReasons': command.reviewReasons,
      'receiptLocalPath': command.receiptLocalPath,
      'receiptImageUrl': command.receiptImageUrl,
      'recurrenceRule': command.recurrenceRule,
      'customSplits': command.customSplits,
      'providerTransactionId': command.providerTransactionId,
      'provider': command.provider,
      'payerUserId': command.payerUserId,
      'isRecurring': command.isRecurring,
      'isPortfolio': command.isPortfolio,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static String _formatDateYmd(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static List<String> _decodeStringList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <String>[];
    }
    return decoded
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _decodeSyncPayload(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Sync payload must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

String _uuid() => const Uuid().v4();

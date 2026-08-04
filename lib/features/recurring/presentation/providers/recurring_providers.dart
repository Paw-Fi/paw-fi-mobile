import 'dart:async';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider, widgetSyncVersionProvider;
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/utils/recurring_occurrence_schedule.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart'
    show SplitType, MemberSplit;
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/app/router.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

void _homeSpendTrace(String message) {
  assert(() {
    foundation.debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

String _buildAnchorDateYmd(DateTime startDate) {
  return formatDateOnlyYmd(
    DateTime(startDate.year, startDate.month, startDate.day),
  );
}

String _buildClientCreatedAtIso(Ref ref) {
  return DateTime.now().toUtc().toIso8601String();
}

String? _buildEndDateYmd(DateTime? endDate) {
  if (endDate == null) return null;
  return formatDateOnlyYmd(DateTime(endDate.year, endDate.month, endDate.day));
}

String _makeOptimisticRecurringId() {
  return 'optimistic-recurring-${DateTime.now().microsecondsSinceEpoch}';
}

RecurringTransaction recurringTransactionFromExpenseEntry(ExpenseEntry entry) {
  final description = entry.rawText?.trim();
  return RecurringTransaction(
    id: entry.id,
    userId: entry.userId,
    date: entry.date,
    category: entry.category ?? 'Uncategorized',
    description: description?.isEmpty == true ? null : description,
    merchant: entry.merchant,
    amount: entry.amount,
    currency: entry.currency ?? 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: entry.householdId,
    splitGroupId: entry.splitGroupId,
    accountId: entry.walletId,
    recurrenceRule: _recurrenceRuleFromExpenseEntry(entry),
    type: entry.type ?? 'expense',
    attachments: const [],
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    analyticsClass: entry.analyticsClass,
    analyticsIsFinal: entry.analyticsIsFinal,
    analyticsSpendingMultiplier: entry.analyticsSpendingMultiplier,
    analyticsCountsTowardIncome: entry.analyticsCountsTowardIncome,
  );
}

RecurrenceRule? _recurrenceRuleFromExpenseEntry(ExpenseEntry entry) {
  final recurrenceRuleJson = entry.recurrenceRuleJson;
  if (recurrenceRuleJson == null) return null;
  try {
    return RecurrenceRule.fromJson(recurrenceRuleJson);
  } catch (_) {
    return null;
  }
}

ExpenseEntry _expenseEntryFromRecurringTransaction(
  RecurringTransaction transaction,
  String fallbackUserId,
) {
  return ExpenseEntry(
    id: transaction.id,
    userId: transaction.userId?.trim().isNotEmpty == true
        ? transaction.userId
        : fallbackUserId,
    householdId: transaction.householdId,
    date: transaction.date,
    amountCents: (transaction.amount * 100).round(),
    currency: transaction.currency,
    category: transaction.category,
    createdAt: transaction.createdAt,
    updatedAt: transaction.updatedAt,
    rawText:
        transaction.description ?? transaction.merchant ?? transaction.source,
    merchant: transaction.merchant,
    splitGroupId: transaction.splitGroupId,
    walletId: transaction.accountId,
    type: transaction.type,
    analyticsClass: transaction.analyticsClass,
    analyticsIsFinal: transaction.analyticsIsFinal,
    analyticsSpendingMultiplier: transaction.analyticsSpendingMultiplier,
    analyticsCountsTowardIncome: transaction.analyticsCountsTowardIncome,
    isRecurring: true,
    recurrenceRuleJson: transaction.recurrenceRule?.toJson(),
  );
}

RecurringTransaction _buildOptimisticRecurringTransaction({
  required String userId,
  required String type,
  required double amount,
  required String category,
  required String currency,
  required DateTime startDate,
  required String frequency,
  DateTime? endDate,
  int? interval,
  String? description,
  String? merchant,
  String? source,
  bool? hasReminder,
  int? reminderValue,
  String? reminderUnit,
  bool projectionEnabled = true,
  String ownerType = 'me',
  String privacyScope = 'full',
  String? householdId,
  String? payerUserId,
  String? accountId,
}) {
  final now = DateTime.now();
  return RecurringTransaction(
    id: _makeOptimisticRecurringId(),
    userId: userId,
    date: DateTime(startDate.year, startDate.month, startDate.day),
    category: category,
    description: description,
    merchant: merchant,
    source: source,
    amount: amount,
    currency: currency,
    ownerType: ownerType,
    privacyScope: privacyScope,
    householdId: householdId,
    payerUserId: payerUserId,
    accountId: accountId,
    recurrenceRule: RecurrenceRule(
      frequency: frequency,
      anchorDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endDate == null
          ? null
          : DateTime(endDate.year, endDate.month, endDate.day),
      interval: interval,
      reminderEnabled: hasReminder,
      reminderValue: hasReminder == true ? reminderValue : null,
      reminderUnit: hasReminder == true ? reminderUnit : null,
      projectionEnabled: projectionEnabled,
    ),
    type: type,
    attachments: const [],
    createdAt: now,
    updatedAt: now,
  );
}

// ============================================================================
// STATE CLASSES WITH CACHING SUPPORT - SINGLE SOURCE OF TRUTH
// ============================================================================

/// Combined state class for ALL recurring transactions (single source of truth)
/// Frontend will filter by type (expense/income) from this unified list
class RecurringTransactionsState {
  final AsyncValue<List<RecurringTransaction>> data;
  final bool hasLoadedOnce;

  RecurringTransactionsState({
    required this.data,
    this.hasLoadedOnce = false,
  });

  RecurringTransactionsState copyWith({
    AsyncValue<List<RecurringTransaction>>? data,
    bool? hasLoadedOnce,
  }) {
    return RecurringTransactionsState(
      data: data ?? this.data,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

@immutable
class DeleteRecurringResult {
  final bool success;
  final String? error;

  const DeleteRecurringResult._({
    required this.success,
    this.error,
  });

  const DeleteRecurringResult.success() : this._(success: true);

  const DeleteRecurringResult.failure([String? error])
      : this._(success: false, error: error);
}

const String recurringOccurrenceConfirmationOperation =
    localRecurringOccurrenceConfirmationMutationOperation;

String recurringOccurrenceIdempotencyKey({
  required String userId,
  required String recurringId,
  required DateTime scheduledOccurrenceDate,
}) {
  return 'recurring-occurrence:v1:${userId.trim()}:${recurringId.trim()}:'
      '${formatDateOnlyYmd(scheduledOccurrenceDate)}';
}

@immutable
class RecurringOccurrenceConfirmationCommand {
  const RecurringOccurrenceConfirmationCommand({
    required this.userId,
    required this.recurringTransaction,
    required this.scheduledOccurrenceDate,
    required this.paidDate,
    required this.amountCents,
    required this.accountId,
    this.merchant,
    this.description,
    this.customSplits,
    this.payerUserId,
    this.updateFutureAmount = false,
  });

  final String userId;
  final RecurringTransaction recurringTransaction;
  final DateTime scheduledOccurrenceDate;
  final DateTime paidDate;
  final int amountCents;
  final String? accountId;
  final String? merchant;
  final String? description;
  final Map<String, dynamic>? customSplits;
  final String? payerUserId;
  final bool updateFutureAmount;

  String get idempotencyKey => recurringOccurrenceIdempotencyKey(
        userId: userId,
        recurringId: recurringTransaction.id,
        scheduledOccurrenceDate: scheduledOccurrenceDate,
      );

  String get optimisticId =>
      'optimistic-recurring-occurrence-${recurringTransaction.id}-${formatDateOnlyYmd(scheduledOccurrenceDate)}';

  Map<String, dynamic> toRequestBody() => <String, dynamic>{
        'userId': userId,
        'recurringId': recurringTransaction.id,
        'scheduledOccurrenceDate': formatDateOnlyYmd(scheduledOccurrenceDate),
        'paidDate': formatDateOnlyYmd(paidDate),
        'amount': amountCents / 100,
        if (accountId?.trim().isNotEmpty == true)
          'accountId': accountId!.trim(),
        if (merchant?.trim().isNotEmpty == true) 'merchant': merchant!.trim(),
        if (description?.trim().isNotEmpty == true)
          'description': description!.trim(),
        if (customSplits != null) 'customSplits': customSplits,
        if (payerUserId?.trim().isNotEmpty == true) 'payerUserId': payerUserId,
        'updateFutureAmount': updateFutureAmount,
        'clientMutationId': idempotencyKey,
        'idempotencyKey': idempotencyKey,
      };
}

@immutable
class RecurringOccurrenceUpdateCommand {
  const RecurringOccurrenceUpdateCommand({
    required this.userId,
    required this.recurringTransaction,
    required this.occurrence,
    required this.paidDate,
    required this.amountCents,
    required this.accountId,
    this.merchant,
    this.description,
    this.updateFutureAmount = false,
  });

  final String userId;
  final RecurringTransaction recurringTransaction;
  final RecurringOccurrenceTimelineItem occurrence;
  final DateTime paidDate;
  final int? amountCents;
  final String? accountId;
  final String? merchant;
  final String? description;
  final bool updateFutureAmount;

  Map<String, dynamic> toRequestBody() => <String, dynamic>{
        'userId': userId,
        'recurringId': recurringTransaction.id,
        'scheduledOccurrenceDate':
            formatDateOnlyYmd(occurrence.scheduledOccurrenceDate),
        if (!occurrence.isSettlementLocked) 'merchant': merchant?.trim(),
        if (!occurrence.isSettlementLocked) ...{
          'paidDate': formatDateOnlyYmd(paidDate),
          'amount': amountCents! / 100,
          if (accountId?.trim().isNotEmpty == true)
            'accountId': accountId!.trim(),
          'updateFutureAmount': updateFutureAmount,
        },
        'description': description?.trim() ?? '',
      };
}

@immutable
class RecurringOccurrenceUnconfirmCommand {
  const RecurringOccurrenceUnconfirmCommand({
    required this.userId,
    required this.recurringTransaction,
    required this.occurrence,
  });

  final String userId;
  final RecurringTransaction recurringTransaction;
  final RecurringOccurrenceTimelineItem occurrence;

  Map<String, dynamic> toRequestBody() => <String, dynamic>{
        'userId': userId,
        'recurringId': recurringTransaction.id,
        'scheduledOccurrenceDate':
            formatDateOnlyYmd(occurrence.scheduledOccurrenceDate),
      };
}

@immutable
class RecurringOccurrenceConfirmationResult {
  const RecurringOccurrenceConfirmationResult.queued({
    required this.optimisticId,
    required this.idempotencyKey,
  })  : isQueued = true,
        error = null;

  const RecurringOccurrenceConfirmationResult.failure(this.error)
      : optimisticId = null,
        idempotencyKey = null,
        isQueued = false;

  final String? optimisticId;
  final String? idempotencyKey;
  final bool isQueued;
  final String? error;
}

@immutable
class RecurringOccurrenceTimelineQuery {
  const RecurringOccurrenceTimelineQuery({
    required this.userId,
    required this.householdId,
    required this.recurringId,
    required this.startDate,
    required this.endDate,
  });

  final String userId;
  final String? householdId;
  final String recurringId;
  final DateTime startDate;
  final DateTime endDate;

  @override
  bool operator ==(Object other) =>
      other is RecurringOccurrenceTimelineQuery &&
      userId == other.userId &&
      householdId == other.householdId &&
      recurringId == other.recurringId &&
      formatDateOnlyYmd(startDate) == formatDateOnlyYmd(other.startDate) &&
      formatDateOnlyYmd(endDate) == formatDateOnlyYmd(other.endDate);

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        recurringId,
        formatDateOnlyYmd(startDate),
        formatDateOnlyYmd(endDate),
      );
}

@immutable
class RecurringOccurrenceTimelineItem {
  const RecurringOccurrenceTimelineItem({
    this.occurrenceId,
    required this.scheduledOccurrenceDate,
    required this.status,
    this.actualTransaction,
    this.paidDate,
    this.amountCents,
    this.currency,
    this.confirmedAt,
    this.confirmationSource,
    this.isSettlementLocked = false,
    this.wasSkippedBeforeConfirmation = false,
  });

  final String? occurrenceId;
  final DateTime scheduledOccurrenceDate;
  final String status;
  final ExpenseEntry? actualTransaction;
  final DateTime? paidDate;
  final int? amountCents;
  final String? currency;
  final DateTime? confirmedAt;
  final String? confirmationSource;
  final bool isSettlementLocked;
  final bool wasSkippedBeforeConfirmation;

  bool get isConfirmed => status == 'confirmed';
  bool get isSkipped => status == 'skipped';
  bool get isImported => confirmationSource == 'legacy_migration';

  factory RecurringOccurrenceTimelineItem.fromPersistedJson(
    Map<String, dynamic> json,
  ) {
    final occurrence = Map<String, dynamic>.from(json['occurrence'] as Map);
    final transaction = json['transaction'];
    final scheduledDate = DateTime.parse(
      occurrence['scheduled_occurrence_date'] as String,
    );
    final paidDate = occurrence['paid_date'] as String?;
    final confirmedAt = occurrence['confirmed_at'] as String?;
    return RecurringOccurrenceTimelineItem(
      occurrenceId: occurrence['id']?.toString(),
      scheduledOccurrenceDate: scheduledDate,
      status: occurrence['status']?.toString() ?? 'pending',
      actualTransaction: transaction is Map
          ? ExpenseEntry.fromJson(Map<String, dynamic>.from(transaction))
          : null,
      paidDate: paidDate == null ? null : DateTime.tryParse(paidDate),
      amountCents: (occurrence['amount_cents'] as num?)?.round(),
      currency: occurrence['currency']?.toString(),
      confirmedAt: confirmedAt == null ? null : DateTime.tryParse(confirmedAt),
      confirmationSource: occurrence['confirmation_source']?.toString(),
      isSettlementLocked: json['settlement_locked'] == true,
      wasSkippedBeforeConfirmation:
          occurrence['was_skipped_before_confirmation'] == true,
    );
  }

  factory RecurringOccurrenceTimelineItem.fromLocalEntry(ExpenseEntry entry) {
    return RecurringOccurrenceTimelineItem(
      scheduledOccurrenceDate: entry.scheduledOccurrenceDate!,
      status: 'confirmed',
      actualTransaction: entry,
      paidDate: entry.date,
      amountCents: entry.amountCents,
      currency: entry.currency,
      confirmedAt: entry.recurringConfirmedAt,
      confirmationSource: entry.recurringConfirmationSource,
    );
  }
}

final recurringOccurrenceTimelineProvider = FutureProvider.family<
    List<RecurringOccurrenceTimelineItem>, RecurringOccurrenceTimelineQuery>(
  (ref, query) async {
    ref.watch(transactionsFeedRefreshSignalProvider);
    final database = await ref.watch(localDatabaseProvider.future);
    final entries = await database.getTransactionsByScheduledOccurrenceRange(
      userId: query.userId,
      householdId: query.householdId,
      parentRecurringId: query.recurringId,
      startDate: query.startDate,
      endDate: query.endDate,
    );
    final localItems = entries
        .where((entry) => entry.scheduledOccurrenceDate != null)
        .map(RecurringOccurrenceTimelineItem.fromLocalEntry)
        .toList(growable: false);
    try {
      final response = await supabase.functions.invoke(
        'list-recurring-occurrences',
        body: {
          'userId': query.userId,
          'recurringId': query.recurringId,
          'limit': 100,
        },
      );
      final payload = response.data;
      if (payload is! Map || payload['success'] != true) return localItems;
      final persistedItems = (payload['data'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => RecurringOccurrenceTimelineItem.fromPersistedJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) =>
              !item.scheduledOccurrenceDate.isBefore(query.startDate) &&
              !item.scheduledOccurrenceDate.isAfter(query.endDate))
          .toList(growable: false);
      final itemsByScheduledDate = <String, RecurringOccurrenceTimelineItem>{
        for (final item in persistedItems)
          formatDateOnlyYmd(item.scheduledOccurrenceDate): item,
        // Pending local confirmations must take precedence until reconciliation.
        for (final item in localItems)
          formatDateOnlyYmd(item.scheduledOccurrenceDate): item,
      };
      final merged = itemsByScheduledDate.values.toList(growable: false)
        ..sort((a, b) => b.scheduledOccurrenceDate.compareTo(
              a.scheduledOccurrenceDate,
            ));
      return merged;
    } catch (_) {
      return localItems;
    }
  },
);

final recurringOccurrenceConfirmationProvider =
    Provider<RecurringOccurrenceConfirmationController>(
  (ref) => RecurringOccurrenceConfirmationController(ref),
);

final recurringOccurrenceUpdateProvider =
    Provider<RecurringOccurrenceUpdateController>(
  (ref) => RecurringOccurrenceUpdateController(ref),
);

final recurringOccurrenceUnconfirmProvider =
    Provider<RecurringOccurrenceUnconfirmController>(
  (ref) => RecurringOccurrenceUnconfirmController(ref),
);

class RecurringOccurrenceUpdateController {
  const RecurringOccurrenceUpdateController(this._ref);

  final Ref _ref;

  Future<RecurringOccurrenceConfirmationResult> update(
    RecurringOccurrenceUpdateCommand command,
  ) async {
    if (_ref.read(previewModeProvider).isActive) {
      _showPreviewToast();
      return const RecurringOccurrenceConfirmationResult.failure(
        'Preview mode is read-only.',
      );
    }
    if (command.userId.trim().isEmpty ||
        command.recurringTransaction.id.trim().isEmpty ||
        (!_isNotesOnly(command) &&
            (command.amountCents == null ||
                command.amountCents! <= 0 ||
                command.accountId?.trim().isEmpty == true))) {
      return const RecurringOccurrenceConfirmationResult.failure(
        'A user, recurring transaction, and positive amount are required.',
      );
    }

    final mutationId =
        'update-recurring-occurrence:${command.recurringTransaction.id}:'
        '${formatDateOnlyYmd(command.occurrence.scheduledOccurrenceDate)}:'
        '${DateTime.now().microsecondsSinceEpoch}';
    final occurrenceHandle = _ref
        .read(recurringOccurrenceOptimisticProvider.notifier)
        .upsert(
          mutationId: mutationId,
          occurrence: RecurringOccurrenceSummary(
            id: command.occurrence.occurrenceId ?? mutationId,
            recurringId: command.recurringTransaction.id,
            scheduledOccurrenceDate: command.occurrence.scheduledOccurrenceDate,
            status: command.occurrence.status,
            confirmationSource: command.occurrence.confirmationSource,
            actualTransactionId: command.occurrence.actualTransaction?.id,
            paidDate: command.occurrence.isSettlementLocked
                ? command.occurrence.paidDate
                : command.paidDate,
            amountCents: command.occurrence.isSettlementLocked
                ? command.occurrence.amountCents
                : command.amountCents,
            currency: command.occurrence.currency ??
                command.recurringTransaction.currency,
            confirmedAt: command.occurrence.confirmedAt,
            confirmedByUserId: command.userId,
            createdAt: command.occurrence.confirmedAt,
            updatedAt: DateTime.now(),
          ),
        );
    final seriesHandle =
        command.updateFutureAmount && command.amountCents != null
            ? _ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                  mutationId: mutationId,
                  transaction: command.recurringTransaction.copyWith(
                    amount: command.amountCents! / 100,
                  ),
                )
            : null;

    try {
      final original = command.occurrence.actualTransaction;
      if (original == null) {
        throw StateError('The confirmed transaction is unavailable.');
      }
      final updated = original.copyWith(
        date: command.occurrence.isSettlementLocked
            ? original.date
            : command.paidDate,
        amountCents: command.occurrence.isSettlementLocked
            ? original.amountCents
            : command.amountCents,
        accountId: command.occurrence.isSettlementLocked
            ? original.walletId
            : command.accountId,
        merchant: command.occurrence.isSettlementLocked
            ? original.merchant
            : command.merchant,
        rawText: command.description,
        updatedAt: DateTime.now(),
        clientMutationId: mutationId,
      );
      final database = await _ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransactionUpdate(
        originalEntry: original,
        updatedEntry: updated,
        clientMutationId: mutationId,
        operation: 'update_recurring_occurrence',
        payload: {
          'functionName': 'update-recurring-occurrence',
          'requestBody': command.toRequestBody(),
        },
        relatedOriginalEntry: command.updateFutureAmount
            ? _expenseEntryFromRecurringTransaction(
                command.recurringTransaction,
                command.userId,
              )
            : null,
        relatedUpdatedEntry:
            command.updateFutureAmount && command.amountCents != null
                ? _expenseEntryFromRecurringTransaction(
                    command.recurringTransaction.copyWith(
                      amount: command.amountCents! / 100,
                    ),
                    command.userId,
                  )
                : null,
      );
      _ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
      _ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      _ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
      _ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      _ref.read(widgetSyncVersionProvider.notifier).state += 1;
      _ref.invalidate(recurringTransactionsProvider(
        command.recurringTransaction.householdId,
      ));
      _ref.invalidate(pocketsProvider);
      _ref.invalidate(currencyTransactionCountsProvider);
      unawaited(drainMobileOutbox(_ref));
      return RecurringOccurrenceConfirmationResult.queued(
        optimisticId: command.recurringTransaction.id,
        idempotencyKey: mutationId,
      );
    } catch (error) {
      _ref
          .read(recurringOccurrenceOptimisticProvider.notifier)
          .rollback(occurrenceHandle);
      if (seriesHandle != null) {
        _ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(seriesHandle);
      }
      return RecurringOccurrenceConfirmationResult.failure(
        ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }

  bool _isNotesOnly(RecurringOccurrenceUpdateCommand command) =>
      command.occurrence.isSettlementLocked;
}

class RecurringOccurrenceUnconfirmController {
  const RecurringOccurrenceUnconfirmController(this._ref);

  final Ref _ref;

  Future<RecurringOccurrenceConfirmationResult> unconfirm(
    RecurringOccurrenceUnconfirmCommand command,
  ) async {
    if (_ref.read(previewModeProvider).isActive) {
      _showPreviewToast();
      return const RecurringOccurrenceConfirmationResult.failure(
        'Preview mode is read-only.',
      );
    }
    if (command.userId.trim().isEmpty ||
        command.recurringTransaction.id.trim().isEmpty ||
        !command.occurrence.isConfirmed) {
      return const RecurringOccurrenceConfirmationResult.failure(
        'A confirmed recurring occurrence is required.',
      );
    }

    final mutationId =
        'unconfirm-recurring-occurrence:${command.recurringTransaction.id}:'
        '${formatDateOnlyYmd(command.occurrence.scheduledOccurrenceDate)}:'
        '${DateTime.now().microsecondsSinceEpoch}';
    final occurrenceHandle = _ref
        .read(recurringOccurrenceOptimisticProvider.notifier)
        .remove(
          mutationId: mutationId,
          recurringId: command.recurringTransaction.id,
          scheduledOccurrenceDate: command.occurrence.scheduledOccurrenceDate,
        );
    final existingRule = command.recurringTransaction.recurrenceRule;
    final restoredRule =
        existingRule == null || command.occurrence.wasSkippedBeforeConfirmation
            ? existingRule
            : existingRule.copyWith(
                excludedDates: existingRule.excludedDates
                    .where((date) =>
                        formatDateOnlyYmd(date) !=
                        formatDateOnlyYmd(
                          command.occurrence.scheduledOccurrenceDate,
                        ))
                    .toList(growable: false),
              );
    final restoredRecurringTransaction = command.recurringTransaction.copyWith(
      recurrenceRule: restoredRule,
      serverNextOccurrenceDate: command.occurrence.scheduledOccurrenceDate,
      serverLatestActionableOccurrenceDate:
          command.occurrence.scheduledOccurrenceDate,
    );
    final seriesHandle =
        _ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
              mutationId: mutationId,
              transaction: restoredRecurringTransaction,
            );

    try {
      final original = command.occurrence.actualTransaction;
      if (original == null) {
        throw StateError('The confirmed transaction is unavailable.');
      }
      final database = await _ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransactionDelete(
        entries: [original],
        clientMutationId: mutationId,
        actingUserId: command.userId,
        operation: 'unconfirm_recurring_occurrence',
        payload: {
          'functionName': 'unconfirm-recurring-occurrence',
          'requestBody': command.toRequestBody(),
        },
        relatedOriginalEntry: _expenseEntryFromRecurringTransaction(
          command.recurringTransaction,
          command.userId,
        ),
        relatedUpdatedEntry: _expenseEntryFromRecurringTransaction(
          restoredRecurringTransaction,
          command.userId,
        ),
      );
      _ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
      _ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      _ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
      _ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      _ref.read(widgetSyncVersionProvider.notifier).state += 1;
      _ref.invalidate(recurringOccurrenceTimelineProvider);
      _ref.invalidate(recurringTransactionsProvider(
        command.recurringTransaction.householdId,
      ));
      _ref.invalidate(pocketsProvider);
      _ref.invalidate(currencyTransactionCountsProvider);
      unawaited(drainMobileOutbox(_ref));
      return RecurringOccurrenceConfirmationResult.queued(
        optimisticId: command.recurringTransaction.id,
        idempotencyKey: mutationId,
      );
    } catch (error) {
      _ref
          .read(recurringOccurrenceOptimisticProvider.notifier)
          .rollback(occurrenceHandle);
      _ref
          .read(recurringSeriesOptimisticProvider.notifier)
          .rollback(seriesHandle);
      return RecurringOccurrenceConfirmationResult.failure(
        ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }
}

class RecurringOccurrenceConfirmationController {
  const RecurringOccurrenceConfirmationController(this._ref);

  final Ref _ref;

  Future<RecurringOccurrenceConfirmationResult> confirm(
    RecurringOccurrenceConfirmationCommand command,
  ) async {
    if (_ref.read(previewModeProvider).isActive) {
      _showPreviewToast();
      return const RecurringOccurrenceConfirmationResult.failure(
        'Preview mode is read-only.',
      );
    }
    if (command.userId.trim().isEmpty ||
        command.recurringTransaction.id.trim().isEmpty ||
        command.accountId?.trim().isEmpty == true ||
        command.amountCents <= 0) {
      return const RecurringOccurrenceConfirmationResult.failure(
        'A user, recurring transaction, and positive amount are required.',
      );
    }

    final scheduledDate = DateTime(
      command.scheduledOccurrenceDate.year,
      command.scheduledOccurrenceDate.month,
      command.scheduledOccurrenceDate.day,
    );
    final paidDate = DateTime(
      command.paidDate.year,
      command.paidDate.month,
      command.paidDate.day,
    );
    final now = DateTime.now();
    final userNow = effectiveNow(
      preferredTimezone:
          _ref.read(analyticsProvider).contact?.preferredTimezone,
    );
    if (!canSubmitRecurringOccurrenceConfirmationAt(
      transaction: command.recurringTransaction,
      scheduledOccurrenceDate: scheduledDate,
      paidDate: paidDate,
      userNow: userNow,
    )) {
      return const RecurringOccurrenceConfirmationResult.failure(
        'This occurrence is not available for confirmation yet.',
      );
    }

    final optimisticEntry = ExpenseEntry(
      id: command.optimisticId,
      userId: command.userId,
      householdId: command.recurringTransaction.householdId,
      date: paidDate,
      amountCents: command.amountCents,
      currency: command.recurringTransaction.currency,
      category: command.recurringTransaction.category,
      createdAt: now,
      rawText: command.description ?? command.recurringTransaction.description,
      merchant: command.merchant ?? command.recurringTransaction.merchant,
      walletId: command.accountId,
      type: command.recurringTransaction.type,
      parentRecurringId: command.recurringTransaction.id,
      scheduledOccurrenceDate: scheduledDate,
      recurringConfirmedAt: now,
      recurringConfirmationSource: 'user',
      clientRecordId: command.optimisticId,
      clientMutationId: command.idempotencyKey,
      idempotencyKey: command.idempotencyKey,
    );

    try {
      final database = await _ref.read(localDatabaseProvider.future);
      final optimisticSeries = command.recurringTransaction.copyWith(
        amount: command.updateFutureAmount
            ? command.amountCents / 100
            : command.recurringTransaction.amount,
        serverNextOccurrenceDate:
            command.recurringTransaction.getNextOccurrence(scheduledDate),
        clearServerLatestActionableOccurrenceDate: true,
      );
      await database.writeOptimisticTransaction(
        entry: optimisticEntry,
        clientMutationId: command.idempotencyKey,
        operation: recurringOccurrenceConfirmationOperation,
        payload: {
          'idempotencyKey': command.idempotencyKey,
          'clientMutationId': command.idempotencyKey,
          'requestBody': command.toRequestBody(),
        },
        relatedOriginalEntry: command.updateFutureAmount
            ? _expenseEntryFromRecurringTransaction(
                command.recurringTransaction,
                command.userId,
              )
            : null,
        relatedUpdatedEntry: command.updateFutureAmount
            ? _expenseEntryFromRecurringTransaction(
                optimisticSeries,
                command.userId,
              )
            : null,
      );
      _ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
            mutationId: command.idempotencyKey,
            transaction: optimisticSeries,
          );
      _ref.read(recurringOccurrenceOptimisticProvider.notifier).upsert(
            mutationId: command.idempotencyKey,
            occurrence: RecurringOccurrenceSummary(
              id: command.optimisticId,
              recurringId: command.recurringTransaction.id,
              scheduledOccurrenceDate: scheduledDate,
              status: 'confirmed',
              confirmationSource: 'user',
              actualTransactionId: command.optimisticId,
              paidDate: paidDate,
              amountCents: command.amountCents,
              currency: command.recurringTransaction.currency,
              confirmedAt: now,
              confirmedByUserId: command.userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      _ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
      _ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      _ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
      _ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      _ref.read(widgetSyncVersionProvider.notifier).state += 1;
      _ref.invalidate(recurringTransactionsProvider(
        command.recurringTransaction.householdId,
      ));
      _ref.invalidate(pocketsProvider);
      _ref.invalidate(currencyTransactionCountsProvider);
      unawaited(drainMobileOutbox(_ref));
      return RecurringOccurrenceConfirmationResult.queued(
        optimisticId: command.optimisticId,
        idempotencyKey: command.idempotencyKey,
      );
    } catch (error) {
      return RecurringOccurrenceConfirmationResult.failure(
        ErrorHandler.getUserFriendlyMessage(error),
      );
    }
  }
}

// ============================================================================
// UNIFIED RECURRING TRANSACTIONS PROVIDER (SINGLE SOURCE OF TRUTH)
// ============================================================================

/// Unified recurring transactions provider - fetches recurring transactions for a specific scope (Personal or Household)
/// householdId: null for Personal, non-null for Household
final recurringTransactionsProvider = StateNotifierProvider.family<
    RecurringTransactionsNotifier, RecurringTransactionsState, String?>(
  (ref, householdId) {
    return RecurringTransactionsNotifier(ref, householdId);
  },
);

class RecurringTransactionsNotifier
    extends StateNotifier<RecurringTransactionsState> {
  final Ref ref;
  final String? householdId; // Scope: null = Personal, non-null = Household
  bool _loadInProgress = false;

  RecurringTransactionsNotifier(this.ref, this.householdId)
      : super(RecurringTransactionsState(
          // Loading means "unknown", not "there are zero recurring rows".
          // Rendering empty data before local hydration causes dashboard totals
          // to flash actual-only amounts before recurring projections arrive.
          data: const AsyncValue<List<RecurringTransaction>>.loading(),
          hasLoadedOnce: false,
        ));

  bool get _isPreview => ref.read(previewModeProvider).isActive;

  bool _guardPreviewWrites() {
    if (_isPreview) {
      _showPreviewToast();
      return true;
    }
    return false;
  }

  /// Load recurring transactions for the current scope (Personal or Household)
  Future<void> loadRecurringTransactions(
    String userId, {
    int limit = 250,
    bool forceRefresh = false,
  }) async {
    final household = householdId ?? '<personal>';
    final traceUser = userId.isEmpty ? '<empty>' : userId;
    if (_loadInProgress && !forceRefresh) {
      _homeSpendTrace('recurring-load skip=in-progress household=$household');
      return;
    }
    _loadInProgress = true;
    _homeSpendTrace(
      'recurring-load start user=$traceUser household=$household force=$forceRefresh '
      'hasLoaded=${state.hasLoadedOnce} stateLoading=${state.data.isLoading} '
      'stateHasValue=${state.data.hasValue} stateCount=${state.data.valueOrNull?.length ?? 0}',
    );
    try {
      if (_isPreview) {
        final mockData = PreviewMockData.recurringTransactions;
        state = state.copyWith(
          data: AsyncValue.data(mockData),
          hasLoadedOnce: true,
        );
        _homeSpendTrace(
            'recurring-load return=preview count=${mockData.length}');
        return;
      }

      if (!mounted) return;

      final isOffline =
          ref.read(networkReachabilityProvider).valueOrNull == false;
      if (!forceRefresh) {
        final hydrated = await _hydrateFromLocalCache(
          userId,
          limit: limit,
          allowIncompleteRecurrenceRules: isOffline,
        );
        if (hydrated) {
          if (!isOffline) {
            _homeSpendTrace(
                'recurring-load hydrated-local schedule=remote-refresh household=$household');
            unawaited(_refreshRecurringTransactionsFromNetwork(
              userId,
              limit,
              preserveCachedDataOnError: true,
            ));
          }
          return;
        }
      }

      if (isOffline) {
        state = state.copyWith(
          data: state.data.hasValue
              ? state.data
              : const AsyncValue.data(<RecurringTransaction>[]),
          hasLoadedOnce: true,
        );
        _homeSpendTrace(
            'recurring-load return=offline-empty household=$household');
        return;
      }

      // Skip loading if already loaded successfully (unless forced refresh)
      final currentHasIncompleteRules = state.data.valueOrNull?.any(
            (transaction) => transaction.recurrenceRule == null,
          ) ??
          false;
      if (state.hasLoadedOnce && !forceRefresh && !currentHasIncompleteRules) {
        _homeSpendTrace(
            'recurring-load skip=already-loaded household=$household');
        return;
      }
      if (!state.hasLoadedOnce || forceRefresh) {
        state = state.copyWith(
          data: const AsyncValue<List<RecurringTransaction>>.loading()
              .copyWithPrevious(state.data),
        );
      }

      await _refreshRecurringTransactionsFromNetwork(userId, limit);
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _refreshRecurringTransactionsFromNetwork(
    String userId,
    int limit, {
    bool preserveCachedDataOnError = false,
  }) async {
    if (!mounted) return;

    try {
      // For recurring transactions we only need rows from the `expenses`
      // table where is_recurring=true. This avoids the heavier
      // list-expenses/list-income Edge Functions and keeps the data
      // flow simple and predictable.
      const timeout = Duration(seconds: 10);

      // CRITICAL: keep account_id in this recurring base query.
      // STRICT REQUIREMENT: wallet pages need account_id to attach projected
      // recurring occurrences to the correct wallet. Removing it makes wallet
      // recurring transactions silently disappear again.
      final allTransactions = <RecurringTransaction>[];
      final pageSize = limit.clamp(1, 1000);
      var offset = 0;
      while (true) {
        final baseQuery = supabase
            .from('expenses')
            .select(
              'id, date, category, raw_text, merchant, breakdown, source, amount_cents, '
              'currency, owner_type, privacy_scope, household_id, is_recurring, '
              'user_id, split_group_id, account_id, bank_account_id, provider, '
              'provider_fields, recurrence_rule, type, attachments, created_at, updated_at, '
              'analytics_class, analytics_is_final, analytics_spending_multiplier, '
              'analytics_counts_toward_income',
            )
            .eq('is_recurring', true)
            .isFilter('deleted_at', null)
            .isFilter('provider', null)
            .isFilter('bank_account_id', null);

        dynamic scopedQuery;
        if (householdId != null && householdId!.trim().isNotEmpty) {
          final householdScope = ref.read(householdScopeProvider);
          scopedQuery = householdScope.isPortfolioId(householdId)
              ? baseQuery.eq('user_id', userId).eq('household_id', householdId!)
              : baseQuery.eq('household_id', householdId!);
        } else {
          scopedQuery =
              baseQuery.eq('user_id', userId).isFilter('household_id', null);
        }

        final rows = await scopedQuery
            .order('date', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + pageSize - 1)
            .timeout(timeout);
        final typedRows = (rows as List).cast<Map<String, dynamic>>();
        for (final item in typedRows) {
          try {
            allTransactions.add(RecurringTransaction.fromJson(item));
          } catch (parseError) {
            _debugPrint('[RecurringTx] Error parsing row: $parseError');
          }
        }
        if (typedRows.length < pageSize) break;
        offset += pageSize;
      }

      if (!mounted) return;

      final currentTransactions =
          state.data.valueOrNull ?? const <RecurringTransaction>[];
      final pendingOptimistic = currentTransactions
          .where((transaction) =>
              transaction.id.startsWith('optimistic-recurring-'))
          .toList(growable: false);
      final serverIds =
          allTransactions.map((transaction) => transaction.id).toSet();
      final mergedTransactions = <RecurringTransaction>[
        ...pendingOptimistic.where(
          (transaction) => !serverIds.contains(transaction.id),
        ),
        ...allTransactions,
      ];

      state = state.copyWith(
        data: AsyncValue.data(mergedTransactions),
        hasLoadedOnce: true,
      );
      final household = householdId ?? '<personal>';
      _homeSpendTrace(
        'recurring-remote-success household=$household '
        'serverCount=${allTransactions.length} pendingCount=${pendingOptimistic.length} '
        'mergedCount=${mergedTransactions.length}',
      );
      unawaited(_cacheRecurringTransactions(allTransactions, userId));

      _debugPrint(
          '[RecurringTx] Loaded ${allTransactions.length} recurring transactions');
    } catch (e, st) {
      _debugPrint('[RecurringTx] Load failed: $e');
      final household = householdId ?? '<personal>';
      _homeSpendTrace(
        'recurring-remote-error household=$household error=$e '
        'preserveCached=$preserveCachedDataOnError hasValue=${state.data.hasValue}',
      );
      if (!mounted) return;
      if (preserveCachedDataOnError && state.data.hasValue) {
        return;
      }
      // Mark hasLoadedOnce=true even on error so the RecurringPage does
      // not keep auto-retrying in a loop. The error state will be
      // rendered and the user can manually pull-to-refresh.
      state = state.copyWith(
        data: AsyncValue.error(e, st),
        hasLoadedOnce: true,
      );
    }
  }

  Future<bool> _hydrateFromLocalCache(
    String userId, {
    required int limit,
    required bool allowIncompleteRecurrenceRules,
  }) async {
    final household = householdId ?? '<personal>';
    try {
      final database = await ref.read(localDatabaseProvider.future);
      final rows = await database.getRecurringTransactions(
        userId: userId,
        householdId: householdId,
        limit: limit,
      );
      final expenseCents = rows.fold<int>(0, (sum, entry) {
        final type = (entry.type ?? 'expense').toLowerCase();
        return type == 'income' ? sum : sum + entry.amountCents.abs();
      });
      _homeSpendTrace(
        'recurring-hydrate-local household=$household count=${rows.length} '
        'expenseTotal=${(expenseCents / 100.0).toStringAsFixed(2)}',
      );
      if (rows.isEmpty || !mounted) return false;

      final cachedTransactions = rows
          .map(recurringTransactionFromExpenseEntry)
          .toList(growable: false);
      final hasMissingRecurrenceRules = cachedTransactions.any(
        (transaction) => transaction.recurrenceRule == null,
      );
      if (hasMissingRecurrenceRules && !allowIncompleteRecurrenceRules) {
        _homeSpendTrace(
          'recurring-hydrate-local incomplete-rules household=$household '
          'count=${rows.length}',
        );
        return false;
      }

      state = state.copyWith(
        data: AsyncValue.data(cachedTransactions),
        hasLoadedOnce: true,
      );
      return true;
    } catch (error) {
      _homeSpendTrace(
          'recurring-hydrate-local error household=$household error=$error');
      _debugPrint('[RecurringTx] Local hydrate failed: $error');
      return false;
    }
  }

  Future<void> _cacheRecurringTransactions(
    List<RecurringTransaction> transactions,
    String fallbackUserId,
  ) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.replaceRecurringTransactionsForScope(
        userId: fallbackUserId,
        householdId: householdId,
        entries: transactions
            .map((transaction) => _expenseEntryFromRecurringTransaction(
                transaction, fallbackUserId))
            .where((entry) => entry.userId?.trim().isNotEmpty == true)
            .toList(growable: false),
      );
    } catch (error) {
      _debugPrint('[RecurringTx] Local cache write failed: $error');
    }
  }

  /// Refresh recurring transactions list
  Future<void> refresh(String userId) async {
    if (!mounted) return;

    await loadRecurringTransactions(
      userId,
      forceRefresh: true,
    );
  }

  /// Add transaction (optimistic update)
  void addRecurring(RecurringTransaction transaction) {
    if (!mounted) return;
    final transactions =
        state.data.valueOrNull ?? const <RecurringTransaction>[];
    final withoutDuplicate = transactions
        .where((existing) => existing.id != transaction.id)
        .toList(growable: false);
    final updated = [transaction, ...withoutDuplicate];
    state = state.copyWith(data: AsyncValue.data(updated));
  }

  /// Update transaction
  void updateRecurring(RecurringTransaction transaction) {
    if (!mounted) return;
    state.data.whenData((transactions) {
      final updated = transactions.map((t) {
        return t.id == transaction.id ? transaction : t;
      }).toList();
      state = state.copyWith(data: AsyncValue.data(updated));
    });
  }

  /// Replace an optimistic row with the saved server row.
  void replaceRecurring(
    String optimisticId,
    RecurringTransaction savedTransaction,
  ) {
    if (!mounted) return;
    final transactions =
        state.data.valueOrNull ?? const <RecurringTransaction>[];
    final updated = <RecurringTransaction>[];
    var inserted = false;

    for (final transaction in transactions) {
      if (transaction.id == optimisticId) {
        if (!inserted) {
          updated.add(savedTransaction);
          inserted = true;
        }
        continue;
      }
      if (transaction.id == savedTransaction.id) {
        if (!inserted) {
          updated.add(savedTransaction);
          inserted = true;
        }
        continue;
      }
      updated.add(transaction);
    }

    if (!inserted) {
      updated.insert(0, savedTransaction);
    }

    state = state.copyWith(data: AsyncValue.data(updated));
  }

  /// Remove a pending or deleted recurring transaction from local state.
  void removeRecurring(String transactionId) {
    if (!mounted) return;
    final transactions =
        state.data.valueOrNull ?? const <RecurringTransaction>[];
    state = state.copyWith(
      data: AsyncValue.data(
        transactions
            .where((transaction) => transaction.id != transactionId)
            .toList(growable: false),
      ),
    );
  }

  /// Delete transaction
  Future<DeleteRecurringResult> deleteRecurring(
    String userId,
    String transactionId, {
    RecurringTransaction? transaction,
  }) async {
    if (_guardPreviewWrites()) {
      return const DeleteRecurringResult.failure('preview_mode_blocked');
    }
    MonekoDatabase? localDatabase;
    List<ExpenseEntry> deletedEntries = const <ExpenseEntry>[];
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: transactionId,
      operation: 'delete_recurring_transaction',
    );
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;

    try {
      // Optimistic update
      if (!mounted) {
        return const DeleteRecurringResult.failure('Provider unmounted');
      }
      final currentTransactions = state.data.valueOrNull ?? const [];
      final target = transaction ??
          currentTransactions
              .where((entry) => entry.id == transactionId)
              .firstOrNull;
      if (target != null) {
        deletedEntries = [
          _expenseEntryFromRecurringTransaction(target, userId),
        ];
        lazyOptimisticHandle =
            ref.read(recurringSeriesOptimisticProvider.notifier).remove(
                  mutationId: mutationMetadata.clientMutationId,
                  recurringId: transactionId,
                  householdId: target.householdId,
                );
      }
      state.data.whenData((transactions) {
        state = state.copyWith(
          data: AsyncValue.data(
            transactions.where((t) => t.id != transactionId).toList(),
          ),
        );
      });

      if (deletedEntries.isNotEmpty) {
        final database = await ref.read(localDatabaseProvider.future);
        localDatabase = database;
        await database.writeOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          actingUserId: userId,
          payload: {
            ...mutationMetadata.toRequestJson(),
            'userId': userId,
            'recurringId': transactionId,
          },
          operation: 'delete_recurring_template',
        );
      }

      // Backend call
      final response = await supabase.functions.invoke(
        'delete-recurring-template',
        body: {
          ...mutationMetadata.toRequestJson(),
          'userId': userId,
          'recurringId': transactionId,
        },
      );

      _debugPrint(
          '✅ [RecurringTx] delete-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
        final lazyHandle = lazyOptimisticHandle;
        if (lazyHandle != null) {
          ref
              .read(recurringSeriesOptimisticProvider.notifier)
              .commit(lazyHandle);
        }
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase?.markOptimisticTransactionDeleteSynced(
          clientMutationId: mutationMetadata.clientMutationId,
        );
        // Keep other tabs (pockets + currency selector) in sync with the
        // underlying `expenses` table mutation.
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        _debugPrint('✅ [RecurringTx] DELETE SUCCEEDED');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.success();
      }

      final payload = response.data;
      final errorMessage = _extractFunctionError(payload) ??
          (response.status >= 400
              ? 'Request failed (${response.status})'
              : null);

      _debugPrint('❌ [RecurringTx] DELETE FAILED: $errorMessage');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (deletedEntries.isNotEmpty) {
        await localDatabase?.rollbackOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          error: errorMessage ?? 'Delete failed',
        );
      }
      final lazyHandle = lazyOptimisticHandle;
      if (lazyHandle != null) {
        ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(lazyHandle);
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] DELETE EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);
        return const DeleteRecurringResult.success();
      }
      if (deletedEntries.isNotEmpty) {
        await localDatabase?.rollbackOptimisticTransactionDelete(
          entries: deletedEntries,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      final lazyHandle = lazyOptimisticHandle;
      if (lazyHandle != null) {
        ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(lazyHandle);
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(
          ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Skip a single occurrence by adding its date to excluded_dates
  Future<DeleteRecurringResult> skipOccurrence(
    String userId,
    String transactionId,
    DateTime dateToSkip, {
    RecurringTransaction? transaction,
  }) async {
    if (_guardPreviewWrites()) {
      return const DeleteRecurringResult.failure('preview_mode_blocked');
    }
    MonekoDatabase? localDatabase;
    ExpenseEntry? originalEntry;
    ExpenseEntry? updatedEntry;
    RecurringTransaction? target = transaction;
    final mutationMetadata = buildTransactionMutationMetadataForRecord(
      clientRecordId: transactionId,
      operation: 'skip_recurring_occurrence',
    );
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;
    RecurringOccurrenceOptimisticHandle? occurrenceOptimisticHandle;
    try {
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugPrint('⏭️ [RecurringTx] SKIP OCCURRENCE REQUESTED');
      _debugPrint(
          '   Scope: ${householdId == null ? 'PERSONAL' : 'HOUSEHOLD($householdId)'}');
      _debugPrint('   User context present');
      _debugPrint('   TransactionId: $transactionId');
      _debugPrint('   DateToSkip: $dateToSkip');

      if (!mounted) {
        return const DeleteRecurringResult.failure('Provider unmounted');
      }

      // Prefer the provider's current state so consecutive skips retain every
      // local exclusion; the route's transaction is only a fallback.
      state.data.whenData((transactions) {
        target = transactions.where((t) => t.id == transactionId).firstOrNull ??
            target;
      });

      if (target == null) {
        _debugPrint('❌ [RecurringTx] SKIP FAILED: Transaction not found');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.failure('Transaction not found');
      }

      final rule = target!.recurrenceRule;
      if (rule == null) {
        _debugPrint('❌ [RecurringTx] SKIP FAILED: No recurrence rule');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.failure('No recurrence rule');
      }

      // Build updated rule with the new excluded date
      final updatedExcluded = {
        ...rule.excludedDates.map(formatDateOnlyYmd),
        formatDateOnlyYmd(dateToSkip),
      }.map(DateTime.parse).toList(growable: false);
      final updatedRule = rule.copyWith(excludedDates: updatedExcluded);

      // Optimistic update
      final updatedTransaction = target!.copyWith(
        recurrenceRule: updatedRule,
        serverNextOccurrenceDate: target!.getNextOccurrence(dateToSkip),
        clearServerLatestActionableOccurrenceDate: true,
      );
      updateRecurring(updatedTransaction);
      lazyOptimisticHandle =
          ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                transaction: updatedTransaction,
              );
      occurrenceOptimisticHandle =
          ref.read(recurringOccurrenceOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                occurrence: RecurringOccurrenceSummary(
                  id: 'optimistic-skip-${mutationMetadata.clientMutationId}',
                  recurringId: transactionId,
                  scheduledOccurrenceDate: dateToSkip,
                  status: 'skipped',
                  confirmationSource: 'user',
                  actualTransactionId: null,
                  paidDate: null,
                  amountCents: null,
                  currency: target!.currency,
                  confirmedAt: null,
                  confirmedByUserId: userId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
      originalEntry = _expenseEntryFromRecurringTransaction(target!, userId);
      updatedEntry = _expenseEntryFromRecurringTransaction(
        updatedTransaction,
        userId,
      );
      final updates = {'recurrence_rule': updatedRule.toJson()};
      final database = await ref.read(localDatabaseProvider.future);
      localDatabase = database;
      await database.writeOptimisticTransactionUpdate(
        originalEntry: originalEntry,
        updatedEntry: updatedEntry,
        clientMutationId: mutationMetadata.clientMutationId,
        payload: {
          ...mutationMetadata.toRequestJson(),
          'functionName': 'skip-recurring-occurrence',
          'requestBody': {
            'userId': userId,
            'recurringId': transactionId,
            'scheduledOccurrenceDate': formatDateOnlyYmd(dateToSkip),
          },
          'userId': userId,
          'expenseId': transactionId,
          'updates': updates,
        },
        operation: 'skip_recurring_occurrence',
      );

      // Backend skip is atomic: ledger state, legacy exclusion, and reminder.
      final response = await supabase.functions.invoke(
        'skip-recurring-occurrence',
        body: {
          'userId': userId,
          'recurringId': transactionId,
          'scheduledOccurrenceDate': formatDateOnlyYmd(dateToSkip),
        },
      );

      _debugPrint(
          '✅ [RecurringTx] update-expense response status=${response.status}');

      if (response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['success'] == true) {
        final lazyHandle = lazyOptimisticHandle;
        ref.read(recurringSeriesOptimisticProvider.notifier).commit(lazyHandle);
        final occurrenceHandle = occurrenceOptimisticHandle;
        ref
            .read(recurringOccurrenceOptimisticProvider.notifier)
            .commit(occurrenceHandle);
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase.markOptimisticTransactionMetadataSynced(
          clientMutationId: mutationMetadata.clientMutationId,
        );
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
        ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
        ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
        ref.read(widgetSyncVersionProvider.notifier).state += 1;
        _debugPrint('✅ [RecurringTx] SKIP OCCURRENCE SUCCEEDED');
        _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return const DeleteRecurringResult.success();
      }

      final payload = response.data;
      final errorMessage = _extractFunctionError(payload) ??
          (response.status >= 400
              ? 'Request failed (${response.status})'
              : null);

      _debugPrint('❌ [RecurringTx] SKIP FAILED: $errorMessage');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await localDatabase.rollbackOptimisticTransactionUpdate(
        originalEntry: originalEntry,
        clientMutationId: mutationMetadata.clientMutationId,
        error: errorMessage ?? 'Skip occurrence failed',
      );
      final lazyHandle = lazyOptimisticHandle;
      ref.read(recurringSeriesOptimisticProvider.notifier).rollback(lazyHandle);
      final occurrenceHandle = occurrenceOptimisticHandle;
      ref
          .read(recurringOccurrenceOptimisticProvider.notifier)
          .rollback(occurrenceHandle);
      updateRecurring(target!);
      await refresh(userId);
      return DeleteRecurringResult.failure(errorMessage);
    } catch (e) {
      _debugPrint('❌ [RecurringTx] SKIP EXCEPTION: $e');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
        ref.read(walletsRecurringMutationSignalProvider.notifier).state += 1;
        ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
        ref.read(widgetSyncVersionProvider.notifier).state += 1;
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);
        return const DeleteRecurringResult.success();
      }
      if (originalEntry != null && updatedEntry != null) {
        await localDatabase?.rollbackOptimisticTransactionUpdate(
          originalEntry: originalEntry,
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      if (target != null) {
        updateRecurring(target!);
      }
      final lazyHandle = lazyOptimisticHandle;
      if (lazyHandle != null) {
        ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(lazyHandle);
      }
      final occurrenceHandle = occurrenceOptimisticHandle;
      if (occurrenceHandle != null) {
        ref
            .read(recurringOccurrenceOptimisticProvider.notifier)
            .rollback(occurrenceHandle);
      }
      await refresh(userId);
      return DeleteRecurringResult.failure(
          ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  String? _extractFunctionError(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    return null;
  }
}

// ============================================================================
// FILTERED PROVIDERS - Filter from single source of truth
// ============================================================================

/// Recurring expenses (filtered from unified provider by scope)
final recurringExpensesProvider =
    Provider.family<AsyncValue<List<RecurringTransaction>>, String?>(
        (ref, householdId) {
  final allTransactions = ref.watch(recurringTransactionsProvider(householdId));

  return allTransactions.data.when(
    data: (transactions) {
      final expenses = transactions.where((t) => t.type == 'expense').toList();
      return AsyncValue.data(expenses);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Recurring incomes (filtered from unified provider by scope)
final recurringIncomesProvider =
    Provider.family<AsyncValue<List<RecurringTransaction>>, String?>(
        (ref, householdId) {
  final allTransactions = ref.watch(recurringTransactionsProvider(householdId));

  return allTransactions.data.when(
    data: (transactions) {
      final incomes = transactions.where((t) => t.type == 'income').toList();
      return AsyncValue.data(incomes);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

class UpcomingRecurringScope {
  final String? householdId;
  final String? currency;
  final List<String>? selectedCurrencies;

  const UpcomingRecurringScope({
    this.householdId,
    this.currency,
    this.selectedCurrencies,
  });

  List<String>? get normalizedSelectedCurrencies {
    final normalized = selectedCurrencies
        ?.map((currency) => currency.trim().toUpperCase())
        .where((currency) => currency.isNotEmpty)
        .toSet()
        .toList();
    if (normalized == null || normalized.isEmpty) return null;
    normalized.sort();
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpcomingRecurringScope &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          currency == other.currency &&
          _sameStringList(
            normalizedSelectedCurrencies,
            other.normalizedSelectedCurrencies,
          );

  @override
  int get hashCode => Object.hash(
        householdId,
        currency,
        Object.hashAll(normalizedSelectedCurrencies ?? const <String>[]),
      );
}

bool _sameStringList(List<String>? left, List<String>? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// Whether the current scope contains an occurrence that can be confirmed.
///
/// This mirrors the eligibility and confirmation checks used by
/// [RecurringTransactionCard] so navigation badges match the visible CTA.
final hasUnconfirmedRecurringOccurrencesProvider =
    Provider.family<bool, UpcomingRecurringScope>((ref, scope) {
  String? userId;
  try {
    userId = supabase.auth.currentUser?.id;
  } catch (_) {
    return false;
  }
  if (userId == null || userId.isEmpty) return false;
  final selectedCurrencies = scope.normalizedSelectedCurrencies;
  final currencies = selectedCurrencies?.isNotEmpty == true
      ? selectedCurrencies!
      : <String>[scope.currency?.trim().toUpperCase() ?? 'USD'];
  final summaries = ref
      .watch(recurringSeriesPageProvider(RecurringSeriesPageQuery(
        scope: RecurringReadScope(
          userId: userId,
          householdId: scope.householdId,
          currencies: currencies,
        ),
      )))
      .valueOrNull
      ?.items;
  return summaries?.any((item) => item.hasActionableOccurrence) == true;
});

class UpcomingRecurringTransaction {
  final RecurringTransaction transaction;
  final DateTime nextOccurrence;
  final int daysUntil;

  const UpcomingRecurringTransaction({
    required this.transaction,
    required this.nextOccurrence,
    required this.daysUntil,
  });
}

/// Next recurring transaction due within 3 days for the current scope.
final upcomingRecurringTransactionProvider =
    Provider.family<UpcomingRecurringTransaction?, UpcomingRecurringScope>(
        (ref, scope) {
  final currency = scope.currency?.trim().toUpperCase();
  final currencies = scope.normalizedSelectedCurrencies;
  final preferredTimezone =
      ref.watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
  final userNow = effectiveNow(preferredTimezone: preferredTimezone);
  final today = DateTime(userNow.year, userNow.month, userNow.day);
  String? userId;
  try {
    userId = supabase.auth.currentUser?.id;
  } catch (_) {
    // Provider tests and unauthenticated previews have no Supabase client.
  }
  final List<RecurringSeriesSummary> summaries;
  if (userId == null || userId.isEmpty) {
    final transactions = ref
        .watch(recurringTransactionsProvider(scope.householdId))
        .data
        .valueOrNull;
    if (transactions == null) return null;
    summaries = transactions
        .map((transaction) => RecurringSeriesSummary(
              transaction: transaction,
              nextOccurrenceDate: transaction.getNextOccurrence(userNow),
              latestActionableOccurrenceDate: null,
            ))
        .toList(growable: false);
  } else {
    final selected = currencies?.isNotEmpty == true
        ? currencies!
        : <String>[currency ?? 'USD'];
    summaries = ref
            .watch(recurringSeriesPageProvider(RecurringSeriesPageQuery(
              scope: RecurringReadScope(
                userId: userId,
                householdId: scope.householdId,
                currencies: selected,
              ),
            )))
            .valueOrNull
            ?.items ??
        const [];
  }
  UpcomingRecurringTransaction? best;

  for (final summary in summaries) {
    final transaction = summary.transaction;
    if (!transaction.isActive) continue;
    final transactionCurrency = transaction.currency.toUpperCase();
    if (currencies != null && !currencies.contains(transactionCurrency)) {
      continue;
    }
    if (currencies == null &&
        currency != null &&
        currency.isNotEmpty &&
        transactionCurrency != currency) {
      continue;
    }

    final nextDate =
        summary.nextOccurrenceDate ?? transaction.getNextOccurrence(userNow);
    final daysUntil = nextDate.difference(today).inDays;

    if (daysUntil < 0 || daysUntil > 3) continue;

    final candidate = UpcomingRecurringTransaction(
      transaction: transaction,
      nextOccurrence: nextDate,
      daysUntil: daysUntil,
    );

    if (best == null || nextDate.isBefore(best.nextOccurrence)) {
      best = candidate;
    }
  }

  return best;
});

// ============================================================================
// SAVE PROVIDER
// ============================================================================

final recurringTransactionSaveProvider = StateNotifierProvider<
    RecurringTransactionSaveNotifier, AsyncValue<RecurringTransaction?>>((ref) {
  return RecurringTransactionSaveNotifier(ref);
});

class RecurringTransactionSaveNotifier
    extends StateNotifier<AsyncValue<RecurringTransaction?>> {
  final Ref ref;

  RecurringTransactionSaveNotifier(this.ref)
      : super(const AsyncValue.data(null));

  bool get _isPreview => ref.read(previewModeProvider).isActive;

  bool _guardPreviewWrites() {
    if (_isPreview) {
      _showPreviewToast();
      return true;
    }
    return false;
  }

  /// Save recurring expense
  Future<RecurringTransaction?> saveRecurringExpense({
    required String userId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();
    RecurringTransaction? optimisticTransaction;
    TransactionMutationMetadata? mutationMetadata;
    MonekoDatabase? localDatabase;
    RecurringTransaction? committedTransaction;
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;
    var backendCommitted = false;

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);
      final clientCreatedAtIso = _buildClientCreatedAtIso(ref);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final Map<String, dynamic> requestBody = {
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': clientCreatedAtIso,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
        'accountId': accountId,
      };

      if (householdId != null) {
        final isPortfolio =
            ref.read(householdScopeProvider).isPortfolioId(householdId);
        requestBody['householdId'] = householdId;
        requestBody['isPortfolio'] = isPortfolio;

        if (!isPortfolio &&
            customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;

          requestBody['customSplits'] = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };

              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };
        }

        if (!isPortfolio && payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
        }
      }

      optimisticTransaction = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'expense',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      );
      mutationMetadata = buildTransactionMutationMetadata(
        optimisticTransaction.id,
      );
      requestBody.addAll(mutationMetadata.toRequestJson());
      ref
          .read(recurringTransactionsProvider(householdId).notifier)
          .addRecurring(optimisticTransaction);
      lazyOptimisticHandle =
          ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                transaction: optimisticTransaction,
              );
      localDatabase = await _queueRecurringCreate(
        optimisticTransaction: optimisticTransaction,
        mutationMetadata: mutationMetadata,
        functionName: 'save-expense',
        requestBody: requestBody,
        fallbackUserId: userId,
      );

      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final expense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        committedTransaction = expense;
        backendCommitted = true;
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(optimisticTransaction.id, expense);
        final lazyHandle = lazyOptimisticHandle;
        ref.read(recurringSeriesOptimisticProvider.notifier).commit(
              lazyHandle,
              canonicalTransaction: expense,
            );
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase?.replaceOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          savedEntry: _expenseEntryFromRecurringTransaction(expense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(expense);

        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, optimistic row reconciled');
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        return expense;
      } else {
        final lazyHandle = lazyOptimisticHandle;
        ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(lazyHandle);
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .removeRecurring(optimisticTransaction.id);
        await localDatabase?.rollbackOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          clientMutationId: mutationMetadata.clientMutationId,
          error: response.data,
        );
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to save recurring expense',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (backendCommitted && committedTransaction != null) {
        try {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .replaceRecurring(
                optimisticTransaction?.id ?? committedTransaction.id,
                committedTransaction,
              );
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
        } catch (refreshError) {
          _debugPrint(
              '⚠️ [SaveRecurring] Post-save reconciliation failed: $refreshError');
        }
        state = AsyncValue.data(committedTransaction);
        return committedTransaction;
      }
      try {
        final optimistic = optimisticTransaction;
        final metadata = mutationMetadata;
        if (optimistic != null &&
            localDatabase != null &&
            _shouldKeepQueuedLocalMutation(e)) {
          state = AsyncValue.data(optimistic);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return optimistic;
        }
        if (optimistic != null) {
          final lazyHandle = lazyOptimisticHandle;
          if (lazyHandle != null) {
            ref
                .read(recurringSeriesOptimisticProvider.notifier)
                .rollback(lazyHandle);
          }
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(optimistic.id);
          if (localDatabase != null && metadata != null) {
            await localDatabase.rollbackOptimisticTransaction(
              optimisticId: optimistic.id,
              clientMutationId: metadata.clientMutationId,
              error: e,
            );
          }
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Save recurring income
  Future<RecurringTransaction?> saveRecurringIncome({
    required String userId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();
    RecurringTransaction? optimisticTransaction;
    TransactionMutationMetadata? mutationMetadata;
    MonekoDatabase? localDatabase;
    RecurringTransaction? committedTransaction;
    var backendCommitted = false;
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);
      final clientCreatedAtIso = _buildClientCreatedAtIso(ref);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      optimisticTransaction = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'income',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        source: source,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      );
      mutationMetadata = buildTransactionMutationMetadata(
        optimisticTransaction.id,
      );
      ref
          .read(recurringTransactionsProvider(householdId).notifier)
          .addRecurring(optimisticTransaction);
      lazyOptimisticHandle =
          ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                transaction: optimisticTransaction,
              );

      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': clientCreatedAtIso,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        if (source != null && source.isNotEmpty) 'source': source,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        if (householdId != null) 'householdId': householdId,
        if (householdId != null)
          'isPortfolio':
              ref.read(householdScopeProvider).isPortfolioId(householdId),
        'isRecurring': true,
        'recurrence_rule': recurrenceRule,
        'accountId': accountId,
      };
      if (householdId != null) {
        final isPortfolio =
            ref.read(householdScopeProvider).isPortfolioId(householdId);
        if (!isPortfolio &&
            customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          requestBody['customSplits'] = {
            'splitType': customSplitType.name,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };
              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };
        }
        if (!isPortfolio && payerUserId?.isNotEmpty == true) {
          requestBody['payerUserId'] = payerUserId;
        }
      }
      localDatabase = await _queueRecurringCreate(
        optimisticTransaction: optimisticTransaction,
        mutationMetadata: mutationMetadata,
        functionName: 'save-income',
        requestBody: requestBody,
        fallbackUserId: userId,
      );

      final response = await supabase.functions.invoke(
        'save-income',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final income = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        committedTransaction = income;
        backendCommitted = true;
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(optimisticTransaction.id, income);
        final lazyHandle = lazyOptimisticHandle;
        ref.read(recurringSeriesOptimisticProvider.notifier).commit(
              lazyHandle,
              canonicalTransaction: income,
            );
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase?.replaceOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          savedEntry: _expenseEntryFromRecurringTransaction(income, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(income);

        _debugPrint(
            '🔄 [SaveRecurring] Saved successfully, optimistic row reconciled');
        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);

        return income;
      } else {
        final lazyHandle = lazyOptimisticHandle;
        ref
            .read(recurringSeriesOptimisticProvider.notifier)
            .rollback(lazyHandle);
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .removeRecurring(optimisticTransaction.id);
        await localDatabase?.rollbackOptimisticTransaction(
          optimisticId: optimisticTransaction.id,
          clientMutationId: mutationMetadata.clientMutationId,
          error: response.data,
        );
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to save recurring income',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (backendCommitted && committedTransaction != null) {
        try {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .replaceRecurring(
                optimisticTransaction?.id ?? committedTransaction.id,
                committedTransaction,
              );
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
        } catch (refreshError) {
          _debugPrint(
              '⚠️ [SaveRecurring] Post-save reconciliation failed: $refreshError');
        }
        state = AsyncValue.data(committedTransaction);
        return committedTransaction;
      }
      try {
        final optimistic = optimisticTransaction;
        final metadata = mutationMetadata;
        if (optimistic != null &&
            localDatabase != null &&
            _shouldKeepQueuedLocalMutation(e)) {
          state = AsyncValue.data(optimistic);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return optimistic;
        }
        if (optimistic != null) {
          final lazyHandle = lazyOptimisticHandle;
          if (lazyHandle != null) {
            ref
                .read(recurringSeriesOptimisticProvider.notifier)
                .rollback(lazyHandle);
          }
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(optimistic.id);
          if (localDatabase != null && metadata != null) {
            await localDatabase.rollbackOptimisticTransaction(
              optimisticId: optimistic.id,
              clientMutationId: metadata.clientMutationId,
              error: e,
            );
          }
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<RecurringTransaction?> updateSingleExpenseOccurrence({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
    required double amount,
    required String category,
    required String currency,
    required DateTime date,
    String? description,
    String? merchant,
    String? householdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(date);

      final requestBody = <String, dynamic>{
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'clientCreatedAt': _buildClientCreatedAtIso(ref),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (merchant != null && merchant.trim().isNotEmpty)
          'merchant': merchant.trim(),
        'ownerType': recurringSeries.ownerType,
        'privacyScope': recurringSeries.privacyScope,
        'isRecurring': false,
        'accountId': accountId,
      };

      if (householdId != null) {
        final isPortfolio =
            ref.read(householdScopeProvider).isPortfolioId(householdId);
        requestBody['householdId'] = householdId;
        requestBody['isPortfolio'] = isPortfolio;

        if (!isPortfolio &&
            customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;
          requestBody['customSplits'] = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };

              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };
        }

        if (!isPortfolio && payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
        }
      }

      final createResponse = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (createResponse.data['success'] != true) {
        final errorPayload = _buildFunctionErrorPayload(
          createResponse.data,
          fallback: 'Failed to save single expense occurrence',
        );
        state = AsyncValue.error(errorPayload, StackTrace.current);
        return null;
      }

      final created = RecurringTransaction.fromJson(
          createResponse.data['data'] as Map<String, dynamic>);

      final skipSucceeded = await _excludeOccurrenceFromSeries(
        userId: userId,
        recurringSeries: recurringSeries,
        occurrenceDateToSkip: occurrenceDateToSkip,
      );

      if (!skipSucceeded) {
        await _deleteExpenseById(userId: userId, expenseId: created.id);
        state = AsyncValue.error(
          const {
            'error': 'Failed to update recurring series for single occurrence',
            'code': 'SERIES_UPDATE_FAILED',
          },
          StackTrace.current,
        );
        return null;
      }

      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<RecurringTransaction?> updateSingleIncomeOccurrence({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
    required double amount,
    required String category,
    required String currency,
    required DateTime date,
    String? description,
    String? merchant,
    String? source,
    String? householdId,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final formattedAccountingDate = dateFormatter.format(date);

      final createResponse = await supabase.functions.invoke(
        'save-income',
        body: {
          'userId': userId,
          'amount': amount,
          'category': category,
          'currency': currency,
          'date': formattedAccountingDate,
          'clientCreatedAt': _buildClientCreatedAtIso(ref),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (merchant != null && merchant.trim().isNotEmpty)
            'merchant': merchant.trim(),
          if (source != null && source.trim().isNotEmpty)
            'source': source.trim(),
          'ownerType': recurringSeries.ownerType,
          'privacyScope': recurringSeries.privacyScope,
          if (householdId != null) 'householdId': householdId,
          if (householdId != null)
            'isPortfolio':
                ref.read(householdScopeProvider).isPortfolioId(householdId),
          'isRecurring': false,
          'accountId': accountId,
        },
      );

      if (createResponse.data['success'] != true) {
        final errorPayload = _buildFunctionErrorPayload(
          createResponse.data,
          fallback: 'Failed to save single income occurrence',
        );
        state = AsyncValue.error(errorPayload, StackTrace.current);
        return null;
      }

      final created = RecurringTransaction.fromJson(
          createResponse.data['data'] as Map<String, dynamic>);

      final skipSucceeded = await _excludeOccurrenceFromSeries(
        userId: userId,
        recurringSeries: recurringSeries,
        occurrenceDateToSkip: occurrenceDateToSkip,
      );

      if (!skipSucceeded) {
        await _deleteExpenseById(userId: userId, expenseId: created.id);
        state = AsyncValue.error(
          const {
            'error': 'Failed to update recurring series for single occurrence',
            'code': 'SERIES_UPDATE_FAILED',
          },
          StackTrace.current,
        );
        return null;
      }

      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update recurring expense
  Future<RecurringTransaction?> updateRecurringExpense({
    required String userId,
    required String expenseId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? previousHouseholdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    bool createSplitGroup = false,
    bool reSplitRequested = false,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    final originalScopeKey = previousHouseholdId;
    final originalExpense = ref
        .read(recurringTransactionsProvider(originalScopeKey))
        .data
        .valueOrNull
        ?.where((transaction) => transaction.id == expenseId)
        .firstOrNull;
    MonekoDatabase? localDatabase;
    TransactionMutationMetadata? mutationMetadata;
    RecurringTransaction? committedTransaction;
    var backendCommitted = false;
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;

    void rollbackOptimisticExpense() {
      try {
        final lazyHandle = lazyOptimisticHandle;
        var ownsCurrentRevision = true;
        if (lazyHandle != null) {
          ownsCurrentRevision = ref
              .read(recurringSeriesOptimisticProvider.notifier)
              .rollback(lazyHandle);
        }
        if (!ownsCurrentRevision) return;
        if (householdId != originalScopeKey) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(expenseId);
        }
        if (originalExpense != null) {
          ref
              .read(recurringTransactionsProvider(originalScopeKey).notifier)
              .replaceRecurring(expenseId, originalExpense);
        }
      } catch (_) {}
    }

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      // Keep the row's `date` aligned with the user-selected schedule day.
      // This value is date-only and is used across the UI for calendar semantics.
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        'projection_enabled':
            originalExpense?.recurrenceRule?.projectionEnabled ?? true,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final updates = <String, dynamic>{
        'amount_cents': (amount * 100).round(),
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'is_recurring': true,
        'recurrence_rule': recurrenceRule,
        'household_id': householdId,
        'account_id': accountId,
      };
      updates['raw_text'] = description != null && description.trim().isNotEmpty
          ? description.trim()
          : null;
      updates['merchant'] = merchant != null && merchant.trim().isNotEmpty
          ? merchant.trim()
          : null;

      _debugPrint('📝 [UpdateRecurring] Building update-expense request body');
      _debugPrint('   userId: $userId');
      _debugPrint('   expenseId: $expenseId');
      _debugPrint('   updates prepared');

      // Build base request body
      mutationMetadata = buildTransactionMutationMetadataForRecord(
        clientRecordId: expenseId,
        operation: 'update_recurring_expense',
      );
      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
        'userId': userId,
        'expenseId': expenseId,
        'updates': updates,
        // Keep update-expense date validation aligned with the caller's local
        // calendar day (same behavior as non-recurring transaction edits).
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      };

      // Attach household sharing + splits only for group expenses
      if (householdId != null) {
        requestBody['householdId'] = householdId;

        if (customSplitType != null &&
            customSplits != null &&
            customSplits.isNotEmpty) {
          final splitTypeStr = customSplitType.toString().split('.').last;
          final splitsPayload = {
            'splitType': splitTypeStr,
            'memberSplits': customSplits.map((split) {
              final memberData = <String, dynamic>{
                'userId': split.member.userId,
              };
              switch (customSplitType) {
                case SplitType.amount:
                  memberData['amount'] = split.amount;
                  break;
                case SplitType.percentage:
                  memberData['percentage'] = split.percentage;
                  break;
                case SplitType.shares:
                  memberData['shares'] = split.shares;
                  break;
                case SplitType.equal:
                  break;
              }
              return memberData;
            }).toList(),
          };

          // If the previous recurring expense was personal (no household),
          // we are converting personal -> group: mirror unified_transaction_sheet
          // by creating the initial split group via customSplits.
          if (createSplitGroup ||
              previousHouseholdId == null ||
              previousHouseholdId != householdId) {
            requestBody['customSplits'] = splitsPayload;
          } else {
            // Existing group recurring expense: mirror unified_transaction_sheet
            // by sending splitUpdate to recompute the split lines.
            requestBody['splitUpdate'] = splitsPayload;
            requestBody['reSplitRequested'] = reSplitRequested;
          }
        }

        // Always propagate payer updates for group expenses when provided
        if (payerUserId != null && payerUserId.isNotEmpty) {
          requestBody['payerUserId'] = payerUserId;
          updates['payer_user_id'] = payerUserId;
        }
      }

      // DEBUG: log outgoing update payload for recurring expense, including
      // splitUpdate/customSplits and payerUserId so we can confirm that
      // split edits are actually being sent to the backend.
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugPrint(
          '💾 [UpdateRecurring] Sending update-expense for recurring expense');
      _debugPrint('   expenseId: $expenseId');
      _debugPrint('   userId: $userId');
      _debugPrint('   householdId (target): $householdId');
      _debugPrint('   previousHouseholdId: $previousHouseholdId');
      _debugPrint('   payer update present: ${payerUserId != null}');
      _debugPrint('   updates prepared');
      if (requestBody.containsKey('customSplits')) {
        _debugPrint('   customSplits payload included');
      }
      if (requestBody.containsKey('splitUpdate')) {
        _debugPrint('   splitUpdate payload included');
      }
      _debugPrint('   Request key count: ${requestBody.length}');

      final optimisticExpense = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'expense',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        projectionEnabled:
            originalExpense?.recurrenceRule?.projectionEnabled ?? true,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      ).copyWith(id: expenseId);
      lazyOptimisticHandle =
          ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                transaction: optimisticExpense,
                sourceHouseholdId: originalScopeKey,
              );
      try {
        if (originalScopeKey != householdId) {
          ref
              .read(recurringTransactionsProvider(originalScopeKey).notifier)
              .removeRecurring(expenseId);
        }
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(expenseId, optimisticExpense);
        if (originalExpense != null) {
          final database = await ref.read(localDatabaseProvider.future);
          localDatabase = database;
          await database.writeOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalExpense, userId),
            updatedEntry: _expenseEntryFromRecurringTransaction(
                optimisticExpense, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            payload: {
              ...mutationMetadata.toRequestJson(),
              'userId': userId,
              'expenseId': expenseId,
              'updates': updates,
              'extraBody': {
                if (householdId != null) 'householdId': householdId,
                if (requestBody.containsKey('customSplits'))
                  'customSplits': requestBody['customSplits'],
                if (requestBody.containsKey('splitUpdate'))
                  'splitUpdate': requestBody['splitUpdate'],
                if (requestBody.containsKey('reSplitRequested'))
                  'reSplitRequested': requestBody['reSplitRequested'],
                if (requestBody.containsKey('payerUserId'))
                  'payerUserId': requestBody['payerUserId'],
              },
            },
          );
        }
      } catch (_) {}

      final response = await supabase.functions.invoke(
        'update-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final updatedExpense = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        committedTransaction = updatedExpense;
        backendCommitted = true;
        final lazyHandle = lazyOptimisticHandle;
        ref.read(recurringSeriesOptimisticProvider.notifier).commit(
              lazyHandle,
              canonicalTransaction: updatedExpense,
            );
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase?.markOptimisticTransactionUpdateSynced(
          entry: _expenseEntryFromRecurringTransaction(updatedExpense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(updatedExpense);
        _debugPrint(
            '✅ [UpdateRecurring] update-expense succeeded for $expenseId');
        _debugPrint(
            '   Updated expense householdId: ${updatedExpense.householdId}');
        _debugPrint(
            '   Updated amount: ${updatedExpense.amount} ${updatedExpense.currency}');
        _debugPrint('   Updated category: ${updatedExpense.category}');

        // Optimistically update the unified recurring transactions list so
        // the Recurring page reflects the edited values immediately without
        // requiring a full app restart. The sheet will still trigger a
        // formal refresh after save to keep all scopes consistent.
        try {
          final scopeKey = updatedExpense.householdId;
          ref
              .read(recurringTransactionsProvider(scopeKey).notifier)
              .updateRecurring(updatedExpense);
        } catch (e, st) {
          _debugPrint(
              '⚠️ [UpdateRecurring] Failed to optimistically update list: $e');
          _debugPrint('   Stack: $st');
        }

        // Force refresh the list provider to show the updated transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [UpdateRecurring] Updated successfully, transaction will be reloaded by invalidation');

        return updatedExpense;
      } else {
        if (localDatabase != null && originalExpense != null) {
          await localDatabase.rollbackOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalExpense, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            error: response.data,
          );
        }
        rollbackOptimisticExpense();
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to update recurring expense',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (backendCommitted && committedTransaction != null) {
        try {
          ref
              .read(recurringTransactionsProvider(
                      committedTransaction.householdId)
                  .notifier)
              .updateRecurring(committedTransaction);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
        } catch (refreshError) {
          _debugPrint(
              '⚠️ [UpdateRecurring] Post-update reconciliation failed: $refreshError');
        }
        state = AsyncValue.data(committedTransaction);
        return committedTransaction;
      }
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        final queued = ref
            .read(recurringTransactionsProvider(householdId))
            .data
            .valueOrNull
            ?.where((transaction) => transaction.id == expenseId)
            .firstOrNull;
        if (queued != null) {
          state = AsyncValue.data(queued);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return queued;
        }
      }
      if (localDatabase != null &&
          originalExpense != null &&
          mutationMetadata != null) {
        await localDatabase.rollbackOptimisticTransactionUpdate(
          originalEntry:
              _expenseEntryFromRecurringTransaction(originalExpense, userId),
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      rollbackOptimisticExpense();
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update recurring income
  Future<RecurringTransaction?> updateRecurringIncome({
    required String userId,
    required String expenseId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    String? source,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? previousHouseholdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    bool createSplitGroup = false,
    bool reSplitRequested = false,
    String? accountId,
  }) async {
    if (_guardPreviewWrites()) {
      return null;
    }
    state = const AsyncValue.loading();

    final originalScopeKey = previousHouseholdId;
    final originalIncome = ref
        .read(recurringTransactionsProvider(originalScopeKey))
        .data
        .valueOrNull
        ?.where((transaction) => transaction.id == expenseId)
        .firstOrNull;
    MonekoDatabase? localDatabase;
    TransactionMutationMetadata? mutationMetadata;
    RecurringTransaction? committedTransaction;
    var backendCommitted = false;
    RecurringSeriesOptimisticHandle? lazyOptimisticHandle;

    void rollbackOptimisticIncome() {
      try {
        final lazyHandle = lazyOptimisticHandle;
        var ownsCurrentRevision = true;
        if (lazyHandle != null) {
          ownsCurrentRevision = ref
              .read(recurringSeriesOptimisticProvider.notifier)
              .rollback(lazyHandle);
        }
        if (!ownsCurrentRevision) return;
        if (householdId != originalScopeKey) {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .removeRecurring(expenseId);
        }
        if (originalIncome != null) {
          ref
              .read(recurringTransactionsProvider(originalScopeKey).notifier)
              .replaceRecurring(expenseId, originalIncome);
        }
      } catch (_) {}
    }

    try {
      final dateFormatter = DateFormat('yyyy-MM-dd');
      // Keep the row's `date` aligned with the user-selected schedule day.
      final formattedAccountingDate = dateFormatter.format(startDate);
      final anchorDateYmd = _buildAnchorDateYmd(startDate);
      final endDateYmd = _buildEndDateYmd(endDate);

      final recurrenceRule = <String, dynamic>{
        'frequency': frequency,
        'anchor_date': anchorDateYmd,
        'projection_enabled':
            originalIncome?.recurrenceRule?.projectionEnabled ?? true,
        if (endDateYmd != null) 'end_date': endDateYmd,
        if (interval != null) 'interval': interval,
        if (hasReminder == true &&
            reminderValue != null &&
            reminderUnit != null)
          'reminder': {
            'enabled': true,
            'value': reminderValue,
            'unit': reminderUnit,
          },
      };

      final updatesIncome = <String, dynamic>{
        'amount_cents': (amount * 100).round(),
        'category': category,
        'currency': currency,
        'date': formattedAccountingDate,
        'is_recurring': true,
        'recurrence_rule': recurrenceRule,
        'household_id': householdId,
        'account_id': accountId,
      };
      updatesIncome['raw_text'] =
          description != null && description.trim().isNotEmpty
              ? description.trim()
              : null;
      updatesIncome['merchant'] = merchant != null && merchant.trim().isNotEmpty
          ? merchant.trim()
          : null;
      updatesIncome['source'] =
          source != null && source.trim().isNotEmpty ? source.trim() : null;
      if (householdId != null && payerUserId?.isNotEmpty == true) {
        updatesIncome['payer_user_id'] = payerUserId;
      }

      final optimisticIncome = _buildOptimisticRecurringTransaction(
        userId: userId,
        type: 'income',
        amount: amount,
        category: category,
        currency: currency,
        startDate: startDate,
        frequency: frequency,
        endDate: endDate,
        interval: interval,
        description: description,
        merchant: merchant,
        source: source,
        hasReminder: hasReminder,
        reminderValue: reminderValue,
        reminderUnit: reminderUnit,
        projectionEnabled:
            originalIncome?.recurrenceRule?.projectionEnabled ?? true,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        payerUserId: payerUserId,
        accountId: accountId,
      ).copyWith(id: expenseId);
      mutationMetadata = buildTransactionMutationMetadataForRecord(
        clientRecordId: expenseId,
        operation: 'update_recurring_income',
      );
      lazyOptimisticHandle =
          ref.read(recurringSeriesOptimisticProvider.notifier).upsert(
                mutationId: mutationMetadata.clientMutationId,
                transaction: optimisticIncome,
                sourceHouseholdId: originalScopeKey,
              );
      final requestBody = <String, dynamic>{
        ...mutationMetadata.toRequestJson(),
        'userId': userId,
        'expenseId': expenseId,
        'updates': updatesIncome,
        if (householdId != null) 'householdId': householdId,
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      };
      if (householdId != null &&
          customSplitType != null &&
          customSplits != null &&
          customSplits.isNotEmpty) {
        final splitsPayload = {
          'splitType': customSplitType.name,
          'memberSplits': customSplits.map((split) {
            final memberData = <String, dynamic>{
              'userId': split.member.userId,
            };
            switch (customSplitType) {
              case SplitType.amount:
                memberData['amount'] = split.amount;
                break;
              case SplitType.percentage:
                memberData['percentage'] = split.percentage;
                break;
              case SplitType.shares:
                memberData['shares'] = split.shares;
                break;
              case SplitType.equal:
                break;
            }
            return memberData;
          }).toList(),
        };
        if (createSplitGroup ||
            previousHouseholdId == null ||
            previousHouseholdId != householdId) {
          requestBody['customSplits'] = splitsPayload;
        } else {
          requestBody['splitUpdate'] = splitsPayload;
          requestBody['reSplitRequested'] = reSplitRequested;
        }
      }
      if (householdId != null && payerUserId?.isNotEmpty == true) {
        requestBody['payerUserId'] = payerUserId;
      }
      try {
        if (originalScopeKey != householdId) {
          ref
              .read(recurringTransactionsProvider(originalScopeKey).notifier)
              .removeRecurring(expenseId);
        }
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .replaceRecurring(expenseId, optimisticIncome);
        if (originalIncome != null) {
          final database = await ref.read(localDatabaseProvider.future);
          localDatabase = database;
          await database.writeOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalIncome, userId),
            updatedEntry:
                _expenseEntryFromRecurringTransaction(optimisticIncome, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            payload: {
              ...mutationMetadata.toRequestJson(),
              'userId': userId,
              'expenseId': expenseId,
              'updates': updatesIncome,
              'extraBody': {
                if (householdId != null) 'householdId': householdId,
                if (requestBody.containsKey('customSplits'))
                  'customSplits': requestBody['customSplits'],
                if (requestBody.containsKey('splitUpdate'))
                  'splitUpdate': requestBody['splitUpdate'],
                if (requestBody.containsKey('reSplitRequested'))
                  'reSplitRequested': requestBody['reSplitRequested'],
                if (requestBody.containsKey('payerUserId'))
                  'payerUserId': requestBody['payerUserId'],
              },
            },
          );
        }
      } catch (_) {}

      final response = await supabase.functions.invoke(
        'update-expense',
        body: requestBody,
      );

      if (response.data['success'] == true) {
        final updatedIncome = RecurringTransaction.fromJson(
            response.data['data'] as Map<String, dynamic>);
        committedTransaction = updatedIncome;
        backendCommitted = true;
        final lazyHandle = lazyOptimisticHandle;
        ref.read(recurringSeriesOptimisticProvider.notifier).commit(
              lazyHandle,
              canonicalTransaction: updatedIncome,
            );
        ref.read(recurringReadRefreshSignalProvider.notifier).state += 1;
        await localDatabase?.markOptimisticTransactionUpdateSynced(
          entry: _expenseEntryFromRecurringTransaction(updatedIncome, userId),
          clientMutationId: mutationMetadata.clientMutationId,
        );
        state = AsyncValue.data(updatedIncome);
        ref
            .read(recurringTransactionsProvider(updatedIncome.householdId)
                .notifier)
            .updateRecurring(updatedIncome);

        // Force refresh the list provider to show the updated transaction
        // Don't use optimistic update as we'll invalidate in the sheet
        _debugPrint(
            '🔄 [UpdateRecurring] Updated successfully, transaction will be reloaded by invalidation');

        return updatedIncome;
      } else {
        if (localDatabase != null && originalIncome != null) {
          await localDatabase.rollbackOptimisticTransactionUpdate(
            originalEntry:
                _expenseEntryFromRecurringTransaction(originalIncome, userId),
            clientMutationId: mutationMetadata.clientMutationId,
            error: response.data,
          );
        }
        rollbackOptimisticIncome();
        final errorPayload = _buildFunctionErrorPayload(
          response.data,
          fallback: 'Failed to update recurring income',
        );
        state = AsyncValue.error(
          errorPayload,
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      if (backendCommitted && committedTransaction != null) {
        try {
          ref
              .read(recurringTransactionsProvider(householdId).notifier)
              .updateRecurring(committedTransaction);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
        } catch (refreshError) {
          _debugPrint(
              '⚠️ [UpdateRecurring] Post-update reconciliation failed: $refreshError');
        }
        state = AsyncValue.data(committedTransaction);
        return committedTransaction;
      }
      if (localDatabase != null && _shouldKeepQueuedLocalMutation(e)) {
        final queued = ref
            .read(recurringTransactionsProvider(householdId))
            .data
            .valueOrNull
            ?.where((transaction) => transaction.id == expenseId)
            .firstOrNull;
        if (queued != null) {
          state = AsyncValue.data(queued);
          ref.invalidate(pocketsProvider);
          ref.invalidate(currencyTransactionCountsProvider);
          return queued;
        }
      }
      if (localDatabase != null &&
          originalIncome != null &&
          mutationMetadata != null) {
        await localDatabase.rollbackOptimisticTransactionUpdate(
          originalEntry:
              _expenseEntryFromRecurringTransaction(originalIncome, userId),
          clientMutationId: mutationMetadata.clientMutationId,
          error: e,
        );
      }
      rollbackOptimisticIncome();
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }

  Future<bool> _excludeOccurrenceFromSeries({
    required String userId,
    required RecurringTransaction recurringSeries,
    required DateTime occurrenceDateToSkip,
  }) async {
    final rule = recurringSeries.recurrenceRule;
    if (rule == null) {
      return false;
    }

    final skipDate = DateTime(
      occurrenceDateToSkip.year,
      occurrenceDateToSkip.month,
      occurrenceDateToSkip.day,
    );

    final alreadyExcluded = rule.excludedDates.any(
      (entry) =>
          entry.year == skipDate.year &&
          entry.month == skipDate.month &&
          entry.day == skipDate.day,
    );

    final updatedExcludedDates = alreadyExcluded
        ? rule.excludedDates
        : [...rule.excludedDates, skipDate];

    final updatedRule = rule.copyWith(excludedDates: updatedExcludedDates);

    final response = await supabase.functions.invoke(
      'update-expense',
      body: {
        'userId': userId,
        'expenseId': recurringSeries.id,
        'updates': {
          'recurrence_rule': updatedRule.toJson(),
        },
      },
    );

    if (response.data is! Map<String, dynamic> ||
        (response.data as Map<String, dynamic>)['success'] != true) {
      return false;
    }

    try {
      ref
          .read(recurringTransactionsProvider(recurringSeries.householdId)
              .notifier)
          .updateRecurring(
            recurringSeries.copyWith(recurrenceRule: updatedRule),
          );
    } catch (_) {}

    return true;
  }

  Future<void> _deleteExpenseById({
    required String userId,
    required String expenseId,
  }) async {
    try {
      await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': userId,
          'expenseIds': expenseId,
        },
      );
    } catch (_) {}
  }

  Map<String, dynamic> _buildFunctionErrorPayload(
    dynamic responseData, {
    required String fallback,
  }) {
    if (responseData is Map<String, dynamic>) {
      final rawError = responseData['error'] ?? responseData['message'];
      final errorText = rawError is String && rawError.trim().isNotEmpty
          ? rawError.trim()
          : fallback;
      return {
        'error': errorText,
        'code': responseData['code']?.toString(),
        'status': responseData['status'],
      };
    }

    return {
      'error': fallback,
      'code': 'SERVER_ERROR',
    };
  }

  Future<MonekoDatabase?> _queueRecurringCreate({
    required RecurringTransaction optimisticTransaction,
    required TransactionMutationMetadata mutationMetadata,
    required String functionName,
    required Map<String, dynamic> requestBody,
    required String fallbackUserId,
  }) async {
    try {
      final database = await ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransaction(
        entry: _expenseEntryFromRecurringTransaction(
          optimisticTransaction,
          fallbackUserId,
        ),
        clientMutationId: mutationMetadata.clientMutationId,
        operation: 'create',
        payload: {
          ...mutationMetadata.toRequestJson(),
          'transaction': _expenseEntryFromRecurringTransaction(
            optimisticTransaction,
            fallbackUserId,
          ).toJson(),
          'functionName': functionName,
          'requestBody': requestBody,
        },
      );
      return database;
    } catch (error) {
      _debugPrint('[RecurringTx] Local recurring queue unavailable: $error');
      return null;
    }
  }
}

bool _shouldKeepQueuedLocalMutation(Object error) {
  return ErrorHandler.isRetryable(error);
}

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

final selectedRecurringTabProvider = StateProvider<int>((ref) => 0);

void _showPreviewToast() {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  AppToast.info(
    ctx,
    'Preview mode is read-only. Create an account to save recurring changes.',
  );
}

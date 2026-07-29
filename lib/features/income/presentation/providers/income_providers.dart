import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/income/domain/models/income_entry.dart';
import 'package:moneko/features/income/domain/models/income_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';

/// Income list state provider
final incomeListProvider =
    StateNotifierProvider<IncomeListNotifier, AsyncValue<List<IncomeEntry>>>(
        (ref) {
  return IncomeListNotifier(ref);
});

Map<String, dynamic> buildIncomeListRequest({
  required String userId,
  required int limit,
  DateTime? startDate,
  DateTime? endDate,
  String? currency,
  String? householdId,
}) =>
    <String, dynamic>{
      'userId': userId,
      'limit': limit,
      'excludeRecurring': true,
      if (startDate != null) 'startDate': formatDateOnlyYmd(startDate),
      if (endDate != null) 'endDate': formatDateOnlyYmd(endDate),
      if (currency != null) 'currency': currency,
      if (householdId != null) 'householdId': householdId,
    };

class IncomeListNotifier extends StateNotifier<AsyncValue<List<IncomeEntry>>> {
  final Ref ref;

  IncomeListNotifier(this.ref) : super(const AsyncValue.loading());

  /// Load income for a user (with optional filters)
  Future<void> loadIncome(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    String? householdId,
    int limit = 50,
  }) async {
    final previous = state;
    state = previous.hasValue
        ? const AsyncLoading<List<IncomeEntry>>().copyWithPrevious(previous)
        : const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'list-income',
        body: buildIncomeListRequest(
          userId: userId,
          limit: limit,
          startDate: startDate,
          endDate: endDate,
          currency: currency,
          householdId: householdId,
        ),
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as List<dynamic>;
        final incomeList = data
            .map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(incomeList);
      } else {
        state = previous.hasValue
            ? previous
            : AsyncValue.error(
                response.data['error'] ?? 'Failed to load income',
                StackTrace.current,
              );
      }
    } catch (e, st) {
      if (!mounted) return;
      state = previous.hasValue ? previous : AsyncValue.error(e, st);
    }
  }

  /// Refresh income list
  Future<void> refresh(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    String? householdId,
  }) async {
    await loadIncome(
      userId,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      householdId: householdId,
    );
  }
}

/// Income summary provider
final incomeSummaryProvider =
    StateNotifierProvider<IncomeSummaryNotifier, AsyncValue<IncomeSummary>>(
        (ref) {
  return IncomeSummaryNotifier(ref);
});

class IncomeSummaryNotifier extends StateNotifier<AsyncValue<IncomeSummary>> {
  final Ref ref;

  IncomeSummaryNotifier(this.ref) : super(const AsyncValue.loading());

  /// Load income summary for a user
  Future<void> loadSummary(
    String userId, {
    String? householdId,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
  }) async {
    final previous = state;
    state = previous.hasValue
        ? const AsyncLoading<IncomeSummary>().copyWithPrevious(previous)
        : const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'income-summary',
        body: {
          'userId': userId,
          if (householdId != null) 'householdId': householdId,
          if (startDate != null) 'startDate': formatDateOnlyYmd(startDate),
          if (endDate != null) 'endDate': formatDateOnlyYmd(endDate),
          if (currency != null) 'currency': currency,
        },
      );

      if (response.data['success'] == true) {
        final summary = IncomeSummary.fromJson(
            response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(summary);
      } else {
        state = previous.hasValue
            ? previous
            : AsyncValue.error(
                response.data['error'] ?? 'Failed to load income summary',
                StackTrace.current,
              );
      }
    } catch (e, st) {
      if (!mounted) return;
      state = previous.hasValue ? previous : AsyncValue.error(e, st);
    }
  }

  /// Refresh income summary
  Future<void> refresh(
    String userId, {
    String? householdId,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
  }) async {
    await loadSummary(
      userId,
      householdId: householdId,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
    );
  }
}

/// Income save provider
final incomeSaveProvider =
    StateNotifierProvider<IncomeSaveNotifier, AsyncValue<IncomeEntry?>>((ref) {
  return IncomeSaveNotifier(ref);
});

class IncomeSaveNotifier extends StateNotifier<AsyncValue<IncomeEntry?>> {
  final Ref ref;

  IncomeSaveNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Save new income
  Future<IncomeEntry?> saveIncome({
    required String userId,
    required double amount,
    required String category,
    required String currency,
    required DateTime date,
    String? description,
    String? merchant,
    String? source,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? accountId,
    double? fxRate,
    String? clientRecordId,
    String? clientMutationId,
    String? idempotencyKey,
    List<Map<String, dynamic>>? attachments,
    bool isRecurring = false,
    Map<String, dynamic>? recurrenceRule,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final isPortfolio = householdId != null &&
          ref.read(householdScopeProvider).isPortfolioId(householdId);
      final accountingDate = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final optimisticId = clientRecordId?.trim().isNotEmpty == true
          ? clientRecordId!.trim()
          : 'optimistic-income-${now.microsecondsSinceEpoch}';
      final mutationId = clientMutationId?.trim().isNotEmpty == true
          ? clientMutationId!.trim()
          : 'mobile:$optimisticId';
      final effectiveIdempotencyKey = idempotencyKey?.trim().isNotEmpty == true
          ? idempotencyKey!.trim()
          : mutationId;

      final requestBody = <String, dynamic>{
        'userId': userId,
        'amount': amount,
        'category': category,
        'currency': currency,
        'date': formatDateOnlyYmd(accountingDate),
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        if (description != null && description.isNotEmpty)
          'description': description,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        if (source != null && source.isNotEmpty) 'source': source,
        'ownerType': ownerType,
        'privacyScope': privacyScope,
        if (householdId != null) 'householdId': householdId,
        if (householdId != null) 'isPortfolio': isPortfolio,
        'accountId': accountId?.trim().isEmpty == true ? null : accountId,
        if (fxRate != null) 'fxRate': fxRate,
        'clientRecordId': optimisticId,
        'clientMutationId': mutationId,
        'idempotencyKey': effectiveIdempotencyKey,
        if (attachments != null) 'attachments': attachments,
        'isRecurring': isRecurring,
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      };

      if (!isPortfolio &&
          householdId != null &&
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

      if (!isPortfolio &&
          householdId != null &&
          payerUserId != null &&
          payerUserId.isNotEmpty) {
        requestBody['payerUserId'] = payerUserId;
      }

      final optimisticIncome = IncomeEntry(
        id: optimisticId,
        date: accountingDate,
        category: category,
        description: description,
        source: source,
        amount: amount,
        currency: currency,
        ownerType: ownerType,
        privacyScope: privacyScope,
        householdId: householdId,
        isAcknowledged: false,
        acknowledgedCount: 0,
        fxRate: fxRate,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule == null
            ? null
            : RecurrenceRule.fromJson(recurrenceRule),
        attachments: const [],
        createdAt: now,
        privacyRedacted: false,
      );
      final database = await ref.read(localDatabaseProvider.future);
      await database.writeOptimisticTransaction(
        entry: ExpenseEntry(
          id: optimisticId,
          userId: userId,
          householdId: householdId,
          date: accountingDate,
          amountCents: (amount * 100).round(),
          currency: currency,
          category: category,
          createdAt: now,
          rawText: description,
          merchant: merchant,
          walletId: accountId,
          type: 'income',
          isRecurring: isRecurring,
          recurrenceRuleJson: recurrenceRule,
          clientRecordId: optimisticId,
          clientMutationId: mutationId,
          idempotencyKey: effectiveIdempotencyKey,
        ),
        clientMutationId: mutationId,
        operation: 'create',
        payload: {
          'functionName': 'save-income',
          'requestBody': requestBody,
        },
      );

      final currentIncome =
          ref.read(incomeListProvider).valueOrNull ?? const <IncomeEntry>[];
      ref.read(incomeListProvider.notifier).state = AsyncValue.data([
        optimisticIncome,
        ...currentIncome.where((entry) => entry.id != optimisticId),
      ]);
      _applyOptimisticIncomeSummary(optimisticIncome);
      state = AsyncValue.data(optimisticIncome);
      ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
      unawaited(_reconcileQueuedIncome(
        database: database,
        mutationId: mutationId,
        userId: userId,
        householdId: householdId,
      ));
      return optimisticIncome;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _applyOptimisticIncomeSummary(IncomeEntry income) {
    final current = ref.read(incomeSummaryProvider).valueOrNull;
    if (current == null ||
        current.currency.toUpperCase() != income.currency.toUpperCase() ||
        income.date.isBefore(current.period.startDate) ||
        income.date.isAfter(current.period.endDate)) {
      return;
    }
    ref.read(incomeSummaryProvider.notifier).state = AsyncValue.data(
      IncomeSummary(
        totalIncome: current.totalIncome + income.amount,
        mtdIncome: current.mtdIncome == null
            ? null
            : current.mtdIncome! + income.amount,
        ytdIncome: current.ytdIncome == null
            ? null
            : current.ytdIncome! + income.amount,
        currency: current.currency,
        categoryBreakdown: {
          ...current.categoryBreakdown,
          income.category:
              (current.categoryBreakdown[income.category] ?? 0) + income.amount,
        },
        currencyBreakdown: current.currencyBreakdown,
        memberBreakdown: current.memberBreakdown,
        transactionCount: current.transactionCount + 1,
        period: current.period,
      ),
    );
  }

  Future<void> _reconcileQueuedIncome({
    required MonekoDatabase database,
    required String mutationId,
    required String userId,
    required String? householdId,
  }) async {
    try {
      await drainMobileOutbox(ref);
      final mutations = await database.getOutboxMutations();
      final matching = mutations.where(
        (mutation) => mutation.clientMutationId == mutationId,
      );
      if (matching.isEmpty ||
          !const {localMutationStatusSynced, localMutationStatusCancelled}
              .contains(matching.single.status) ||
          !mounted) {
        return;
      }
      await ref
          .read(incomeListProvider.notifier)
          .refresh(userId, householdId: householdId);
      if (!mounted) return;
      await ref
          .read(incomeSummaryProvider.notifier)
          .refresh(userId, householdId: householdId);
    } catch (_) {
      // The outbox owns retry and terminal-error reporting.
    }
  }

  /// Reset save state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Income acknowledgement provider
final incomeAcknowledgeProvider =
    StateNotifierProvider<IncomeAcknowledgeNotifier, AsyncValue<bool>>((ref) {
  return IncomeAcknowledgeNotifier(ref);
});

class IncomeAcknowledgeNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;

  IncomeAcknowledgeNotifier(this.ref) : super(const AsyncValue.data(false));

  /// Acknowledge income
  Future<bool> acknowledgeIncome(String userId, String incomeId) async {
    state = const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'acknowledge-income',
        body: {
          'userId': userId,
          'incomeId': incomeId,
        },
      );

      if (response.data['success'] == true) {
        state = const AsyncValue.data(true);

        // Refresh income list to show updated acknowledgement status
        final currentIncome = ref.read(incomeListProvider);
        if (currentIncome.hasValue) {
          // Update local state optimistically
          final updatedList = currentIncome.value!.map((income) {
            if (income.id == incomeId) {
              return income.copyWith(
                isAcknowledged: true,
                acknowledgedCount: income.acknowledgedCount + 1,
              );
            }
            return income;
          }).toList();
          ref.read(incomeListProvider.notifier).state =
              AsyncValue.data(updatedList);
        }

        return true;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to acknowledge income',
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Reset acknowledgement state
  void reset() {
    state = const AsyncValue.data(false);
  }
}

/// Pending income provider (for temporary storage during entry)
final pendingIncomeProvider = StateProvider<IncomeEntry?>((ref) => null);

/// Selected currency provider for income entry
final selectedCurrencyProvider = StateProvider<String>((ref) => 'USD');

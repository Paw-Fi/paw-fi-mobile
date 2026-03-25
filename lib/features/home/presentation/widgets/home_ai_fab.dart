import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/ai_hold_quick_action_preference.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

/// Shared helpers and widgets for the unified transaction FAB / AI expense capture.

const int _reviewFirstPromptAt = 2;
const int _reviewSecondInterval = 2;
const int _reviewThirdInterval = 3;
const int _reviewMaxInterval = 5;
const String _reviewExpenseCountKey = 'review_expense_count';
const String _reviewLastPromptKey = 'review_last_prompt_count';
const String _reviewLastIntervalKey = 'review_last_prompt_interval';
const String _holdQuickActionReminderShownKey =
    'hold_quick_action_reminder_shown';
const String _holdQuickActionReminderExpenseCountKey =
    'hold_quick_action_reminder_expense_count';
const int _holdQuickActionReminderFirstPromptAt = 2;
const int _maxBatchSize = 400;
const int _maxAiFileUploadBytes = 20 * 1024 * 1024;
const double _recordCancelDragThreshold = 90;
const int _minimumHoldRecordingMs = 1000;

final ImagePicker _imagePicker = ImagePicker();

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

class _AiParsedItem {
  final ParsedExpense transaction;
  final String optimisticId;
  final Map<String, dynamic> raw;

  const _AiParsedItem({
    required this.transaction,
    required this.optimisticId,
    required this.raw,
  });
}

class AiLogSuccess {
  final int count;
  final String targetLabel;
  final List<ParsedExpense> items;

  const AiLogSuccess({
    required this.count,
    required this.targetLabel,
    required this.items,
  });
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  return null;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_asStringDynamicMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

Map<String, dynamic> _unwrapFunctionData(Object? responseData) {
  final payload = _asStringDynamicMap(responseData);
  if (payload == null) {
    throw Exception('Unexpected response shape from Edge Function');
  }
  return payload;
}

Map<String, dynamic>? _extractSavedEntryPayload(Object? responseData) {
  final payload = _asStringDynamicMap(responseData);
  if (payload == null) return null;

  final nested = _asStringDynamicMap(payload['data']);
  if (nested != null) return nested;

  if (payload.containsKey('id') && payload['id'] != null) {
    return payload;
  }

  return null;
}

double? _parseAmountValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String? _resolveHouseholdIdForAi(WidgetRef ref) {
  final scope = ref.read(householdScopeProvider);
  return scope.activeAccountHouseholdId;
}

String _resolveLogTargetLabel(BuildContext context, WidgetRef ref) {
  final householdId = _resolveHouseholdIdForAi(ref);
  if (householdId == null) return context.l10n.personalScope;

  final selected = ref.read(selectedHouseholdProvider);
  return selected.household?.name ?? context.l10n.forUs;
}

String _truncateForToast(String? value, {int maxLen = 28}) {
  final s = (value ?? '').trim();
  if (s.isEmpty) return '';
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 1)}…';
}

String _formatAiLoggedToastMessage(
  BuildContext context,
  WidgetRef ref, {
  required List<_AiParsedItem> items,
}) {
  final target = _resolveLogTargetLabel(context, ref);
  if (items.isEmpty) return context.l10n.failedToAnalyzeNoData;

  final count = items.length;
  final allIncome = items.every((e) => e.transaction.isIncome);
  final allExpense = items.every((e) => !e.transaction.isIncome);

  if (count == 1) {
    final tx = items.first.transaction;
    final savedLabel =
        tx.isIncome ? context.l10n.incomeSaved : context.l10n.expenseSaved;
    final desc = _truncateForToast(tx.description);
    final detail = desc.isEmpty ? '' : ' • $desc';
    return '$savedLabel ${tx.formattedAmount}$detail → $target';
  }

  if (allIncome) {
    return '${context.l10n.incomeSaved} ($count) → $target';
  }
  if (allExpense) {
    return '${context.l10n.expenseSaved} ($count) → $target';
  }
  return '${context.l10n.transactions} ($count) → $target';
}

List<Map<String, dynamic>> _buildHouseholdMemberContext(
  WidgetRef ref,
  String householdId,
) {
  final membersAsync = ref.read(householdMembersProvider(householdId));
  final members = membersAsync.valueOrNull;
  if (members == null || members.isEmpty) return const [];

  return members
      .map(
        (m) => {
          'userId': m.userId,
          if (m.userName != null && m.userName!.trim().isNotEmpty)
            'userName': m.userName,
          if (m.userEmail != null && m.userEmail!.trim().isNotEmpty)
            'userEmail': m.userEmail,
        },
      )
      .toList(growable: false);
}

Future<void> _maybeRequestReviewAfterExpenseSave({
  required String userId,
  required SharedPreferences prefs,
  required int additionalExpenseCount,
}) async {
  try {
    if (userId.isEmpty || additionalExpenseCount <= 0) return;
    final userKey = sha256.convert(utf8.encode(userId)).toString();
    final countKey = '${_reviewExpenseCountKey}_$userKey';
    final lastPromptKey = '${_reviewLastPromptKey}_$userKey';
    final lastIntervalKey = '${_reviewLastIntervalKey}_$userKey';

    final updatedCount = (prefs.getInt(countKey) ?? 0) + additionalExpenseCount;
    await prefs.setInt(countKey, updatedCount);

    final lastPromptCount = prefs.getInt(lastPromptKey) ?? 0;
    final lastInterval = prefs.getInt(lastIntervalKey) ?? 0;
    final nextInterval = () {
      if (lastInterval <= 0) return _reviewSecondInterval;
      if (lastInterval == _reviewSecondInterval) return _reviewThirdInterval;
      return _reviewMaxInterval;
    }();

    final shouldPrompt = updatedCount == _reviewFirstPromptAt ||
        (updatedCount - lastPromptCount) >= nextInterval;
    if (!shouldPrompt) return;

    await prefs.setInt(lastPromptKey, updatedCount);
    await prefs.setInt(lastIntervalKey, nextInterval);

    final inAppReview = InAppReview.instance;
    final available = await inAppReview.isAvailable();
    if (!available) return;

    await inAppReview.requestReview();
  } catch (error) {
    _debugPrint('[REVIEW] Failed to request review: $error');
  }
}

Future<void> _persistAiTransactions(
  ProviderContainer container, {
  required String userId,
  required String? householdId,
  required bool isPortfolio,
  required List<_AiParsedItem> transactions,
  String? localImagePath,
}) async {
  if (transactions.isEmpty) return;

  final clientCreatedAtIso = DateTime.now().toUtc().toIso8601String();

  String? normalizeBucketId(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool resolveIsRecurring(Map<String, dynamic> raw) {
    final dynamicValue = raw['is_recurring'] ?? raw['isRecurring'];
    if (dynamicValue is bool) return dynamicValue;
    if (dynamicValue is num) return dynamicValue != 0;
    if (dynamicValue is String) {
      final normalized = dynamicValue.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Map<String, dynamic>? normalizeRecurrenceRule(
    Map<String, dynamic> raw,
    String fallbackAnchorDate,
  ) {
    String? normalizeCalendarDateString(dynamic value) {
      final parsed = parseCalendarDateFromFlexibleInput(value?.toString());
      return parsed == null ? null : formatDateOnlyYmd(parsed);
    }

    final sourceRule = raw['recurrence_rule'] ?? raw['recurrenceRule'];
    final sourceMap = sourceRule is Map
        ? Map<String, dynamic>.from(sourceRule)
        : <String, dynamic>{};

    final rawFrequency = sourceMap['frequency'] ?? raw['frequency'];
    final frequency =
        rawFrequency is String ? rawFrequency.trim().toLowerCase() : '';
    const allowedFrequencies = <String>{
      'daily',
      'weekly',
      'biweekly',
      'monthly',
      'yearly',
      'custom',
    };
    if (!allowedFrequencies.contains(frequency)) {
      return null;
    }

    final rawAnchorDate = sourceMap['anchor_date'] ?? sourceMap['anchorDate'];
    final anchorDate =
        normalizeCalendarDateString(rawAnchorDate) ?? fallbackAnchorDate;

    final normalizedRule = <String, dynamic>{
      'frequency': frequency,
      'anchor_date': anchorDate,
    };

    final rawEndDate = sourceMap['end_date'] ?? sourceMap['endDate'];
    final normalizedEndDate = normalizeCalendarDateString(rawEndDate);
    if (normalizedEndDate != null) {
      normalizedRule['end_date'] = normalizedEndDate;
    }

    final rawInterval = sourceMap['interval'];
    if (rawInterval is num && rawInterval > 0) {
      normalizedRule['interval'] = rawInterval.toInt();
    }

    final rawReminder = sourceMap['reminder'];
    if (rawReminder is Map) {
      final reminder = Map<String, dynamic>.from(rawReminder);
      final rawEnabled = reminder['enabled'];
      final rawValue = reminder['value'];
      final rawUnit = reminder['unit'];
      if (rawEnabled is bool &&
          rawValue is num &&
          rawValue > 0 &&
          rawUnit is String) {
        final unit = rawUnit.trim().toLowerCase();
        if (unit == 'days' || unit == 'hours') {
          normalizedRule['reminder'] = <String, dynamic>{
            'enabled': rawEnabled,
            'value': rawValue,
            'unit': unit,
          };
        }
      }
    }

    return normalizedRule;
  }

  void upsertSavedEntry({
    required String optimisticId,
    required ExpenseEntry savedEntry,
  }) {
    if (savedEntry.id.isNotEmpty) {
      container
          .read(householdOptimisticExpensesProvider.notifier)
          .removeExpenseByIdAcrossHouseholds(savedEntry.id);
    }
    final fromBucket = normalizeBucketId(householdId);
    final toBucket = normalizeBucketId(savedEntry.householdId);

    if (fromBucket == toBucket) {
      replaceOptimisticTransactionWithContainer(
        container: container,
        optimisticId: optimisticId,
        savedEntry: savedEntry,
        householdId: fromBucket,
      );
      return;
    }

    removeOptimisticTransactionWithContainer(
      container: container,
      optimisticId: optimisticId,
      householdId: fromBucket,
    );
    addOptimisticTransactionWithContainer(
      container: container,
      entry: savedEntry,
      householdId: toBucket,
    );
  }

  Future<void> attachOptimisticSplitsForSavedExpenses(
    Map<String, ExpenseEntry> savedExpensesById,
  ) async {
    if (savedExpensesById.isEmpty) return;
    final targetHouseholdId = householdId?.trim();
    if (targetHouseholdId == null || targetHouseholdId.isEmpty) return;
    if (isPortfolio) return;

    try {
      final repository = container.read(householdRepositoryProvider);
      const maxAttempts = 5;
      const delay = Duration(milliseconds: 250);

      List<ExpenseSplitGroup> splits = const <ExpenseSplitGroup>[];
      Map<String, ExpenseSplitGroup> splitsByExpenseId =
          const <String, ExpenseSplitGroup>{};

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        splits = await repository.getHouseholdSplits(
          householdId: targetHouseholdId,
        );

        splitsByExpenseId = {
          for (final group in splits) group.expenseId: group,
        };

        final missing = savedExpensesById.keys
            .where((id) => !splitsByExpenseId.containsKey(id))
            .toList(growable: false);

        if (missing.isEmpty || attempt == maxAttempts) break;
        await Future.delayed(delay);
      }

      if (splitsByExpenseId.isEmpty) return;

      final splitsNotifier =
          container.read(householdOptimisticSplitsProvider.notifier);
      final expensesNotifier =
          container.read(householdOptimisticExpensesProvider.notifier);

      for (final entry in savedExpensesById.values) {
        final group = splitsByExpenseId[entry.id];
        if (group == null) continue;
        splitsNotifier.addSplitGroup(targetHouseholdId, group);

        final splitGroupId = entry.splitGroupId?.trim();
        if (splitGroupId == null || splitGroupId.isEmpty) {
          final updated = entry.copyWith(splitGroupId: group.id);
          expensesNotifier.replaceExpense(targetHouseholdId, entry.id, updated);
        }
      }
    } catch (error) {
      _debugPrint('❌ [AI Batch Save] Failed to attach split groups: $error');
    }
  }

  // Upload receipt image first (if any) - shared across all transactions
  String? receiptUrl;
  if (localImagePath != null && localImagePath.isNotEmpty) {
    receiptUrl = await container
        .read(expenseSaveNotifierProvider.notifier)
        .uploadReceiptImage(File(localImagePath), userId);
  }

  // Build batch payload - all transactions in a single request
  final batchTransactions = transactions.map((item) {
    final tx = item.transaction;
    final isIncome = tx.isIncome;
    final isRecurring = resolveIsRecurring(item.raw);
    final recurrenceRule = normalizeRecurrenceRule(
      item.raw,
      formatDateOnlyYmd(tx.date),
    );

    // Extract payer and splits for expenses
    final rawPayerUserId = item.raw['payerUserId'];
    final payerUserId =
        rawPayerUserId is String && rawPayerUserId.trim().isNotEmpty
            ? rawPayerUserId.trim()
            : null;

    final rawCustomSplits = item.raw['customSplits'];
    final customSplits = rawCustomSplits is Map
        ? Map<String, dynamic>.from(rawCustomSplits)
        : null;

    final splitType = customSplits?['splitType']?.toString().trim();
    final safeCustomSplits =
        (splitType == null || splitType == 'equal') ? null : customSplits;

    return <String, dynamic>{
      'type': isIncome ? 'income' : 'expense',
      'amount': tx.amount,
      'category': tx.category,
      'currency': tx.currency,
      'date': formatDateOnlyYmd(tx.date),
      'clientCreatedAt': clientCreatedAtIso,
      if (isRecurring) 'isRecurring': true,
      if (isRecurring && recurrenceRule != null)
        'recurrence_rule': recurrenceRule,
      if (tx.description?.isNotEmpty == true) 'description': tx.description,
      if (tx.breakdown?.isNotEmpty == true) 'breakdown': tx.breakdown,
      if (receiptUrl != null && !isIncome) 'receiptImageUrl': receiptUrl,
      // Expense-specific fields
      if (!isIncome && payerUserId != null) 'payerUserId': payerUserId,
      if (!isIncome && safeCustomSplits != null)
        'customSplits': safeCustomSplits,
      // Income-specific fields (ownerType, privacyScope use defaults on backend)
    };
  }).toList(growable: false);

  try {
    _debugPrint(
        '[AI Batch Save] Saving ${batchTransactions.length} transactions in single request');
    _debugPrint('[AI Batch Save] Function: save-transactions-batch');

    final batches = chunkList(batchTransactions, _maxBatchSize);
    var batchOffset = 0;

    var didPersistAny = false;
    var savedExpenseCount = 0;
    final savedExpenseEntriesById = <String, ExpenseEntry>{};

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      _debugPrint(
          '[AI Batch Save] Batch ${batchIndex + 1}/${batches.length} size=${batch.length}');

      final response = await supabase.functions.invoke(
        'save-transactions-batch',
        body: {
          'userId': userId,
          if (householdId != null && householdId.isNotEmpty)
            'householdId': householdId,
          if (householdId != null && householdId.isNotEmpty)
            'isPortfolio': isPortfolio,
          'transactions': batch,
        },
      );

      if (response.data == null) {
        throw Exception('No response from save-transactions-batch');
      }

      final responseData = _unwrapFunctionData(response.data);
      final results = _asMapList(responseData['results']);
      final summary = _asStringDynamicMap(responseData['summary']);
      final backendSucceeded = responseData['success'] == true;
      final hasStructuredResults = results.isNotEmpty;

      if (!backendSucceeded && !hasStructuredResults) {
        final backendError = responseData['error']?.toString();
        throw Exception(backendError ?? 'Batch save failed');
      }

      _debugPrint(
          '[AI Batch Save] Result: ${summary?['succeeded'] ?? 0} succeeded, ${summary?['failed'] ?? 0} failed');

      if (hasStructuredResults) {
        // Map results back to optimistic entries by index
        for (final resultItem in results) {
          final result = resultItem;
          final index = (result['index'] as num?)?.toInt();
          final success = result['success'] == true;
          final data = _asStringDynamicMap(result['data']);

          if (index == null) {
            _debugPrint(
              '⚠️ Batch result missing index, ignoring item: $result',
            );
            continue;
          }

          final originalIndex = batchOffset + index;
          if (originalIndex < 0 || originalIndex >= transactions.length) {
            continue;
          }

          final originalItem = transactions[originalIndex];

          if (success && data != null) {
            final savedEntry = ExpenseEntry.fromJson(data);
            upsertSavedEntry(
              optimisticId: originalItem.optimisticId,
              savedEntry: savedEntry,
            );
            didPersistAny = true;
            if (!originalItem.transaction.isIncome) {
              savedExpenseCount += 1;
              savedExpenseEntriesById[savedEntry.id] = savedEntry;
            }
          } else {
            // Remove failed optimistic entry
            removeOptimisticTransactionWithContainer(
              container: container,
              optimisticId: originalItem.optimisticId,
              householdId: householdId,
            );
            _debugPrint(
                '❌ Failed to persist transaction at index $originalIndex: ${result['error'] ?? 'unknown error'}');
          }
        }
      } else {
        _debugPrint(
          '⚠️ Batch response returned no per-item results; preserving optimistic entries and continuing',
        );
      }

      batchOffset += batch.length;
    }

    await attachOptimisticSplitsForSavedExpenses(savedExpenseEntriesById);

    if (didPersistAny) {
      await container
          .read(expenseSaveNotifierProvider.notifier)
          .invalidateAfterBatch(
            userId: userId,
            householdId: householdId,
          );
    }

    if (savedExpenseCount > 0) {
      final prefs = container.read(sharedPreferencesProvider);
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _maybeRequestReviewAfterExpenseSave(
          userId: userId,
          prefs: prefs,
          additionalExpenseCount: savedExpenseCount,
        ),
      ));
    }
  } catch (error) {
    _debugPrint('❌ Batch save failed: $error');

    final shouldFallback = shouldFallbackForBatchError(error);

    if (shouldFallback) {
      _debugPrint(
          '⚠️ Batch endpoint not available, falling back to individual saves');

      // Save transactions individually using existing endpoints
      var savedCount = 0;
      var savedExpenseCount = 0;
      final savedExpenseEntriesById = <String, ExpenseEntry>{};

      for (final item in transactions) {
        try {
          final tx = item.transaction;
          final isIncome = tx.isIncome;
          final isRecurring = resolveIsRecurring(item.raw);
          final recurrenceRule = normalizeRecurrenceRule(
            item.raw,
            formatDateOnlyYmd(tx.date),
          );
          final endpoint = isIncome ? 'save-income' : 'save-expense';

          final requestBody = <String, dynamic>{
            'userId': userId,
            'amount': tx.amount,
            'category': tx.category,
            'currency': tx.currency,
            'date': formatDateOnlyYmd(tx.date),
            'clientCreatedAt': clientCreatedAtIso,
            if (isRecurring) 'isRecurring': true,
            if (isRecurring && recurrenceRule != null)
              'recurrence_rule': recurrenceRule,
            if (tx.description?.isNotEmpty == true)
              'description': tx.description,
            if (tx.breakdown?.isNotEmpty == true) 'breakdown': tx.breakdown,
            if (receiptUrl != null && !isIncome) 'receiptImageUrl': receiptUrl,
            if (householdId != null && householdId.isNotEmpty)
              'householdId': householdId,
            if (householdId != null && householdId.isNotEmpty)
              'isPortfolio': isPortfolio,
          };

          // Add expense-specific fields
          if (!isIncome) {
            final rawPayerUserId = item.raw['payerUserId'];
            final payerUserId =
                rawPayerUserId is String && rawPayerUserId.trim().isNotEmpty
                    ? rawPayerUserId.trim()
                    : null;

            final rawCustomSplits = item.raw['customSplits'];
            final customSplits = rawCustomSplits is Map
                ? Map<String, dynamic>.from(rawCustomSplits)
                : null;

            final splitType = customSplits?['splitType']?.toString().trim();
            final safeCustomSplits = (splitType == null || splitType == 'equal')
                ? null
                : customSplits;

            if (payerUserId != null) requestBody['payerUserId'] = payerUserId;
            if (safeCustomSplits != null) {
              requestBody['customSplits'] = safeCustomSplits;
            }
          }

          final response =
              await supabase.functions.invoke(endpoint, body: requestBody);

          final savedPayload = _extractSavedEntryPayload(response.data);

          if (savedPayload != null) {
            final savedEntry = ExpenseEntry.fromJson(savedPayload);
            upsertSavedEntry(
              optimisticId: item.optimisticId,
              savedEntry: savedEntry,
            );
            savedCount++;
            if (!isIncome) {
              savedExpenseCount++;
              savedExpenseEntriesById[savedEntry.id] = savedEntry;
            }
          } else {
            throw Exception(
                'No saved transaction data returned from $endpoint');
          }
        } catch (itemError) {
          _debugPrint('❌ Failed to save individual transaction: $itemError');
          removeOptimisticTransactionWithContainer(
            container: container,
            optimisticId: item.optimisticId,
            householdId: householdId,
          );
        }
      }

      _debugPrint(
          '[AI Fallback Save] Saved $savedCount/${transactions.length} transactions');

      if (savedCount > 0) {
        await container
            .read(expenseSaveNotifierProvider.notifier)
            .invalidateAfterBatch(
              userId: userId,
              householdId: householdId,
            );
      }

      if (savedExpenseEntriesById.isNotEmpty) {
        await attachOptimisticSplitsForSavedExpenses(savedExpenseEntriesById);
      }

      if (savedExpenseCount > 0) {
        final prefs = container.read(sharedPreferencesProvider);
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 300),
          () => _maybeRequestReviewAfterExpenseSave(
            userId: userId,
            prefs: prefs,
            additionalExpenseCount: savedExpenseCount,
          ),
        ));
      }

      return; // Exit successfully after fallback
    }

    // For non-recoverable errors, remove all optimistic entries and rethrow
    for (final item in transactions) {
      removeOptimisticTransactionWithContainer(
        container: container,
        optimisticId: item.optimisticId,
        householdId: householdId,
      );
    }

    rethrow;
  }
}

bool shouldFallbackForBatchError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('404') || message.contains('not_found')) {
    return true;
  }
  if (message.contains('bad file descriptor')) {
    return true;
  }
  // Backend rejected the batch size — fall back to individual saves.
  if (message.contains('batch size exceeds')) {
    return true;
  }
  return false;
}

List<List<T>> chunkList<T>(List<T> items, int maxSize) {
  if (items.isEmpty) return <List<T>>[];
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += maxSize) {
    final end = (i + maxSize) > items.length ? items.length : (i + maxSize);
    chunks.add(items.sublist(i, end));
  }
  return chunks;
}

Future<void> handleAiCameraCapture(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  _debugPrint('🎥 Starting camera capture...');

  try {
    final XFile? photo = await pickImageWithGuard(
      picker: _imagePicker,
      source: ImageSource.camera,
      imageQuality: 85,
    );

    _debugPrint('🎥 Photo captured: ${photo != null}');

    if (photo != null) {
      if (context.mounted) {
        await _processExpense(
          context,
          ref,
          imagePath: photo.path,
          onSuccess: onSuccess,
        );
      }
    } else {
      _debugPrint('🎥 User cancelled or permission denied');
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiLibraryCapture(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  try {
    final XFile? image = await pickImageWithGuard(
      picker: _imagePicker,
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !context.mounted) {
      return;
    }

    await _processExpense(
      context,
      ref,
      imagePath: image.path,
      onSuccess: onSuccess,
    );
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiAudioBytes(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List audioBytes,
  String contentType = 'audio/aac',
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  if (!context.mounted) return;
  await _processExpense(
    context,
    ref,
    audioBytes: audioBytes,
    audioContentType: contentType,
    onSuccess: onSuccess,
  );
}

Future<void> handleAiFreeFormText(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  final controller = TextEditingController();

  await showTextInputDrawer(
    context,
    controller,
    (text) async {
      if (!context.mounted) return;
      await _processExpense(
        context,
        ref,
        text: text,
        onSuccess: onSuccess,
      );
    },
    onSubmitAudio: (audioBytes, contentType) async {
      if (!context.mounted) return;
      await _processExpense(
        context,
        ref,
        audioBytes: audioBytes,
        audioContentType: contentType,
        onSuccess: onSuccess,
      );
    },
  );
}

Future<void> handleAiFileUpload(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv', 'pdf', 'xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final path = file.path;

    if (path == null) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.failedToAnalyze);
      }
      return;
    }

    final fileSize = file.size;
    if (fileSize > _maxAiFileUploadBytes) {
      if (context.mounted) {
        AppToast.error(
          context,
          'File is too large to analyze. Keep it under 20MB or split it into smaller files.',
        );
      }
      return;
    }

    final bytes = await File(path).readAsBytes();
    final base64Data = base64Encode(bytes);

    final extension = path.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';
    if (extension == 'csv') {
      contentType = 'text/csv';
    } else if (extension == 'pdf') {
      contentType = 'application/pdf';
    } else if (extension == 'xlsx') {
      contentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (extension == 'xls') {
      contentType = 'application/vnd.ms-excel';
    }

    final attachments = <Map<String, dynamic>>[
      {
        'filename': file.name,
        'contentType': contentType,
        'data': base64Data,
      },
    ];

    if (context.mounted) {
      await _processExpense(
        context,
        ref,
        attachments: attachments,
        onSuccess: onSuccess,
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiFileOrGallery(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.l10n.appTitle,
    message: context.l10n.chooseSourceForAnalysis,
    actions: [
      AlertAction(
        title: context.l10n.files,
        style: AlertActionStyle.primary,
        onPressed: () async {
          await handleAiFileUpload(context, ref, onSuccess: onSuccess);
        },
      ),
      AlertAction(
        title: context.l10n.gallery,
        style: AlertActionStyle.primary,
        onPressed: () async {
          await handleAiLibraryCapture(context, ref, onSuccess: onSuccess);
        },
      ),
      AlertAction(
        title: context.l10n.cancel,
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
    ],
  );
}

/// Process analysis request with SSE streaming for real-time progress updates
Future<Map<String, dynamic>?> _processWithSSE({
  required Map<String, dynamic> body,
  required BlockingProcessingController dialogController,
  required bool Function() onCancelCheck,
}) async {
  // Get Supabase URL and auth token
  final supabaseUrl = Constants.supabaseUrl;
  final session = supabase.auth.currentSession;
  if (session == null) {
    throw Exception('No auth session');
  }

  // Build SSE URL with stream=true query param
  final sseUrl =
      Uri.parse('$supabaseUrl/functions/v1/analyze-expense?stream=true');

  _debugPrint('[SSE] Starting streaming request');

  Map<String, dynamic>? result;

  await for (final event in SSEService.streamRequest(
    url: sseUrl,
    body: body,
    headers: {
      'Authorization': 'Bearer ${session.accessToken}',
    },
    timeout: const Duration(minutes: 3),
  )) {
    // Check for cancellation
    if (onCancelCheck()) {
      _debugPrint('[SSE] Cancelled by user');
      throw Exception('Cancelled');
    }

    _debugPrint('[SSE] Received event: ${event.event}');

    switch (event.event) {
      case 'progress':
        final progressEvent = AnalysisProgressEvent.fromJson(event.data);
        dialogController.updateSubMessage(progressEvent.displayMessage);
        break;
      case 'complete':
        result = event.data;
        break;
      case 'error':
        if (event.data is Map<String, dynamic>) {
          throw Map<String, dynamic>.from(event.data as Map<String, dynamic>);
        }
        throw Exception(event.data?.toString() ?? 'Unknown error');
    }
  }

  return result;
}

Future<void> _maybeShowUnsetHoldQuickActionReminder(
  BuildContext context,
  WidgetRef ref, {
  required int additionalExpenseCount,
}) async {
  if (!context.mounted) return;
  if (additionalExpenseCount <= 0) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final quickAction = readAiHoldQuickActionPreference(prefs);
  if (quickAction != null) return;

  final userId = ref.read(authProvider).uid;
  if (userId.trim().isEmpty) return;
  final userKey = sha256.convert(utf8.encode(userId)).toString();

  final countKey = '${_holdQuickActionReminderExpenseCountKey}_$userKey';
  final shownKey = '${_holdQuickActionReminderShownKey}_$userKey';

  final updatedCount = (prefs.getInt(countKey) ?? 0) + additionalExpenseCount;
  await prefs.setInt(countKey, updatedCount);

  final alreadyShown = prefs.getBool(shownKey) ?? false;
  if (alreadyShown) return;
  if (updatedCount < _holdQuickActionReminderFirstPromptAt) return;
  if (!context.mounted) return;

  await MonekoAlertDialog.show(
    context: context,
    title: context.l10n.fasterLoggingTipTitle,
    description: context.l10n.fasterLoggingTipDescription,
    confirmLabel: context.l10n.gotIt,
    cancelLabel: null,
  );
  await prefs.setBool(shownKey, true);
}

Future<void> _processExpense(
  BuildContext context,
  WidgetRef ref, {
  String? text,
  String? imagePath,
  List<Map<String, dynamic>>? attachments,
  Uint8List? audioBytes,
  String? audioContentType,
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  final user = ref.read(authProvider);
  final preview = ref.read(previewModeProvider);
  final contact = ref.read(analyticsProvider).contact;
  final householdId = _resolveHouseholdIdForAi(ref);
  final scope = ref.read(householdScopeProvider);
  final isPortfolio = scope.activeAccountType == ActiveAccountType.portfolio;
  final effectiveUserId = preview.isActive
      ? (PreviewMockData.contact.userId ?? 'preview-user')
      : user.uid;

  // Determine if this is a potentially slow operation (PDF/file uploads)
  final hasAttachments = attachments?.isNotEmpty ?? false;
  final isPdfUpload = attachments?.any((a) =>
          a['contentType']?.toString().contains('pdf') == true ||
          a['filename']?.toString().toLowerCase().endsWith('.pdf') == true) ??
      false;
  final isLargeFile = attachments?.any((a) {
        final data = a['data']?.toString() ?? '';
        // Base64 data > 500KB (roughly 375KB raw)
        return data.length > 500000;
      }) ??
      false;

  final shouldStream = hasAttachments;
  final useEnhancedDialog = shouldStream || isPdfUpload || isLargeFile;

  // Show enhanced processing modal with timeout handling for PDFs
  BlockingProcessingController? dialogController;

  if (useEnhancedDialog) {
    dialogController = showEnhancedBlockingDialog(
      context: context,
      message: context.l10n.analyzingReceipt,
      subMessage: isPdfUpload
          ? 'Processing PDF document...'
          : hasAttachments
              ? 'Processing file...'
              : 'Processing large file...',
      showElapsedTime: true,
      enableCancelAfterSeconds: 0,
    );
  } else {
    showBlockingProcessingDialog(
      context: context,
      message: imagePath != null
          ? context.l10n.analyzingReceipt
          : context.l10n.analyzingExpense,
    );
  }

  try {
    final locale = Localizations.localeOf(context);
    final languageTag =
        locale.countryCode != null && locale.countryCode!.isNotEmpty
            ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
            : locale.languageCode;

    final today = effectiveToday(preferredTimezone: contact?.preferredTimezone);
    Map<String, dynamic>? responseData;

    if (preview.isActive) {
      responseData = {
        'success': true,
        'data': {
          'items': [
            {
              'description': 'Demo coffee at Cafe Bloom',
              'amount': 5.50,
              'currency': 'USD',
              'category': 'Dining',
              'date': formatDateOnlyYmd(today),
              'is_income': false,
            },
          ],
        },
      };
    }

    final Map<String, dynamic> body = {
      'userId': effectiveUserId,
      'date': formatDateOnlyYmd(today),
      'language': languageTag,
      'typeHint': 'mixed',
    };

    if (householdId != null && householdId.isNotEmpty) {
      body['householdId'] = householdId;
      body['isPortfolio'] = isPortfolio;
      if (!isPortfolio) {
        final memberContext = _buildHouseholdMemberContext(ref, householdId);
        if (memberContext.isNotEmpty) {
          body['householdMembers'] = memberContext;
        }
      }
    }

    // Always use selected currency as default (same as personal expense)
    // Backend will use this as a fallback if no currency is detected in the text/image.
    // If this is also missing, backend defaults to USD.
    final filterState = ref.read(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency;
    if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
      body['currency'] = selectedCurrency.toUpperCase();
    } else if (contact?.preferredCurrency != null) {
      body['currency'] = contact!.preferredCurrency!.toUpperCase();
    }

    // Add either text, image, audio, or file attachments to the request
    if (text != null) {
      body['text'] = text;
    } else if (imagePath != null) {
      // Read image bytes and convert to base64
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final extension = imagePath.split('.').last.toLowerCase();
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'heic') {
        contentType = 'image/heic';
      }

      body['image'] = {
        'data': base64Image,
        'contentType': contentType,
      };
    }

    if (attachments != null && attachments.isNotEmpty) {
      body['attachments'] = attachments;
    }

    if (audioBytes != null && audioBytes.isNotEmpty) {
      final base64Audio = base64Encode(audioBytes);
      body['audio'] = {
        'data': base64Audio,
        'contentType': audioContentType ?? 'audio/mpeg',
      };
    }

    // Update dialog for PDFs
    if (dialogController != null && isPdfUpload) {
      dialogController.updateSubMessage('Extracting transactions from PDF...');
    }

    // Check if user cancelled before making request
    if (dialogController?.isCancelled ?? false) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return;
    }

    // Use SSE streaming for file uploads to get real-time progress
    if (responseData == null && shouldStream && dialogController != null) {
      try {
        responseData = await _processWithSSE(
          body: body,
          dialogController: dialogController,
          onCancelCheck: () => dialogController?.isCancelled ?? false,
        );
      } catch (e) {
        _debugPrint('[SSE] Failed, falling back to regular request: $e');
        // Fall through to regular request
        responseData = null;
      }
    }

    // Regular request (fallback or non-PDF/small files)
    if (responseData == null) {
      // Update dialog for PDFs
      if (dialogController != null && isPdfUpload) {
        dialogController
            .updateSubMessage('Extracting transactions from PDF...');
      }

      // Explicitly pass JWT so the Edge Function can enrich household context
      // (householdMembers) under RLS. This is required for reliable split output.
      final session = supabase.auth.currentSession;
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
        headers: session != null
            ? <String, String>{
                'Authorization': 'Bearer ${session.accessToken}',
              }
            : null,
      );

      final parsedResponse = _asStringDynamicMap(response.data);
      if (parsedResponse != null) {
        responseData = parsedResponse;
      }
    }

    // Close processing modal
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) {
      return;
    }

    _debugPrint('Analysis response received');

    if (responseData != null && responseData['success'] == true) {
      final innerData = _asStringDynamicMap(responseData['data']);

      if (innerData != null && innerData['items'] is List) {
        List items = List.from(innerData['items'] as List);
        // Safety filter: drop total/subtotal rows when multiple items exist
        if (items.length > 1) {
          bool isTotalLike(dynamic it) {
            final desc = (it is Map && it['description'] is String)
                ? (it['description'] as String)
                : '';
            return RegExp(r'(sub\s*total|subtotal|grand\s*total|total)',
                    caseSensitive: false)
                .hasMatch(desc);
          }

          final filtered = items.where((it) => !isTotalLike(it)).toList();
          if (filtered.isNotEmpty) items = filtered;
        }

        if (items.isNotEmpty) {
          final analyticsContactId = ref.read(analyticsProvider).contact?.id;

          // Parse ALL items and immediately optimistic-log them.
          final parsed = items
              .map((rawItem) {
                final item = rawItem is Map
                    ? Map<String, dynamic>.from(rawItem)
                    : <String, dynamic>{};
                final rawDate = item['date']?.toString();
                final parsedDateOnly = tryParseDateOnlyYmd(rawDate);
                DateTime? accountingDate;
                if (parsedDateOnly != null) {
                  accountingDate = parsedDateOnly;
                } else {
                  final parsedInstant = DateTime.tryParse(rawDate ?? '');
                  if (parsedInstant != null) {
                    final effective = parsedInstant.isUtc
                        ? parsedInstant.toLocal()
                        : parsedInstant;
                    accountingDate = DateTime(
                        effective.year, effective.month, effective.day);
                  }
                }
                if (accountingDate == null) {
                  _debugPrint('Skipping AI item with invalid date');
                  return null;
                }
                final isIncome =
                    (item['type']?.toString().toLowerCase() == 'income');
                final amount = _parseAmountValue(item['amount']);
                final currency = item['currency']?.toString().trim();
                if (amount == null || currency == null || currency.isEmpty) {
                  _debugPrint('Skipping AI item with invalid amount/currency');
                  return null;
                }
                final transaction = ParsedExpense(
                  isIncome: isIncome,
                  amount: amount,
                  // Normalize income categories to at least 'income' umbrella if model returns a granular one
                  category: (item['category'] as String?)?.isNotEmpty == true
                      ? (isIncome
                          ? (item['category'] as String)
                          : item['category'] as String)
                      : (isIncome ? 'income' : 'other'),
                  currency: currency,
                  currencySymbol: item['currencySymbol'] as String? ?? '\$',
                  date: accountingDate,
                  description: item['description'] is String
                      ? sanitizeUtf16(item['description'] as String)
                      : null,
                  breakdown: item['breakdown'] is List
                      ? (item['breakdown'] as List)
                          .map((e) => sanitizeUtf16(e.toString()))
                          .toList()
                      : null,
                  localImagePath: imagePath,
                  payerUserId: (item['payerUserId'] is String)
                      ? (item['payerUserId'] as String)
                      : null,
                  payerHint: (item['payerHint'] is String)
                      ? (item['payerHint'] as String)
                      : (item['payerName'] is String)
                          ? (item['payerName'] as String)
                          : (item['paidBy'] is String)
                              ? (item['paidBy'] as String)
                              : (item['payerEmail'] is String)
                                  ? (item['payerEmail'] as String)
                                  : null,
                );

                final optimisticId = makeOptimisticTransactionId();
                final entry = buildOptimisticEntry(
                  transaction: transaction,
                  optimisticId: optimisticId,
                  userId: user.uid,
                  contactId: analyticsContactId,
                  householdId: householdId,
                  type: isIncome ? 'income' : 'expense',
                );
                addOptimisticTransaction(
                  ref: ref,
                  entry: entry,
                  householdId: householdId,
                );

                return _AiParsedItem(
                  transaction: transaction,
                  optimisticId: optimisticId,
                  raw: item,
                );
              })
              .whereType<_AiParsedItem>()
              .toList();

          if (parsed.isEmpty) {
            if (context.mounted) {
              AppToast.info(
                  context, context.l10n.noExpenseInformationExtracted);
            }
            return;
          }

          if (context.mounted) {
            AppToast.success(
              context,
              _formatAiLoggedToastMessage(
                context,
                ref,
                items: parsed,
              ),
            );
          }

          if (context.mounted && onSuccess != null) {
            onSuccess(
              AiLogSuccess(
                count: parsed.length,
                targetLabel: _resolveLogTargetLabel(context, ref),
                items: parsed
                    .map((entry) => entry.transaction)
                    .toList(growable: false),
              ),
            );
          }

          final expenseCount =
              parsed.where((entry) => !entry.transaction.isIncome).length;
          if (context.mounted && expenseCount > 0) {
            unawaited(_maybeShowUnsetHoldQuickActionReminder(
              context,
              ref,
              additionalExpenseCount: expenseCount,
            ));
          }

          if (!preview.isActive) {
            final container = ProviderScope.containerOf(context, listen: false);
            unawaited(
              _persistAiTransactions(
                container,
                userId: user.uid,
                householdId: householdId,
                isPortfolio: isPortfolio,
                transactions: parsed,
                localImagePath: imagePath,
              ),
            );
          }
        } else {
          if (context.mounted) {
            AppToast.info(context, context.l10n.noExpenseInformationExtracted);
          }
        }
      } else {
        if (context.mounted) {
          AppToast.info(context, context.l10n.failedToAnalyzeNoData);
        }
      }
    } else {
      final errorPayload = <String, dynamic>{
        'error': responseData?['error'],
        'message': responseData?['message'],
        'code': responseData?['code'],
        'status': responseData?['status'],
      };
      if (context.mounted) {
        AppToast.error(
          context,
          ErrorHandler.getUserFriendlyMessage(
            errorPayload,
            context: BackendErrorContext.analyzeExpense,
          ),
        );
      }
    }
  } catch (e) {
    _debugPrint('Error in analysis: $e');

    // Close processing modal
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

/// Determines if the unified transaction FAB should be visible for a given
/// view mode and household loading state.
bool shouldShowHomeFab(
  ViewModeState viewMode,
  AsyncValue<List<Household>> householdsAsync,
) {
  // Always show FAB in personal mode
  if (viewMode.mode == ViewMode.personal) {
    return true;
  }

  // In household mode, hide FAB if households are empty (showing onboarding)
  return householdsAsync.maybeWhen(
    data: (households) => households.isNotEmpty,
    orElse: () => true, // Show FAB during loading or error states
  );
}

class HomeAiExpandableFab extends ConsumerStatefulWidget {
  const HomeAiExpandableFab({super.key});

  @override
  ConsumerState<HomeAiExpandableFab> createState() =>
      _HomeAiExpandableFabState();
}

class _HomeAiExpandableFabState extends ConsumerState<HomeAiExpandableFab> {
  final AudioRecorder _holdRecorder = AudioRecorder();
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

  bool _isHoldRecording = false;
  bool _isHoldCancelled = false;
  bool _didCrossCancelThreshold = false;
  double _holdDragDeltaX = 0;
  DateTime? _holdRecordingStartedAt;
  double? _holdStartGlobalX;
  bool _isFabOpen = false;

  @override
  void dispose() {
    _holdRecorder.dispose();
    super.dispose();
  }

  Future<void> _playQuickActionDualNudge() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    HapticFeedback.lightImpact();
  }

  Future<void> _openManualEntrySheet() async {
    final contact = ref.read(analyticsProvider).contact;
    final filterState = ref.read(homeFilterProvider);
    final selectedCurrency =
        (filterState.selectedCurrency ?? contact?.preferredCurrency ?? 'USD')
            .trim()
            .toUpperCase();

    await showUnifiedTransactionSheet(
      context,
      contact: contact,
      newExpense: ParsedExpense(
        amount: 0,
        category: 'other',
        currency: selectedCurrency,
        currencySymbol: '\$',
        date: effectiveToday(preferredTimezone: contact?.preferredTimezone),
        description: null,
      ),
    );
  }

  Future<void> _runHoldAction() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final holdAction = readAiHoldQuickActionPreference(prefs);
    final selectedAction = holdAction ?? AiHoldQuickAction.textInputDrawer;

    switch (selectedAction) {
      case AiHoldQuickAction.camera:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiCameraCapture(context, ref);
        return;
      case AiHoldQuickAction.photoLibrary:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiLibraryCapture(context, ref);
        return;
      case AiHoldQuickAction.textInputDrawer:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiFreeFormText(context, ref);
        return;
      case AiHoldQuickAction.manualEntry:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await _openManualEntrySheet();
        return;
      case AiHoldQuickAction.recordAudio:
        await _startHoldRecording();
        return;
    }
  }

  Future<void> _startHoldRecording() async {
    if (_isHoldRecording) return;

    try {
      final hasPermission = await _holdRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          AppToast.info(
            context,
            context.l10n.microphonePermissionRequiredForQuickAudioLogging,
          );
        }
        return;
      }

      HapticFeedback.lightImpact();

      if (mounted) {
        setState(() {
          _isHoldRecording = true;
          _isHoldCancelled = false;
          _didCrossCancelThreshold = false;
          _holdDragDeltaX = 0;
          _holdRecordingStartedAt = DateTime.now();
        });
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/moneko_hold_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _holdRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _isHoldRecording = false;
          _isHoldCancelled = false;
          _didCrossCancelThreshold = false;
          _holdDragDeltaX = 0;
        });
        AppToast.error(
          context,
          context.l10n.unableToStartRecording(
            ErrorHandler.getUserFriendlyMessage(
              error,
              context: BackendErrorContext.recording,
            ),
          ),
        );
      }
    }
  }

  void _applyHoldDragDelta(double deltaX) {
    if (!_isHoldRecording) return;

    final shouldCancel = deltaX.abs() >= _recordCancelDragThreshold;
    final crossedIntoCancelArea = shouldCancel && !_didCrossCancelThreshold;
    final movedOutOfCancelArea = !shouldCancel && _didCrossCancelThreshold;

    if (crossedIntoCancelArea) {
      HapticFeedback.mediumImpact();
    }

    if (!mounted) return;
    setState(() {
      _holdDragDeltaX = deltaX;
      _isHoldCancelled = shouldCancel;
      if (crossedIntoCancelArea) {
        _didCrossCancelThreshold = true;
      } else if (movedOutOfCancelArea) {
        _didCrossCancelThreshold = false;
      }
    });
  }

  void _updateHoldRecordingDrag(LongPressMoveUpdateDetails details) {
    _applyHoldDragDelta(details.offsetFromOrigin.dx);
  }

  void _onHoldPointerMove(PointerMoveEvent event) {
    final startX = _holdStartGlobalX;
    if (startX == null || !_isHoldRecording) {
      return;
    }
    _applyHoldDragDelta(event.position.dx - startX);
  }

  Future<void> _finishHoldRecording() async {
    if (!_isHoldRecording) return;

    final wasCancelled = _isHoldCancelled;
    final startedAt = _holdRecordingStartedAt;

    if (mounted) {
      setState(() {
        _isHoldRecording = false;
        _isHoldCancelled = false;
        _didCrossCancelThreshold = false;
        _holdDragDeltaX = 0;
        _holdStartGlobalX = null;
      });
    }

    File? audioFile;
    try {
      final path = await _holdRecorder.stop();
      if (path == null) return;
      audioFile = File(path);

      if (wasCancelled) {
        HapticFeedback.selectionClick();
        return;
      }

      if (startedAt != null &&
          DateTime.now().difference(startedAt).inMilliseconds <
              _minimumHoldRecordingMs) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingTooShort);
        }
        return;
      }

      if (!await audioFile.exists()) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingFileMissing);
        }
        return;
      }

      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingIsEmpty);
        }
        return;
      }

      HapticFeedback.lightImpact();
      if (!mounted) return;
      await handleAiAudioBytes(
        context,
        ref,
        audioBytes: bytes,
        contentType: 'audio/aac',
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.unableToProcessRecording(
            ErrorHandler.getUserFriendlyMessage(
              error,
              context: BackendErrorContext.recording,
            ),
          ),
        );
      }
    } finally {
      if (audioFile != null) {
        try {
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Widget _buildContextPill(ColorScheme colorScheme) {
    final householdId = _resolveHouseholdIdForAi(ref);
    final targetLabel = _resolveLogTargetLabel(context, ref);

    final contact = ref.watch(analyticsProvider).contact;
    final filterState = ref.watch(homeFilterProvider);
    final selectedCurrency =
        (filterState.selectedCurrency ?? contact?.preferredCurrency ?? 'USD')
            .trim()
            .toUpperCase();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastLinearToSlowEaseIn,
      bottom: 12,
      right: _isFabOpen ? 72 : 24,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _isFabOpen ? 1.0 : 0.0,
        curve: Curves.easeOut,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: _isFabOpen ? 1.0 : 0.9,
          curve: Curves.fastLinearToSlowEaseIn,
          alignment: Alignment.centerRight,
          child: IgnorePointer(
            ignoring: !_isFabOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.7),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        householdId == null
                            ? Icons.person_outline
                            : Icons.people_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$targetLabel • $selectedCurrency',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoldRecordingIndicator(ColorScheme colorScheme) {
    final dragProgress = (_holdDragDeltaX.abs() / _recordCancelDragThreshold)
        .clamp(0.0, 1.0)
        .toDouble();
    final indicatorBackground = _isHoldCancelled
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHigh;

    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 120),
        offset: _isHoldRecording ? Offset.zero : const Offset(0.25, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isHoldRecording ? 1 : 0,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: indicatorBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHoldCancelled
                    ? colorScheme.error
                    : colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isHoldRecording
                      ? _FabAudioWave(colorScheme: colorScheme)
                      : _FabAudioWavePlaceholder(colorScheme: colorScheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isHoldCancelled
                        ? context.l10n.releaseToCancel
                        : context.l10n.slideRightToCancel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isHoldCancelled
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  duration: const Duration(milliseconds: 110),
                  scale: _isHoldCancelled ? 1.14 : 1.0,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 110),
                    turns: _isHoldCancelled ? 0.03 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      transform: Matrix4.translationValues(
                        (_holdDragDeltaX.sign * (dragProgress * 8)),
                        0,
                        0,
                      ),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.error.withValues(
                          alpha: 0.08 + (dragProgress * 0.22),
                        ),
                        border: Border.all(
                          color: colorScheme.error.withValues(
                            alpha: 0.15 + (dragProgress * 0.55),
                          ),
                        ),
                        boxShadow: _isHoldCancelled
                            ? [
                                BoxShadow(
                                  color:
                                      colorScheme.error.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: colorScheme.error.withValues(
                          alpha: 0.45 + (dragProgress * 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        _buildContextPill(colorScheme),
        ExpandableFab(
          key: _fabKey,
          distance: 120,
          onToggle: (isOpen) {
            if (mounted) {
              setState(() {
                _isFabOpen = isOpen;
              });
            }
          },
          openButtonBuilder: (context, defaultButton) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerMove: _onHoldPointerMove,
              onPointerUp: (_) {
                if (_isHoldRecording) {
                  unawaited(_finishHoldRecording());
                }
              },
              onPointerCancel: (_) {
                if (_isHoldRecording) {
                  unawaited(_finishHoldRecording());
                }
              },
              child: RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 280),
                    ),
                    (instance) {
                      instance
                        ..onLongPressStart = (details) async {
                          _holdStartGlobalX = details.globalPosition.dx;
                          await _runHoldAction();
                        }
                        ..onLongPressMoveUpdate = _updateHoldRecordingDrag
                        ..onLongPressEnd = (_) async {
                          await _finishHoldRecording();
                        }
                        ..onLongPressUp = () async {
                          await _finishHoldRecording();
                        };
                    },
                  ),
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: _isHoldRecording ? 1.08 : 1.0,
                      child: defaultButton,
                    ),
                    Positioned(
                      right: 66,
                      child: _buildHoldRecordingIndicator(colorScheme),
                    ),
                  ],
                ),
              ),
            );
          },
          children: [
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiFreeFormText(context, ref);
              },
              icon: Image.asset(
                'lib/assets/images/audio-message.png',
                width: 25,
                height: 25,
              ),
              label: context.l10n.textAudio,
            ),
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiCameraCapture(context, ref);
              },
              icon: const Icon(Icons.camera_alt),
              label: context.l10n.takePhoto,
            ),
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiFileOrGallery(context, ref);
              },
              icon: const Icon(Icons.attach_file),
              label: context.l10n.files,
            ),
          ],
        ),
      ],
    );
  }
}

class _FabAudioWave extends StatefulWidget {
  const _FabAudioWave({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  State<_FabAudioWave> createState() => _FabAudioWaveState();
}

class _FabAudioWaveState extends State<_FabAudioWave> {
  late final List<double> _bars;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bars = List<double>.filled(10, 0.25);
    _timer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _bars.length; i++) {
          final phase = DateTime.now().millisecondsSinceEpoch / 150 + i;
          final value = 0.15 + (sin(phase).abs() * 0.85);
          _bars[i] = value.clamp(0.12, 1.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(_bars.length, (index) {
          final barHeight = 4 + (_bars[index] * 13);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            width: 2.4,
            height: barHeight,
            decoration: BoxDecoration(
              color: widget.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class _FabAudioWavePlaceholder extends StatelessWidget {
  const _FabAudioWavePlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(10, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            width: 2.4,
            height: 7,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

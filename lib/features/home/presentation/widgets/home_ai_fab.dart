import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
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
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

/// Shared helpers and widgets for the unified transaction FAB / AI expense capture.

const int _reviewFirstPromptAt = 1;
const int _reviewSecondInterval = 2;
const int _reviewThirdInterval = 3;
const int _reviewMaxInterval = 5;
const String _reviewExpenseCountKey = 'review_expense_count';
const String _reviewLastPromptKey = 'review_last_prompt_count';
const String _reviewLastIntervalKey = 'review_last_prompt_interval';
const int _maxBatchSize = 400;

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
  String? preferredTimezone,
  String? localImagePath,
}) async {
  if (transactions.isEmpty) return;

  final timezoneOffsetMinutes =
      resolveUserTimezoneOffsetMinutes(preferredTimezone);
  final userNow = userNowFromOffsetMinutes(timezoneOffsetMinutes);
  final clientCreatedAtIso = utcInstantForUserLocalDateTime(
    localDateTime: userNow,
    offsetMinutes: timezoneOffsetMinutes,
  ).toIso8601String();

  String? normalizeBucketId(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
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

      final responseData = response.data as Map<String, dynamic>;
      final results = responseData['results'] as List?;
      final summary = responseData['summary'] as Map<String, dynamic>?;

      _debugPrint(
          '[AI Batch Save] Result: ${summary?['succeeded'] ?? 0} succeeded, ${summary?['failed'] ?? 0} failed');

      if (results != null && results.isNotEmpty) {
        // Map results back to optimistic entries by index
        for (final resultItem in results) {
          final result = resultItem as Map<String, dynamic>;
          final index = result['index'] as int;
          final success = result['success'] as bool;
          final data = result['data'] as Map<String, dynamic>?;

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
                '❌ Failed to persist transaction at index $originalIndex: ${result['error']}');
          }
        }
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
          final endpoint = isIncome ? 'save-income' : 'save-expense';

          final requestBody = <String, dynamic>{
            'userId': userId,
            'amount': tx.amount,
            'category': tx.category,
            'currency': tx.currency,
            'date': formatDateOnlyYmd(tx.date),
            'clientCreatedAt': clientCreatedAtIso,
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
            if (safeCustomSplits != null)
              requestBody['customSplits'] = safeCustomSplits;
          }

          final response =
              await supabase.functions.invoke(endpoint, body: requestBody);

          if (response.data != null) {
            final savedEntry =
                ExpenseEntry.fromJson(response.data as Map<String, dynamic>);
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
            // Remove failed optimistic entry
            removeOptimisticTransactionWithContainer(
              container: container,
              optimisticId: item.optimisticId,
              householdId: householdId,
            );
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
        '${context.l10n.failedToCapturePhoto}: ${e.toString()}',
      );
    }
  }
}

Future<void> handleAiFreeFormText(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  final controller = TextEditingController();

  showTextInputDrawer(
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
        '${context.l10n.failedToAnalyze}: ${e.toString()}',
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
          try {
            final XFile? image = await pickImageWithGuard(
              picker: _imagePicker,
              source: ImageSource.gallery,
              imageQuality: 85,
            );

            if (image != null) {
              if (context.mounted) {
                await _processExpense(
                  context,
                  ref,
                  imagePath: image.path,
                  onSuccess: onSuccess,
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              AppToast.error(
                context,
                '${context.l10n.failedToCapturePhoto}: ${e.toString()}',
              );
            }
          }
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
        final errorMsg = event.data['error']?.toString() ?? 'Unknown error';
        throw Exception(errorMsg);
    }
  }

  return result;
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
  final contact = ref.read(analyticsProvider).contact;
  final householdId = _resolveHouseholdIdForAi(ref);
  final scope = ref.read(householdScopeProvider);
  final isPortfolio = scope.activeAccountType == ActiveAccountType.portfolio;

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
      enableCancelAfterSeconds: 45,
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

    final Map<String, dynamic> body = {
      'userId': user.uid,
      'date': formatDateOnlyYmd(
        userNowFromOffsetMinutes(
          resolveUserTimezoneOffsetMinutes(contact?.preferredTimezone),
        ),
      ),
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

    Map<String, dynamic>? responseData;

    // Use SSE streaming for file uploads to get real-time progress
    if (shouldStream && dialogController != null) {
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

      if (response.data != null) {
        responseData = response.data as Map<String, dynamic>;
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
      final innerData = responseData['data'];

      if (innerData != null && innerData['items'] != null) {
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
          // Additional check: if any item equals sum of others, drop it
          double amt(dynamic it) {
            final a = (it is Map && it['amount'] != null)
                ? (it['amount'] as num).toDouble()
                : 0.0;
            return a;
          }

          items = items.where((it) {
            final others = items.where((x) => !identical(x, it)).toList();
            final sumOthers = others.fold<double>(0.0, (s, x) => s + amt(x));
            return (amt(it) - sumOthers).abs() > 1e-6;
          }).toList();
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
                    final effective = toEffectiveWallTime(
                      utcOrLocalInstant: parsedInstant,
                      preferredTimezone: contact?.preferredTimezone,
                    );
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
                final transaction = ParsedExpense(
                  isIncome: isIncome,
                  amount: (item['amount'] as num).toDouble(),
                  // Normalize income categories to at least 'income' umbrella if model returns a granular one
                  category: (item['category'] as String?)?.isNotEmpty == true
                      ? (isIncome
                          ? (item['category'] as String)
                          : item['category'] as String)
                      : (isIncome ? 'income' : 'other'),
                  currency: item['currency'] as String,
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

          final container = ProviderScope.containerOf(context, listen: false);
          unawaited(
            _persistAiTransactions(
              container,
              userId: user.uid,
              householdId: householdId,
              isPortfolio: isPortfolio,
              transactions: parsed,
              preferredTimezone: contact?.preferredTimezone,
              localImagePath: imagePath,
            ),
          );
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
      String error;
      if (context.mounted) {
        error =
            responseData?['error']?.toString() ?? context.l10n.failedToAnalyze;
      } else {
        error = responseData?['error']?.toString() ?? 'Failed to analyze';
      }
      if (context.mounted) {
        AppToast.error(context, '${context.l10n.failedToAnalyze}: $error');
      }
    }
  } catch (e) {
    _debugPrint('Error in analysis: $e');

    // Close processing modal
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    String errorMessage;
    final errorString = e.toString().toLowerCase();

    // Check for gateway timeout errors (502, 504)
    if (errorString.contains('502') ||
        errorString.contains('504') ||
        errorString.contains('bad gateway') ||
        errorString.contains('gateway timeout') ||
        errorString.contains('timeout')) {
      errorMessage = context.mounted
          ? 'Request timed out. Try with a smaller file or fewer pages.'
          : 'Request timed out';
    } else if (e.runtimeType.toString().contains('Exception') &&
        e.toString().contains('status: 400') &&
        e.toString().contains('details:')) {
      // Parse the error from the exception string representation
      final detailsMatch =
          RegExp(r'details: \{([^}]+)\}').firstMatch(e.toString());
      if (detailsMatch != null) {
        final detailsStr = detailsMatch.group(1) ?? '';
        final errorMatch = RegExp(r'error: ([^,]+)').firstMatch(detailsStr);
        if (errorMatch != null) {
          errorMessage = errorMatch.group(1)?.replaceAll("'", '').trim() ??
              (context.mounted
                  ? context.l10n.failedToAnalyze
                  : 'Failed to analyze');
        } else {
          errorMessage = context.mounted
              ? context.l10n.failedToAnalyze
              : 'Failed to analyze';
        }
      } else {
        errorMessage = context.mounted
            ? context.l10n.failedToAnalyze
            : 'Failed to analyze';
      }
    } else {
      errorMessage = e.toString();
    }

    if (context.mounted) {
      AppToast.error(context, '${context.l10n.failedToAnalyze}: $errorMessage');
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

class HomeAiExpandableFab extends ConsumerWidget {
  const HomeAiExpandableFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fabKey = GlobalKey<ExpandableFabState>();

    return ExpandableFab(
      key: fabKey,
      distance: 120,
      children: [
        ActionButton(
          onPressed: () async {
            fabKey.currentState?.close();
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
            fabKey.currentState?.close();
            await handleAiCameraCapture(context, ref);
          },
          icon: const Icon(Icons.camera_alt),
          label: context.l10n.takePhoto,
        ),
        ActionButton(
          onPressed: () async {
            fabKey.currentState?.close();
            await handleAiFileOrGallery(context, ref);
          },
          icon: const Icon(Icons.attach_file),
          label: context.l10n.files,
        ),
      ],
    );
  }
}

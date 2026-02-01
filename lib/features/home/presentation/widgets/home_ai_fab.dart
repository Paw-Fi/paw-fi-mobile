import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
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

final ImagePicker _imagePicker = ImagePicker();

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
    debugPrint('[REVIEW] Failed to request review: $error');
  }
}

Future<void> _persistAiTransactions(
  WidgetRef ref, {
  required String userId,
  required String? householdId,
  required bool isPortfolio,
  required List<_AiParsedItem> transactions,
  String? localImagePath,
}) async {
  if (transactions.isEmpty) return;

  String? normalizeBucketId(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void upsertSavedEntry({
    required String optimisticId,
    required ExpenseEntry savedEntry,
  }) {
    final fromBucket = normalizeBucketId(householdId);
    final toBucket = normalizeBucketId(savedEntry.householdId);

    if (fromBucket == toBucket) {
      replaceOptimisticTransaction(
        ref: ref,
        optimisticId: optimisticId,
        savedEntry: savedEntry,
        householdId: fromBucket,
      );
      return;
    }

    removeOptimisticTransaction(
      ref: ref,
      optimisticId: optimisticId,
      householdId: fromBucket,
    );
    addOptimisticTransaction(
      ref: ref,
      entry: savedEntry,
      householdId: toBucket,
    );
  }

  // Upload receipt image first (if any) - shared across all transactions
  String? receiptUrl;
  if (localImagePath != null && localImagePath.isNotEmpty) {
    receiptUrl = await ref
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
      'date': tx.date.toIso8601String().split('T')[0],
      'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
      if (tx.description?.isNotEmpty == true) 'description': tx.description,
      if (receiptUrl != null && !isIncome) 'receiptImageUrl': receiptUrl,
      // Expense-specific fields
      if (!isIncome && payerUserId != null) 'payerUserId': payerUserId,
      if (!isIncome && safeCustomSplits != null)
        'customSplits': safeCustomSplits,
      // Income-specific fields (ownerType, privacyScope use defaults on backend)
    };
  }).toList(growable: false);

  try {
    debugPrint(
        '[AI Batch Save] Saving ${batchTransactions.length} transactions in single request');

    final response = await supabase.functions.invoke(
      'save-transactions-batch',
      body: {
        'userId': userId,
        if (householdId != null && householdId.isNotEmpty)
          'householdId': householdId,
        if (householdId != null && householdId.isNotEmpty)
          'isPortfolio': isPortfolio,
        'transactions': batchTransactions,
      },
    );

    if (response.data == null) {
      throw Exception('No response from save-transactions-batch');
    }

    final responseData = response.data as Map<String, dynamic>;
    final results = responseData['results'] as List?;
    final summary = responseData['summary'] as Map<String, dynamic>?;

    debugPrint(
        '[AI Batch Save] Result: ${summary?['succeeded'] ?? 0} succeeded, ${summary?['failed'] ?? 0} failed');

    var didPersistAny = false;
    var savedExpenseCount = 0;

    if (results != null && results.isNotEmpty) {
      // Map results back to optimistic entries by index
      for (final resultItem in results) {
        final result = resultItem as Map<String, dynamic>;
        final index = result['index'] as int;
        final success = result['success'] as bool;
        final data = result['data'] as Map<String, dynamic>?;

        if (index < 0 || index >= transactions.length) continue;

        final originalItem = transactions[index];

        if (success && data != null) {
          final savedEntry = ExpenseEntry.fromJson(data);
          upsertSavedEntry(
            optimisticId: originalItem.optimisticId,
            savedEntry: savedEntry,
          );
          didPersistAny = true;
          if (!originalItem.transaction.isIncome) {
            savedExpenseCount += 1;
          }
        } else {
          // Remove failed optimistic entry
          removeOptimisticTransaction(
            ref: ref,
            optimisticId: originalItem.optimisticId,
            householdId: householdId,
          );
          debugPrint(
              '❌ Failed to persist transaction at index $index: ${result['error']}');
        }
      }
    }

    if (didPersistAny) {
      await ref.read(expenseSaveNotifierProvider.notifier).invalidateAfterBatch(
            userId: userId,
            householdId: householdId,
          );
    }

    if (savedExpenseCount > 0) {
      final prefs = ref.read(sharedPreferencesProvider);
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
    debugPrint('❌ Batch save failed: $error');

    // On batch failure, remove all optimistic entries
    for (final item in transactions) {
      removeOptimisticTransaction(
        ref: ref,
        optimisticId: item.optimisticId,
        householdId: householdId,
      );
    }

    // Rethrow to allow caller to handle if needed
    rethrow;
  }
}

Future<void> handleAiCameraCapture(BuildContext context, WidgetRef ref) async {
  debugPrint('🎥 Starting camera capture...');

  try {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    debugPrint('🎥 Photo captured: ${photo != null}');

    if (photo != null) {
      if (context.mounted) {
        await _processExpense(context, ref, imagePath: photo.path);
      }
    } else {
      debugPrint('🎥 User cancelled or permission denied');
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

Future<void> handleAiFreeFormText(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();

  showTextInputDrawer(
    context,
    controller,
    (text) async {
      await _processExpense(context, ref, text: text);
    },
    onSubmitAudio: (audioBytes, contentType) async {
      await _processExpense(
        context,
        ref,
        audioBytes: audioBytes,
        audioContentType: contentType,
      );
    },
  );
}

Future<void> handleAiFileUpload(
  BuildContext context,
  WidgetRef ref,
) async {
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
  WidgetRef ref,
) async {
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.l10n.appTitle,
    message: context.l10n.chooseSourceForAnalysis,
    actions: [
      AlertAction(
        title: context.l10n.files,
        style: AlertActionStyle.primary,
        onPressed: () async {
          await handleAiFileUpload(context, ref);
        },
      ),
      AlertAction(
        title: context.l10n.gallery,
        style: AlertActionStyle.primary,
        onPressed: () async {
          try {
            final XFile? image = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );

            if (image != null) {
              if (context.mounted) {
                await _processExpense(context, ref, imagePath: image.path);
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

  debugPrint('[SSE] Starting streaming request to $sseUrl');

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
      debugPrint('[SSE] Cancelled by user');
      throw Exception('Cancelled');
    }

    debugPrint('[SSE] Received event: ${event.event} - ${event.data}');

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
}) async {
  final user = ref.read(authProvider);
  final contact = ref.read(analyticsProvider).contact;
  final householdId = _resolveHouseholdIdForAi(ref);
  final scope = ref.read(householdScopeProvider);
  final isPortfolio = scope.activeAccountType == ActiveAccountType.portfolio;

  // Determine if this is a potentially slow operation (PDF/file uploads)
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

  // Show enhanced processing modal with timeout handling for PDFs
  BlockingProcessingController? dialogController;
  bool wasCancelled = false;

  if (isPdfUpload || isLargeFile) {
    dialogController = showEnhancedBlockingDialog(
      context: context,
      message: context.l10n.analyzingReceipt,
      subMessage: isPdfUpload
          ? 'Processing PDF document...'
          : 'Processing large file...',
      showElapsedTime: true,
      enableCancelAfterSeconds: 45,
      onCancel: () {
        wasCancelled = true;
      },
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
      'date': DateTime.now().toIso8601String().split('T')[0],
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
    if (wasCancelled || (dialogController?.isCancelled ?? false)) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return;
    }

    Map<String, dynamic>? responseData;

    // Use SSE streaming for PDF/large files to get real-time progress
    if ((isPdfUpload || isLargeFile) && dialogController != null) {
      try {
        responseData = await _processWithSSE(
          body: body,
          dialogController: dialogController,
          onCancelCheck: () =>
              wasCancelled || (dialogController?.isCancelled ?? false),
        );
      } catch (e) {
        debugPrint('[SSE] Failed, falling back to regular request: $e');
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

      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
      );

      if (response.data != null) {
        responseData = response.data as Map<String, dynamic>;
      }
    }

    // Close processing modal
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    debugPrint('=== ANALYSIS RESPONSE ===');
    debugPrint('response data: $responseData');
    debugPrint('========================');

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
          final parsed = items.map((rawItem) {
            final item = rawItem is Map
                ? Map<String, dynamic>.from(rawItem)
                : <String, dynamic>{};
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
              date: DateTime.parse(item['date'] as String),
              description: item['description'] as String?,
              localImagePath: imagePath,
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
          }).toList();

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

          unawaited(
            _persistAiTransactions(
              ref,
              userId: user.uid,
              householdId: householdId,
              isPortfolio: isPortfolio,
              transactions: parsed,
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
    debugPrint('=== ERROR IN ANALYSIS: $e ===');

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

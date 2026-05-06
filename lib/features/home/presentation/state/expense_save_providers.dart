// State providers for expense save flow

import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    as split_entities;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/core/utils/image_compressor.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';
import 'package:moneko/features/transactions/presentation/state/transaction_capture_controller.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

String? receiptStoragePathFromPublicUrl(String? publicUrl) {
  if (publicUrl == null || publicUrl.trim().isEmpty) return null;

  final uri = Uri.tryParse(publicUrl.trim());
  if (uri == null) return null;

  final segments = uri.pathSegments;
  final bucketIndex = segments.indexOf('expense-receipts');
  if (bucketIndex == -1 || bucketIndex == segments.length - 1) return null;

  final objectPath = segments.skip(bucketIndex + 1).join('/');
  if (!objectPath.startsWith('receipts/')) return null;

  return objectPath;
}

// ============================================================================
// PENDING EXPENSE PROVIDER
// ============================================================================

/// Holds the parsed expense before user confirms and saves
final pendingExpenseProvider = StateProvider<ParsedExpense?>((ref) => null);

// ============================================================================
// SELECTED HOUSEHOLD FOR SHARING
// ============================================================================

/// Tracks which household to share expense with (null = personal only)
final selectedHouseholdForSharingProvider =
    StateProvider<String?>((ref) => null);

// ============================================================================
// EXPENSE SAVE NOTIFIER
// ============================================================================

/// Handles saving confirmed expense to database
class ExpenseSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ExpenseSaveNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Save expense to database
  /// If householdId provided, creates household split
  /// If customSplits provided, uses custom split configuration
  Future<void> saveExpense({
    required ParsedExpense expense,
    String? householdId,
    String? accountId,
    String? receiptImageUrl,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    bool invalidateProviders = true,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(authProvider);

      _debugPrint('💾 Saving expense request');
      if (householdId != null) {
        _debugPrint('👥 Sharing with household: $householdId');
        if (customSplitType != null && customSplits != null) {
          _debugPrint('📊 Custom split configuration provided');
        }
      }

      final accountingDate = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      final normalizedHouseholdId = _normalizeOptionalId(householdId);
      final normalizedAccountId = _normalizeOptionalId(accountId);
      final isPortfolio = normalizedHouseholdId != null &&
          ref.read(householdScopeProvider).isPortfolioId(normalizedHouseholdId);
      final syncableCategory = _syncableCategory(expense.category);
      final syncableExpense = syncableCategory == expense.category
          ? expense
          : expense.copyWith(category: syncableCategory);

      final transactionId = await ref
          .read(transactionCaptureControllerProvider.notifier)
          .createLocalTransaction(
            CreateTransactionCommand(
              userId: user.uid,
              householdId: normalizedHouseholdId,
              walletId: normalizedAccountId,
              type: TransactionCommandType.expense,
              amountCents: syncableExpense.amountCents.abs(),
              currency: syncableExpense.currency,
              category: syncableExpense.category,
              merchant: syncableExpense.merchant,
              rawText: syncableExpense.description,
              description: syncableExpense.description,
              date: accountingDate,
              captureSource: receiptImageUrl == null
                  ? TransactionCaptureSource.manual
                  : TransactionCaptureSource.receiptPhoto,
              reviewReasons: const [],
              receiptLocalPath: syncableExpense.localImagePath,
              payerUserId: payerUserId,
              isPortfolio: isPortfolio,
            ),
          );

      final createdAt = DateTime.now();
      final entry = _buildOptimisticExpenseEntry(
        expense: syncableExpense,
        expenseId: transactionId,
        householdId: normalizedHouseholdId,
        userId: user.uid,
        receiptImageUrl: receiptImageUrl,
        createdAt: createdAt,
        accountId: normalizedAccountId,
      );

      ref.read(analyticsProvider.notifier).addOptimisticTransaction(entry);
      _addLocalFirstHouseholdData(
        entry: entry,
        expense: syncableExpense,
        householdId: normalizedHouseholdId,
        payerUserId: payerUserId ?? user.uid,
        customSplitType: customSplitType,
        customSplits: customSplits,
      );

      if (invalidateProviders) {
        _notifyLocalFirstMutation(normalizedHouseholdId);
      }

      state = const AsyncValue.data(null);
      unawaited(
        ref
            .read(syncQueueControllerProvider.notifier)
            .syncNow(SyncTrigger.manual),
      );
    } catch (error, stackTrace) {
      _debugPrint('❌ Error saving expense: $error');
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  String? _normalizeOptionalId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _syncableCategory(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'uncategorized' : trimmed;
  }

  void _notifyLocalFirstMutation(String? householdId) {
    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    ref.invalidate(pocketsProvider);
    ref.invalidate(currencyTransactionCountsProvider);

    if (householdId == null) return;
    ref.read(cacheInvalidatorProvider).invalidateHouseholdData(householdId);
  }

  void _addLocalFirstHouseholdData({
    required ExpenseEntry entry,
    required ParsedExpense expense,
    required String? householdId,
    required String payerUserId,
    required SplitType? customSplitType,
    required List<MemberSplit>? customSplits,
  }) {
    if (householdId == null || householdId.isEmpty) return;

    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(householdId, entry);

    final splitGroupId = 'local_split_${entry.id}';
    final members = ref.read(householdMembersProvider(householdId)).valueOrNull;
    final splitGroup = _buildOptimisticSplitGroup(
      householdId: householdId,
      expenseId: entry.id,
      splitGroupId: splitGroupId,
      payerUserId: payerUserId,
      expense: expense,
      customSplitType: customSplitType,
      customSplits: customSplits,
      members: members,
    );
    if (splitGroup == null) return;

    final updatedEntry = entry.copyWith(splitGroupId: splitGroup.id);
    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .replaceExpense(householdId, entry.id, updatedEntry);
    ref
        .read(householdOptimisticSplitsProvider.notifier)
        .addSplitGroup(householdId, splitGroup);
  }

  ExpenseEntry _buildOptimisticExpenseEntry({
    required ParsedExpense expense,
    required String expenseId,
    required String? householdId,
    required String userId,
    required String? receiptImageUrl,
    required DateTime createdAt,
    String? splitGroupId,
    String? accountId,
  }) {
    return ExpenseEntry(
      id: expenseId,
      userId: userId,
      householdId: householdId,
      date: expense.date,
      amountCents: expense.amountCents.abs(),
      currency: expense.currency,
      category: expense.category,
      createdAt: createdAt,
      rawText: expense.description,
      merchant: expense.merchant,
      breakdown: expense.breakdown,
      receiptImageUrl: receiptImageUrl,
      splitGroupId: splitGroupId,
      walletId: accountId,
      type: 'expense',
    );
  }

  split_entities.ExpenseSplitGroup? _buildOptimisticSplitGroup({
    required String householdId,
    required String expenseId,
    required String splitGroupId,
    required String payerUserId,
    required ParsedExpense expense,
    required SplitType? customSplitType,
    required List<MemberSplit>? customSplits,
    required List<HouseholdMember>? members,
  }) {
    final totalCents = expense.amountCents.abs();
    if (totalCents <= 0) return null;

    final splitType = customSplitType ?? SplitType.equal;
    final resolvedSplits = (customSplits != null && customSplits.isNotEmpty)
        ? customSplits
        : (members != null && members.isNotEmpty)
            ? buildDefaultMemberSplits(
                members: members,
                totalAmount: expense.amount,
              )
            : const <MemberSplit>[];

    if (resolvedSplits.isEmpty) return null;

    final included = _includedSplits(splitType, resolvedSplits);
    if (included.isEmpty) return null;

    final cents = switch (splitType) {
      SplitType.equal => _allocateEqualCents(totalCents, included.length),
      SplitType.amount => _allocateAmountCents(totalCents, included),
      SplitType.percentage => _allocateWeightedCents(
          totalCents,
          included.map((s) => s.percentage ?? 0).toList(),
        ),
      SplitType.shares => _allocateWeightedCents(
          totalCents,
          included.map((s) => s.shares ?? 0).toList(),
        ),
    };

    final now = DateTime.now();
    final lines = <split_entities.ExpenseSplitLine>[];

    for (var i = 0; i < included.length; i++) {
      final split = included[i];
      final member = split.member;
      lines.add(
        split_entities.ExpenseSplitLine(
          id: 'optimistic_line_${expenseId}_${member.userId}',
          splitGroupId: splitGroupId,
          userId: member.userId,
          amountCents: cents[i],
          percentage:
              splitType == SplitType.percentage ? split.percentage : null,
          shares: splitType == SplitType.shares ? split.shares : null,
          isSettled: false,
          createdAt: now,
          updatedAt: now,
          userEmail: member.userEmail,
          userName: member.userName,
        ),
      );
    }

    return split_entities.ExpenseSplitGroup(
      id: splitGroupId,
      householdId: householdId,
      expenseId: expenseId,
      payerUserId: payerUserId,
      splitType: _mapSplitType(splitType),
      currency: expense.currency,
      totalAmountCents: totalCents,
      description: expense.description,
      createdAt: now,
      updatedAt: now,
      splitLines: lines,
    );
  }

  List<MemberSplit> _includedSplits(
    SplitType splitType,
    List<MemberSplit> splits,
  ) {
    return switch (splitType) {
      SplitType.amount => splits.where((s) => s.includedInAmount).toList(),
      SplitType.percentage =>
        splits.where((s) => s.includedInPercentage).toList(),
      SplitType.shares => splits.where((s) => (s.shares ?? 0) > 0).toList(),
      SplitType.equal => splits,
    };
  }

  split_entities.SplitType _mapSplitType(SplitType splitType) {
    return switch (splitType) {
      SplitType.equal => split_entities.SplitType.equal,
      SplitType.amount => split_entities.SplitType.amount,
      SplitType.percentage => split_entities.SplitType.percentage,
      SplitType.shares => split_entities.SplitType.shares,
    };
  }

  List<int> _allocateEqualCents(int totalCents, int count) {
    if (count <= 0) return const <int>[];
    final perMember = totalCents ~/ count;
    final remainder = totalCents - (perMember * count);
    return List<int>.generate(
      count,
      (index) => perMember + (index == 0 ? remainder : 0),
    );
  }

  List<int> _allocateAmountCents(int totalCents, List<MemberSplit> splits) {
    if (splits.isEmpty) return const <int>[];
    final cents = splits
        .map((split) => (split.amount ?? 0) * 100)
        .map((value) => value.round())
        .map((value) => value < 0 ? 0 : value)
        .toList();

    final sum = cents.fold<int>(0, (sum, value) => sum + value);
    final diff = totalCents - sum;
    if (diff != 0 && cents.isNotEmpty) {
      final index = cents.length - 1;
      cents[index] = (cents[index] + diff).clamp(0, totalCents);
    }
    return cents;
  }

  List<int> _allocateWeightedCents(int totalCents, List<num> weights) {
    if (weights.isEmpty) return const <int>[];
    final normalized = weights
        .map((value) => value.isNegative ? 0.0 : value.toDouble())
        .toList();
    final totalWeight = normalized.fold<double>(0, (sum, value) => sum + value);
    if (totalWeight <= 0) {
      return List<int>.filled(weights.length, 0);
    }

    final raw =
        normalized.map((value) => (totalCents * value) / totalWeight).toList();
    final floorValues = raw.map((value) => value.floor()).toList();
    var remainder = totalCents - floorValues.fold<int>(0, (sum, v) => sum + v);

    if (remainder > 0) {
      final order = List<int>.generate(raw.length, (i) => i);
      order.sort((a, b) {
        final fracA = raw[a] - raw[a].floor();
        final fracB = raw[b] - raw[b].floor();
        return fracB.compareTo(fracA);
      });
      for (var i = 0; i < remainder; i++) {
        final index = order[i % order.length];
        floorValues[index] += 1;
      }
    }

    return floorValues;
  }

  /// Invalidate appropriate providers based on sharing preference
  Future<void> _invalidateProviders(String userId, String? householdId) async {
    _debugPrint('🔄 Invalidating providers...');

    final isPortfolioSave = householdId != null &&
        householdId.isNotEmpty &&
        ref.read(householdScopeProvider).isPortfolioId(householdId);

    // Refresh analytics for personal + portfolio saves.
    // Portfolio dashboards read from analytics state, so they need an immediate
    // refresh after save to reflect backend category remaps and server truth.
    if (householdId == null || householdId.isEmpty || isPortfolioSave) {
      ref.read(analyticsProvider.notifier).refresh(userId);
    }

    ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    ref.read(walletActionsProvider).refreshAccountData();

    // Refresh pockets so budget calculations reflect the new expense.
    // Note: currencyTransactionCountsProvider auto-recomputes reactively
    // via ref.watch(analyticsProvider), so no explicit invalidation needed.
    ref.invalidate(pocketsProvider);

    if (householdId != null) {
      // Shared expense: refresh household data
      _debugPrint(
          '🔄 Invalidating household providers for household: $householdId');

      // Clear RequestDeduplicator cache so cached providers don't serve stale data.
      ref.read(cacheInvalidatorProvider).invalidateHouseholdData(householdId);

      // Invalidate family providers so all parameterized instances refresh
      ref.invalidate(
          householdExpensesProvider); // fix: refresh all limits (e.g., 500)
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);

      // Invalidate cached family providers too (they do not depend on the base
      // providers via ref.watch, so they must be invalidated explicitly).
      ref.invalidate(cachedHouseholdExpensesProvider);
      ref.invalidate(cachedHouseholdSplitsProvider);

      _debugPrint('✅ Invalidated families: expenses, splits, budgets');
    }

    _debugPrint('✅ Providers invalidated and ready for refresh');
  }

  /// Allows batch save callers to skip invalidations per item and refresh once.
  Future<void> invalidateAfterBatch({
    required String userId,
    String? householdId,
  }) async {
    await _invalidateProviders(userId, householdId);
  }

  /// Upload receipt image to storage (if needed)
  Future<String?> uploadReceiptImage(File imageFile, String userId) async {
    try {
      _debugPrint('📤 Uploading receipt image...');

      // Compress before upload to reduce egress (raw photos are 1-6MB)
      final compressedBytes = await ImageCompressor.compressFile(
        imageFile,
        config: ImageCompressConfig.receipt,
      );

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      //This Path is fixed, SO DO NOT CHANGE IT!
      final path = 'receipts/$userId/$fileName';

      final response = await supabase.storage
          .from('expense-receipts')
          .uploadBinary(path, compressedBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '31536000',
              ));

      if (response.isEmpty) {
        throw Exception('Upload failed');
      }

      final publicUrl =
          supabase.storage.from('expense-receipts').getPublicUrl(path);

      _debugPrint('✅ Receipt uploaded successfully');
      return publicUrl;
    } catch (error) {
      _debugPrint('❌ Receipt upload failed: $error');
      return null; // Continue without receipt image
    }
  }

  Future<void> deleteReceiptImage(String? receiptImageUrl) async {
    final path = receiptStoragePathFromPublicUrl(receiptImageUrl);
    if (path == null) return;

    try {
      _debugPrint('🗑️ Deleting receipt image...');
      await supabase.storage.from('expense-receipts').remove([path]);
      _debugPrint('✅ Receipt image deleted');
    } catch (error) {
      _debugPrint('❌ Receipt delete failed: $error');
    }
  }
}

final expenseSaveNotifierProvider =
    StateNotifierProvider<ExpenseSaveNotifier, AsyncValue<void>>((ref) {
  return ExpenseSaveNotifier(ref);
});

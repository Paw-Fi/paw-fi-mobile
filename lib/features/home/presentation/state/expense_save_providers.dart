// State providers for expense save flow

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    as split_entities;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

// ============================================================================
// PENDING EXPENSE PROVIDER
// ============================================================================

/// Holds the parsed expense before user confirms and saves
final pendingExpenseProvider = StateProvider<ParsedExpense?>((ref) => null);

// ============================================================================
// SELECTED HOUSEHOLD FOR SHARING
// ============================================================================

/// Tracks which household to share expense with (null = personal only)
final selectedHouseholdForSharingProvider = StateProvider<String?>((ref) => null);

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
    String? receiptImageUrl,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    bool invalidateProviders = true,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(authProvider);
      
      debugPrint('💾 Saving expense: ${expense.formattedAmount} ${expense.category}');
      if (householdId != null) {
        debugPrint('👥 Sharing with household: $householdId');
        if (customSplitType != null && customSplits != null) {
          debugPrint('📊 Custom split type: $customSplitType with ${customSplits.length} members');
        }
      }

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'userId': user.uid,
        'amount': expense.amount,
        'category': expense.category,
        'currency': expense.currency,
        // Date is used by BE for the calendar day; includes time here but DB stores DATE
        'date': expense.date.toIso8601String(),
        // Preserve client timezone by sending an explicit UTC timestamp for created_at
        'clientCreatedAt': expense.date.toUtc().toIso8601String(),
        'description': expense.description,
        'receiptImageUrl': receiptImageUrl,
        'householdId': householdId, // null = personal, id = shared
        // Explicitly set type for new expenses
        'type': 'expense',
      };

      // Add custom splits if provided
      if (householdId != null && customSplitType != null && customSplits != null) {
        final splitTypeStr = customSplitType.toString().split('.').last;
        
        debugPrint('🔍 [SAVE EXPENSE] Preparing custom splits:');
        debugPrint('  - Split type: $splitTypeStr');
        debugPrint('  - Number of members: ${customSplits.length}');
        
        requestBody['customSplits'] = {
          'splitType': splitTypeStr,
          'memberSplits': customSplits.map((split) {
            final memberData = <String, dynamic>{
              'userId': split.member.userId,
            };
            
            // Add the appropriate field based on split type
            switch (customSplitType) {
              case SplitType.amount:
                memberData['amount'] = split.amount;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: amount=${split.amount}');
                break;
              case SplitType.percentage:
                memberData['percentage'] = split.percentage;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: percentage=${split.percentage}');
                break;
              case SplitType.shares:
                memberData['shares'] = split.shares;
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: shares=${split.shares}');
                break;
              case SplitType.equal:
                debugPrint('  - Member ${split.member.userName ?? split.member.userEmail}: equal (no data)');
                // No additional data needed for equal splits
                break;
            }
            
            return memberData;
          }).toList(),
        };
        
        debugPrint('📊 Custom splits payload: ${requestBody['customSplits']}');
      } else if (householdId != null) {
        debugPrint('⚠️ [SAVE EXPENSE] No custom splits - backend will default to equal split');
        debugPrint('  - customSplitType: $customSplitType');
        debugPrint('  - customSplits: ${customSplits?.length ?? 0} members');
      }

      if (householdId != null && payerUserId != null && payerUserId.isNotEmpty) {
        requestBody['payerUserId'] = payerUserId;
      }

      // Call save-expense edge function
      final response = await supabase.functions.invoke(
        'save-expense',
        body: requestBody,
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? 'Failed to save expense');
      }

      debugPrint('✅ Expense saved successfully');
      final responseMap =
          response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
      _addOptimisticHouseholdData(
        expense: expense,
        householdId: householdId,
        payerUserId: payerUserId ?? user.uid,
        receiptImageUrl: receiptImageUrl,
        customSplitType: customSplitType,
        customSplits: customSplits,
        responseData: responseMap,
        userId: user.uid,
      );

      if (invalidateProviders) {
        // Invalidate providers to trigger UI refresh
        await _invalidateProviders(user.uid, householdId);
      }

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      debugPrint('❌ Error saving expense: $error');
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  void _addOptimisticHouseholdData({
    required ParsedExpense expense,
    required String? householdId,
    required String payerUserId,
    required String? receiptImageUrl,
    required SplitType? customSplitType,
    required List<MemberSplit>? customSplits,
    required Map<String, dynamic>? responseData,
    required String userId,
  }) {
    if (householdId == null || householdId.isEmpty) return;
    final sharedFlag = responseData?['shared'];
    if (sharedFlag is bool && sharedFlag == false) return;
    if (sharedFlag == null && responseData?['warning'] != null) return;

    final saved = responseData?['data'];
    final savedMap =
        saved is Map<String, dynamic> ? saved : <String, dynamic>{};
    final savedId = savedMap['id']?.toString();
    final hasServerId = savedId != null && savedId.isNotEmpty;
    final expenseId = hasServerId
        ? savedId!
        : 'optimistic_${DateTime.now().millisecondsSinceEpoch}';

    final createdAtRaw = savedMap['created_at']?.toString();
    final createdAt =
        createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;

    final members =
        ref.read(householdMembersProvider(householdId)).valueOrNull;

    final splitGroup = hasServerId
        ? _buildOptimisticSplitGroup(
            householdId: householdId,
            expenseId: expenseId,
            payerUserId: payerUserId,
            expense: expense,
            customSplitType: customSplitType,
            customSplits: customSplits,
            members: members,
          )
        : null;

    final entry = _buildOptimisticExpenseEntry(
      expense: expense,
      expenseId: expenseId,
      householdId: householdId,
      userId: userId,
      receiptImageUrl: receiptImageUrl,
      createdAt: createdAt ?? expense.date,
      splitGroupId: splitGroup?.id,
    );

    ref
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(householdId, entry);

    if (splitGroup != null) {
      ref
          .read(householdOptimisticSplitsProvider.notifier)
          .addSplitGroup(householdId, splitGroup);
    }
  }

  ExpenseEntry _buildOptimisticExpenseEntry({
    required ParsedExpense expense,
    required String expenseId,
    required String householdId,
    required String userId,
    required String? receiptImageUrl,
    required DateTime createdAt,
    String? splitGroupId,
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
      receiptImageUrl: receiptImageUrl,
      splitGroupId: splitGroupId,
      type: 'expense',
    );
  }

  split_entities.ExpenseSplitGroup? _buildOptimisticSplitGroup({
    required String householdId,
    required String expenseId,
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
    final groupId = 'optimistic_$expenseId';
    final lines = <split_entities.ExpenseSplitLine>[];

    for (var i = 0; i < included.length; i++) {
      final split = included[i];
      final member = split.member;
      lines.add(
        split_entities.ExpenseSplitLine(
          id: 'optimistic_line_${expenseId}_${member.userId}',
          splitGroupId: groupId,
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
      id: groupId,
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
      SplitType.amount =>
        splits.where((s) => s.includedInAmount).toList(),
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
    final totalWeight =
        normalized.fold<double>(0, (sum, value) => sum + value);
    if (totalWeight <= 0) {
      return List<int>.filled(weights.length, 0);
    }

    final raw = normalized
        .map((value) => (totalCents * value) / totalWeight)
        .toList();
    final floorValues = raw.map((value) => value.floor()).toList();
    var remainder =
        totalCents - floorValues.fold<int>(0, (sum, v) => sum + v);

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
    debugPrint('🔄 Invalidating providers...');

    // Always refresh personal analytics (expense is in user's expenses table)
    ref.read(analyticsProvider.notifier).refresh(userId);

    // Always refresh pockets + currency counts so other tabs reflect changes.
    ref.invalidate(pocketsProvider);
    ref.invalidate(currencyTransactionCountsProvider);
    
    if (householdId != null) {
      // Shared expense: refresh household data
      debugPrint('🔄 Invalidating household providers for household: $householdId');

      // Clear RequestDeduplicator cache so cached providers don't serve stale data.
      ref.read(cacheInvalidatorProvider).invalidateHouseholdData(householdId);

      // Invalidate household list (to update counts)
      ref.invalidate(userHouseholdsProvider(userId));

      // Invalidate family providers so all parameterized instances refresh
      ref.invalidate(householdSummaryProvider);
      ref.invalidate(householdExpensesProvider); // fix: refresh all limits (e.g., 500)
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdMembersProvider);

      // Invalidate cached family providers too (they do not depend on the base
      // providers via ref.watch, so they must be invalidated explicitly).
      ref.invalidate(cachedHouseholdExpensesProvider);
      ref.invalidate(cachedHouseholdSplitsProvider);

      debugPrint('✅ Invalidated families: expenses, splits, budgets, summary');
    }
    
    // Small delay to ensure backend has propagated changes
    await Future.delayed(const Duration(milliseconds: 300));
    
    debugPrint('✅ Providers invalidated and ready for refresh');
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
      debugPrint('📤 Uploading receipt image...');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      //This Path is fixed, SO DO NOT CHANGE IT!
      final path = 'receipts/$userId/$fileName';

      final response = await supabase.storage
          .from('expense-receipts')
          .upload(path, imageFile);

      if (response.isEmpty) {
        throw Exception('Upload failed');
      }

      final publicUrl = supabase.storage
          .from('expense-receipts')
          .getPublicUrl(path);

      debugPrint('✅ Receipt uploaded: $publicUrl');
      return publicUrl;
    } catch (error) {
      debugPrint('❌ Receipt upload failed: $error');
      return null; // Continue without receipt image
    }
  }
}

final expenseSaveNotifierProvider =
    StateNotifierProvider<ExpenseSaveNotifier, AsyncValue<void>>((ref) {
  return ExpenseSaveNotifier(ref);
});

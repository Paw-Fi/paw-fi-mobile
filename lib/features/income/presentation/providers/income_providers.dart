import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/income/domain/models/income_entry.dart';
import 'package:moneko/features/income/domain/models/income_summary.dart';

/// Income list state provider
final incomeListProvider = StateNotifierProvider<IncomeListNotifier, AsyncValue<List<IncomeEntry>>>((ref) {
  return IncomeListNotifier(ref);
});

class IncomeListNotifier extends StateNotifier<AsyncValue<List<IncomeEntry>>> {
  final Ref ref;

  IncomeListNotifier(this.ref) : super(const AsyncValue.loading());

  /// Load income for a user (with optional filters)
  Future<void> loadIncome(String userId, {
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    String? householdId,
    int limit = 50,
  }) async {
    state = const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'list-income',
        body: {
          'userId': userId,
          'limit': limit,
          if (startDate != null) 'startDate': startDate.toIso8601String().split('T')[0],
          if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
          if (currency != null) 'currency': currency,
          if (householdId != null) 'householdId': householdId,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'] as List<dynamic>;
        final incomeList = data.map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>)).toList();
        state = AsyncValue.data(incomeList);
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to load income',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh income list
  Future<void> refresh(String userId, {
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
final incomeSummaryProvider = StateNotifierProvider<IncomeSummaryNotifier, AsyncValue<IncomeSummary>>((ref) {
  return IncomeSummaryNotifier(ref);
});

class IncomeSummaryNotifier extends StateNotifier<AsyncValue<IncomeSummary>> {
  final Ref ref;

  IncomeSummaryNotifier(this.ref) : super(const AsyncValue.loading());

  /// Load income summary for a user
  Future<void> loadSummary(String userId, {
    String? householdId,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
  }) async {
    state = const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'income-summary',
        body: {
          'userId': userId,
          if (householdId != null) 'householdId': householdId,
          if (startDate != null) 'startDate': startDate.toIso8601String().split('T')[0],
          if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
          if (currency != null) 'currency': currency,
        },
      );

      if (response.data['success'] == true) {
        final summary = IncomeSummary.fromJson(response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(summary);
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to load income summary',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh income summary
  Future<void> refresh(String userId, {
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
final incomeSaveProvider = StateNotifierProvider<IncomeSaveNotifier, AsyncValue<IncomeEntry?>>((ref) {
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
    String? source,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    double? fxRate,
    String? idempotencyKey,
    List<Map<String, dynamic>>? attachments,
    bool isRecurring = false,
    Map<String, dynamic>? recurrenceRule,
  }) async {
    state = const AsyncValue.loading();

    try {
      final response = await supabase.functions.invoke(
        'save-income',
        body: {
          'userId': userId,
          'amount': amount,
          'category': category,
          'currency': currency,
          'date': date.toIso8601String(),
          'clientCreatedAt': DateTime.now().toIso8601String(),
          if (description != null && description.isNotEmpty) 'description': description,
          if (source != null && source.isNotEmpty) 'source': source,
          'ownerType': ownerType,
          'privacyScope': privacyScope,
          if (householdId != null) 'householdId': householdId,
          if (fxRate != null) 'fxRate': fxRate,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
          if (attachments != null) 'attachments': attachments,
          'isRecurring': isRecurring,
          if (recurrenceRule != null) 'recurrenceRule': recurrenceRule,
        },
      );

      if (response.data['success'] == true) {
        final income = IncomeEntry.fromJson(response.data['data'] as Map<String, dynamic>);
        state = AsyncValue.data(income);

        // Refresh income list
        ref.read(incomeListProvider.notifier).refresh(userId, householdId: householdId);

        // Refresh income summary
        ref.read(incomeSummaryProvider.notifier).refresh(userId, householdId: householdId);

        return income;
      } else {
        state = AsyncValue.error(
          response.data['error'] ?? 'Failed to save income',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Reset save state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Income acknowledgement provider
final incomeAcknowledgeProvider = StateNotifierProvider<IncomeAcknowledgeNotifier, AsyncValue<bool>>((ref) {
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
          ref.read(incomeListProvider.notifier).state = AsyncValue.data(updatedList);
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

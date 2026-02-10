import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' as foundation;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/processing_state.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

/// Expense processing notifier
class ExpenseProcessingNotifier extends StateNotifier<ProcessingState> {
  final Ref ref;

  ExpenseProcessingNotifier(this.ref) : super(ProcessingState());

  String _userTodayYmd() {
    final preferredTimezone =
        ref.read(analyticsProvider).contact?.preferredTimezone;
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);
    return formatDateOnlyYmd(userNow);
  }

  DateTime _parseExpenseDate(dynamic raw, DateTime fallback) {
    final value = raw?.toString();
    final dateOnly = tryParseDateOnlyYmd(value);
    if (dateOnly != null) {
      return DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
    }
    return DateTime.tryParse(value ?? '') ?? fallback;
  }

  Future<void> processText(String text, String phone) async {
    state = state.copyWith(
        isProcessing: true,
        message: 'Processing expense...',
        progress: 0.1,
        clearExpense: true);

    try {
      final response = await supabase.functions.invoke(
        'process-expenses',
        body: {
          'phone': phone,
          'text': text,
          'date': _userTodayYmd(),
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];
        ExpenseEntry? createdExpense;

        // The response structure is: {success: true, data: {type: 'expense', items: [...], expenses: [...]}}
        // We need the 'expenses' array which has the actual DB records
        if (responseData != null &&
            responseData['expenses'] != null &&
            responseData['expenses'].isNotEmpty) {
          try {
            final expenseData =
                responseData['expenses'][0]; // Get first expense from DB
            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: _parseExpenseDate(expenseData['date'], DateTime.now()),
              createdAt: DateTime.parse(expenseData['created_at'] ??
                  DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
          } catch (parseError) {
            _debugPrint('Error parsing expense data: $parseError');
          }
        } else if (responseData != null &&
            responseData['items'] != null &&
            responseData['items'].isNotEmpty) {
          // Fallback: If 'expenses' array is missing, create from 'items' (Gemini parsed data)
          try {
            final item = responseData['items'][0];
            final amountCents = ((item['amount'] ?? 0.0) * 100).round();
            createdExpense = ExpenseEntry(
              id: '', // No ID from items
              contactId: '',
              amountCents: amountCents,
              category: item['category'] ?? 'uncategorized',
              date: _parseExpenseDate(item['date'], DateTime.now()),
              createdAt: DateTime.now(),
              rawText: text,
              currency: item['currency'] ?? 'USD',
              receiptImageUrl: null,
            );
          } catch (parseError) {
            _debugPrint('Error parsing items data: $parseError');
          }
        }

        // Mark as complete
        state = state.copyWith(
            isProcessing: false,
            progress: 1.0,
            createdExpense: createdExpense,
            clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process expense';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(
          isProcessing: false,
          message: 'Error: ${e.toString()}',
          clearMessage: false);
      rethrow;
    }
  }

  Future<void> processImage(File imageFile, String phone) async {
    state = state.copyWith(
        isProcessing: true,
        message: 'Processing receipt image...',
        progress: 0.1,
        clearExpense: true,
        localImagePath: imageFile.path);

    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'heic') {
        contentType = 'image/heic';
      }

      final response = await supabase.functions.invoke(
        'process-expenses',
        body: {
          'phone': phone,
          'image': {
            'data': base64Image,
            'contentType': contentType,
          },
          'date': _userTodayYmd(),
        },
      );

      if (response.data != null && response.data['success'] == true) {
        // Parse expense data from response - it's nested in data.expenses array
        final responseData = response.data['data'];

        ExpenseEntry? createdExpense;

        if (responseData != null &&
            responseData['expenses'] != null &&
            responseData['expenses'].isNotEmpty) {
          try {
            final expenseData =
                responseData['expenses'][0]; // Get first expense

            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: _parseExpenseDate(expenseData['date'], DateTime.now()),
              createdAt: DateTime.parse(expenseData['created_at'] ??
                  DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
            _debugPrint('Expense entry parsed successfully');
          } catch (parseError) {
            _debugPrint('Error parsing expense data: $parseError');
          }
        } else {
          _debugPrint('No expense rows returned from processing response');
        }

        // Mark as complete
        state = state.copyWith(
            isProcessing: false,
            progress: 1.0,
            createdExpense: createdExpense,
            clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process receipt';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(
          isProcessing: false,
          message: 'Error: ${e.toString()}',
          clearMessage: false);
      rethrow;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  /// Clear all processing state (on logout)
  void clear() {
    state = ProcessingState();
  }
}

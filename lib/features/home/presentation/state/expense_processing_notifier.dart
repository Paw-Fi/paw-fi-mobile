import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/processing_state.dart';

/// Expense processing notifier
class ExpenseProcessingNotifier extends StateNotifier<ProcessingState> {
  ExpenseProcessingNotifier() : super(ProcessingState());

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
          'date': DateTime.now().toIso8601String().split('T')[0],
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
              date: DateTime.parse(
                  expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ??
                  DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
          } catch (parseError) {
            debugPrint('Error parsing expense data: $parseError');
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
              date: DateTime.parse(item['date'] ??
                  DateTime.now().toIso8601String().split('T')[0]),
              createdAt: DateTime.now(),
              rawText: text,
              currency: item['currency'] ?? 'USD',
              receiptImageUrl: null,
            );
          } catch (parseError) {
            debugPrint('Error parsing items data: $parseError');
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
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );

      if (response.data != null && response.data['success'] == true) {
        // DEBUG: Log the full response structure
        debugPrint('=== FULL RESPONSE ===');
        debugPrint(response.data);

        // Parse expense data from response - it's nested in data.expenses array
        final responseData = response.data['data'];
        debugPrint('=== RESPONSE DATA ===');
        debugPrint(responseData);

        ExpenseEntry? createdExpense;

        if (responseData != null &&
            responseData['expenses'] != null &&
            responseData['expenses'].isNotEmpty) {
          try {
            debugPrint('=== EXPENSES ARRAY ===');
            debugPrint(responseData['expenses']);

            final expenseData =
                responseData['expenses'][0]; // Get first expense
            debugPrint('=== FIRST EXPENSE ===');
            debugPrint(expenseData);

            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: DateTime.parse(
                  expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ??
                  DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
            debugPrint('=== CREATED EXPENSE ENTRY ===');
            debugPrint(
                'Category: ${createdExpense.category}, Amount: ${createdExpense.amount}');
          } catch (parseError) {
            debugPrint('Error parsing expense data: $parseError');
          }
        } else {
          debugPrint('=== NO EXPENSES FOUND ===');
          debugPrint('responseData is null: ${responseData == null}');
          debugPrint('expenses is null: ${responseData?['expenses'] == null}');
          debugPrint('expenses isEmpty: ${responseData?['expenses']?.isEmpty}');
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

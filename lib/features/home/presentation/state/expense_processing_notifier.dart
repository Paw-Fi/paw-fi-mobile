import 'dart:convert';
import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/processing_state.dart';

/// Expense processing notifier
class ExpenseProcessingNotifier extends StateNotifier<ProcessingState> {
  ExpenseProcessingNotifier() : super(ProcessingState());

  Future<void> _simulateProgress() async {
    // Fast initial progress
    await Future.delayed(const Duration(milliseconds: 100));
    state = state.copyWith(progress: 0.3);

    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(progress: 0.5);

    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(progress: 0.65);

    // Slower as it approaches the end
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(progress: 0.75);

    await Future.delayed(const Duration(milliseconds: 800));
    state = state.copyWith(progress: 0.82);

    await Future.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(progress: 0.88);

    // Very slow near completion
    await Future.delayed(const Duration(milliseconds: 1500));
    state = state.copyWith(progress: 0.92);
  }

  Future<void> processText(String text, String phone) async {
    state = state.copyWith(isProcessing: true, message: 'Processing expense...', progress: 0.1, clearExpense: true);

    // Start fake progress simulation
    _simulateProgress();

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
        if (responseData != null && responseData['expenses'] != null && responseData['expenses'].isNotEmpty) {
          try {
            final expenseData = responseData['expenses'][0]; // Get first expense from DB
            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: DateTime.parse(expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ?? DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
          } catch (parseError) {
            print('Error parsing expense data: $parseError');
          }
        } else if (responseData != null && responseData['items'] != null && responseData['items'].isNotEmpty) {
          // Fallback: If 'expenses' array is missing, create from 'items' (Gemini parsed data)
          try {
            final item = responseData['items'][0];
            final amountCents = ((item['amount'] ?? 0.0) * 100).round();
            createdExpense = ExpenseEntry(
              id: '', // No ID from items
              contactId: '',
              amountCents: amountCents,
              category: item['category'] ?? 'uncategorized',
              date: DateTime.parse(item['date'] ?? DateTime.now().toIso8601String().split('T')[0]),
              createdAt: DateTime.now(),
              rawText: text,
              currency: item['currency'] ?? 'USD',
              receiptImageUrl: null,
            );
          } catch (parseError) {
            print('Error parsing items data: $parseError');
          }
        }

        // Jump to 100% on success
        state = state.copyWith(progress: 1.0, createdExpense: createdExpense);
        // Very short delay to show completion, then hide to allow toast to show immediately
        await Future.delayed(const Duration(milliseconds: 50));
        state = state.copyWith(isProcessing: false, clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process expense';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false, message: 'Error: ${e.toString()}', clearMessage: false);
      rethrow;
    }
  }

  Future<void> processImage(File imageFile, String phone) async {
    state = state.copyWith(isProcessing: true, message: 'Processing receipt image...', progress: 0.1, clearExpense: true, localImagePath: imageFile.path);

    // Start fake progress simulation
    _simulateProgress();

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
        print('=== FULL RESPONSE ===');
        print(response.data);

        // Parse expense data from response - it's nested in data.expenses array
        final responseData = response.data['data'];
        print('=== RESPONSE DATA ===');
        print(responseData);

        ExpenseEntry? createdExpense;

        if (responseData != null && responseData['expenses'] != null && responseData['expenses'].isNotEmpty) {
          try {
            print('=== EXPENSES ARRAY ===');
            print(responseData['expenses']);

            final expenseData = responseData['expenses'][0]; // Get first expense
            print('=== FIRST EXPENSE ===');
            print(expenseData);

            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: DateTime.parse(expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ?? DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
            print('=== CREATED EXPENSE ENTRY ===');
            print('Category: ${createdExpense.category}, Amount: ${createdExpense.amount}');
          } catch (parseError) {
            print('Error parsing expense data: $parseError');
          }
        } else {
          print('=== NO EXPENSES FOUND ===');
          print('responseData is null: ${responseData == null}');
          print('expenses is null: ${responseData?['expenses'] == null}');
          print('expenses isEmpty: ${responseData?['expenses']?.isEmpty}');
        }

        // Jump to 100% on success
        state = state.copyWith(progress: 1.0, createdExpense: createdExpense);
        // Very short delay to show completion, then hide to allow toast to show immediately
        await Future.delayed(const Duration(milliseconds: 50));
        state = state.copyWith(isProcessing: false, clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process receipt';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false, message: 'Error: ${e.toString()}', clearMessage: false);
      rethrow;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

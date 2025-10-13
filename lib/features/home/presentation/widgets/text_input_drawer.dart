import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

void showTextInputDrawer(BuildContext context, TextEditingController textController) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Expense',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.foreground),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Describe your expense (eg: "Spent 25 on lunch")',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter expense details...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: colorScheme.foreground),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: shadcnui.PrimaryButton(
                onPressed: () async {
                  final text = textController.text.trim();
                  if (text.isEmpty) {
                    _showToast(context, 'Please enter expense details');
                    return;
                  }

                  Navigator.pop(context);

                  final user = ProviderScope.containerOf(context).read(authProvider);
                  final contact = ProviderScope.containerOf(context).read(analyticsProvider).contact;

                  if (contact == null) {
                    _showToast(context, 'No contact found. Please link your WhatsApp first.');
                    return;
                  }

                  try {
                    print('=== STARTING TEXT PROCESSING ===');
                    await ProviderScope.containerOf(context).read(expenseProcessingProvider.notifier).processText(
                      text,
                      contact.phoneE164,
                    );
                    print('=== TEXT PROCESSING COMPLETED ===');

                    textController.clear();

                    // Show success toast with View link
                    final processingState = ProviderScope.containerOf(context).read(expenseProcessingProvider);
                    print('=== PROCESSING STATE: createdExpense is ${processingState.createdExpense != null ? "NOT NULL" : "NULL"} ===');

                    if (processingState.createdExpense != null) {
                      print('=== SHOWING SUCCESS TOAST ===');
                      _showSuccessToast(context, processingState.createdExpense!, contact);
                    }

                    // Close drawer
                    if (context.mounted) Navigator.pop(context);

                    // Refresh analytics data immediately
                    final userId = user.uid;
                    if (userId.isNotEmpty) {
                      print('=== REFRESHING ANALYTICS DATA FOR USER: $userId ===');
                      await ProviderScope.containerOf(context).read(analyticsProvider.notifier).loadData(userId);
                      print('=== ANALYTICS DATA REFRESH COMPLETED ===');
                    } else {
                      print('=== ERROR: User ID is null or empty, cannot refresh analytics ===');
                    }
                  } catch (e) {
                    print('=== ERROR IN TEXT PROCESSING: $e ===');
                    // Error is already handled in the notifier
                  }
                },
                child: const Text('Add Expense'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

void _showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _showSuccessToast(BuildContext context, dynamic expense, dynamic contact) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(
            child: Text(
              'Logged successfully',
              style: TextStyle(color: colorScheme.primaryForeground),
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              // TODO: Implement showTransactionDetailSheet
              // showTransactionDetailSheet(context, expense, contact: contact);
            },
            child: Text(
              'View',
              style: TextStyle(
                color: colorScheme.primaryForeground,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colorScheme.primary,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

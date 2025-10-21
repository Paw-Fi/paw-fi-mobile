import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/home/presentation/widgets/edit_transaction_bottom_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Format date with relative terms (Today, Yesterday, etc.)
String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final localDate = toLocalTime(date);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);
  
  if (dateOnly == today) {
    return 'Today';
  } else if (dateOnly == yesterday) {
    return 'Yesterday';
  } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
    return DateFormat('EEEE').format(localDate); // Day name (e.g., Monday)
  } else {
    return DateFormat('EEEE, d MMMM yyyy').format(localDate);
  }
}

/// Shows transaction detail bottom sheet with modern 2025 UI design
/// Inspired by N26 bank app - clean, minimal, Apple-like aesthetic
void showTransactionDetailSheet(
  BuildContext context,
  ExpenseEntry expense, {
  UserContact? contact,
  String? localImagePath,
}) {
  final category = expense.category ?? 'uncategorized';
  final categoryIcon = getCategoryIcon(category);
  final timeFormat = DateFormat('HH:mm');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final theme = shadcnui.Theme.of(context);
      final colorScheme = theme.colorScheme;
      
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minimal Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Close Button
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                child: IconButton(
                  icon: Icon(Icons.chevron_left, color: colorScheme.foreground, size: 28),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large Amount with Pencil Icon (Centered, Bold)
                    GestureDetector(
                      onTap: () => _showEditBottomSheet(
                        context,
                        expense: expense,
                        field: EditField.amount,
                        currentValue: expense.amount,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '-${formatCurrency(expense.amount, expense.currency)}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: colorScheme.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date and Time (Small, Gray, Centered)
                    Text(
                      '${formatRelativeDate(expense.date)}, ${timeFormat.format(toLocalTime(expense.createdAt))}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Details Section Header
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Card
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      icon: categoryIcon,
                      label: 'Category',
                      value: category.substring(0, 1).toUpperCase() + category.substring(1),
                      onTap: () => _showEditBottomSheet(
                        context,
                        expense: expense,
                        field: EditField.category,
                        currentValue: category,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Currency Card
                    if (expense.currency != null)
                      _buildDetailCard(
                        colorScheme: colorScheme,
                        icon: Icons.monetization_on_outlined,
                        label: 'Currency',
                        value: expense.currency!.toUpperCase(),
                        onTap: () => _showEditBottomSheet(
                          context,
                          expense: expense,
                          field: EditField.currency,
                          currentValue: expense.currency,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Date Card
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: formatRelativeDate(expense.date),
                      onTap: () => _showEditBottomSheet(
                        context,
                        expense: expense,
                        field: EditField.date,
                        currentValue: expense.date,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Time Card
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: timeFormat.format(toLocalTime(expense.createdAt)),
                      onTap: () => _showEditBottomSheet(
                        context,
                        expense: expense,
                        field: EditField.time,
                        currentValue: expense.createdAt,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Notes Section
                    if (expense.rawText != null && expense.rawText!.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNotesCard(
                        colorScheme: colorScheme,
                        notes: expense.rawText!,
                        onTap: () => _showEditBottomSheet(
                          context,
                          expense: expense,
                          field: EditField.description,
                          currentValue: expense.rawText,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Receipt Section
                    if (localImagePath != null || (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty)) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Receipt',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReceiptCard(
                        colorScheme: colorScheme,
                        localImagePath: localImagePath,
                        receiptImageUrl: expense.receiptImageUrl,
                      ),
                      const SizedBox(height: 32),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Build detail card with modern card design
Widget _buildDetailCard({
  required shadcnui.ColorScheme colorScheme,
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.border, width: 0.5),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.mutedForeground,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

/// Build notes card
Widget _buildNotesCard({
  required shadcnui.ColorScheme colorScheme,
  required String notes,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.border, width: 0.5),
            ),
            child: Icon(
              Icons.notes_outlined,
              size: 20,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              notes,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.foreground,
                fontWeight: FontWeight.w400,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: colorScheme.mutedForeground,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

/// Build receipt card
Widget _buildReceiptCard({
  required shadcnui.ColorScheme colorScheme,
  String? localImagePath,
  String? receiptImageUrl,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: localImagePath != null
          ? Image.file(
              File(localImagePath),
              fit: BoxFit.cover,
            )
          : receiptImageUrl != null
              ? Image.network(
                  receiptImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: colorScheme.muted,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppTheme.success,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: colorScheme.muted,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 40,
                              color: colorScheme.mutedForeground,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox(),
    ),
  );
}

/// Helper function to show edit bottom sheet
void _showEditBottomSheet(
  BuildContext context, {
  required ExpenseEntry expense,
  required EditField field,
  required dynamic currentValue,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EditTransactionBottomSheet(
      expenseId: expense.id,
      expense: expense,
      field: field,
      currentValue: currentValue,
    ),
  );
}

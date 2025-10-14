import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Shows transaction detail bottom sheet
void showTransactionDetailSheet(
  BuildContext context,
  ExpenseEntry expense, {
  UserContact? contact,
  String? localImagePath, // Optional local image path for newly captured photos
}) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  final category = expense.category ?? 'uncategorized';
  final categoryColor = getCategoryColor(category);
  final categoryIcon = getCategoryIcon(category);
  final currencySymbol = getCurrencySymbol(contact);
  final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
  final timeFormat = DateFormat('h:mm a');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.mutedForeground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 24,
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
            ),

            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category and Amount Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.border, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Category Icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              categoryIcon,
                              color: categoryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Category Name
                          Text(
                            category.substring(0, 1).toUpperCase() + category.substring(1),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Amount
                          Text(
                            '-$currencySymbol${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Receipt Image (if available - prefer local image, fallback to remote URL)
                    if (localImagePath != null || (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty)) ...[
                      Text(
                        'Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: localImagePath != null
                            ? Image.file(
                                File(localImagePath),
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                expense.receiptImageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: colorScheme.muted,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: colorScheme.muted,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported, size: 48, color: colorScheme.mutedForeground),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: TextStyle(color: colorScheme.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Details Section
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date
                    _buildDetailRow(
                      'Date',
                      dateFormat.format(toLocalTime(expense.date)),
                      Icons.calendar_today,
                      colorScheme,
                    ),
                    const SizedBox(height: 12),

                    // Time
                    _buildDetailRow(
                      'Time',
                      timeFormat.format(toLocalTime(expense.createdAt)),
                      Icons.access_time,
                      colorScheme,
                    ),
                    const SizedBox(height: 12),

                    // Currency
                    if (expense.currency != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDetailRow(
                          'Currency',
                          expense.currency!.toUpperCase(),
                          Icons.attach_money,
                          colorScheme,
                        ),
                      ),

                    // Raw Text / Notes
                    if (expense.rawText != null && expense.rawText!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.muted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          expense.rawText!,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
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

Widget _buildDetailRow(String label, String value, IconData icon, shadcnui.ColorScheme colorScheme) {
  return Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colorScheme.foreground),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}


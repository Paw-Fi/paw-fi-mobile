import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

Widget buildRecentTransactionsCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> allExpenses,
  UserContact? contact,
 {
  String? selectedCurrency,
  String? householdId,
  required VoidCallback onViewAll,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // Recent transactions - show latest 5 by transaction date (to match
  // TransactionsPage behavior and user expectation of "recent" by date).
  final recent = allExpenses.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      // If date/time are exactly the same, break ties by createdAt (newest first).
      return b.createdAt.compareTo(a.createdAt);
    });
  final latest = recent.take(5).toList();

  return Material(
    child: Container(
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Consumer(
        builder: (context, ref, _) {
          if (latest.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  context.l10n.noTransactionsFound,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
              ),
            );
          }
    
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.recentTransactions.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              ...latest.map((e) {
                final isIncome = (e.type ?? 'expense').toLowerCase() == 'income';

                // Use the same semantics as the unified transaction sheet:
                // date comes from the transaction's logical date field, while
                // the time component comes from createdAt. This avoids
                // showing 00:00 when the original transaction time was later
                // in the day (e.g. 14:25).
                final displayDateTime = DateTime(
                  e.date.year,
                  e.date.month,
                  e.date.day,
                  e.createdAt.hour,
                  e.createdAt.minute,
                  e.createdAt.second,
                  e.createdAt.millisecond,
                  e.createdAt.microsecond,
                );

                return Slidable(
                  key: ValueKey(e.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.22,
                    children: [
                      SlidableAction(
                        onPressed: (_) async {
                          final l10n = context.l10n;
                          final uid =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (uid == null) return;
                          try {
                            final res = await Supabase.instance.client.functions
                                .invoke('delete-expense', body: {
                              'userId': uid,
                              'expenseId': e.id,
                            });
    
                            if (!context.mounted) return;
    
                            if (res.data != null &&
                                (res.data['success'] == true)) {
                              if (householdId == null) {
                                ref.read(analyticsProvider.notifier).refresh(uid);
                              } else {
                                ref.invalidate(householdExpensesProvider);
                                ref.invalidate(householdSplitsProvider);
                                ref.invalidate(householdSummaryProvider);
                              }
                              AppToast.success(context, l10n.transactionDeleted);
                            } else {
                              AppToast.error(context, l10n.anErrorOccurred);
                            }
                          } catch (err) {
                            if (context.mounted) {
                              AppToast.error(context, '${l10n.error}: $err');
                            }
                          }
                        },
                        backgroundColor: const Color(0xFFFE4A49),
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: context.l10n.delete,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  child: buildExpenseTransactionTile(
                    context: context,
                    category: e.category,
                    rawText: e.rawText,
                    date: displayDateTime,
                    amount: e.amount,
                    currency: selectedCurrency ?? 'USD',
                    isIncome: isIncome,
                    onTap: () => showUnifiedTransactionSheet(
                      context,
                      existingExpense: e,
                      contact: contact,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: onViewAll,
                  child: Text(context.l10n.viewAll),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

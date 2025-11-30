import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
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

Widget buildCategoryBreakdownCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  UserContact? contact, {
  String? selectedCurrency,
  String? householdId,
  required VoidCallback onViewAll,
}) {
  // Recent transactions - show latest 5 by transaction date (to match
  // TransactionsPage behavior and user expectation of "recent" by date).
  final recent = expenses.toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final latest = recent.take(5).toList();

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                child: TransactionListTile(
                  onTap: () => showUnifiedTransactionSheet(context,
                      existingExpense: e, contact: contact),
                  category: e.category ?? 'other',
                  title: getCategoryTranslation(context, e.category ?? 'other'),
                  description: e.rawText,
                  date: e.date,
                  amount: e.amount,
                  currency: selectedCurrency ?? 'USD',
                  isIncome: isIncome,
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
  );
}

import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/recurring/presentation/widgets/upcoming_recurring_banner.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';

Widget buildRecentTransactionsCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> allExpenses,
  UserContact? contact, {
  Key? key,
  String? selectedCurrency,
  String? householdId,
  required VoidCallback onViewAll,
}) {
  final nonRecurringExpenses =
      allExpenses.where((e) => !e.isRecurring).toList(growable: false);

  // Recent transactions - show latest 5 by transaction date (to match
  // TransactionsPage behavior and user expectation of "recent" by date).
  final recent = nonRecurringExpenses.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      // If date/time are exactly the same, break ties by createdAt (newest first).
      return b.createdAt.compareTo(a.createdAt);
    });
  final latest = recent.take(5).toList();
  final cardRadius = BorderRadius.circular(24);

  return Material(
    key: key,
    child: Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: cardRadius,
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: Consumer(
          builder: (context, ref, child) {
            final upcoming = ref.watch(
              upcomingRecurringTransactionProvider(
                UpcomingRecurringScope(
                  householdId: householdId,
                  currency: selectedCurrency,
                ),
              ),
            );

            if (latest.isEmpty && upcoming == null) {
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

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Column(
                key: ValueKey('recent_tx_col_${latest.length}_${latest.firstOrNull?.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming != null) ...[
                    UpcomingRecurringBanner(
                      upcoming: upcoming,
                      onTap: () {
                        showAddRecurringSheet(
                          context,
                          type: upcoming.transaction.type,
                          existingTransaction: upcoming.transaction,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      upcoming != null ? 0 : 16,
                      0,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...latest.map((e) {
                          final isIncome =
                              (e.type ?? 'expense').toLowerCase() == 'income';

                          // Use the same semantics as the unified transaction sheet:
                          // date comes from the transaction's logical date field, while
                          // the time component comes from createdAt. This avoids
                          // showing 00:00 when the original transaction time was later
                          // in the day (e.g. 14:25).
                          final displayDateTime =
                              composeTransactionDisplayDateTime(
                            transactionDate: e.date,
                            createdAt: e.createdAt,
                            preferredTimezone: contact?.preferredTimezone,
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
                                    final rootNavigator = Navigator.of(context,
                                        rootNavigator: true);
                                    final toastContext = rootNavigator.context;

                                    AppToast.success(
                                        toastContext, l10n.transactionDeleted);
                                    final success = await ref
                                        .read(transactionEditProvider.notifier)
                                        .deleteExpensesOptimistically([e]);

                                    if (!success) {
                                      final error =
                                          ref.read(transactionEditProvider).error;
                                      if (!toastContext.mounted) return;
                                      AppToast.error(
                                        toastContext,
                                        ErrorHandler.getUserFriendlyMessage(
                                          error,
                                          context:
                                              BackendErrorContext.deleteExpense,
                                        ),
                                      );
                                    }
                                  },
                                  backgroundColor: colorScheme.destructive,
                                  foregroundColor: colorScheme.onError,
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
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

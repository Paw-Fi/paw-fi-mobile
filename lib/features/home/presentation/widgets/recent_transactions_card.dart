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
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

String _buildUpcomingDueLabel(BuildContext context, int daysUntil) {
  if (daysUntil <= 0) return context.l10n.today;
  if (daysUntil == 1) return context.l10n.tomorrow;
  return context.l10n.inDays(daysUntil);
}

Widget _buildUpcomingRecurringTile({
  required BuildContext context,
  required ColorScheme colorScheme,
  required UpcomingRecurringTransaction upcoming,
  required VoidCallback onTap,
}) {
  final transaction = upcoming.transaction;
  final isIncome = transaction.type == 'income';
  final title =
      isIncome ? context.l10n.upcomingPaychecks : context.l10n.upcomingBills;
  final dueLabel = _buildUpcomingDueLabel(context, upcoming.daysUntil);
  final normalized = double.parse(formatAmount(transaction.amount.abs()));
  final localized = formatLocalizedNumber(context, normalized);
  final symbol = resolveCurrencySymbol(transaction.currency);
  final sign = isIncome ? '+' : '-';
  final amountText = '$sign$symbol$localized';

  return Material(
    color: colorScheme.surface.withValues(alpha: 0.0),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.muted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.mutedForeground.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.repeat,
                color: colorScheme.mutedForeground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dueLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildRecentTransactionsCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> allExpenses,
  UserContact? contact, {
  String? selectedCurrency,
  String? householdId,
  required VoidCallback onViewAll,
}) {
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
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
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
      child: Consumer(
        builder: (context, ref, _) {
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (upcoming != null) ...[
                _buildUpcomingRecurringTile(
                  context: context,
                  colorScheme: colorScheme,
                  upcoming: upcoming,
                  onTap: () {
                    ref.read(mainShellTabIndexProvider.notifier).state = 1;
                  },
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  upcoming != null ? 0 : 24,
                  24,
                  24,
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
                                final uid = Supabase
                                    .instance.client.auth.currentUser?.id;
                                if (uid == null) return;
                                try {
                                  final res = await Supabase
                                      .instance.client.functions
                                      .invoke('delete-expense', body: {
                                    'userId': uid,
                                    'expenseId': e.id,
                                  });

                                  if (!context.mounted) return;

                                  if (res.data != null &&
                                      (res.data['success'] == true)) {
                                    // Always refresh analytics (personal tab) since the
                                    // deleted row may be present in the user's dataset.
                                    ref
                                        .read(analyticsProvider.notifier)
                                        .refresh(uid);

                                    if (householdId != null) {
                                      ref
                                          .read(cacheInvalidatorProvider)
                                          .invalidateHouseholdData(householdId);
                                      ref.invalidate(
                                          userHouseholdsProvider(uid));
                                      ref.invalidate(householdExpensesProvider);
                                      ref.invalidate(
                                          cachedHouseholdExpensesProvider);
                                      ref.invalidate(householdSplitsProvider);
                                      ref.invalidate(
                                          cachedHouseholdSplitsProvider);
                                      ref.invalidate(householdBudgetsProvider);
                                      ref.invalidate(householdMembersProvider);
                                    }

                                    // Keep other tabs and the currency selector in sync.
                                    ref.invalidate(pocketsProvider);
                                    ref.invalidate(
                                        currencyTransactionCountsProvider);
                                    AppToast.success(
                                        context, l10n.transactionDeleted);
                                  } else {
                                    final payload =
                                        res.data is Map<String, dynamic>
                                            ? (res.data as Map<String, dynamic>)
                                            : null;
                                    final message =
                                        (payload?['error'] as String?)?.trim();
                                    AppToast.error(
                                      context,
                                      (message != null && message.isNotEmpty)
                                          ? message
                                          : l10n.anErrorOccurred,
                                    );
                                  }
                                } catch (err) {
                                  if (context.mounted) {
                                    AppToast.error(
                                      context,
                                      ErrorHandler.getUserFriendlyMessage(err),
                                    );
                                  }
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
          );
        },
      ),
    ),
  );
}

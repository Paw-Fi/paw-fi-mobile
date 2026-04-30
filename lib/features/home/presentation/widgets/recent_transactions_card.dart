import 'dart:async';

import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/recurring/presentation/widgets/upcoming_recurring_banner.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';
import 'package:moneko/features/transactions/presentation/state/transaction_review_providers.dart';

const double _recentTransactionsDashboardFootprintHeight = 410;

Widget buildRecentTransactionsCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> allExpenses,
  UserContact? contact, {
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
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _recentTransactionsDashboardFootprintHeight,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      context.l10n.noTransactionsFound,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  ),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _recentTransactionsDashboardFootprintHeight,
              ),
              child: Column(
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
                                    final uid = Supabase
                                        .instance.client.auth.currentUser?.id;
                                    if (uid == null) {
                                      AppToast.error(
                                          context, l10n.userNotAuthenticated);
                                      return;
                                    }

                                    final rootNavigator = Navigator.of(context,
                                        rootNavigator: true);
                                    final toastContext = rootNavigator.context;
                                    var dialogOpen = false;
                                    void closeDialog() {
                                      if (!dialogOpen) return;
                                      if (rootNavigator.canPop()) {
                                        rootNavigator.pop();
                                      }
                                      dialogOpen = false;
                                    }

                                    // Show loading dialog
                                    showBlockingProcessingDialog(
                                      context: toastContext,
                                      message: '${l10n.delete}...',
                                    );
                                    dialogOpen = true;

                                    try {
                                      final res = await Supabase
                                          .instance.client.functions
                                          .invoke('delete-expense', body: {
                                        'userId': uid,
                                        'expenseIds': e.id,
                                      });

                                      if (!context.mounted) {
                                        closeDialog();
                                        return;
                                      }

                                      closeDialog();

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
                                              .invalidateHouseholdData(
                                                  householdId);
                                          ref.invalidate(
                                              userHouseholdsProvider(uid));
                                          ref.invalidate(
                                              householdExpensesProvider);
                                          ref.invalidate(
                                              cachedHouseholdExpensesProvider);
                                          ref.invalidate(
                                              householdSplitsProvider);
                                          ref.invalidate(
                                              cachedHouseholdSplitsProvider);
                                          ref.invalidate(
                                              householdBudgetsProvider);
                                          ref.invalidate(
                                              householdMembersProvider);
                                        }

                                        // Keep other tabs and the currency selector in sync.
                                        ref.invalidate(pocketsProvider);
                                        ref.invalidate(
                                            currencyTransactionCountsProvider);
                                        ref
                                            .read(dashboardRefreshSignalProvider
                                                .notifier)
                                            .state += 1;
                                        AppToast.success(toastContext,
                                            l10n.transactionDeleted);
                                      } else {
                                        final payload = res.data
                                                is Map<String, dynamic>
                                            ? (res.data as Map<String, dynamic>)
                                            : null;
                                        final message =
                                            (payload?['error'] as String?)
                                                ?.trim();
                                        AppToast.error(
                                          toastContext,
                                          (message != null &&
                                                  message.isNotEmpty)
                                              ? message
                                              : l10n.anErrorOccurred,
                                        );
                                      }
                                    } catch (err) {
                                      closeDialog();
                                      if (context.mounted) {
                                        AppToast.error(
                                          toastContext,
                                          ErrorHandler.getUserFriendlyMessage(
                                              err),
                                        );
                                      }
                                    } finally {
                                      closeDialog();
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
                              trailingWidget: _buildSyncStatusChip(
                                context,
                                e,
                                colorScheme,
                              ),
                              onTap: () {
                                if (e.syncStatus == 'needsReview') {
                                  _showNeedsReviewTransactionSheet(
                                    context,
                                    ref,
                                    e,
                                    contact,
                                    selectedCurrency,
                                  );
                                  return;
                                }

                                showUnifiedTransactionSheet(
                                  context,
                                  existingExpense: e,
                                  contact: contact,
                                );
                              },
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

Widget? _buildSyncStatusChip(
  BuildContext context,
  ExpenseEntry entry,
  ColorScheme colorScheme,
) {
  final status = entry.syncStatus?.trim();
  if (status == null || status.isEmpty || status == 'synced') {
    return null;
  }

  final isFailure = status == 'failed' || status == 'conflict';
  final label = switch (status) {
    'needsReview' => context.l10n.confirm,
    'failed' => context.l10n.retry,
    'conflict' => context.l10n.failed,
    _ => context.l10n.pending,
  };

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isFailure ? colorScheme.errorSurface : colorScheme.warningSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isFailure ? colorScheme.errorBorder : colorScheme.warningBorder,
      ),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: isFailure ? colorScheme.errorAccent : colorScheme.warning,
      ),
    ),
  );
}

Future<void> _showNeedsReviewTransactionSheet(
  BuildContext context,
  WidgetRef ref,
  ExpenseEntry entry,
  UserContact? contact,
  String? selectedCurrency,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final isIncome = (entry.type ?? 'expense').toLowerCase() == 'income';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      var selectedCategory = entry.category?.trim() ?? '';
      var reviewReasons = [...?entry.reviewReasons];

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final hasMissingCategory =
              reviewReasons.contains('missingCategory') ||
                  selectedCategory.trim().isEmpty;
          final displayDateTime = composeTransactionDisplayDateTime(
            transactionDate: entry.date,
            createdAt: entry.createdAt,
            preferredTimezone: contact?.preferredTimezone,
          );

          return Material(
            color: colorScheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.sheetBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIncome
                          ? context.l10n.confirmIncome
                          : context.l10n.confirmExpense,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.sheetElementBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.sheetBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: buildExpenseTransactionTile(
                        context: context,
                        category: selectedCategory.isNotEmpty
                            ? selectedCategory
                            : entry.category,
                        rawText: entry.rawText,
                        date: displayDateTime,
                        amount: entry.amount,
                        currency: selectedCurrency ?? entry.currency ?? 'USD',
                        isIncome: isIncome,
                        dense: false,
                      ),
                    ),
                    if (reviewReasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final reason in reviewReasons)
                            _ReviewReasonChip(reason: reason),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ReviewActionTile(
                      icon: Icons.category_outlined,
                      label: context.l10n.category,
                      value: selectedCategory.isNotEmpty
                          ? selectedCategory
                          : context.l10n.categoryUncategorized,
                      needsAttention: hasMissingCategory,
                      onTap: () async {
                        final next = await showCategoryPicker(
                          context: context,
                          currentCategory: selectedCategory,
                          isIncome: isIncome,
                        );
                        if (next == null || next.trim().isEmpty) return;

                        try {
                          await ref
                              .read(
                                  transactionReviewControllerProvider.notifier)
                              .updateCategory(
                                transactionId: entry.id,
                                category: next,
                              );
                          setSheetState(() {
                            selectedCategory = next.trim().toLowerCase();
                            reviewReasons = reviewReasons
                                .where(
                                  (reason) => reason != 'missingCategory',
                                )
                                .toList(growable: false);
                          });
                        } catch (error) {
                          if (context.mounted) {
                            AppToast.error(
                              context,
                              ErrorHandler.getUserFriendlyMessage(error),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(context.l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: hasMissingCategory
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(
                                            transactionReviewControllerProvider
                                                .notifier,
                                          )
                                          .markReviewed(entry.id);
                                      ref
                                          .read(dashboardRefreshSignalProvider
                                              .notifier)
                                          .state += 1;
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        AppToast.error(
                                          context,
                                          ErrorHandler.getUserFriendlyMessage(
                                              error),
                                        );
                                      }
                                    }
                                  },
                            child: Text(context.l10n.confirm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ReviewReasonChip extends StatelessWidget {
  const _ReviewReasonChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.warningBorder),
      ),
      child: Text(
        _reviewReasonLabel(context, reason),
        style: TextStyle(
          color: colorScheme.warning,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewActionTile extends StatelessWidget {
  const _ReviewActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.needsAttention,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool needsAttention;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.sheetElementBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: needsAttention
                  ? colorScheme.warningBorder
                  : colorScheme.sheetBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    needsAttention ? colorScheme.warning : colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _reviewReasonLabel(BuildContext context, String reason) {
  return switch (reason) {
    'missingCategory' => context.l10n.category,
    'missingWallet' => context.l10n.wallet,
    'lowConfidence' => context.l10n.importIssueLowConfidence,
    _ => context.l10n.attention,
  };
}

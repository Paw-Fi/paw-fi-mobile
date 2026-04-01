import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/pages/account_details_page.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_balance_adjustment_sheet.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_transfer_sheet.dart';
import 'package:moneko/features/accounts/presentation/widgets/create_edit_account_sheet.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(scopedAccountsProvider);
    final actions = ref.watch(accountActionsProvider);
    final analytics = ref.watch(analyticsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final viewMode = ref.watch(viewModeProvider);
    final AsyncValue<List<Household>> householdsAsync =
        viewMode.mode == ViewMode.personal
            ? const AsyncValue<List<Household>>.data(<Household>[])
            : ref.watch(userHouseholdsProvider(ref.watch(authProvider).uid));

    Future<void> onRefresh() async {
      ref.invalidate(scopedAccountsProvider);
      await ref.read(scopedAccountsProvider.future);

      final userId = ref.read(authProvider).uid;
      if (userId.isNotEmpty) {
        await ref.read(analyticsProvider.notifier).loadData(
              userId,
              forceReload: true,
            );
      }
    }

    final scopedTransactions = analytics.allExpenses.where((expense) {
      return _isInActiveScope(expense, householdScope) && !expense.isRecurring;
    }).where((expense) {
      return _isInSelectedCurrency(expense, selectedCurrencyCode);
    }).toList(growable: false);

    final now = DateTime.now();
    final monthExpenses = scopedTransactions.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    });
    var totalIncome = 0.0;
    var totalSpent = 0.0;
    for (final expense in monthExpenses) {
      final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
      if (isIncome) {
        totalIncome += expense.amount.abs();
      } else {
        totalSpent += expense.amount.abs();
      }
    }
    final netWorth = totalIncome - totalSpent;

    Future<void> onAddAccount() async {
      final result = await showCreateEditAccountSheet(context);
      if (result == null) return;
      try {
        await actions.createAccount(
          name: result.name,
          icon: result.icon,
          color: result.color,
          openingBalanceCents: result.openingBalanceCents,
          goalAmountCents: result.goalAmountCents,
          isDefault: result.isDefault,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.save);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onEditAccount(AccountEntity account) async {
      final result =
          await showCreateEditAccountSheet(context, initial: account);
      if (result == null) return;
      try {
        await actions.updateAccount(
          accountId: account.id,
          name: result.name,
          icon: result.icon,
          color: result.color,
          goalAmountCents: result.goalAmountCents,
          includeGoalAmount: true,
          isDefault: result.isDefault,
        );
        if (result.openingBalanceCents != account.currentBalanceCents) {
          await actions.updateBalance(
            accountId: account.id,
            targetBalanceCents: result.openingBalanceCents,
            note: 'Updated from account editor',
          );
        }
        if (context.mounted) {
          AppToast.success(context, context.l10n.saveChanges);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onTransfer(List<AccountEntity> accounts) async {
      final result = await showAccountTransferSheet(
        context,
        accounts: accounts,
      );
      if (result == null) return;
      try {
        await actions.createTransfer(
          fromAccountId: result.fromAccountId,
          toAccountId: result.toAccountId,
          amountCents: result.amountCents,
          currency: selectedCurrencyCode,
          date: result.date,
          note: result.note,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.save);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    return Scaffold(
      floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
          ? const Padding(
              padding: EdgeInsets.all(0),
              child: HomeAiExpandableFab(),
            )
          : null,
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          data: (accounts) {
            final defaultAccountId = _resolveDefaultAccountId(accounts);
            final accountBalances = <String, int>{
              for (final account in accounts)
                account.id: account.openingBalanceCents,
            };
            for (final tx in scopedTransactions) {
              final resolvedAccountId = _resolveTransactionAccountId(
                transaction: tx,
                defaultAccountId: defaultAccountId,
              );
              if (resolvedAccountId == null ||
                  !accountBalances.containsKey(resolvedAccountId)) {
                continue;
              }
              final amountCents = (tx.amount.abs() * 100).round();
              final isIncome = (tx.type ?? 'expense').toLowerCase() == 'income';
              final current = accountBalances[resolvedAccountId] ?? 0;
              accountBalances[resolvedAccountId] =
                  isIncome ? current + amountCents : current - amountCents;
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _AccountsOverviewCard(
                    monthLabel: DateFormat.MMMM().format(now),
                    currencyCode: selectedCurrencyCode,
                    netWorth: netWorth,
                    totalIncome: totalIncome,
                    totalSpent: totalSpent,
                  ),
                  const SizedBox(height: 16),
                  if (accounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.sheetBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.border),
                      ),
                      child: Text(
                        'No accounts yet',
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    ...accounts.map((account) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AccountListTile(
                          account: account,
                          currencyCode: selectedCurrencyCode,
                          displayBalanceCents: accountBalances[account.id] ??
                              account.currentBalanceCents,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AccountDetailsPage(
                                  account: account,
                                ),
                              ),
                            );
                          },
                          onEdit: () => onEditAccount(account),
                          onSetDefault: account.isDefault
                              ? null
                              : () async {
                                  try {
                                    await actions.updateAccount(
                                      accountId: account.id,
                                      isDefault: true,
                                    );
                                    if (context.mounted) {
                                      AppToast.success(
                                        context,
                                        context.l10n.saveChanges,
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      AppToast.error(
                                        context,
                                        ErrorHandler.getUserFriendlyMessage(
                                          error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          onAdjustBalance: () async {
                            final result =
                                await showAccountBalanceAdjustmentSheet(
                              context,
                              account: account,
                            );
                            if (result == null) return;
                            try {
                              await actions.updateBalance(
                                accountId: account.id,
                                targetBalanceCents: result.targetBalanceCents,
                                note: result.note,
                              );
                              if (context.mounted) {
                                AppToast.success(
                                  context,
                                  context.l10n.saveChanges,
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                AppToast.error(
                                  context,
                                  ErrorHandler.getUserFriendlyMessage(error),
                                );
                              }
                            }
                          },
                          onArchive: account.isSystem
                              ? null
                              : () async {
                                  try {
                                    await actions.archiveAccount(account.id);
                                    if (context.mounted) {
                                      AppToast.success(
                                        context,
                                        context.l10n.saveChanges,
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      AppToast.error(
                                        context,
                                        ErrorHandler.getUserFriendlyMessage(
                                          error,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAddAccount,
                    icon: Icon(Icons.add, color: colorScheme.primary),
                    label: Text(
                      'New Account',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (accounts.length > 1)
                    TextButton.icon(
                      onPressed: () => onTransfer(accounts),
                      icon: Icon(Icons.swap_horiz, color: colorScheme.primary),
                      label: Text(
                        'Transfer',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountsOverviewCard extends StatelessWidget {
  const _AccountsOverviewCard({
    required this.monthLabel,
    required this.currencyCode,
    required this.netWorth,
    required this.totalIncome,
    required this.totalSpent,
  });

  final String monthLabel;
  final String currencyCode;
  final double netWorth;
  final double totalIncome;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.pocketHeaderBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.pocketHeaderShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Net Worth',
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  monthLabel,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(netWorth)))}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -1.0,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalIncome,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(totalIncome)))}',
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalSpent,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(totalSpent)))}',
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  const _AccountListTile({
    required this.account,
    required this.currencyCode,
    required this.displayBalanceCents,
    required this.onTap,
    this.onEdit,
    this.onSetDefault,
    this.onAdjustBalance,
    this.onArchive,
  });

  final AccountEntity account;
  final String currencyCode;
  final int displayBalanceCents;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback? onAdjustBalance;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = displayBalanceCents / 100.0;
    final isNegative = amount < 0;

    final goal = (account.goalAmountCents ?? 0) / 100.0;
    final currentProgressAmount = amount < 0 ? 0.0 : amount;

    double progress = 0.0;
    if (goal > 0) {
      progress = (currentProgressAmount / goal).clamp(0.0, 1.0);
    } else if (goal == 0) {
      progress = 1.0;
    }

    final accountColorRaw = account.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseAccountColor(account.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      accountColorRaw,
      colorScheme,
      hasCustomColor: account.color.toUpperCase() != '#6B7280',
    );

    final backgroundTint = colorScheme.pocketTileFill(baseColor);

    return ClipPath(
      clipper: _OrganicAccountTileClipper(),
      child: Material(
        color: backgroundTint,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Placeholder for avatars/icon
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: baseColor.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  resolveAccountIcon(account.icon),
                                  color: baseColor,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'BALANCE THIS MONTH',
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                            style: TextStyle(
                              color: isNegative
                                  ? colorScheme.destructive
                                  : colorScheme.foreground,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ]),
                  ],
                ),

                // Progress Bar Section
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(currentProgressAmount)))}',
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(goal)))}',
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: baseColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _resolveDefaultAccountId(List<AccountEntity> accounts) {
  for (final account in accounts) {
    if (account.isDefault && !account.isArchived) {
      return account.id;
    }
  }
  for (final account in accounts) {
    if (account.isSystem &&
        account.name.trim().toLowerCase() == 'spending' &&
        !account.isArchived) {
      return account.id;
    }
  }
  return accounts.isNotEmpty ? accounts.first.id : null;
}

String? _resolveTransactionAccountId({
  required ExpenseEntry transaction,
  required String? defaultAccountId,
}) {
  final raw = transaction.accountId?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return defaultAccountId;
}

bool _isInSelectedCurrency(ExpenseEntry expense, String currencyCode) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == currencyCode;
}

class _OrganicAccountTileClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const radius = 24.0;
    const dipDepth = 16.0;
    final path = Path();

    // Math to keep the hole perfectly centered at exactly 50% width
    final double holeCenter = size.width * 0.50;
    final double holeHalfWidth = size.width * 0.16;
    final double flatBottomHalfWidth = size.width * 0.03;

    final double startX = holeCenter - holeHalfWidth;
    final double flatStartX = holeCenter - flatBottomHalfWidth;
    final double flatEndX = holeCenter + flatBottomHalfWidth;
    final double endX = holeCenter + holeHalfWidth;

    final double curveWidth = flatStartX - startX;
    final double cpOffset =
        curveWidth * 0.45; // Creates a smooth curve interpolation

    path.moveTo(radius, 0);
    // Straight top edge on the left
    path.lineTo(startX, 0);

    // Smooth step down (left curve)
    path.cubicTo(
      startX + cpOffset,
      0,
      flatStartX - cpOffset,
      dipDepth,
      flatStartX,
      dipDepth,
    );

    // Small flat bottom of the dip
    path.lineTo(flatEndX, dipDepth);

    // Smooth step up (right curve)
    path.cubicTo(
      flatEndX + cpOffset,
      dipDepth,
      endX - cpOffset,
      0,
      endX,
      0,
    );

    // Straight top edge on the right
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

bool _isInActiveScope(ExpenseEntry expense, HouseholdScope scope) {
  final householdId = expense.householdId;
  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      return householdId == null || householdId.isEmpty;
    case ActiveAccountType.portfolio:
      final selected = scope.activeAccountHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
    case ActiveAccountType.household:
      final selected = scope.selectedHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
  }
}

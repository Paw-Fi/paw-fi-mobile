import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/accounts/presentation/widgets/create_edit_account_sheet.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({
    super.key,
    required this.account,
    required this.currencyCode,
  });

  final AccountEntity account;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.watch(accountActionsProvider);
    final allExpenses = ref.watch(analyticsProvider).allExpenses;
    final householdScope = ref.watch(householdScopeProvider);
    final accountColor = parseAccountColor(account.color, colorScheme.primary);
    final gradientColors =
        AppTheme.pocketDetailsGradient(accountColor, colorScheme);
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor =
        isBackgroundLight ? AppTheme.lightMuted : AppTheme.darkMutedForeground;

    final scopedExpenses = allExpenses.where((expense) {
      return _isInActiveScope(expense, householdScope) &&
          (expense.accountId == account.id);
    }).toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final now = DateTime.now();
    final monthExpenses = scopedExpenses.where((expense) {
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
    final net = totalIncome - totalSpent;

    final symbol = resolveCurrencySymbol(currencyCode);

    Future<void> onEdit() async {
      final result =
          await showCreateEditAccountSheet(context, initial: account);
      if (result == null) return;
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
    }

    return Scaffold(
      backgroundColor: gradientColors.first,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.edit, color: textColor),
                    onPressed: onEdit,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              resolveAccountIcon(account.icon),
                              color: textColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            account.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.balanceSummary,
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatAmount(
                              context,
                              account.currentBalanceCents / 100.0,
                              currencyCode,
                            ),
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -1,
                            ),
                          ),
                          if (account.goalAmountCents != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${context.l10n.balanceSummary} ${_formatAmount(context, account.goalAmountCents! / 100.0, currencyCode)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.sheetBackground,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.keyInsights,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: context.l10n.totalIncome,
                                value:
                                    '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(totalIncome)))}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: context.l10n.totalSpent,
                                value:
                                    '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(totalSpent)))}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Net',
                                value:
                                    '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(net)))}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.recentTransactions,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: scopedExpenses.isEmpty
                              ? Center(
                                  child: Text(
                                    context.l10n.noTransactionsYet,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: scopedExpenses.length > 8
                                      ? 8
                                      : scopedExpenses.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: colorScheme.border,
                                  ),
                                  itemBuilder: (context, index) {
                                    final expense = scopedExpenses[index];
                                    final isIncome =
                                        (expense.type ?? 'expense') == 'income';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        expense.rawText?.trim().isNotEmpty ==
                                                true
                                            ? expense.rawText!.trim()
                                            : expense.category ??
                                                context.l10n.expense,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        DateFormat.MMMd().format(expense.date),
                                      ),
                                      trailing: Text(
                                        '${isIncome ? '+' : '-'}${_formatAmount(context, expense.amount.abs(), currencyCode)}',
                                        style: TextStyle(
                                          color: isIncome
                                              ? colorScheme.success
                                              : colorScheme.foreground,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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

String _formatAmount(BuildContext context, double amount, String currencyCode) {
  final symbol = resolveCurrencySymbol(currencyCode);
  final normalized = double.parse(formatAmount(amount));
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

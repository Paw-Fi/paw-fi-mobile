import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/accounts/presentation/widgets/create_edit_account_sheet.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class AccountDetailsPage extends HookConsumerWidget {
  const AccountDetailsPage({
    super.key,
    required this.account,
  });

  final AccountEntity account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.watch(accountActionsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final providerAccount = ref.watch(accountByIdProvider(account.id));
    final serverAccount = ref.watch(serverAccountByIdProvider(account.id));
    final latestDisplayedAccountState = useState<AccountEntity>(account);

    useEffect(() {
      if (providerAccount != null) {
        debugPrint(
          '[AccountDetails] providerAccount accountId=${providerAccount.id} name=${providerAccount.name} color=${providerAccount.color} opening=${providerAccount.openingBalanceCents} current=${providerAccount.currentBalanceCents}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final latestServerAccount =
              ref.read(serverAccountByIdProvider(account.id));
          if (latestServerAccount == null) {
            return;
          }
          actions.reconcileOptimisticAccountWithServer(latestServerAccount);
        });
        latestDisplayedAccountState.value = providerAccount;
      } else {
        final cached = latestDisplayedAccountState.value;
        debugPrint(
          '[AccountDetails] providerAccount=null fallbackToCached accountId=${cached.id} name=${cached.name} color=${cached.color} opening=${cached.openingBalanceCents} current=${cached.currentBalanceCents}',
        );
      }
      return null;
    }, [providerAccount, serverAccount]);

    final latestAccount = providerAccount ?? latestDisplayedAccountState.value;
    final householdScope = ref.watch(householdScopeProvider);
    final scopedAccounts = ref.watch(scopedAccountsProvider).valueOrNull ??
        const <AccountEntity>[];
    final defaultAccountId = _resolveDefaultAccountId(scopedAccounts);
    final isDefaultResolvedAccount = latestAccount.id == defaultAccountId;

    final effectiveHouseholdId = _resolveScopedHouseholdId(householdScope);
    final accountFeedQuery = TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: selectedCurrencyCode,
      selectedCategory: null,
      selectedAccountId: latestAccount.id,
      selectedCategories: null,
      includeUnassignedAccount: isDefaultResolvedAccount,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: null,
    );
    final accountFeedState =
        ref.watch(transactionsFeedProvider(accountFeedQuery));

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthFeedQuery = accountFeedQuery.copyWith(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final monthFeedState = ref.watch(transactionsFeedProvider(monthFeedQuery));

    final scopedExpenses = accountFeedState.items;
    final accountColor =
        parseAccountColor(latestAccount.color, colorScheme.primary);
    final gradientColors =
        AppTheme.pocketDetailsGradient(accountColor, colorScheme);
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor =
        isBackgroundLight ? AppTheme.lightMuted : AppTheme.darkMutedForeground;

    final currentBalanceCents = latestAccount.openingBalanceCents +
        ((accountFeedState.summary.incomeTotal -
                    accountFeedState.summary.expenseTotal) *
                100)
            .round();
    final totalIncome = monthFeedState.summary.incomeTotal;
    final totalSpent = monthFeedState.summary.expenseTotal;

    final net = totalIncome - totalSpent;

    final symbol = resolveCurrencySymbol(selectedCurrencyCode);

    Future<void> onEdit() async {
      final result =
          await showCreateEditAccountSheet(context, initial: latestAccount);
      if (result == null) return;

      debugPrint(
        '[AccountDetails][Edit] save tapped accountId=${latestAccount.id} name=${result.name} icon=${result.icon} color=${result.color} opening=${result.openingBalanceCents} goal=${result.goalAmountCents} isDefault=${result.isDefault}',
      );

      final optimisticAccount = _copyAccount(
        latestAccount,
        name: result.name,
        icon: result.icon,
        color: result.color,
        goalAmountCents: result.goalAmountCents,
        isDefault: result.isDefault,
        openingBalanceCents: result.openingBalanceCents,
        currentBalanceCents: result.openingBalanceCents,
      );

      actions.setOptimisticAccount(optimisticAccount);

      if (context.mounted) {
        AppToast.success(context, context.l10n.saveChanges);
      }

      try {
        await actions.updateAccount(
          accountId: latestAccount.id,
          name: result.name,
          icon: result.icon,
          color: result.color,
          goalAmountCents: result.goalAmountCents,
          includeGoalAmount: true,
          isDefault: result.isDefault,
          invalidate: false,
        );
        if (result.openingBalanceCents != latestAccount.currentBalanceCents) {
          debugPrint(
            '[AccountDetails][Edit] updateBalance needed accountId=${latestAccount.id} fromCurrent=${latestAccount.currentBalanceCents} toTarget=${result.openingBalanceCents}',
          );
          await actions.updateBalance(
            accountId: latestAccount.id,
            targetBalanceCents: result.openingBalanceCents,
            note: 'Updated from account editor',
            invalidate: false,
          );
        }
        debugPrint(
            '[AccountDetails][Edit] refreshAccountData accountId=${latestAccount.id}');
        actions.refreshAccountData();
      } catch (error) {
        debugPrint(
            '[AccountDetails][Edit] error accountId=${latestAccount.id} error=$error');
        actions.clearOptimisticAccount(latestAccount.id);
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onArchive() async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: 'Archive this account?',
        description:
            'You can only archive accounts with no transactions or transfers. This account will be hidden from active lists.',
        confirmLabel: 'Archive',
        cancelLabel: context.l10n.cancel,
      );

      if (confirm?.confirmed != true || !context.mounted) return;

      try {
        await actions.archiveAccount(latestAccount.id);
        if (!context.mounted) return;
        AppToast.success(context, 'Account archived successfully');
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
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
          AutoPaginatedScroll(
            hasMore: accountFeedState.hasMore,
            isLoading: accountFeedState.isLoading,
            isLoadingMore: accountFeedState.isLoadingMore,
            onLoadMore: () {
              ref
                  .read(transactionsFeedProvider(accountFeedQuery).notifier)
                  .loadMore();
            },
            child: CustomScrollView(
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
                    if (!latestAccount.isSystem && !latestAccount.isArchived)
                      IconButton(
                        icon: Icon(Icons.archive_outlined, color: textColor),
                        onPressed: onArchive,
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
                                resolveAccountIcon(latestAccount.icon),
                                color: textColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              latestAccount.name,
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
                                currentBalanceCents / 100.0,
                                selectedCurrencyCode,
                              ),
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -1,
                              ),
                            ),
                            if (latestAccount.goalAmountCents != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${context.l10n.balanceSummary} ${_formatAmount(context, latestAccount.goalAmountCents! / 100.0, selectedCurrencyCode)}',
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
                          if (accountFeedState.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (accountFeedState.error != null)
                            Center(
                              child: Text(
                                context.l10n.error(accountFeedState.error!),
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            )
                          else if (scopedExpenses.isEmpty)
                            Center(
                              child: Text(
                                context.l10n.noTransactionsYet,
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            )
                          else
                            GroupedTransactionsList(
                              transactions: scopedExpenses,
                              currency: selectedCurrencyCode,
                            ),
                          PaginatedLoadMoreIndicator(
                            show: accountFeedState.isLoadingMore,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

AccountEntity _copyAccount(
  AccountEntity source, {
  String? name,
  String? icon,
  String? color,
  int? openingBalanceCents,
  int? goalAmountCents,
  bool? isDefault,
  int? currentBalanceCents,
}) {
  return AccountEntity(
    id: source.id,
    userId: source.userId,
    householdId: source.householdId,
    name: name ?? source.name,
    icon: icon ?? source.icon,
    color: color ?? source.color,
    openingBalanceCents: openingBalanceCents ?? source.openingBalanceCents,
    goalAmountCents: goalAmountCents,
    isDefault: isDefault ?? source.isDefault,
    isSystem: source.isSystem,
    isArchived: source.isArchived,
    currentBalanceCents: currentBalanceCents ?? source.currentBalanceCents,
  );
}

String? _resolveScopedHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      return null;
    case ActiveAccountType.portfolio:
      final householdId = scope.activeAccountHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
    case ActiveAccountType.household:
      final householdId = scope.selectedHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
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

String _formatAmount(BuildContext context, double amount, String currencyCode) {
  final symbol = resolveCurrencySymbol(currencyCode);
  final normalized = double.parse(formatAmount(amount));
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

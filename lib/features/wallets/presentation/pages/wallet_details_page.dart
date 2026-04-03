import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class WalletDetailsPage extends HookConsumerWidget {
  const WalletDetailsPage({
    super.key,
    required this.wallet,
  });

  final WalletEntity wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.watch(walletActionsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final providerAccount = ref.watch(walletByIdProvider(wallet.id));
    final serverAccount = ref.watch(serverWalletByIdProvider(wallet.id));
    final latestDisplayedAccountState = useState<WalletEntity>(wallet);

    useEffect(() {
      if (providerAccount != null) {
        debugPrint(
          '[AccountDetails] providerAccount accountId=${providerAccount.id} name=${providerAccount.name} color=${providerAccount.color} opening=${providerAccount.openingBalanceCents} current=${providerAccount.currentBalanceCents}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final latestServerAccount =
              ref.read(serverWalletByIdProvider(wallet.id));
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

    final latestWallet = providerAccount ?? latestDisplayedAccountState.value;
    final householdScope = ref.watch(householdScopeProvider);
    final scopedAccounts = ref.watch(scopedWalletsProvider).valueOrNull ??
        const <WalletEntity>[];
    final defaultAccountId = _resolveDefaultAccountId(scopedAccounts);
    final isDefaultResolvedAccount = latestWallet.id == defaultAccountId;

    final effectiveHouseholdId = _resolveScopedHouseholdId(householdScope);
    final walletFeedQuery = TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: selectedCurrencyCode,
      selectedCategory: null,
      selectedAccountId: latestWallet.id,
      selectedCategories: null,
      includeUnassignedAccount: isDefaultResolvedAccount,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: null,
    );
    final walletFeedState =
        ref.watch(transactionsFeedProvider(walletFeedQuery));

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthFeedQuery = walletFeedQuery.copyWith(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final monthFeedState = ref.watch(transactionsFeedProvider(monthFeedQuery));

    final scopedExpenses = walletFeedState.items;
    final walletColor =
        parseAccountColor(latestWallet.color, colorScheme.primary);
    final gradientColors =
        AppTheme.pocketDetailsGradient(walletColor, colorScheme);
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor =
        isBackgroundLight ? AppTheme.lightMuted : AppTheme.darkMutedForeground;

    final currentBalanceCents = latestWallet.openingBalanceCents +
        ((walletFeedState.summary.incomeTotal -
                    walletFeedState.summary.expenseTotal) *
                100)
            .round();
    final totalIncome = monthFeedState.summary.incomeTotal;
    final totalSpent = monthFeedState.summary.expenseTotal;

    final net = totalIncome - totalSpent;

    final symbol = resolveCurrencySymbol(selectedCurrencyCode);

    Future<void> onEdit() async {
      final result =
          await showCreateEditWalletSheet(context, initial: latestWallet);
      if (result == null) return;

      debugPrint(
        '[AccountDetails][Edit] save tapped accountId=${latestWallet.id} name=${result.name} icon=${result.icon} color=${result.color} opening=${result.openingBalanceCents} goal=${result.goalAmountCents} isDefault=${result.isDefault}',
      );

      final optimisticAccount = _copyAccount(
        latestWallet,
        name: result.name,
        icon: result.icon,
        color: result.color,
        goalAmountCents: result.goalAmountCents,
        isDefault: result.isDefault,
        openingBalanceCents: result.openingBalanceCents,
        currentBalanceCents: result.openingBalanceCents,
      );

      actions.setOptimisticWallet(optimisticAccount);

      if (context.mounted) {
        AppToast.success(context, context.l10n.saveChanges);
      }

      try {
        await actions.updateAccount(
          walletId: latestWallet.id,
          name: result.name,
          icon: result.icon,
          color: result.color,
          goalAmountCents: result.goalAmountCents,
          includeGoalAmount: true,
          isDefault: result.isDefault,
          invalidate: false,
        );
        if (result.openingBalanceCents != latestWallet.currentBalanceCents) {
          debugPrint(
            '[AccountDetails][Edit] updateBalance needed accountId=${latestWallet.id} fromCurrent=${latestWallet.currentBalanceCents} toTarget=${result.openingBalanceCents}',
          );
          await actions.updateBalance(
            walletId: latestWallet.id,
            targetBalanceCents: result.openingBalanceCents,
            note: 'Updated from wallet editor',
            invalidate: false,
          );
        }
        debugPrint(
            '[AccountDetails][Edit] refreshAccountData accountId=${latestWallet.id}');
        actions.refreshAccountData();
      } catch (error) {
        debugPrint(
            '[AccountDetails][Edit] error accountId=${latestWallet.id} error=$error');
        actions.clearOptimisticWallet(latestWallet.id);
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onArchive() async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: 'Archive this wallet?',
        description:
            'You can only archive wallets with no transactions or transfers. This wallet will be hidden from active lists.',
        confirmLabel: 'Archive',
        cancelLabel: context.l10n.cancel,
      );

      if (confirm?.confirmed != true || !context.mounted) return;

      try {
        await actions.archiveAccount(latestWallet.id);
        if (!context.mounted) return;
        AppToast.success(context, 'Account archived successfully');
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    Future<void> onTransfer() async {
      // Get all wallets for transfer selection
      final scopedAccounts = ref.read(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
      if (scopedAccounts.length < 2) {
        AppToast.info(context, 'You need at least two wallets to make a transfer');
        return;
      }

      final result = await showWalletTransferSheet(
        context,
        wallets: scopedAccounts,
        defaultFromWalletId: latestWallet.id,
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
        // Refresh wallet data after successful transfer
        actions.refreshAccountData();
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    return Scaffold(
      backgroundColor: gradientColors.first,
      floatingActionButton: !latestWallet.isArchived
          ? Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: FloatingActionButton.extended(
                onPressed: onTransfer,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Transfer'),
              ),
            )
          : null,
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
            hasMore: walletFeedState.hasMore,
            isLoading: walletFeedState.isLoading,
            isLoadingMore: walletFeedState.isLoadingMore,
            onLoadMore: () {
              ref
                  .read(transactionsFeedProvider(walletFeedQuery).notifier)
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
                    if (!latestWallet.isSystem && !latestWallet.isArchived)
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
                                resolveWalletIcon(latestWallet.icon),
                                color: textColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              latestWallet.name,
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
                            if (latestWallet.goalAmountCents != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${context.l10n.balanceSummary} ${_formatAmount(context, latestWallet.goalAmountCents! / 100.0, selectedCurrencyCode)}',
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
                          if (walletFeedState.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (walletFeedState.error != null)
                            Center(
                              child: Text(
                                context.l10n.error(walletFeedState.error!),
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
                            show: walletFeedState.isLoadingMore,
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

WalletEntity _copyAccount(
  WalletEntity source, {
  String? name,
  String? icon,
  String? color,
  int? openingBalanceCents,
  int? goalAmountCents,
  bool? isDefault,
  int? currentBalanceCents,
}) {
  return WalletEntity(
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
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      final householdId = scope.activeAccountHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
    case ActiveWalletType.household:
      final householdId = scope.selectedHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
  }
}

String? _resolveDefaultAccountId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault && !wallet.isArchived) {
      return wallet.id;
    }
  }
  for (final wallet in wallets) {
    if (wallet.isSystem &&
        wallet.name.trim().toLowerCase() == 'spending' &&
        !wallet.isArchived) {
      return wallet.id;
    }
  }
  return wallets.isNotEmpty ? wallets.first.id : null;
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

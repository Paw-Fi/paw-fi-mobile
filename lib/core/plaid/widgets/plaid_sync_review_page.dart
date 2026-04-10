import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaidSyncReviewPage extends ConsumerStatefulWidget {
  const PlaidSyncReviewPage({
    super.key,
    required this.session,
  });

  final BankSyncReviewSession session;

  @override
  ConsumerState<PlaidSyncReviewPage> createState() =>
      _PlaidSyncReviewPageState();
}

class _PlaidSyncReviewPageState extends ConsumerState<PlaidSyncReviewPage> {
  late List<BankSyncReviewAccount> _accounts;
  late String _selectedBankAccountId;
  List<SyncedTransaction> _transactions = const [];
  PlaidSyncStatus? _syncStatus;
  bool _isPreparing = true;
  bool _isUpdatingWallet = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _accounts = widget.session.accounts;
    _selectedBankAccountId =
        _accounts.isEmpty ? '' : _accounts.first.bankAccountId;
    unawaited(_prepareReview());
  }

  BankSyncReviewAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.bankAccountId == _selectedBankAccountId) {
        return account;
      }
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  List<SyncedTransaction> get _selectedTransactions {
    final selected = _selectedAccount;
    if (selected == null) {
      return const [];
    }

    return _transactions
        .where((tx) => tx.expense.bankAccountId == selected.bankAccountId)
        .toList(growable: false);
  }

  Future<void> _prepareReview() async {
    if (!mounted) return;
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      await _ensureLinkedWallets();
      final result = await _syncTransactions();
      final resolvedCurrency = _resolveCurrencyCode(result.transactions);

      ref.read(bankSyncResultProvider.notifier).state = BankSyncResult(
        currencyCode: resolvedCurrency,
      );
      try {
        await _refreshAfterSync();
      } catch (error) {
        if (mounted) {
          AppToast.error(context, error.toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _syncStatus = result.syncStatus;
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _ensureLinkedWallets() async {
    final client = Supabase.instance.client;
    final updatedAccounts = <BankSyncReviewAccount>[];

    for (final account in _accounts) {
      if (account.hasLinkedWallet) {
        updatedAccounts.add(account);
        continue;
      }

      final response = await client.functions.invoke(
        'save-wallet',
        body: {
          'name': account.walletName,
          'icon': account.walletIcon,
          'color': account.walletColor,
          'openingBalanceCents': account.openingBalanceCents,
          'goalAmountCents': account.goalAmountCents,
          'isDefault': account.isDefault,
          'linkedBankAccountId': account.bankAccountId,
          if (widget.session.targetHouseholdId != null)
            'householdId': widget.session.targetHouseholdId,
        },
      );

      final payload = response.data as Map<String, dynamic>?;
      if (response.status >= 400 ||
          payload == null ||
          payload['success'] != true) {
        final message =
            payload?['error']?.toString() ?? 'Failed to create linked wallet';
        throw Exception(message);
      }

      final walletData = payload['data'] as Map<String, dynamic>?;
      final updatedAccount = account.copyWith(
        walletId: walletData?['id'] as String?,
        walletName: (walletData?['name'] as String?)?.trim(),
        walletIcon: (walletData?['icon'] as String?)?.trim(),
        walletColor: (walletData?['color'] as String?)?.trim(),
        goalAmountCents: (walletData?['goal_amount_cents'] as num?)?.round(),
        openingBalanceCents:
            (walletData?['opening_balance_cents'] as num?)?.round(),
        isDefault: walletData?['is_default'] == true,
      );
      updatedAccounts.add(updatedAccount);
      _accounts = List<BankSyncReviewAccount>.from(updatedAccounts)
        ..addAll(_accounts.skip(updatedAccounts.length));
    }

    _accounts = updatedAccounts;
  }

  Future<ParsedSyncedTransactions> _syncTransactions() async {
    final client = Supabase.instance.client;
    final functionName = widget.session.provider == 'tink'
        ? 'tink-sync-transactions'
        : 'plaid-sync-transactions';

    final response = await client.functions.invoke(
      functionName,
      body: {
        'connectionId': widget.session.connectionId,
        if (widget.session.targetHouseholdId != null)
          'targetHouseholdId': widget.session.targetHouseholdId,
      },
    );

    if (response.status >= 400) {
      final payload = response.data as Map<String, dynamic>?;
      final message =
          payload?['error']?.toString() ?? 'Failed to sync bank transactions';
      throw Exception(message);
    }

    return parseSyncedTransactionPayload(response.data);
  }

  Future<void> _refreshAfterSync() async {
    final user = ref.read(authProvider);
    if (user.uid.isEmpty) return;

    ref.read(walletActionsProvider).refreshAccountData();
    ref.invalidate(currencyTransactionCountsProvider);
    ref.invalidate(pocketsProvider);
    if (widget.session.targetHouseholdId != null) {
      ref.invalidate(userHouseholdsProvider(user.uid));
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdMembersProvider);
    }
    await ref
        .read(recurringTransactionsProvider(widget.session.targetHouseholdId)
            .notifier)
        .refresh(user.uid);
    await ref.read(analyticsProvider.notifier).loadData(
          user.uid,
          forceReload: true,
        );
  }

  Future<void> _editSelectedWallet() async {
    final selected = _selectedAccount;
    if (selected == null || !selected.hasLinkedWallet) {
      return;
    }

    final user = ref.read(authProvider);
    final result = await showCreateEditWalletSheet(
      context,
      initial: WalletEntity(
        id: selected.walletId!,
        userId: user.uid,
        householdId: widget.session.targetHouseholdId,
        name: selected.walletName,
        icon: selected.walletIcon,
        color: selected.walletColor,
        openingBalanceCents: selected.openingBalanceCents,
        goalAmountCents: selected.goalAmountCents,
        isDefault: selected.isDefault,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 0,
      ),
    );

    if (result == null) return;

    setState(() => _isUpdatingWallet = true);
    try {
      await ref.read(walletActionsProvider).updateAccount(
            walletId: selected.walletId!,
            name: result.name,
            icon: result.icon,
            color: result.color,
            openingBalanceCents: result.openingBalanceCents,
            goalAmountCents: result.goalAmountCents,
            includeGoalAmount: true,
            isDefault: result.isDefault,
          );

      if (!mounted) return;
      setState(() {
        _accounts = _accounts.map((account) {
          if (account.bankAccountId != selected.bankAccountId) {
            return account;
          }

          return account.copyWith(
            walletName: result.name,
            walletIcon: result.icon,
            walletColor: result.color,
            openingBalanceCents: result.openingBalanceCents,
            goalAmountCents: result.goalAmountCents,
            isDefault: result.isDefault,
          );
        }).toList(growable: false);
        _isUpdatingWallet = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingWallet = false);
      AppToast.error(context, error.toString());
    }
  }

  Future<void> _deleteTransaction(SyncedTransaction transaction) async {
    final user = ref.read(authProvider);
    final response = await Supabase.instance.client.functions.invoke(
      'delete-expense',
      body: {
        'userId': user.uid,
        'expenseIds': transaction.expense.id,
      },
    );

    final payload = response.data as Map<String, dynamic>?;
    final success = response.status < 400 &&
        (payload?['success'] == true || payload == null);
    if (!success) {
      final message =
          payload?['error']?.toString() ?? 'Failed to delete transaction';
      if (!mounted) return;
      AppToast.error(context, message);
      return;
    }

    if (!mounted) return;
    setState(() {
      _transactions = _transactions
          .where((item) => item.expense.id != transaction.expense.id)
          .toList(growable: false);
    });
  }

  Future<void> _editTransaction(SyncedTransaction transaction) async {
    await showUnifiedTransactionSheet(
      context,
      existingExpense: transaction.expense,
    );

    final refreshedExpense = await _fetchExpense(transaction.expense.id);
    if (!mounted) return;

    setState(() {
      if (refreshedExpense == null) {
        _transactions = _transactions
            .where((item) => item.expense.id != transaction.expense.id)
            .toList(growable: false);
        return;
      }

      _transactions = _transactions.map((item) {
        if (item.expense.id != transaction.expense.id) {
          return item;
        }

        return SyncedTransaction(
          expense: refreshedExpense,
          isRecurring: refreshedExpense.isRecurring,
          recurrenceRule: item.recurrenceRule,
        );
      }).toList(growable: false);
    });
  }

  Future<ExpenseEntry?> _fetchExpense(String expenseId) async {
    final row = await Supabase.instance.client
        .from('expenses')
        .select(
          'id, contact_id, user_id, household_id, date, amount_cents, currency, '
          'category, created_at, updated_at, raw_text, split_group_id, '
          'bank_account_id, account_id, type, is_recurring',
        )
        .eq('id', expenseId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ExpenseEntry.fromJson(row);
  }

  Future<void> _handleDone() async {
    if (_isPreparing || _isUpdatingWallet) {
      return;
    }
    try {
      await _refreshAfterSync();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedAccount;
    final grouped = _groupByMonth(_selectedTransactions);
    final monthKeys = grouped.keys.toList()
      ..sort((a, b) => b.asDate.compareTo(a.asDate));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isPreparing || _isUpdatingWallet) {
          return;
        }
        unawaited(_handleDone());
      },
      child: Scaffold(
        backgroundColor: colorScheme.appBackground,
        appBar: AppBar(
          backgroundColor: colorScheme.appBackground,
          elevation: 0,
          leading: IconButton(
            onPressed: _isPreparing || _isUpdatingWallet
                ? null
                : () => unawaited(_handleDone()),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: Text(
            selected == null ? context.l10n.transactions : selected.walletName,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_accounts.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        final isSelected =
                            account.bankAccountId == _selectedBankAccountId;
                        return ChoiceChip(
                          label: Text(account.displayName),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedBankAccountId = account.bankAccountId;
                            });
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: _accounts.length,
                    ),
                  ),
                ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _WalletReviewCard(
                    account: selected,
                    isBusy: _isPreparing || _isUpdatingWallet,
                    onEdit: _editSelectedWallet,
                  ),
                ),
              if (!_isPreparing &&
                  _errorMessage == null &&
                  widget.session.provider == 'plaid' &&
                  (_syncStatus?.historicalUpdateComplete != true))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _HistoricalSyncStatusCard(syncStatus: _syncStatus),
                ),
              Expanded(
                child: _errorMessage != null
                    ? _ReviewErrorState(
                        message: _errorMessage!,
                        onRetry: _prepareReview,
                      )
                    : _isPreparing
                        ? _ReviewLoadingState(
                            accountName: selected?.walletName,
                          )
                        : _selectedTransactions.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    context.l10n.noTransactionsFound,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                ),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 0),
                                children: [
                                  for (final month in monthKeys)
                                    _MonthSection(
                                      title: DateFormat('MMMM yyyy')
                                          .format(month.asDate),
                                      transactions: grouped[month]!,
                                      onDelete: _deleteTransaction,
                                      onEdit: _editTransaction,
                                    ),
                                ],
                              ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _handleDone,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(context.l10n.done),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricalSyncStatusCard extends StatelessWidget {
  const _HistoricalSyncStatusCard({
    required this.syncStatus,
  });

  final PlaidSyncStatus? syncStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initialComplete = syncStatus?.initialUpdateComplete;
    final title = initialComplete == false
        ? 'Plaid is still preparing your first transaction download.'
        : 'Recent transactions are ready. Historical imports may still be syncing.';
    final description = initialComplete == false
        ? 'Keep this wallet connected. We will continue importing your bank history in the background as Plaid finishes the initial pull.'
        : 'Your newest activity is available now. Older history can continue appearing in the background until Plaid finishes the full backfill.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    height: 1.4,
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

class _WalletReviewCard extends StatelessWidget {
  const _WalletReviewCard({
    required this.account,
    required this.isBusy,
    required this.onEdit,
  });

  final BankSyncReviewAccount account;
  final bool isBusy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor =
        parseWalletColor(account.walletColor, colorScheme.primary);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.border),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolveWalletIcon(account.walletIcon),
                  color: baseColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.walletName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isBusy ? null : onEdit,
                child: Text(context.l10n.edit),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WalletMetaChip(
                label: account.currency,
                colorScheme: colorScheme,
              ),
              if (account.subtype != null)
                _WalletMetaChip(
                  label: account.subtype!,
                  colorScheme: colorScheme,
                ),
              if (account.isDefault)
                _WalletMetaChip(
                  label: context.l10n.primary,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletMetaChip extends StatelessWidget {
  const _WalletMetaChip({
    required this.label,
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewLoadingState extends StatelessWidget {
  const _ReviewLoadingState({
    required this.accountName,
  });

  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              accountName == null
                  ? 'Preparing your bank sync...'
                  : 'Syncing transactions into $accountName...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We are creating your wallet links and importing recent transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewErrorState extends StatelessWidget {
  const _ReviewErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.destructive,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.foreground),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

Map<_MonthKey, List<SyncedTransaction>> _groupByMonth(
  List<SyncedTransaction> items,
) {
  final map = <_MonthKey, List<SyncedTransaction>>{};
  for (final tx in items) {
    final key = _MonthKey(tx.expense.date.year, tx.expense.date.month);
    map.putIfAbsent(key, () => []).add(tx);
  }
  for (final entry in map.entries) {
    entry.value.sort((a, b) => b.expense.date.compareTo(a.expense.date));
  }
  return map;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.title,
    required this.transactions,
    required this.onDelete,
    required this.onEdit,
  });

  final String title;
  final List<SyncedTransaction> transactions;
  final Future<void> Function(SyncedTransaction) onDelete;
  final Future<void> Function(SyncedTransaction) onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.0),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          iconColor: colorScheme.mutedForeground,
          collapsedIconColor: colorScheme.mutedForeground,
          initiallyExpanded: true,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          children: [
            for (final tx in transactions)
              Slidable(
                key: ValueKey(tx.expense.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.22,
                  children: [
                    SlidableAction(
                      onPressed: (_) => onDelete(tx),
                      backgroundColor: colorScheme.destructive,
                      foregroundColor: colorScheme.onError,
                      icon: Icons.delete,
                      label: context.l10n.delete,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TransactionListTile(
                    onTap: () => onEdit(tx),
                    category: tx.expense.category ?? 'other',
                    title: getCategoryTranslation(
                      context,
                      tx.expense.category ?? 'other',
                    ),
                    description: tx.expense.rawText,
                    date: tx.expense.date,
                    amount: tx.expense.amount,
                    currency: tx.expense.currency ?? 'USD',
                    isIncome: (tx.expense.type ?? 'expense').toLowerCase() ==
                        'income',
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MonthKey {
  _MonthKey(this.year, this.month);

  final int year;
  final int month;

  DateTime get asDate => DateTime(year, month, 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MonthKey && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

String? _resolveCurrencyCode(List<SyncedTransaction> transactions) {
  for (final transaction in transactions) {
    final currency = transaction.expense.currency?.trim().toUpperCase();
    if (currency != null && currency.isNotEmpty) {
      return currency;
    }
  }
  return null;
}

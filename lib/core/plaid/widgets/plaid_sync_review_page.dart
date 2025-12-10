import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/theme/app_theme.dart';

class PlaidSyncReviewPage extends StatelessWidget {
  const PlaidSyncReviewPage({
    super.key,
    required this.transactions,
    required this.onDelete,
    required this.onEdit,
    required this.onFinish,
  });

  final List<SyncedTransaction> transactions;
  final Future<void> Function(SyncedTransaction) onDelete;
  final Future<void> Function(SyncedTransaction) onEdit;
  final VoidCallback onFinish;

  Future<bool> _promptRestart(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            context.l10n.attention,
            style: TextStyle(color: colorScheme.foreground),
          ),
          content: Text(
            'Please restart the app to see your synced transactions.',
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                context.l10n.ok,
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      onFinish();
      await SystemNavigator.pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupByMonth(transactions);
    final monthKeys = grouped.keys.toList()
      ..sort((a, b) => b.asDate.compareTo(a.asDate));

    final isEmpty = transactions.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _promptRestart(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => _promptRestart(context),
          ),
          title: Text(context.l10n.transactions),
          backgroundColor: colorScheme.appBackground,
          elevation: 0,
        ),
        backgroundColor: colorScheme.appBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        context.l10n.noTransactionsFound,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final month in monthKeys)
                        _MonthSection(
                          title: DateFormat('MMMM yyyy').format(month.asDate),
                          transactions: grouped[month]!,
                          onDelete: onDelete,
                          onEdit: onEdit,
                        ),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => _promptRestart(context),
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

  Map<_MonthKey, List<SyncedTransaction>> _groupByMonth(List<SyncedTransaction> items) {
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
    return Card(
      color: colorScheme.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: AdaptiveExpansionTile(
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
                    backgroundColor: const Color(0xFFFE4A49),
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: context.l10n.delete,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              child: TransactionListTile(
                onTap: () => onEdit(tx),
                category: tx.expense.category ?? 'other',
                title: getCategoryTranslation(context, tx.expense.category ?? 'other'),
                description: tx.expense.rawText,
                date: tx.expense.date,
                amount: tx.expense.amount,
                currency: tx.expense.currency ?? 'USD',
                isIncome: (tx.expense.type ?? 'expense').toLowerCase() == 'income',
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MonthKey {
  final int year;
  final int month;

  _MonthKey(this.year, this.month);

  DateTime get asDate => DateTime(year, month, 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MonthKey && runtimeType == other.runtimeType && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_section_widgets.dart';

class DashboardAccountsSection extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final List<Household> households;
  final void Function(String name, double income, double expense)? onAccountTap;
  final VoidCallback? onTap;
  final double Function(ConsolidatedTransaction tx)? amountResolver;

  const DashboardAccountsSection({
    super.key,
    required this.transactions,
    required this.households,
    this.onAccountTap,
    this.onTap,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final amountFormatter = NumberFormat.compact();

    Map<String, double> calcScopeStats(String? accountId) {
      double income = 0;
      double expense = 0;

      for (final tx in transactions) {
        if (tx.entry.date.isBefore(startOfMonth)) continue;

        if (accountId == null) {
          if (tx.accountId != null) continue;
        } else {
          if (tx.accountId != accountId) continue;
        }

        final amount = tx.entry.amountCents / 100.0;
        final resolvedAmount = amountResolver?.call(tx) ?? amount;
        if (tx.entry.type == 'income') {
          income += resolvedAmount;
        } else {
          expense += resolvedAmount;
        }
      }

      return {'income': income, 'expense': expense};
    }

    final personalStats = calcScopeStats(null);
    final hasPersonalActivity =
        personalStats['income']! > 0 || personalStats['expense']! > 0;

    final accountTiles = <Widget>[];

    if (hasPersonalActivity) {
      accountTiles.add(
        _AccountTile(
          name: context.l10n.personal,
          isPersonal: true,
          stats: personalStats,
          amountFormatter: amountFormatter,
          onTap: onAccountTap,
        ),
      );
    }

    for (final household in households) {
      final stats = calcScopeStats(household.id);
      if (stats['income'] == 0 && stats['expense'] == 0) continue;
      accountTiles.add(
        _AccountTile(
          name: household.name,
          isPortfolio: household.isPortfolio,
          stats: stats,
          amountFormatter: amountFormatter,
          onTap: onAccountTap,
        ),
      );
    }

    if (accountTiles.isEmpty) {
      accountTiles.add(
        _AccountTile(
          name: context.l10n.personal,
          isPersonal: true,
          stats: const {'income': 0, 'expense': 0},
          amountFormatter: amountFormatter,
          onTap: onAccountTap,
        ),
      );
    }

    return DashboardSectionCard(children: accountTiles, onTap: onTap);
  }
}

class _AccountTile extends StatelessWidget {
  final String name;
  final bool isPersonal;
  final bool isPortfolio;
  final Map<String, double> stats;
  final NumberFormat amountFormatter;
  final void Function(String name, double income, double expense)? onTap;

  const _AccountTile({
    required this.name,
    this.isPersonal = false,
    this.isPortfolio = false,
    required this.stats,
    required this.amountFormatter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final income = stats['income'] ?? 0;
    final expense = stats['expense'] ?? 0;
    final net = income - expense;
    final netLabel = net >= 0
        ? '+${amountFormatter.format(net)}'
        : '-${amountFormatter.format(net.abs())}';

    return DashboardListTile(
      title: name,
      subtitle:
          '${context.l10n.accountSpent} ${amountFormatter.format(expense)} ${context.l10n.ofWord} ${amountFormatter.format(income)}',
      icon: isPersonal
          ? Icons.person
          : (isPortfolio ? Icons.trending_up : Icons.people),
      iconColor: isPersonal
          ? colorScheme.info
          : (isPortfolio ? colorScheme.warning : colorScheme.success),
      value: netLabel,
      showChevron: onTap != null,
      onTap: onTap == null ? null : () => onTap!(name, income, expense),
    );
  }
}

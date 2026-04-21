import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_section_widgets.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';

class DashboardWalletSummaryCard extends StatelessWidget {
  const DashboardWalletSummaryCard({
    super.key,
    required this.wallets,
    required this.selectedCurrency,
  });

  final List<WalletEntity> wallets;
  final String? selectedCurrency;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return DashboardSectionCard(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              context.l10n.noWalletsYet,
              style: TextStyle(
                color: Theme.of(context).colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final currencyCode = selectedCurrency ?? 'USD';
    final symbol = resolveCurrencySymbol(currencyCode);

    return DashboardSectionCard(
      children: [
        DashboardSectionHeader(title: context.l10n.wallet),
        ...wallets.map((wallet) {
          final displayBalanceCents = wallet.currentBalanceCents;
          final amount = displayBalanceCents / 100.0;
          final isNegative = amount < 0;
          
          final colorScheme = Theme.of(context).colorScheme;
          final walletColorRaw = wallet.color.toUpperCase() == '#6B7280'
              ? colorScheme.primary
              : parseWalletColor(wallet.color, colorScheme.primary);
          final baseColor = AppTheme.tunedPocketBaseColor(
            walletColorRaw,
            colorScheme,
            hasCustomColor: wallet.color.toUpperCase() != '#6B7280',
          );
          
          return DashboardListTile(
            title: wallet.name,
            icon: resolveWalletIcon(wallet.icon),
            iconColor: baseColor,
            value: '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
            showChevron: true,
          );
        }),
      ],
    );
  }
}

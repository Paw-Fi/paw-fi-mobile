import 'package:flutter/material.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/utils/currency.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.wallet,
    required this.currencyCode,
    this.onTap,
    this.onArchive,
    this.onSetDefault,
    this.onAdjustBalance,
  });

  final WalletEntity wallet;
  final String currencyCode;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onSetDefault;
  final VoidCallback? onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = wallet.currentBalanceCents / 100.0;
    final isPositive = amount >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Text(wallet.icon.isNotEmpty
                        ? wallet.icon.characters.first
                        : 'W'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (wallet.isDefault)
                    _Badge(
                        text: 'Default', color: colorScheme.primaryContainer),
                  if (wallet.isSystem) ...[
                    const SizedBox(width: 8),
                    _Badge(
                        text: 'System', color: colorScheme.tertiaryContainer),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${isPositive ? '+' : '-'}${resolveCurrencySymbol(currencyCode)}${formatAmount(amount.abs())}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? colorScheme.primary : colorScheme.error,
                ),
              ),
              if (wallet.goalAmountCents != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Goal: ${resolveCurrencySymbol(currencyCode)}${formatAmount(wallet.goalAmountCents! / 100.0)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (!wallet.isDefault)
                    TextButton(
                        onPressed: onSetDefault,
                        child: const Text('Set default')),
                  TextButton(
                      onPressed: onAdjustBalance,
                      child: const Text('Adjust balance')),
                  if (!wallet.isSystem)
                    TextButton(
                        onPressed: onArchive, child: const Text('Archive')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

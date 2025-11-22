import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';

class TransactionListTile extends StatelessWidget {
  final String category;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final double amount;
  final String currency;
  final bool isIncome;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final bool dense;

  const TransactionListTile({
    super.key,
    required this.category,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    required this.amount,
    required this.currency,
    required this.isIncome,
    this.onTap,
    this.trailingWidget,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = getCategoryColor(category);
    final icon = getCategoryIcon(category);
    final sign = isIncome ? '+' : '-';
    final formattedAmount = formatCurrency(amount.abs(), currency);

    return ListTile(
      onTap: onTap,
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
        ),
      ),
      subtitle: subtitleWidget ??
          (subtitle != null
              ? Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                )
              : null),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign$formattedAmount',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color:
                  isIncome ? const Color(0xFF10B981) : colorScheme.foreground,
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(height: 2),
            trailingWidget!,
          ],
        ],
      ),
    );
  }
}

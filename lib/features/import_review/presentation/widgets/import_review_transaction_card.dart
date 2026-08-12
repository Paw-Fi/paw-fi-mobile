import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';

class ImportReviewTransactionCard extends StatelessWidget {
  const ImportReviewTransactionCard({
    super.key,
    required this.transaction,
    this.isNested = false,
  });

  final ImportReviewTransaction transaction;
  final bool isNested;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = transaction.amount;
    final amountLabel = amount == null
        ? null
        : '${transaction.currency ?? ''} ${amount.toStringAsFixed(2)}'.trim();
    final title = transaction.merchant ??
        transaction.description ??
        'Transaction awaiting review';
    final details = <String>[
      if (transaction.type != null) _titleCase(transaction.type!),
      if (transaction.category != null) _titleCase(transaction.category!),
      if (transaction.date != null) _formatDate(transaction.date!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: isNested ? const BoxDecoration(
        color: Colors.transparent,
      ) : BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.surfaceBorder.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (amountLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  amountLabel,
                  style: TextStyle(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          if (transaction.description != null &&
              transaction.description != title) ...[
            const SizedBox(height: 6),
            Text(
              transaction.description!,
              style: TextStyle(
                color: scheme.mutedForeground,
                height: 1.4,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: details
                  .map(
                    (detail) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.muted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        detail,
                        style: TextStyle(
                          color: scheme.mutedForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _titleCase(String value) => value
    .split(RegExp(r'[_\s-]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');

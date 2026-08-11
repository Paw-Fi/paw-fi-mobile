import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:moneko/features/import_review/presentation/widgets/import_review_source_card.dart';
import 'package:moneko/features/import_review/presentation/widgets/import_review_transaction_card.dart';

class ImportReviewCompletedView extends StatelessWidget {
  const ImportReviewCompletedView({
    super.key,
    required this.review,
    required this.onClose,
  });

  final ImportReview review;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 80, bottom: 48),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: scheme.success,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.importReviewCompleteTitle,
                  style: TextStyle(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your reviewed transactions are ready\nin Moneko.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.mutedForeground,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (review.source.hasDetails) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ImportReviewSourceCard(source: review.source),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            24,
            32,
            24,
            24 ,
          ),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 4),
                child: Text(
                  context.l10n.importReviewResultsTitle,
                  style: TextStyle(
                    color: scheme.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              for (var index = 0; index < review.items.length; index++) ...[
                _LoggedTransactionCard(item: review.items[index]),
                if (index < review.items.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, 48 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.card,
                  foregroundColor: scheme.foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.l10n.importReviewClosePage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedTransactionCard extends StatelessWidget {
  const _LoggedTransactionCard({required this.item});

  final ImportReviewItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSaved = item.saveStatus == 'saved';
    
    final statusLabel = switch (item.saveStatus) {
      'saved' => context.l10n.importReviewTransactionLogged,
      'duplicate' => 'Already logged',
      'declined' => 'Not imported',
      'failed' => 'Could not log',
      _ => 'Processed',
    };
    
    final statusColor = switch (item.saveStatus) {
      'saved' => scheme.success,
      'failed' => scheme.error,
      _ => scheme.mutedForeground,
    };
    
    return Container(
      decoration: BoxDecoration(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              statusLabel.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Opacity(
            opacity: isSaved ? 1.0 : 0.6,
            child: ImportReviewTransactionCard(
              transaction: item.transaction,
              isNested: true,
            ),
          ),
        ],
      ),
    );
  }
}

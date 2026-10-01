import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';

/// One decorated group with viewport-built rows and row-owned occurrence reads.
class RecurringSeriesGroupSliver extends StatelessWidget {
  const RecurringSeriesGroupSliver({
    super.key,
    required this.summaries,
    required this.showCurrencyFlag,
    this.onTransactionTap,
    this.onTransactionDelete,
  });

  final List<RecurringSeriesSummary> summaries;
  final bool showCurrencyFlag;
  final ValueChanged<RecurringTransaction>? onTransactionTap;
  final ValueChanged<RecurringTransaction>? onTransactionDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final indices = <String, int>{
      for (var index = 0; index < summaries.length; index++)
        summaries[index].transaction.id: index,
    };
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.homeCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(1),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final summary = summaries[index];
              return ClipRRect(
                key: ValueKey(summary.transaction.id),
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(9) : Radius.zero,
                  bottom: index == summaries.length - 1
                      ? const Radius.circular(9)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: index == summaries.length - 1 ? 0 : 8,
                  ),
                  child: _RecurringSeriesRow(
                    summary: summary,
                    showCurrencyFlag: showCurrencyFlag,
                    onTransactionTap: onTransactionTap,
                    onTransactionDelete: onTransactionDelete,
                  ),
                ),
              );
            },
            childCount: summaries.length,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indices[key.value] : null,
          ),
        ),
      ),
    );
  }
}

class _RecurringSeriesRow extends ConsumerWidget {
  const _RecurringSeriesRow({
    required this.summary,
    required this.showCurrencyFlag,
    required this.onTransactionTap,
    required this.onTransactionDelete,
  });

  final RecurringSeriesSummary summary;
  final bool showCurrencyFlag;
  final ValueChanged<RecurringTransaction>? onTransactionTap;
  final ValueChanged<RecurringTransaction>? onTransactionDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = summary.transaction;
    final actionableDate = summary.latestActionableOccurrenceDate;
    final materialized = actionableDate == null
        ? null
        : ref.watch(recurringOccurrenceMaterializedProvider(
            RecurringOccurrenceMaterializationQuery(
              userId: transaction.userId ?? '',
              householdId: transaction.householdId,
              recurringId: transaction.id,
              scheduledOccurrenceDate: actionableDate,
            ),
          ));
    return RecurringTransactionCard(
      transaction: transaction,
      nextOccurrenceDate: summary.nextOccurrenceDate,
      // Unknown materialization must not briefly expose a stale confirm CTA.
      latestActionableOccurrenceDate:
          materialized?.valueOrNull == false ? actionableDate : null,
      showCurrencyFlag: showCurrencyFlag,
      grouped: true,
      onTap: onTransactionTap == null
          ? null
          : () => onTransactionTap!(transaction),
      onDelete: onTransactionDelete == null
          ? null
          : () => onTransactionDelete!(transaction),
    );
  }
}

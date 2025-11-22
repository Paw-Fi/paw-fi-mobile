import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

void showUncategorizedSheet(BuildContext context, ColorScheme colorScheme,
    String currency, List<UncategorizedCategory> uncategorized,
    {Map<String, List<Map<String, dynamic>>>? uncategorizedExpenses}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final sorted = [...uncategorized]
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).padding.bottom + 16,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.uncategorizedSpendingTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.uncategorizedSpendingDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.5,
                child: ListView.separated(
                  itemCount: sorted.length,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    final expensesForCategory = uncategorizedExpenses?[
                            item.category] ??
                        uncategorizedExpenses?[item.category.toLowerCase()] ??
                        const [];
                    return AdaptiveExpansionTile(
                      title: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      trailing: Text(
                        formatCurrency(item.amount, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      children: expensesForCategory.isEmpty
                          ? [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Text(
                                  context.l10n.noDetailedExpensesFound,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              )
                            ]
                          : expensesForCategory.map((exp) {
                              final desc =
                                  (exp['description'] as String?)?.trim();
                              final amountCents =
                                  (exp['amount_cents'] as num?)?.toDouble() ??
                                      0;
                              final dateStr = exp['date'] as String?;
                              DateTime? date;
                              if (dateStr != null) {
                                date = DateTime.tryParse(dateStr);
                              }
                              final isRecurring =
                                  (exp['is_recurring'] as bool?) ?? false;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc?.isNotEmpty == true
                                                ? desc!
                                                : context.l10n.expense,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.foreground,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (date != null)
                                                Text(
                                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme
                                                        .mutedForeground,
                                                  ),
                                                ),
                                              if (isRecurring) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    context.l10n.recurring,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(
                                          amountCents / 100.0, currency),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

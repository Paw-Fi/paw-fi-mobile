import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
Widget buildCategoryBreakdownCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  UserContact? contact, {
  String? selectedCurrency,
  String? householdId,
}) {
  // Recent transactions - show latest 5 expense rows (exclude income)
  final recent = expenses
      .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final latest = recent.take(5).toList();

  return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Consumer(
        builder: (context, ref, _) {
          if (latest.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  context.l10n.noTransactionsFound,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
              ),
            );
          }

          String fmt(double v) => formatCurrency(v, selectedCurrency ?? 'USD');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.foreground),
              ),
              const SizedBox(height: 8),
              ...latest.map((e) {
                final color = getCategoryColor(e.category);
                final icon = getCategoryIcon(e.category);
                final isIncome = (e.type ?? 'expense').toLowerCase() == 'income';
                final sign = isIncome ? '+' : '-';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Slidable(
                    key: ValueKey(e.id),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) async {
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) return;
                            try {
                              final res = await Supabase.instance.client.functions.invoke('delete-expense', body: {
                                'userId': uid,
                                'expenseId': e.id,
                              });
                              if (res.data != null && (res.data['success'] == true)) {
                                // Refresh analytics
                                ref.read(analyticsProvider.notifier).refresh(uid);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Transaction deleted')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${res.data?['error'] ?? 'Failed to delete'}')),
                                );
                              }
                            } catch (err) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $err')),
                              );
                            }
                          },
                          backgroundColor: const Color(0xFFFE4A49),
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () => showUnifiedTransactionSheet(context, existingExpense: e, contact: contact),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        getCategoryTranslation(context, e.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.foreground),
                      ),
                      subtitle: Text(
                        e.rawText ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                      ),
                      trailing: Text(
                        '$sign${fmt(e.amount.abs())}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isIncome ? const Color(0xFF10B981) : colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsPage()));
                  },
                  child: const Text('See all'),
                ),
              ),
            ],
          );
        },
      ),
    );
}

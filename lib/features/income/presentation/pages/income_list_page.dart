import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/income/domain/models/income_entry.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/income/presentation/constants/income_categories.dart';
import 'package:moneko/features/income/presentation/widgets/income_entry_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;


import 'package:moneko/core/ui/notifications/app_toast.dart';

class IncomeListPage extends ConsumerStatefulWidget {
  const IncomeListPage({super.key});

  @override
  ConsumerState<IncomeListPage> createState() => _IncomeListPageState();
}

class _IncomeListPageState extends ConsumerState<IncomeListPage> {
  @override
  void initState() {
    super.initState();

    // Load income on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      ref.read(incomeListProvider.notifier).loadIncome(user.uid);
    });
  }

  Future<void> _refresh() async {
    final user = ref.read(authProvider);
    await ref.read(incomeListProvider.notifier).refresh(user.uid);
  }

  Future<void> _acknowledgeIncome(IncomeEntry income) async {
    final user = ref.read(authProvider);
    final success = await ref.read(incomeAcknowledgeProvider.notifier).acknowledgeIncome(
      user.uid,
      income.id,
    );

    if (success && mounted) {
      AppToast.success(context.l10n.incomeAcknowledged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final incomeListState = ref.watch(incomeListProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          context.l10n.income,
          style: TextStyle(color: colorScheme.foreground),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.primary),
            onPressed: () => showIncomeEntrySheet(context),
          ),
        ],
      ),
      body: incomeListState.when(
        data: (incomeList) {
          if (incomeList.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incomeList.length,
              itemBuilder: (context, index) {
                final income = incomeList[index];
                return _buildIncomeCard(income, colorScheme, user.uid);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.destructive),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                style: TextStyle(color: colorScheme.foreground),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              shadcnui.PrimaryButton(
                onPressed: _refresh,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: colorScheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noIncome,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.noIncomeDescription,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          shadcnui.PrimaryButton(
            onPressed: () => showIncomeEntrySheet(context),
            child: Text(context.l10n.addIncome),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(
    IncomeEntry income,
    ColorScheme colorScheme,
    String currentUserId,
  ) {
    final isOwner = income.id.contains(currentUserId); // Simplified check
    final needsAcknowledgement = income.householdId != null &&
        !income.isAcknowledged &&
        !isOwner;

    final categoryIcon = getIncomeCategoryIcon(income.category);
    final categoryColor = Color(
      int.parse(getIncomeCategoryColor(income.category).replaceFirst('#', '0xFF')),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsAcknowledgement ? colorScheme.primary : colorScheme.border,
          width: needsAcknowledgement ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: Show income detail sheet
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          categoryIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Category & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCategoryLabel(income.category),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat.yMMMd().format(income.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(income.amount, income.currency),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                        if (income.normalizedAmount != null &&
                            income.baseCurrency != null &&
                            income.currency != income.baseCurrency) ...[
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(income.normalizedAmount!, income.baseCurrency!),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Source & Description (if not redacted)
                if (!income.privacyRedacted) ...[
                  if (income.source != null && income.source!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.source}: ${income.source}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                  if (income.description != null && income.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      income.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],

                // Privacy Badge
                if (income.householdId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPrivacyScopeColor(income.privacyScope).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPrivacyScopeLabel(income.privacyScope),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getPrivacyScopeColor(income.privacyScope),
                          ),
                        ),
                      ),
                      if (income.acknowledgedCount > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${income.acknowledgedCount} ${context.l10n.acknowledged}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Acknowledgement Button
                if (needsAcknowledgement) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: shadcnui.PrimaryButton(
                      onPressed: () => _acknowledgeIncome(income),
                      child: Text(context.l10n.acknowledge),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'income:salary':
        return context.l10n.incomeSalary;
      case 'income:freelance':
        return context.l10n.incomeFreelance;
      case 'income:investment':
        return context.l10n.incomeInvestment;
      case 'income:refund':
        return context.l10n.incomeRefund;
      case 'income:gift':
        return context.l10n.incomeGift;
      case 'income:bonus':
        return context.l10n.incomeBonus;
      case 'income:rental':
        return context.l10n.incomeRental;
      case 'income:other':
        return context.l10n.incomeOther;
      default:
        return category.replaceFirst('income:', '');
    }
  }

  String _getPrivacyScopeLabel(String scope) {
    switch (scope) {
      case 'full':
        return context.l10n.privacyFull;
      case 'balances_only':
        return context.l10n.privacyBalancesOnly;
      case 'private':
        return context.l10n.privacyPrivate;
      default:
        return scope;
    }
  }

  Color _getPrivacyScopeColor(String scope) {
    switch (scope) {
      case 'full':
        return Colors.green;
      case 'balances_only':
        return Colors.orange;
      case 'private':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

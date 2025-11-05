import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';
import '../../../../core/l10n/l10n.dart';

/// Page for creating a new household budget
class CreateBudgetPage extends HookConsumerWidget {
  final String householdId;

  const CreateBudgetPage({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final nameController = useTextEditingController();
    final amountController = useTextEditingController();
    final selectedPeriod = useState<BudgetPeriod>(BudgetPeriod.monthly);
    final selectedType = useState<BudgetType>(BudgetType.household);
    final countSplitPortionOnly = useState<bool>(false);
    final warnThreshold = useState<double>(0.8);
    final alertThreshold = useState<double>(1.0);
    final isCreating = useState<bool>(false);
    final selectedCurrency = useState<String>('USD');

    // Available currencies
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'CAD', 'AUD'];

    Future<void> createBudget() async {
      // Validation
      if (nameController.text.trim().isEmpty) {
        _showError(context, context.l10n.pleaseEnterABudgetName);
        return;
      }

      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        _showError(context, context.l10n.pleaseEnterAValidAmountGreaterThan0);
        return;
      }

      // Validate thresholds
      if (warnThreshold.value < 0 || warnThreshold.value > 1) {
        _showError(context, context.l10n.warningThresholdMustBeBetween0And100);
        return;
      }

      if (alertThreshold.value < 0 || alertThreshold.value > 1) {
        _showError(context, context.l10n.alertThresholdMustBeBetween0And100);
        return;
      }

      if (warnThreshold.value > alertThreshold.value) {
        _showError(context, context.l10n.warningThresholdMustBeLessThanOrEqualToAlert);
        return;
      }

      isCreating.value = true;

      try {
        await ref
            .read(householdBudgetsProvider(householdId).notifier)
            .createBudget(
              name: nameController.text.trim(),
              period: selectedPeriod.value.toJson(),
              currency: selectedCurrency.value,
              amountCents: (amount * 100).toInt(),
              warnThreshold: warnThreshold.value,
              alertThreshold: alertThreshold.value,
              budgetType: selectedType.value.toJson(),
              countSplitPortionOnly: countSplitPortionOnly.value,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.budgetCreatedSuccessfully),
              backgroundColor: colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          final l10n = context.l10n;
          _showError(context, '${l10n.failedToCreateBudget}: $e');
        }
      } finally {
        isCreating.value = false;
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          context.l10n.createBudget,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Budget Name
            Text(
              context.l10n.budgetName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: context.l10n.groceriesRentEntertainment,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.card,
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 24),

            // Budget Amount
            Text(
              context.l10n.amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      hintText: context.l10n.zeroAmount,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.card,
                      prefixText: context.l10n.dollarPrefix,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Currency Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.border),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCurrency.value,
                    underline: const SizedBox.shrink(),
                    items: currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(
                          currency,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedCurrency.value = value;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Budget Period
            Text(
              context.l10n.period,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.border),
              ),
              child: DropdownButton<BudgetPeriod>(
                value: selectedPeriod.value,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: BudgetPeriod.values.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(
                      _formatPeriod(context, period),
                      style: TextStyle(color: colorScheme.foreground),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedPeriod.value = value;
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Budget Type (not used for now)
            // Text(
            //   context.l10n.budgetType,
            //   style: TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.w600,
            //     color: colorScheme.foreground,
            //   ),
            // ),
            // const SizedBox(height: 8),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 12),
            //   decoration: BoxDecoration(
            //     color: colorScheme.card,
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(color: colorScheme.border),
            //   ),
            //   child: DropdownButton<BudgetType>(
            //     value: selectedType.value,
            //     isExpanded: true,
            //     underline: const SizedBox.shrink(),
            //     items: BudgetType.values.map((type) {
            //       return DropdownMenuItem(
            //         value: type,
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             Text(
            //               _formatBudgetType(context, type),
            //               style: TextStyle(
            //                 fontWeight: FontWeight.w600,
            //                 color: colorScheme.foreground,
            //               ),
            //             ),
            //             Text(
            //               type == BudgetType.household
            //                   ? context.l10n.sharedWithAllHouseholdMembers
            //                   : context.l10n.personalBudgetForYourExpensesOnly,
            //               style: TextStyle(
            //                 fontSize: 12,
            //                 color: colorScheme.mutedForeground,
            //               ),
            //             ),
            //           ],
            //         ),
            //       );
            //     }).toList(),
            //     onChanged: (value) {
            //       if (value != null) {
            //         selectedType.value = value;
            //       }
            //     },
            //   ),
            // ),
            // const SizedBox(height: 24),

            // Personal Budget Options
            if (selectedType.value == BudgetType.personal) ...[
              Card(
                color: colorScheme.muted.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.countSplitPortionOnly,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.onlyCountYourPortionOfSplitExpenses,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: countSplitPortionOnly.value,
                        onChanged: (value) {
                          countSplitPortionOnly.value = value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Notification Thresholds (TODO: Re-enable when implemented)
            // Text(
            //   context.l10n.notificationSettings,
            //   style: TextStyle(
            //     fontSize: 18,
            //     fontWeight: FontWeight.bold,
            //     color: colorScheme.foreground,
            //   ),
            // ),
            // const SizedBox(height: 16),

            // // Warning Threshold (TODO: Re-enable when implemented)
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             Row(
            //               children: [
            //                 Icon(
            //                   Icons.notifications,
            //                   size: 20,
            //                   color: colorScheme.primary,
            //                 ),
            //                 const SizedBox(width: 8),
            //                 Text(
            //                   context.l10n.budgetBoop,
            //                   style: TextStyle(
            //                     fontSize: 14,
            //                     fontWeight: FontWeight.w600,
            //                     color: colorScheme.foreground,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //             Text(
            //               '${(warnThreshold.value * 100).toInt()}%',
            //               style: TextStyle(
            //                 fontSize: 16,
            //                 fontWeight: FontWeight.bold,
            //                 color: colorScheme.primary,
            //               ),
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           context.l10n.getGentleReminder,
            //           style: TextStyle(
            //             fontSize: 12,
            //             color: colorScheme.mutedForeground,
            //           ),
            //         ),
            //         const SizedBox(height: 12),
            //         Slider(
            //           value: warnThreshold.value,
            //           min: 0.0,
            //           max: 1.0,
            //           divisions: 20,
            //           label: '${(warnThreshold.value * 100).toInt()}%',
            //           onChanged: (value) {
            //             warnThreshold.value = value;
            //             // Ensure alert threshold is not less than warning
            //             if (alertThreshold.value < value) {
            //               alertThreshold.value = value;
            //             }
            //           },
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 12),

            // // Alert Threshold (TODO: Re-enable when implemented)
            // Card(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             Row(
            //               children: [
            //                 Icon(
            //                   Icons.warning,
            //                   size: 20,
            //                   color: colorScheme.destructive,
            //                 ),
            //                 const SizedBox(width: 8),
            //                 Text(
            //                   context.l10n.purrSuasiveNudge,
            //                   style: TextStyle(
            //                     fontSize: 14,
            //                     fontWeight: FontWeight.w600,
            //                     color: colorScheme.foreground,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //             Text(
            //               '${(alertThreshold.value * 100).toInt()}%',
            //               style: TextStyle(
            //                 fontSize: 16,
            //                 fontWeight: FontWeight.bold,
            //                 color: colorScheme.destructive,
            //               ),
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           context.l10n.getStrongerNudge,
            //           style: TextStyle(
            //             fontSize: 12,
            //             color: colorScheme.mutedForeground,
            //           ),
            //         ),
            //         const SizedBox(height: 12),
            //         Slider(
            //           value: alertThreshold.value,
            //           min: warnThreshold.value, // Must be >= warning threshold
            //           max: 1.5, // Allow over-budget alerts
            //           divisions: 30,
            //           label: '${(alertThreshold.value * 100).toInt()}%',
            //           onChanged: (value) {
            //             alertThreshold.value = value;
            //           },
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 32),

            // Create Button
            shadcnui.PrimaryButton(
              onPressed: isCreating.value ? null : createBudget,
              child: isCreating.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(context.l10n.createBudgetButton),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeriod(BuildContext context, BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.daily:
        return context.l10n.daily;
      case BudgetPeriod.weekly:
        return context.l10n.weekly;
      case BudgetPeriod.monthly:
        return context.l10n.monthly;
      case BudgetPeriod.yearly:
        return context.l10n.yearly;
    }
  }

  // ignore: unused_element
  String _formatBudgetType(BuildContext context, BudgetType type) {
    switch (type) {
      case BudgetType.household:
        return context.l10n.householdBudgetType;
      case BudgetType.personal:
        return context.l10n.personalBudgetType;
    }
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: shadcnui.Theme.of(context).colorScheme.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

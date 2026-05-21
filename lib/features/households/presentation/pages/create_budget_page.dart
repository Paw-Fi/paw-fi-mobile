import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';

import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

/// Page for creating a new household budget
class CreateBudgetPage extends HookConsumerWidget {
  final String householdId;
  final String? initialCurrency;

  const CreateBudgetPage({
    super.key,
    required this.householdId,
    this.initialCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = useTextEditingController();
    final amountController = useTextEditingController();
    final selectedPeriod = useState<BudgetPeriod>(BudgetPeriod.monthly);
    final selectedType = useState<BudgetType>(BudgetType.household);
    final countSplitPortionOnly = useState<bool>(false);
    final warnThreshold = useState<double>(0.8);
    final alertThreshold = useState<double>(1.0);
    final isCreating = useState<bool>(false);
    final selectedCurrency =
        useState<String>((initialCurrency ?? 'USD').toUpperCase());

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
        _showError(
            context, context.l10n.warningThresholdMustBeLessThanOrEqualToAlert);
        return;
      }

      isCreating.value = true;

      try {
        debugPrint('🔵 Creating budget with:');
        debugPrint('  - householdId: $householdId');
        debugPrint('  - name: ${nameController.text.trim()}');
        debugPrint('  - period: ${selectedPeriod.value.toJson()}');
        debugPrint('  - currency: ${selectedCurrency.value}');
        debugPrint('  - amountCents: ${(amount * 100).toInt()}');
        debugPrint('  - warnThreshold: ${warnThreshold.value}');
        debugPrint('  - alertThreshold: ${alertThreshold.value}');
        debugPrint('  - budgetType: ${selectedType.value.toJson()}');
        debugPrint('  - countSplitPortionOnly: ${countSplitPortionOnly.value}');

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

        debugPrint('✅ Budget created successfully');

        if (context.mounted) {
          AppToast.success(context, context.l10n.budgetCreatedSuccessfully);
          Navigator.pop(context);
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error creating budget:');
        debugPrint('Error type: ${e.runtimeType}');
        debugPrint('Error message: $e');
        debugPrint('Stack trace: $stackTrace');

        if (context.mounted) {
          final l10n = context.l10n;
          _showError(context, '${l10n.failedToCreateBudget}: $e');
        }
      } finally {
        isCreating.value = false;
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.createBudget,
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
                  child: Builder(
                    builder: (context) => GestureDetector(
                      onTap: () async {
                        final currency = selectedCurrency.value;
                        final symbol = resolveCurrencySymbol(currency);
                        final displayTitle = nameController.text.trim();
                        final effectiveTitle = displayTitle.isNotEmpty ? displayTitle : context.l10n.budget;

                        final header = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.donut_large_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                effectiveTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.mutedForeground.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.amount,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        );

                        final value = await showCalculatorKeypadSheet(
                          context: context,
                          initialValue: amountController.text,
                          prefix: symbol,
                          header: header,
                        );
                        if (value != null) {
                          amountController.text = value;
                        }
                      },
                      child: AbsorbPointer(
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
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Currency Selector
                GestureDetector(
                  onTap: () async {
                    final result = await showCurrencyPicker(
                      context: context,
                      currentCurrency: selectedCurrency.value,
                    );
                    if (result != null) {
                      selectedCurrency.value = result;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCurrency.value.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_drop_down,
                          color: colorScheme.mutedForeground,
                          size: 24,
                        ),
                      ],
                    ),
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
            GestureDetector(
              onTap: () async {
                final result =
                    await showTransactionSelectionSheet<BudgetPeriod>(
                  context: context,
                  items: BudgetPeriod.values,
                  getLabel: (period) => _formatPeriod(context, period),
                  initial: selectedPeriod.value,
                );
                if (result != null) {
                  selectedPeriod.value = result;
                }
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatPeriod(context, selectedPeriod.value),
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: colorScheme.mutedForeground,
                      size: 24,
                    ),
                  ],
                ),
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
                      AdaptiveSwitch(
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
            PrimaryAdaptiveButton(
              onPressed: isCreating.value ? null : createBudget,
              child: isCreating.value
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primaryForeground,
                        ),
                      ),
                    )
                  : Text(context.l10n.createBudgetButton),
            ),
          ],
        ),
      ),
    ));
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
      AppToast.error(context, message);
    }
  }
}

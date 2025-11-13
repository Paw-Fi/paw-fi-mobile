import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';

/// Modern bottom sheet for adding/editing recurring transactions
/// Apple-inspired design with clean animations and intuitive UX
class AddRecurringSheet extends HookConsumerWidget {
  final String type; // 'expense' or 'income'
  final RecurringTransaction? existingTransaction; // For editing

  const AddRecurringSheet({
    super.key,
    required this.type,
    this.existingTransaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final selectedType = useState<String>(type == 'income' ? 'income' : 'expense');
    final isExpense = selectedType.value == 'expense';
    final isEditing = existingTransaction != null;

    final amountController = useTextEditingController(
      text: existingTransaction?.amount.toString() ?? '',
    );
    final descriptionController = useTextEditingController(
      text: existingTransaction?.description ?? '',
    );
    final sourceController = useTextEditingController(
      text: existingTransaction?.source ?? '',
    );

    final selectedCategory = useState<String?>(existingTransaction?.category);
    final selectedFrequency = useState<String>(
      existingTransaction?.recurrenceRule?.frequency ?? 'monthly',
    );
    final selectedCurrency = useState<String>(
      existingTransaction?.currency ?? 'USD',
    );
    final startDate = useState<DateTime>(
      existingTransaction?.recurrenceRule?.anchorDate ?? DateTime.now(),
    );
    final hasEndDate = useState<bool>(existingTransaction?.recurrenceRule?.endDate != null);
    final endDate = useState<DateTime?>(existingTransaction?.recurrenceRule?.endDate);
    final customInterval = useState<int?>(existingTransaction?.recurrenceRule?.interval);
    final hasReminder = useState<bool>(!isEditing); // Default to true for new transactions
    final reminderValue = useState<int>(1);
    final reminderUnit = useState<String>('days');
    final isLoading = useState<bool>(false);

    Future<void> handleSave() async {
      debugPrint('🔵 handleSave called');
      debugPrint('🔵 isEditing: $isEditing');
      debugPrint('🔵 existingTransaction: ${existingTransaction?.id}');
      debugPrint('🔵 selectedCategory: ${selectedCategory.value}');
      debugPrint('🔵 amountText: ${amountController.text}');
      
      if (selectedCategory.value == null) {
        debugPrint('🔴 Error: No category selected');
        _showError(context, context.l10n.pleaseSelectCategory);
        return;
      }

      final amountText = amountController.text.trim();
      if (amountText.isEmpty) {
        debugPrint('🔴 Error: Amount is empty');
        _showError(context, context.l10n.pleaseEnterAmount);
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        debugPrint('🔴 Error: Invalid amount');
        _showError(context, context.l10n.pleaseEnterValidAmount);
        return;
      }

      debugPrint('✅ Validation passed, starting save...');
      isLoading.value = true;

      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          debugPrint('🔴 User not authenticated');
          _showError(context, context.l10n.userNotAuthenticated);
          isLoading.value = false;
          return;
        }

        debugPrint('👤 User ID: ${user.id}');
        debugPrint('💰 Amount: $amount');
        debugPrint('📂 Category: ${selectedCategory.value}');
        debugPrint('💱 Currency: ${selectedCurrency.value}');
        debugPrint('📅 Start Date: ${startDate.value}');
        debugPrint('🔄 Frequency: ${selectedFrequency.value}');
        debugPrint('📝 Description: ${descriptionController.text.trim()}');
        debugPrint('🏢 Source: ${sourceController.text.trim()}');
        debugPrint('📆 Has End Date: ${hasEndDate.value}');
        debugPrint('🔚 End Date: ${endDate.value}');
        debugPrint('⏱️ Interval: ${customInterval.value}');

        RecurringTransaction? result;

        if (isExpense) {
          if (isEditing) {
            // UPDATE existing expense
            debugPrint('💸 Calling updateRecurringExpense...');
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringExpense(
                  userId: user.id,
                  expenseId: existingTransaction!.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                );
          } else {
            // CREATE new expense
            debugPrint('💸 Calling saveRecurringExpense...');
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringExpense(
                  userId: user.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                );
          }
        } else {
          if (isEditing) {
            // UPDATE existing income
            debugPrint('💵 Calling updateRecurringIncome...');
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringIncome(
                  userId: user.id,
                  expenseId: existingTransaction!.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  source: sourceController.text.trim().isEmpty
                      ? null
                      : sourceController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                );
          } else {
            // CREATE new income
            debugPrint('💵 Calling saveRecurringIncome...');
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringIncome(
                  userId: user.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  source: sourceController.text.trim().isEmpty
                      ? null
                      : sourceController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                );
          }
        }

        debugPrint('📊 Result: $result');
        isLoading.value = false;

        if (result != null) {
          debugPrint('✅ ${isEditing ? 'Update' : 'Save'} successful!');
          if (context.mounted) {
            Navigator.of(context).pop();
            final successMsg = isExpense
                ? (isEditing
                    ? context.l10n.recurringExpenseUpdatedSuccessfully
                    : context.l10n.recurringExpenseAddedSuccessfully)
                : (isEditing
                    ? context.l10n.recurringIncomeUpdatedSuccessfully
                    : context.l10n.recurringIncomeAddedSuccessfully);
            _showSuccess(context, successMsg);
          }
        } else {
          debugPrint('🔴 Result is null - ${isEditing ? 'update' : 'save'} failed');
          final errMsg = isExpense
              ? context.l10n.failedToUpdateRecurringExpense
              : context.l10n.failedToUpdateRecurringIncome;
          _showError(context, errMsg);
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Exception caught: $e');
        debugPrint('Stack trace: $stackTrace');
        isLoading.value = false;
        _showError(context, 'Error: ${e.toString()}');
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height *
            0.85, // Limit to 85% of screen height
      ),
      decoration: BoxDecoration(
        color: colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [              
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? (isExpense
                              ? context.l10n.editRecurringExpense
                              : context.l10n.editRecurringIncome)
                          : (isExpense
                              ? context.l10n.addRecurringExpense
                              : context.l10n.addRecurringIncome),
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type toggle
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => selectedType.value = 'expense',
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? colorScheme.background
                                    : colorScheme.muted.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isExpense
                                      ? colorScheme.primary.withValues(alpha: 0.4)
                                      : colorScheme.border.withValues(alpha: 0.2),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                context.l10n.expenses,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isExpense
                                      ? colorScheme.foreground
                                      : colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => selectedType.value = 'income',
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isExpense
                                    ? colorScheme.background
                                    : colorScheme.muted.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isExpense
                                      ? colorScheme.primary.withValues(alpha: 0.4)
                                      : colorScheme.border.withValues(alpha: 0.2),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                context.l10n.income,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !isExpense
                                      ? colorScheme.foreground
                                      : colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Amount input
                    _buildLabel(context.l10n.amount, colorScheme),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      placeholder: '0.00',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),

                    const SizedBox(height: 20),
          
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      label: context.l10n.category,
                      value: selectedCategory.value != null
                          ? getCategoryTranslation(context, selectedCategory.value!)
                          : context.l10n.selectCategory,
                      onTap: () async {
                        final result = await showCategoryPicker(
                          context: context,
                          currentCategory: selectedCategory.value ?? (isExpense ? 'other' : 'salary'),
                          isIncome: !isExpense,
                        );
                        if (result != null) {
                          selectedCategory.value = result;
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Currency selector
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      label: context.l10n.currency,
                      value: selectedCurrency.value.toUpperCase(),
                      onTap: () async {
                        final result = await showCurrencyPicker(
                          context: context,
                          currentCurrency: selectedCurrency.value,
                        );
                        if (result != null) {
                          selectedCurrency.value = result;
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      label: context.l10n.frequency,
                      value: () {
                        // Get the label for the current frequency
                        final freq = getDefaultFrequencyOptions(context).firstWhere(
                          (f) => f.value == selectedFrequency.value,
                          orElse: () => getDefaultFrequencyOptions(context)[3], // Default to 'monthly'
                        );
                        return freq.label;
                      }(),
                      onTap: () async {
                        final result = await showFrequencyPicker(
                          context: context,
                          currentFrequency: selectedFrequency.value,
                        );
                        if (result != null) {
                          selectedFrequency.value = result;
                        }
                      },
                    ),

                    const SizedBox(height: 20),
             
               
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      label: context.l10n.startDate,
                      value: formatLocalizedDate(context, startDate.value, includeYear: true),
                      onTap: () async {
                        final result = await showTransactionDatePicker(
                          context: context,
                          currentDate: startDate.value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (result != null) {
                          startDate.value = result;
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // End date toggle (clickable container)
                    GestureDetector(
                      onTap: () {
                        hasEndDate.value = !hasEndDate.value;
                        if (!hasEndDate.value) {
                          endDate.value = null;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.muted.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.border.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            shadcnui.Checkbox(
                              state: hasEndDate.value
                                  ? shadcnui.CheckboxState.checked
                                  : shadcnui.CheckboxState.unchecked,
                              onChanged: (state) {
                                hasEndDate.value =
                                    state == shadcnui.CheckboxState.checked;
                                if (!hasEndDate.value) {
                                  endDate.value = null;
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.l10n.setEndDate,
                                style: TextStyle(
                                  color: colorScheme.foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // End date picker (if enabled)
                    if (hasEndDate.value) ...[
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        colorScheme: colorScheme,
                        label: context.l10n.endDate,
                        value: endDate.value != null
                            ? formatLocalizedDate(context, endDate.value!, includeYear: true)
                            : context.l10n.selectEndDate,
                        onTap: () async {
                          final result = await showTransactionDatePicker(
                            context: context,
                            currentDate: endDate.value ??
                                startDate.value.add(const Duration(days: 365)),
                            firstDate: startDate.value,
                            lastDate: DateTime(2030),
                          );
                          if (result != null) {
                            endDate.value = result;
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Description
                    _buildLabel(context.l10n.descriptionOptional, colorScheme),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: descriptionController,
                      placeholder: context.l10n.addANote,
                      maxLines: 2,
                    ),

                    // Source (for income only)
                    if (!isExpense) ...[
                      const SizedBox(height: 20),
                      _buildLabel(context.l10n.sourceOptional, colorScheme),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: sourceController,
                        placeholder: context.l10n.companyNameClientNameExample,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Reminder toggle (clickable container)
                    GestureDetector(
                      onTap: () {
                        hasReminder.value = !hasReminder.value;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.muted.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.border.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            shadcnui.Checkbox(
                              state: hasReminder.value
                                  ? shadcnui.CheckboxState.checked
                                  : shadcnui.CheckboxState.unchecked,
                              onChanged: (state) {
                                hasReminder.value =
                                    state == shadcnui.CheckboxState.checked;
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.l10n.setReminder,
                                style: TextStyle(
                                  color: colorScheme.foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Reminder configuration (if enabled)
                    if (hasReminder.value) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          // Detect word order based on language
                          final lang = Localizations.localeOf(context).languageCode.toLowerCase();
                          final useSOV = {'zh', 'ja', 'ko', 'hi', 'ur', 'tr', 'fa'}.contains(lang);
                          
                          // Build UI components
                          final valueInput = SizedBox(
                            width: 80,
                            child: CustomTextField(
                              initialValue: reminderValue.value.toString(),
                              keyboardType: TextInputType.number,
                              placeholder: '1',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0) {
                                  reminderValue.value = parsed;
                                }
                              },
                            ),
                          );
                          
                          final unitPicker = GestureDetector(
                            onTap: () async {
                              final result = await showTransactionSelectionSheet<String>(
                                context: context,
                                items: ['days', 'hours'],
                                getLabel: (unit) {
                                  if (unit == 'days') return context.l10n.days;
                                  if (unit == 'hours') return context.l10n.hours;
                                  return unit;
                                },
                                initial: reminderUnit.value,
                              );
                              if (result != null) {
                                reminderUnit.value = result;
                              }
                            },
                            child: IntrinsicWidth(
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 80), // Minimum width
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: colorScheme.muted.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.border.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      reminderUnit.value == 'days' ? context.l10n.days : context.l10n.hours,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.foreground,
                                        fontWeight: FontWeight.w600,
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
                          );
                          
                          // Arrange based on word order
                          List<Widget> rowChildren;
                          if (useSOV) {
                            // SOV languages: beforePrefix [value][unit]beforeSuffix
                            // Chinese: 在 2天之前
                            rowChildren = [
                              Text(
                                context.l10n.beforePrefix,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              valueInput,
                              const SizedBox(width: 12),
                              unitPicker,
                              const SizedBox(width: 12),
                              Text(
                                context.l10n.beforeSuffix,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ];
                          } else {
                            // Default SVO: [value] [unit] before
                            // English: 2 days before
                            rowChildren = [
                              valueInput,
                              const SizedBox(width: 12),
                              unitPicker,
                              const SizedBox(width: 12),
                              Text(
                                context.l10n.before,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ];
                          }
                          
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: rowChildren,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.youWillBeNotifiedBeforeEachOccurrence(
                          reminderValue.value,
                          reminderUnit.value == 'days' ? context.l10n.days : context.l10n.hours,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // Save button
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: shadcnui.PrimaryButton(
                        onPressed: isLoading.value 
                            ? null 
                            : () {
                                debugPrint('🟢 Save button pressed!');
                                handleSave();
                              },
                        child: isLoading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(isEditing ? context.l10n.updateRecurringTransaction : context.l10n.addRecurringTransaction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, shadcnui.ColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        color: colorScheme.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDetailCard({
    required shadcnui.ColorScheme colorScheme,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.muted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.mutedForeground,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    debugPrint('🔴 _showError called: $message');
    AppToast.error(message);
  }

  void _showSuccess(BuildContext context, String message) {
    debugPrint('✅ _showSuccess called: $message');
    AppToast.success(message);
  }
}

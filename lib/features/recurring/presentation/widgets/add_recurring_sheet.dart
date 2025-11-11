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

/// Modern bottom sheet for adding recurring transactions
/// Apple-inspired design with clean animations and intuitive UX
class AddRecurringSheet extends HookConsumerWidget {
  final String type; // 'expense' or 'income'

  const AddRecurringSheet({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isExpense = type == 'expense';

    final amountController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final sourceController = useTextEditingController();

    final selectedCategory = useState<String?>(null);
    final selectedFrequency = useState<String>('monthly');
    final selectedCurrency = useState<String>('USD');
    final startDate = useState<DateTime>(DateTime.now());
    final hasEndDate = useState<bool>(false);
    final endDate = useState<DateTime?>(null);
    final customInterval = useState<int?>(null);
    final hasReminder = useState<bool>(false);
    final reminderValue = useState<int>(1);
    final reminderUnit = useState<String>('days');
    final isLoading = useState<bool>(false);

    Future<void> handleSave() async {
      debugPrint('🔵 handleSave called');
      debugPrint('🔵 selectedCategory: ${selectedCategory.value}');
      debugPrint('🔵 amountText: ${amountController.text}');
      
      if (selectedCategory.value == null) {
        debugPrint('🔴 Error: No category selected');
        _showError(context, 'Please select a category');
        return;
      }

      final amountText = amountController.text.trim();
      if (amountText.isEmpty) {
        debugPrint('🔴 Error: Amount is empty');
        _showError(context, 'Please enter an amount');
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        debugPrint('🔴 Error: Invalid amount');
        _showError(context, 'Please enter a valid amount');
        return;
      }

      debugPrint('✅ Validation passed, starting save...');
      isLoading.value = true;

      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          debugPrint('🔴 User not authenticated');
          _showError(context, 'User not authenticated');
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
        } else {
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

        debugPrint('📊 Result: $result');
        isLoading.value = false;

        if (result != null) {
          debugPrint('✅ Save successful!');
          if (context.mounted) {
            Navigator.of(context).pop();
            _showSuccess(context,
                'Recurring ${isExpense ? 'expense' : 'income'} added successfully');
          }
        } else {
          debugPrint('🔴 Result is null - save failed');
          _showError(context,
              'Failed to add recurring ${isExpense ? 'expense' : 'income'}');
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
                      'Add Recurring ${isExpense ? 'Expense' : 'Income'}',
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
                    // Amount input
                    _buildLabel('Amount', colorScheme),
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
                      label: 'Category',
                      value: selectedCategory.value != null
                          ? getCategoryTranslation(context, selectedCategory.value!)
                          : 'Select category',
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
                      label: 'Currency',
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
                      label: 'Frequency',
                      value: () {
                        // Get the label for the current frequency
                        final freq = defaultFrequencyOptions.firstWhere(
                          (f) => f.value == selectedFrequency.value,
                          orElse: () => defaultFrequencyOptions[3], // Default to 'monthly'
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
                      label: 'Start Date',
                      value: DateFormat('MMM d, y').format(startDate.value),
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
                                'Set end date',
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
                        label: 'End Date',
                        value: endDate.value != null
                            ? DateFormat('MMM d, y').format(endDate.value!)
                            : 'Select end date',
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
                    _buildLabel('Description (Optional)', colorScheme),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: descriptionController,
                      placeholder: 'Add a note...',
                      maxLines: 2,
                    ),

                    // Source (for income only)
                    if (!isExpense) ...[
                      const SizedBox(height: 20),
                      _buildLabel('Source (Optional)', colorScheme),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: sourceController,
                        placeholder: 'e.g., Company name, Client name',
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
                                'Set reminder',
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Reminder value input
                          SizedBox(
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
                          ),
                          const SizedBox(width: 12),
                          // Reminder unit picker
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final result = await showTransactionSelectionSheet<String>(
                                  context: context,
                                  items: ['days', 'hours'],
                                  getLabel: (unit) => unit.substring(0, 1).toUpperCase() + unit.substring(1),
                                  initial: reminderUnit.value,
                                );
                                if (result != null) {
                                  reminderUnit.value = result;
                                }
                              },
                              child: Container(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      reminderUnit.value.substring(0, 1).toUpperCase() + 
                                      reminderUnit.value.substring(1),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.foreground,
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
                          ),
                          const SizedBox(width: 12),
                          // "Before" label
                          Text(
                            'Before',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You will be notified ${reminderValue.value} ${reminderUnit.value} before each occurrence',
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
                            : const Text('Add Recurring Transaction'),
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

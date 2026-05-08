import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

import 'package:moneko/shared/widgets/calculator_keypad.dart';

/// Generic bottom sheet for editing transaction fields
class EditTransactionBottomSheet extends ConsumerStatefulWidget {
  final String expenseId;
  final ExpenseEntry expense;
  final EditField field;
  final dynamic currentValue;

  const EditTransactionBottomSheet({
    required this.expenseId,
    required this.expense,
    required this.field,
    required this.currentValue,
    super.key,
  });

  @override
  ConsumerState<EditTransactionBottomSheet> createState() =>
      _EditTransactionBottomSheetState();
}

class _EditTransactionBottomSheetState
    extends ConsumerState<EditTransactionBottomSheet> {
  late TextEditingController _controller;
  String? _error;
  String? _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _getInitialValue());

    if (widget.field == EditField.category) {
      _selectedCategory = widget.currentValue?.toString().toLowerCase();
    }

    if (widget.field == EditField.date) {
      _selectedDate = widget.currentValue as DateTime;
    }

    if (widget.field == EditField.time) {
      final dateTime = toLocalTime(widget.currentValue as DateTime);
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    }

    if (widget.field == EditField.currency) {
      _selectedCurrency =
          widget.currentValue?.toString().toUpperCase() ?? 'USD';
    }
  }

  String _getInitialValue() {
    switch (widget.field) {
      case EditField.amount:
        return (widget.currentValue as double).toStringAsFixed(2);
      case EditField.category:
        return widget.currentValue?.toString() ?? 'other';
      case EditField.description:
        return widget.currentValue?.toString() ?? '';
      case EditField.date:
        return DateFormat('yyyy-MM-dd').format(widget.currentValue as DateTime);
      case EditField.time:
        final dateTime = toLocalTime(widget.currentValue as DateTime);
        return DateFormat('HH:mm').format(dateTime);
      case EditField.currency:
        return widget.currentValue?.toString() ?? 'USD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final editState = ref.watch(transactionEditProvider);
    final isLoading = editState.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _getTitle(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),

          // Input field based on type
          _buildInputField(colorScheme),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: AdaptiveButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  style: AdaptiveButtonStyle.plain,
                  label: context.l10n.cancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryAdaptiveButton(
                  onPressed: isLoading ? null : _handleSave,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(ColorScheme colorScheme) {
    if (widget.field == EditField.category) {
      return _buildCategoryPicker(colorScheme);
    } else if (widget.field == EditField.date) {
      return _buildDatePicker(colorScheme);
    } else if (widget.field == EditField.time) {
      return _buildTimePicker(colorScheme);
    } else if (widget.field == EditField.currency) {
      return _buildCurrencyPicker(colorScheme);
    } else {
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () async {
            final value = await showCalculatorKeypadSheet(
              context: context,
              initialValue: _controller.text,
            );
            if (value != null) {
              _controller.text = value;
              if (widget.field == EditField.amount) {
                widget.onChanged?.call();
              }
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: _controller,
              autofocus: widget.field != EditField.date &&
                  widget.field != EditField.time &&
                  widget.field != EditField.currency,
              maxLines: widget.field == EditField.description ? 3 : 1,
              inputFormatters: widget.field == EditField.amount
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
                  : null,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                labelText: _getLabel(),
                labelStyle: TextStyle(color: colorScheme.foreground),
                errorText: _error,
                prefixText: widget.field == EditField.amount
                    ? resolveCurrencySymbol(widget.expense.currency)
                    : null,
                prefixStyle: TextStyle(
                  fontSize: 16,
                  color: colorScheme.foreground,
                ),
              ),
            ),
          ),
        ),
      );
    }
        },
      );
    }
  }

  Widget _buildCategoryPicker(ColorScheme colorScheme) {
    final isIncome =
        (widget.expense.type ?? 'expense').toLowerCase() == 'income';
    final lists = ref.watch(userCategoryListsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

    final baseCategories = isIncome
        ? (lists?.incomeCategories ?? getIncomeCategories())
        : (lists?.expenseCategories ?? getExpenseCategories());
    final categories = () {
      final current = (widget.currentValue?.toString().toLowerCase());
      if (current != null && !baseCategories.contains(current)) {
        return [...baseCategories, current];
      }
      return baseCategories;
    }();

    Future<void> openPicker() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
        builder: (sheetContext) {
          return CategoryPickerBottomSheet(
            allCategories: categories,
            onCreateCategory: (name) => createUserCustomCategory(
              ref: ref,
              name: name,
              isIncome: isIncome,
            ),
            selectedCategories: _selectedCategory != null
                ? <String>[_selectedCategory!]
                : const [],
            isSingleSelect: true,
            onChanged: (value) {
              final next = value.isNotEmpty ? value.first : null;
              setState(() {
                _selectedCategory = next;
                _error = null;
              });
              if (next != null) {
                Navigator.of(sheetContext).pop();
              }
            },
          );
        },
      );
    }

    final selectedCategoryColor = _selectedCategory != null
        ? getCategoryColor(_selectedCategory!)
        : colorScheme.border;
    final selectedCategoryIcon =
        _selectedCategory != null ? getCategoryIcon(_selectedCategory!) : null;
    final selectedCategoryLabel = _selectedCategory != null
        ? getCategoryTranslation(context, _selectedCategory!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.destructive, fontSize: 12),
            ),
          ),
        InkWell(
          onTap: openPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedCategory != null
                    ? selectedCategoryColor
                    : colorScheme.border,
              ),
            ),
            child: Row(
              children: [
                if (selectedCategoryIcon != null) ...[
                  Icon(
                    selectedCategoryIcon,
                    color: selectedCategoryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    selectedCategoryLabel ?? context.l10n.tapToSelectCategories,
                    style: TextStyle(
                      color: _selectedCategory != null
                          ? selectedCategoryColor
                          : colorScheme.foreground,
                      fontWeight: _selectedCategory != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
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
        ),
      ],
    );
  }

  Widget _buildDatePicker(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.destructive, fontSize: 12),
            ),
          ),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: colorScheme.foreground, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy')
                      .format(_selectedDate ?? DateTime.now()),
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now, // Prevent future dates
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _error = null;
      });
    }
  }

  Widget _buildTimePicker(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.destructive, fontSize: 12),
            ),
          ),
        InkWell(
          onTap: () => _selectTime(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: colorScheme.foreground, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedTime?.format(context) ??
                      TimeOfDay.now().format(context),
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
        _error = null;
      });
    }
  }

  Widget _buildCurrencyPicker(ColorScheme colorScheme) {
    final currencies = getAvailableCurrencyOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.destructive, fontSize: 12),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 20, color: colorScheme.mutedForeground),
              isExpanded: true,
              dropdownColor: colorScheme.card,
              style: TextStyle(color: colorScheme.foreground, fontSize: 15),
              selectedItemBuilder: (context) {
                return currencies.entries.map((entry) {
                  final flagPath = getCurrencyFlagPath(entry.key);
                  final symbol = resolveCurrencySymbol(entry.key);

                  return Row(
                    children: [
                      if (flagPath != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.border.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              flagPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(symbol,
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Text(symbol, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                      ],
                      Text(entry.key),
                    ],
                  );
                }).toList();
              },
              items: currencies.entries.map((entry) {
                final flagPath = getCurrencyFlagPath(entry.key);
                final symbol = resolveCurrencySymbol(entry.key);

                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      if (flagPath != null) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.border.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              flagPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(symbol,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.muted.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Text(symbol,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        '${entry.key} - ${entry.value}',
                        style: TextStyle(
                          color: colorScheme.foreground,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCurrency = value;
                    _error = null;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (ref.read(previewModeProvider).isActive) {
      Navigator.of(context, rootNavigator: true).pop();
      AppToast.success(
        context,
        'Preview: changes applied for demo (not saved).',
      );
      return;
    }

    // Validate
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    // Prepare updates
    final updates = _prepareUpdates();

    if (updates.isEmpty) {
      // No changes made
      Navigator.pop(context);
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    final shouldShowCurrencyNotification =
        widget.field == EditField.currency && updates.containsKey('currency');
    final newCurrency = updates['currency'] as String?;

    Navigator.pop(context);
    AppToast.success(toastContext, '${_getLabel()} updated successfully');

    unawaited(() async {
      final success =
          await ref.read(transactionEditProvider.notifier).updateExpense(
                widget.expenseId,
                updates,
                originalExpense: widget.expense,
              );

      if (success) {
        if (shouldShowCurrencyNotification && newCurrency != null) {
          await _showCurrencyChangeNotification(newCurrency);
        }
        return;
      }

      final error = ref.read(transactionEditProvider).error;
      final message = ErrorHandler.getUserFriendlyMessage(
        error,
        context: BackendErrorContext.updateExpense,
      );
      if (!toastContext.mounted) return;
      AppToast.error(toastContext, message);
    }());
  }

  Future<void> _showCurrencyChangeNotification(String newCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    final dontShowAgain =
        prefs.getBool('dont_show_currency_change_notification') ?? false;

    if (dontShowAgain || !mounted) return;

    final colorScheme = Theme.of(context).colorScheme;
    bool checkboxValue = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: colorScheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transaction Moved',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'This transaction has been moved to $newCurrency currency.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.foreground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 16,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To view this transaction, change the currency on the home page.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.foreground,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      checkboxValue = !checkboxValue;
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: checkboxValue,
                          onChanged: (value) {
                            setState(() {
                              checkboxValue = value ?? false;
                            });
                          },
                          activeColor: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Don\'t show this message again',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (checkboxValue) {
                        await prefs.setBool(
                            'dont_show_currency_change_notification', true);
                      }
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.primaryForeground,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validate() {
    switch (widget.field) {
      case EditField.amount:
        final text = _controller.text.trim();
        if (text.isEmpty) {
          return 'Amount cannot be empty';
        }
        final amount = double.tryParse(text);
        if (amount == null) {
          return 'Enter a valid number';
        }
        if (amount <= 0) {
          return 'Amount must be greater than 0';
        }
        if (amount > 1000000) {
          return 'Amount must be less than 1,000,000';
        }
        return null;

      case EditField.description:
        final text = _controller.text.trim();
        if (text.isEmpty) {
          return 'Description cannot be empty';
        }
        if (text.length > 1000) {
          return 'Description must be less than 1000 characters';
        }
        return null;

      case EditField.category:
        if (_selectedCategory == null || _selectedCategory!.isEmpty) {
          return 'Please select a category';
        }
        return null;

      case EditField.date:
        if (_selectedDate == null) {
          return 'Please select a date';
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedLocal = toLocalTime(_selectedDate!);
        final selectedDateOnly = DateTime(
          selectedLocal.year,
          selectedLocal.month,
          selectedLocal.day,
        );
        if (selectedDateOnly.isAfter(today)) {
          return 'Date cannot be in the future';
        }
        return null;

      case EditField.time:
        if (_selectedTime == null) {
          return 'Please select a time';
        }
        return null;

      case EditField.currency:
        if (_selectedCurrency == null || _selectedCurrency!.isEmpty) {
          return 'Please select a currency';
        }
        if (!isSupportedCurrencyCode(_selectedCurrency!)) {
          return 'Invalid currency code';
        }
        return null;
    }
  }

  Map<String, dynamic> _prepareUpdates() {
    final updates = <String, dynamic>{};

    switch (widget.field) {
      case EditField.amount:
        final amount = double.parse(_controller.text);
        final newAmountCents = (amount * 100).round();
        if (newAmountCents != widget.expense.amountCents) {
          updates['amount_cents'] = newAmountCents;
        }
        break;

      case EditField.category:
        final newCategory = _selectedCategory?.toLowerCase();
        if (newCategory != widget.expense.category) {
          updates['category'] = newCategory;
        }
        break;

      case EditField.description:
        final newText = _controller.text.trim();
        if (newText != widget.expense.rawText) {
          updates['raw_text'] = newText;
        }
        break;

      case EditField.date:
        final newDateStr =
            DateFormat('yyyy-MM-dd').format(toLocalTime(_selectedDate!));
        final oldDateStr =
            DateFormat('yyyy-MM-dd').format(toLocalTime(widget.expense.date));
        if (newDateStr != oldDateStr) {
          updates['date'] = newDateStr;
        }
        break;

      case EditField.time:
        final oldTime = toLocalTime(widget.expense.createdAt);
        final newTime = _selectedTime!;
        // Compare time parts only
        if (newTime.hour != oldTime.hour || newTime.minute != oldTime.minute) {
          // Interpret as a local wall-clock edit, then persist as UTC ISO.
          final updatedLocalDateTime = DateTime(
            oldTime.year,
            oldTime.month,
            oldTime.day,
            newTime.hour,
            newTime.minute,
          );
          updates['created_at'] =
              updatedLocalDateTime.toUtc().toIso8601String();
        }
        break;

      case EditField.currency:
        final newCurrency = _selectedCurrency!.toUpperCase();
        if (newCurrency != widget.expense.currency?.toUpperCase()) {
          updates['currency'] = newCurrency;
        }
        break;
    }

    return updates;
  }

  String _getTitle() {
    switch (widget.field) {
      case EditField.amount:
        return 'Edit Amount';
      case EditField.category:
        return 'Edit Category';
      case EditField.description:
        return 'Edit Description';
      case EditField.date:
        return 'Edit Date';
      case EditField.time:
        return 'Edit Time';
      case EditField.currency:
        return 'Edit Currency';
    }
  }

  String _getLabel() {
    switch (widget.field) {
      case EditField.amount:
        return 'Amount';
      case EditField.category:
        return 'Category';
      case EditField.description:
        return 'Description';
      case EditField.date:
        return 'Date';
      case EditField.time:
        return 'Time';
      case EditField.currency:
        return 'Currency';
    }
  }

  TextInputType _getKeyboardType() {
    switch (widget.field) {
      case EditField.amount:
        return const TextInputType.numberWithOptions(decimal: true);
      case EditField.currency:
        return TextInputType.text;
      default:
        return TextInputType.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

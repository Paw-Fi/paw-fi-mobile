import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/income/presentation/constants/income_categories.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

void showIncomeEntrySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    builder: (context) => const _IncomeEntrySheet(),
  );
}

class _IncomeEntrySheet extends ConsumerStatefulWidget {
  const _IncomeEntrySheet();

  @override
  ConsumerState<_IncomeEntrySheet> createState() => _IncomeEntrySheetState();
}

class _IncomeEntrySheetState extends ConsumerState<_IncomeEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceController = TextEditingController();

  String _selectedCategory = incomeCategories[0];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedOwnerType = 'me';
  String _selectedPrivacyScope = 'full';
  bool _shareWithHousehold = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Auto-enable household sharing when in household view mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(viewModeProvider);
      if (vm.mode == ViewMode.household) {
        setState(() {
          _shareWithHousehold = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showError(context.l10n.enterValidAmountGreaterThan0);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(authProvider);
      final selectedHousehold = ref.read(selectedHouseholdProvider);

      // Combine date and time
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Generate idempotency key
      final idempotencyKey = _shareWithHousehold && selectedHousehold.householdId != null
          ? '${DateTime.now().millisecondsSinceEpoch}_${user.uid}'
          : null;

      final income = await ref.read(incomeSaveProvider.notifier).saveIncome(
        userId: user.uid,
        amount: amount,
        category: _selectedCategory,
        currency: ref.read(selectedCurrencyProvider),
        date: dateTime,
        description: _descriptionController.text.trim(),
        source: _sourceController.text.trim(),
        ownerType: _selectedOwnerType,
        privacyScope: _selectedPrivacyScope,
        householdId: _shareWithHousehold ? selectedHousehold.householdId : null,
        idempotencyKey: idempotencyKey,
      );

      if (income != null && mounted) {
        Navigator.of(context).pop();
        _showSuccess(context.l10n.incomeAdded ?? 'Income added successfully');
      } else if (mounted) {
        _showError('Failed to save income');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'income:salary':
        return context.l10n.incomeSalary ?? 'Salary';
      case 'income:freelance':
        return context.l10n.incomeFreelance ?? 'Freelance';
      case 'income:investment':
        return context.l10n.incomeInvestment ?? 'Investment';
      case 'income:refund':
        return context.l10n.incomeRefund ?? 'Refund';
      case 'income:gift':
        return context.l10n.incomeGift ?? 'Gift';
      case 'income:bonus':
        return context.l10n.incomeBonus ?? 'Bonus';
      case 'income:rental':
        return context.l10n.incomeRental ?? 'Rental';
      case 'income:other':
        return context.l10n.incomeOther ?? 'Other';
      default:
        return category;
    }
  }

  String _getOwnerTypeLabel(String ownerType) {
    switch (ownerType) {
      case 'me':
        return context.l10n.me ?? 'Me';
      case 'partner':
        return context.l10n.partner ?? 'Partner';
      case 'household':
        return context.l10n.household ?? 'Household';
      default:
        return ownerType;
    }
  }

  String _getPrivacyScopeLabel(String scope) {
    switch (scope) {
      case 'full':
        return context.l10n.privacyFull ?? 'Full Details';
      case 'balances_only':
        return context.l10n.privacyBalancesOnly ?? 'Balances Only';
      case 'private':
        return context.l10n.privacyPrivate ?? 'Private';
      default:
        return scope;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = shadcnui.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.addIncome ?? 'Add Income',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.border),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.l10n.amount,
                        prefixText: resolveCurrencySymbol(ref.watch(selectedCurrencyProvider)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      autofocus: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.enterValidAmountGreaterThan0;
                        }
                        final amount = double.tryParse(value.replaceAll(',', ''));
                        if (amount == null || amount <= 0) {
                          return context.l10n.enterValidAmountGreaterThan0;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Currency Selector
                    GestureDetector(
                      onTap: () async {
                        final result = await showCurrencySelectorModal(context, ref);
                        if (result != null) {
                          ref.read(selectedCurrencyProvider.notifier).state = result;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.currency,
                              style: TextStyle(color: colorScheme.foreground),
                            ),
                            Row(
                              children: [
                                Text(
                                  ref.watch(selectedCurrencyProvider),
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_drop_down, color: colorScheme.mutedForeground),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Category Selector
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: context.l10n.category ?? 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: incomeCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(_getCategoryLabel(category)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Source
                    TextFormField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        labelText: context.l10n.source ,
                        hintText: context.l10n.sourceHint ,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context.l10n.description,
                        hintText: context.l10n.descriptionHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.date ?? 'Date',
                                    style: TextStyle(color: colorScheme.foreground),
                                  ),
                                  Text(
                                    DateFormat.yMMMd().format(_selectedDate),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.time ?? 'Time',
                                    style: TextStyle(color: colorScheme.foreground),
                                  ),
                                  Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Share with Household
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.shareWithHousehold ?? 'Share with Household',
                            style: TextStyle(color: colorScheme.foreground),
                          ),
                          Switch(
                            value: _shareWithHousehold,
                            onChanged: (value) {
                              setState(() {
                                _shareWithHousehold = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    if (_shareWithHousehold) ...[
                      const SizedBox(height: 16),

                      // Owner Type
                      DropdownButtonFormField<String>(
                        value: _selectedOwnerType,
                        decoration: InputDecoration(
                          labelText: context.l10n.owner ?? 'Owner',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['me', 'partner', 'household'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getOwnerTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedOwnerType = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Privacy Scope
                      DropdownButtonFormField<String>(
                        value: _selectedPrivacyScope,
                        decoration: InputDecoration(
                          labelText: context.l10n.privacyScope ?? 'Privacy',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['full', 'balances_only', 'private'].map((scope) {
                          return DropdownMenuItem(
                            value: scope,
                            child: Text(_getPrivacyScopeLabel(scope)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedPrivacyScope = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 8),

                      // Privacy Explanation
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.muted.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getPrivacyExplanation(_selectedPrivacyScope),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: shadcnui.PrimaryButton(
                        onPressed: _isSaving ? null : _saveIncome,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(context.l10n.save ?? 'Save'),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPrivacyExplanation(String scope) {
    switch (scope) {
      case 'full':
        return context.l10n.privacyFullExplanation ??
            'Partner can see all details including amount, source, and description.';
      case 'balances_only':
        return context.l10n.privacyBalancesOnlyExplanation ??
            'Partner can see this income in totals but not the details (source, description hidden).';
      case 'private':
        return context.l10n.privacyPrivateExplanation ??
            'Only you can see this income. It contributes to household totals but partner cannot see details.';
      default:
        return '';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/goals_providers.dart';
import '../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

void showCreateGoalSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CreateGoalSheet(),
  );
}

class _CreateGoalSheet extends ConsumerStatefulWidget {
  const _CreateGoalSheet();

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();

  String _category = 'savings';
  String _currency = 'USD';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  String _privacyScope = 'full';
  final String _ownerType = 'me';
  final String _goalType = 'custom';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.createGoal,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l10n.goalTitle,
                            hintText: l10n.enterGoalTitle,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.pleaseEnterTitle;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Category
                        Text(l10n.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'savings',
                              label: Text(l10n.savings),
                              icon: const Icon(Icons.savings),
                            ),
                            ButtonSegment(
                              value: 'paydown',
                              label: Text(l10n.paydown),
                              icon: const Icon(Icons.trending_down),
                            ),
                          ],
                          selected: {_category},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _category = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Target amount
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _targetAmountController,
                                decoration: InputDecoration(
                                  labelText: l10n.targetAmount,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.pleaseEnterAmount;
                                  }
                                  final amount = double.tryParse(value);
                                  if (amount == null || amount <= 0) {
                                    return l10n.invalidAmount;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                initialValue: _currency,
                                items: ['USD', 'EUR', 'GBP', 'JPY', 'CNY']
                                    .map((currency) => DropdownMenuItem(
                                          value: currency,
                                          child: Text(currency),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _currency = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Current amount (optional)
                        TextFormField(
                          controller: _currentAmountController,
                          decoration: InputDecoration(
                            labelText: l10n.currentAmount,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        // Target date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.targetDate),
                          subtitle: Text(_targetDate.toString().split(' ')[0]),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _targetDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (date != null) {
                              setState(() {
                                _targetDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Description (optional)
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: l10n.description,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        // Privacy scope
                        Text(l10n.privacyScope, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _privacyScope,
                          items: [
                            DropdownMenuItem(
                              value: 'full',
                              child: Text(l10n.privacyFull),
                            ),
                            DropdownMenuItem(
                              value: 'balances_only',
                              child: Text(l10n.privacyBalancesOnly),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text(l10n.privacyPrivate),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _privacyScope = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            child: Text(l10n.createGoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = context.l10n;
    final targetAmount = double.parse(_targetAmountController.text);
    final currentAmount = _currentAmountController.text.isEmpty
        ? 0.0
        : double.parse(_currentAmountController.text);

    // TODO: Get actual user ID and household ID from auth/context
    const userId = 'current-user-id';
    const householdId = null; // TODO: Get from context if in household view

    await ref.read(createGoalProvider.notifier).createGoal(
          userId: userId,
          householdId: householdId,
          title: _titleController.text,
          category: _category,
          targetAmount: targetAmount,
          currentAmount: currentAmount > 0 ? currentAmount : null,
          currency: _currency,
          targetDate: _targetDate.toString().split(' ')[0],
          goalType: _goalType,
          privacyScope: _privacyScope,
          ownerType: _ownerType,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          idempotencyKey: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
        );

    if (mounted) {
      Navigator.of(context).pop();
      AppToast.success(context, l10n.goalCreated);
    }
  }
}

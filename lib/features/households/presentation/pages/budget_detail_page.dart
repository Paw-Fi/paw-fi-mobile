// Budget detail and edit page
// Displays full budget information with edit and delete capabilities

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Budget Detail Page
/// Shows complete budget information and allows editing
class BudgetDetailPage extends ConsumerStatefulWidget {
  final SharedBudget budget;
  final String householdId;

  const BudgetDetailPage({
    super.key,
    required this.budget,
    required this.householdId,
  });

  @override
  ConsumerState<BudgetDetailPage> createState() => _BudgetDetailPageState();
}

class _BudgetDetailPageState extends ConsumerState<BudgetDetailPage> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _warnThresholdController;
  late TextEditingController _alertThresholdController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.budget.name);
    _amountController = TextEditingController(
      text: (widget.budget.amountCents / 100).toStringAsFixed(2),
    );
    _warnThresholdController = TextEditingController(
      text: (widget.budget.warnThreshold * 100).toStringAsFixed(0),
    );
    _alertThresholdController = TextEditingController(
      text: (widget.budget.alertThreshold * 100).toStringAsFixed(0),
    );
    _isActive = widget.budget.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _warnThresholdController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          _isEditing ? context.l10n.editBudget : context.l10n.budgetDetails,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.primary),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: context.l10n.editBudget,
            ),
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.destructive),
              onPressed: _confirmDelete,
              tooltip: context.l10n.deleteBudget,
            ),
        ],
      ),
      body: _isSaving || _isDeleting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isDeleting ? context.l10n.deletingBudget : context.l10n.savingChanges,
                    style: TextStyle(color: colorScheme.mutedForeground),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Budget Name
                  _buildField(
                    label: context.l10n.budgetName,
                    controller: _nameController,
                    enabled: _isEditing,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  _buildField(
                    label: '${context.l10n.amount} (${widget.budget.currency})',
                    controller: _amountController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                    colorScheme: colorScheme,
                    prefix: widget.budget.currency == 'USD' ? '\$' : widget.budget.currency,
                  ),

                  const SizedBox(height: 16),

                  // Period (Read-only)
                  _buildReadOnlyField(
                    label: context.l10n.period,
                    value: widget.budget.period.toJson().toUpperCase(),
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

                  // Currency (Read-only)
                  _buildReadOnlyField(
                    label: context.l10n.currency,
                    value: widget.budget.currency,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 24),

                  // // Thresholds Section
                  // Text(
                  //   context.l10n.alertThresholds,
                  //   style: TextStyle(
                  //     fontSize: 18,
                  //     fontWeight: FontWeight.w600,
                  //     color: colorScheme.foreground,
                  //   ),
                  // ),
                  // const SizedBox(height: 12),

                  // // Warn Threshold
                  // _buildField(
                  //   label: context.l10n.warningThreshold,
                  //   controller: _warnThresholdController,
                  //   enabled: _isEditing,
                  //   keyboardType: TextInputType.number,
                  //   colorScheme: colorScheme,
                  //   suffix: '%',
                  //   helperText: context.l10n.warningThresholdHelper,
                  // ),

                  // const SizedBox(height: 16),

                  // // Alert Threshold
                  // _buildField(
                  //   label: context.l10n.alertThreshold,
                  //   controller: _alertThresholdController,
                  //   enabled: _isEditing,
                  //   keyboardType: TextInputType.number,
                  //   colorScheme: colorScheme,
                  //   suffix: '%',
                  //   helperText: context.l10n.alertThresholdHelper,
                  // ),

                  // const SizedBox(height: 24),

                  // // Status Toggle
                  // if (_isEditing)
                  //   Card(
                  //     child: Padding(
                  //       padding: const EdgeInsets.all(16),
                  //       child: Row(
                  //         children: [
                  //           Expanded(
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.start,
                  //               children: [
                  //                 Text(
                  //                   context.l10n.budgetStatus,
                  //                   style: TextStyle(
                  //                     fontSize: 16,
                  //                     fontWeight: FontWeight.w600,
                  //                     color: colorScheme.foreground,
                  //                   ),
                  //                 ),
                  //                 const SizedBox(height: 4),
                  //                 Text(
                  //                   _isActive ? context.l10n.active : context.l10n.inactive,
                  //                   style: TextStyle(
                  //                     fontSize: 14,
                  //                     color: colorScheme.mutedForeground,
                  //                   ),
                  //                 ),
                  //               ],
                  //             ),
                  //           ),
                  //           Switch(
                  //             value: _isActive,
                  //             onChanged: (value) => setState(() => _isActive = value),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),

                  // const SizedBox(height: 24),

                  // Save/Cancel Buttons
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: shadcnui.OutlineButton(
                            onPressed: _cancelEditing,
                            child: Text(context.l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: shadcnui.PrimaryButton(
                            onPressed: _saveChanges,
                            child: Text(context.l10n.saveChanges),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required shadcnui.ColorScheme colorScheme,
    TextInputType? keyboardType,
    String? prefix,
    String? suffix,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            helperText: helperText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: !enabled,
            fillColor: enabled ? null : colorScheme.muted.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required shadcnui.ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.border),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.foreground,
            ),
          ),
        ),
      ],
    );
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      // Reset controllers to original values
      _nameController.text = widget.budget.name;
      _amountController.text = (widget.budget.amountCents / 100).toStringAsFixed(2);
      _warnThresholdController.text = (widget.budget.warnThreshold * 100).toStringAsFixed(0);
      _alertThresholdController.text = (widget.budget.alertThreshold * 100).toStringAsFixed(0);
      _isActive = widget.budget.isActive;
    });
  }

  Future<void> _saveChanges() async {
    // Validate inputs
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(context.l10n.budgetNameCannotBeEmpty);
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError(context.l10n.pleaseEnterValidAmount);
      return;
    }

    final warnThreshold = double.tryParse(_warnThresholdController.text);
    if (warnThreshold == null || warnThreshold < 0 || warnThreshold > 100) {
      _showError(context.l10n.warningThresholdRange);
      return;
    }

    final alertThreshold = double.tryParse(_alertThresholdController.text);
    if (alertThreshold == null || alertThreshold < 0 || alertThreshold > 100) {
      _showError(context.l10n.alertThresholdRange);
      return;
    }

    if (warnThreshold > alertThreshold) {
      _showError(context.l10n.warningThresholdLessThanAlert);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(householdRepositoryProvider);
      await repository.updateBudget(
        budgetId: widget.budget.id,
        name: name != widget.budget.name ? name : null,
        amountCents: (amount * 100).toInt() != widget.budget.amountCents
            ? (amount * 100).toInt()
            : null,
        warnThreshold: (warnThreshold / 100) != widget.budget.warnThreshold
            ? warnThreshold / 100
            : null,
        alertThreshold: (alertThreshold / 100) != widget.budget.alertThreshold
            ? alertThreshold / 100
            : null,
        isActive: _isActive != widget.budget.isActive ? _isActive : null,
      );

      // Invalidate budgets provider to refresh list
      ref.invalidate(householdBudgetsProvider);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.budgetUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('${context.l10n.failedToUpdateBudget}: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteBudget),
        content: Text(
          '${context.l10n.confirmDeleteBudget} "${widget.budget.name}"? ${context.l10n.deleteBudgetCannotBeUndone}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.destructive),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteBudget();
    }
  }

  Future<void> _deleteBudget() async {
    setState(() => _isDeleting = true);

    try {
      final repository = ref.read(householdRepositoryProvider);
      await repository.deleteBudget(widget.budget.id);

      // Invalidate budgets provider to refresh list
      ref.invalidate(householdBudgetsProvider);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.budgetDeletedSuccessfully),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('${context.l10n.failedToDeleteBudget}: $error');
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: shadcnui.Theme.of(context).colorScheme.destructive,
      ),
    );
  }
}

// Budget detail and edit page
// Displays full budget information with edit and delete capabilities

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';

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
          _isEditing ? 'Edit Budget' : 'Budget Details',
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
              tooltip: 'Edit Budget',
            ),
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.destructive),
              onPressed: _confirmDelete,
              tooltip: 'Delete Budget',
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
                    _isDeleting ? 'Deleting budget...' : 'Saving changes...',
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
                    label: 'Budget Name',
                    controller: _nameController,
                    enabled: _isEditing,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  _buildField(
                    label: 'Amount (${widget.budget.currency})',
                    controller: _amountController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                    colorScheme: colorScheme,
                    prefix: widget.budget.currency == 'USD' ? '\$' : widget.budget.currency,
                  ),

                  const SizedBox(height: 16),

                  // Period (Read-only)
                  _buildReadOnlyField(
                    label: 'Period',
                    value: widget.budget.period.toJson().toUpperCase(),
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

                  // Currency (Read-only)
                  _buildReadOnlyField(
                    label: 'Currency',
                    value: widget.budget.currency,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 24),

                  // Thresholds Section
                  Text(
                    'Alert Thresholds',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warn Threshold
                  _buildField(
                    label: 'Warning Threshold (%)',
                    controller: _warnThresholdController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                    colorScheme: colorScheme,
                    suffix: '%',
                    helperText: 'Alert when budget usage reaches this percentage',
                  ),

                  const SizedBox(height: 16),

                  // Alert Threshold
                  _buildField(
                    label: 'Alert Threshold (%)',
                    controller: _alertThresholdController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                    colorScheme: colorScheme,
                    suffix: '%',
                    helperText: 'Critical alert at this percentage',
                  ),

                  const SizedBox(height: 24),

                  // Status Toggle
                  if (_isEditing)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Budget Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (value) => setState(() => _isActive = value),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Save/Cancel Buttons
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: shadcnui.OutlineButton(
                            onPressed: _cancelEditing,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: shadcnui.PrimaryButton(
                            onPressed: _saveChanges,
                            child: const Text('Save Changes'),
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
            fillColor: enabled ? null : colorScheme.muted.withOpacity(0.3),
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
            color: colorScheme.muted.withOpacity(0.3),
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
      _showError('Budget name cannot be empty');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    final warnThreshold = double.tryParse(_warnThresholdController.text);
    if (warnThreshold == null || warnThreshold < 0 || warnThreshold > 100) {
      _showError('Warning threshold must be between 0 and 100');
      return;
    }

    final alertThreshold = double.tryParse(_alertThresholdController.text);
    if (alertThreshold == null || alertThreshold < 0 || alertThreshold > 100) {
      _showError('Alert threshold must be between 0 and 100');
      return;
    }

    if (warnThreshold > alertThreshold) {
      _showError('Warning threshold must be less than or equal to alert threshold');
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
          const SnackBar(
            content: Text('Budget updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('Failed to update budget: $error');
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
        title: const Text('Delete Budget'),
        content: Text(
          'Are you sure you want to delete "${widget.budget.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.destructive),
            child: const Text('Delete'),
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
          const SnackBar(
            content: Text('Budget deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('Failed to delete budget: $error');
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

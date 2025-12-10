import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
/// Split Builder Page
/// Interactive expense splitting tool
class SplitBuilderPage extends ConsumerStatefulWidget {
  final String householdId;
  final String? expenseId; // FIXED: Changed from transactionId to match database schema
  final int? totalAmountCents;

  const SplitBuilderPage({
    super.key,
    required this.householdId,
    this.expenseId,
    this.totalAmountCents,
  });

  @override
  ConsumerState<SplitBuilderPage> createState() => _SplitBuilderPageState();
}

class _SplitBuilderPageState extends ConsumerState<SplitBuilderPage> {
  SplitType _selectedType = SplitType.equal;
  final Map<String, double> _splitValues = {};
  String? _selectedPayer;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.totalAmountCents != null) {
      _amountController.text = (widget.totalAmountCents! / 100).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(householdMembersProvider(widget.householdId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.appBackground,
        elevation: 0,
        title: Text(
          'Split Expense',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: membersAsync.when(
        data: (members) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Amount
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: context.l10n.totalAmount,
                  prefixText: context.l10n.dollarSign,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),

              // Who Paid?
              Text(
                context.l10n.whoPaid,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPayer,
                decoration: InputDecoration(
                  labelText: context.l10n.payer,
                  border: const OutlineInputBorder(),
                ),
                items: members
                    .map((m) => DropdownMenuItem(
                          value: m.userId,
                          child: Text(m.userName ?? m.userEmail ?? context.l10n.unknown),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPayer = value);
                },
              ),
              const SizedBox(height: 24),

              // Split Type
              Text(
                'Split Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              _SplitTypeSelector(
                selectedType: _selectedType,
                onChanged: (type) {
                  setState(() {
                    _selectedType = type;
                    _splitValues.clear();
                  });
                },
              ),
              const SizedBox(height: 24),

              // Split Configuration
              Text(
                'Split Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              ...members.map((member) => _SplitMemberRow(
                    member: member,
                    splitType: _selectedType,
                    value: _splitValues[member.userId],
                    onChanged: (value) {
                      setState(() {
                        _splitValues[member.userId] = value;
                      });
                    },
                  )),
              const SizedBox(height: 24),

              // Preview
              _SplitPreview(
                members: members,
                totalAmountCents: _getTotalAmountCents(),
                splitType: _selectedType,
                splitValues: _splitValues,
              ),
              const SizedBox(height: 24),

              // Create Split Button
              SizedBox(
                width: double.infinity,
                child: PrimaryAdaptiveButton(
                  onPressed: _canCreateSplit(members)
                      ? () => _createSplit(members)
                      : null,
                  child: Text(context.l10n.createSplit),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('${context.l10n.error}: $error', style: TextStyle(color: colorScheme.destructive)),
        ),
      ),
    );
  }

  int _getTotalAmountCents() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return (amount * 100).toInt();
  }

  bool _canCreateSplit(List<HouseholdMember> members) {
    if (_selectedPayer == null) return false;
    if (_getTotalAmountCents() <= 0) return false;

    switch (_selectedType) {
      case SplitType.equal:
        return true;
      case SplitType.percentage:
        final total = _splitValues.values.fold(0.0, (sum, val) => sum + val);
        return (total - 100).abs() < 0.01;
      case SplitType.amount:
        final total = _splitValues.values.fold(0.0, (sum, val) => sum + val);
        return (total - _getTotalAmountCents() / 100).abs() < 0.01;
      case SplitType.shares:
        return _splitValues.values.any((v) => v > 0);
    }
  }

  Future<void> _createSplit(List<HouseholdMember> members) async {
    try {
      final splits = members.map((member) {
        switch (_selectedType) {
          case SplitType.equal:
            return SplitLineRequest(userId: member.userId);
          case SplitType.percentage:
            return SplitLineRequest(
              userId: member.userId,
              percentage: _splitValues[member.userId] ?? 0,
            );
          case SplitType.amount:
            return SplitLineRequest(
              userId: member.userId,
              amountCents: ((_splitValues[member.userId] ?? 0) * 100).toInt(),
            );
          case SplitType.shares:
            return SplitLineRequest(
              userId: member.userId,
              shares: (_splitValues[member.userId] ?? 0).toInt(),
            );
        }
      }).toList();

      final request = SplitRequest(
        expenseId: widget.expenseId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        householdId: widget.householdId,
        payerUserId: _selectedPayer!,
        splitType: _selectedType,
        currency: 'USD',
        totalAmountCents: _getTotalAmountCents(),
        splits: splits,
      );

      final repository = ref.read(householdRepositoryProvider);
      await repository.computeSplit(request);

      if (mounted) {
        AppToast.success(context, 'Split created successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error creating split: $e');
      }
    }
  }
}

/// Split Type Selector
class _SplitTypeSelector extends StatelessWidget {
  final SplitType selectedType;
  final Function(SplitType) onChanged;

  const _SplitTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SplitType.values.map((type) {
        final isSelected = type == selectedType;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type.toJson().toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Split Member Row
class _SplitMemberRow extends StatelessWidget {
  final HouseholdMember member;
  final SplitType splitType;
  final double? value;
  final Function(double) onChanged;

  const _SplitMemberRow({
    required this.member,
    required this.splitType,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (splitType == SplitType.equal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(member.userName ?? member.userEmail ?? 'Unknown'),
            ),
            Text(context.l10n.equalShare),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(member.userName ?? member.userEmail ?? 'Unknown'),
          ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: _getSuffix(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (text) {
                final val = double.tryParse(text) ?? 0;
                onChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getSuffix() {
    switch (splitType) {
      case SplitType.percentage:
        return '%';
      case SplitType.amount:
        return '\$';
      case SplitType.shares:
        return 'shares';
      default:
        return '';
    }
  }
}

/// Split Preview
class _SplitPreview extends StatelessWidget {
  final List<HouseholdMember> members;
  final int totalAmountCents;
  final SplitType splitType;
  final Map<String, double> splitValues;

  const _SplitPreview({
    required this.members,
    required this.totalAmountCents,
    required this.splitType,
    required this.splitValues,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const Divider(),
            ...members.map((member) {
              final amount = _calculateAmount(member.userId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(member.userName ?? member.userEmail ?? 'Unknown'),
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _calculateAmount(String userId) {
    final totalAmount = totalAmountCents / 100;

    switch (splitType) {
      case SplitType.equal:
        return totalAmount / members.length;
      case SplitType.percentage:
        final percentage = splitValues[userId] ?? 0;
        return totalAmount * (percentage / 100);
      case SplitType.amount:
        return splitValues[userId] ?? 0;
      case SplitType.shares:
        final shares = splitValues[userId] ?? 0;
        final totalShares = splitValues.values.fold(0.0, (sum, val) => sum + val);
        return totalShares > 0 ? totalAmount * (shares / totalShares) : 0;
    }
  }
}

// Custom split configuration sheet
// Allows users to split expenses by amount, percentage, or shares

import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/utils/household_ui_utils.dart';

enum SplitType { equal, amount, percentage, shares }

class MemberSplit {
  final HouseholdMember member;
  double? amount;
  double? percentage;
  int? shares;

  MemberSplit({
    required this.member,
    this.amount,
    this.percentage,
    this.shares,
  });

  MemberSplit copyWith({
    double? amount,
    double? percentage,
    int? shares,
  }) {
    return MemberSplit(
      member: member,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
    );
  }
}

/// Shows custom split configuration sheet
void showCustomSplitSheet({
  required BuildContext context,
  required List<HouseholdMember> members,
  required double totalAmount,
  required String currencySymbol,
  required Function(SplitType splitType, List<MemberSplit> splits) onSave,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    builder: (context) => _CustomSplitSheet(
      members: members,
      totalAmount: totalAmount,
      currencySymbol: currencySymbol,
      onSave: onSave,
    ),
  );
}

class _CustomSplitSheet extends StatefulWidget {
  final List<HouseholdMember> members;
  final double totalAmount;
  final String currencySymbol;
  final Function(SplitType splitType, List<MemberSplit> splits) onSave;

  const _CustomSplitSheet({
    required this.members,
    required this.totalAmount,
    required this.currencySymbol,
    required this.onSave,
  });

  @override
  State<_CustomSplitSheet> createState() => _CustomSplitSheetState();
}

class _CustomSplitSheetState extends State<_CustomSplitSheet> {
  SplitType _selectedType = SplitType.equal;
  late List<MemberSplit> _memberSplits;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _initializeSplits();
  }

  void _initializeSplits() {
    _memberSplits = widget.members.map((member) {
      return MemberSplit(
        member: member,
        amount: widget.totalAmount / widget.members.length,
        percentage: 100.0 / widget.members.length,
        shares: 1,
      );
    }).toList();
  }

  void _validateAndSave() {
    setState(() => _validationError = null);

    // Validate based on split type
    switch (_selectedType) {
      case SplitType.equal:
        // No validation needed for equal splits
        break;

      case SplitType.amount:
        final totalSplit = _memberSplits.fold<double>(
          0,
          (sum, split) => sum + (split.amount ?? 0),
        );
        if ((totalSplit - widget.totalAmount).abs() > 0.01) {
          setState(() => _validationError =
              'Split amounts must equal ${widget.currencySymbol}${widget.totalAmount.toStringAsFixed(2)}');
          return;
        }
        break;

      case SplitType.percentage:
        final totalPercent = _memberSplits.fold<double>(
          0,
          (sum, split) => sum + (split.percentage ?? 0),
        );
        if ((totalPercent - 100).abs() > 0.01) {
          setState(() => _validationError = 'Percentages must total 100%');
          return;
        }
        break;

      case SplitType.shares:
        // Shares always valid as long as > 0
        if (_memberSplits.any((s) => (s.shares ?? 0) <= 0)) {
          setState(() => _validationError = 'Each person must have at least 1 share');
          return;
        }
        break;
    }

    widget.onSave(_selectedType, _memberSplits);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: colorScheme.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Split Expense',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Total Amount Display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.muted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Total: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${widget.currencySymbol}${widget.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Split Type Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTypeChip(colorScheme, 'Amount', SplitType.amount),
                const SizedBox(width: 8),
                _buildTypeChip(colorScheme, 'Percent', SplitType.percentage),
                const SizedBox(width: 8),
                _buildTypeChip(colorScheme, 'Share', SplitType.shares),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Member List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _memberSplits.length,
              itemBuilder: (context, index) {
                return _buildMemberRow(colorScheme, index);
              },
            ),
          ),

          // Validation Error
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.destructive.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.destructive.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, 
                        color: colorScheme.destructive, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.destructive,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Save Button
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: shadcnui.PrimaryButton(
                onPressed: _validateAndSave,
                child: const Text('Apply Split'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(shadcnui.ColorScheme colorScheme, String label, SplitType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.muted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.border.withOpacity(0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? colorScheme.primaryForeground : colorScheme.foreground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberRow(shadcnui.ColorScheme colorScheme, int index) {
    final memberSplit = _memberSplits[index];
    final member = memberSplit.member;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          MemberAvatar(
            role: member.role,
            avatarUrl: member.avatarUrl,
            name: member.userName,
            email: member.userEmail,
            radius: 20,
          ),
          const SizedBox(width: 12),

          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.userName ?? member.userEmail ?? 'Member',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedType != SplitType.equal)
                  Text(
                    _getOweText(index),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),

          // Split Input
          if (_selectedType == SplitType.equal)
            Text(
              '${widget.currencySymbol}${(widget.totalAmount / widget.members.length).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            )
          else
            SizedBox(
              width: 100,
              child: _buildSplitInput(colorScheme, index),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitInput(shadcnui.ColorScheme colorScheme, int index) {
    final memberSplit = _memberSplits[index];
    String value = '';
    String suffix = '';

    switch (_selectedType) {
      case SplitType.amount:
        value = memberSplit.amount?.toStringAsFixed(2) ?? '';
        suffix = widget.currencySymbol;
        break;
      case SplitType.percentage:
        value = memberSplit.percentage?.toStringAsFixed(1) ?? '';
        suffix = '%';
        break;
      case SplitType.shares:
        value = memberSplit.shares?.toString() ?? '';
        suffix = '';
        break;
      case SplitType.equal:
        break;
    }

    return TextField(
      controller: TextEditingController(text: value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.foreground,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.border),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.mutedForeground,
        ),
      ),
      onChanged: (text) {
        setState(() {
          switch (_selectedType) {
            case SplitType.amount:
              _memberSplits[index].amount = double.tryParse(text) ?? 0;
              break;
            case SplitType.percentage:
              _memberSplits[index].percentage = double.tryParse(text) ?? 0;
              break;
            case SplitType.shares:
              _memberSplits[index].shares = int.tryParse(text) ?? 1;
              break;
            case SplitType.equal:
              break;
          }
          _validationError = null;
        });
      },
    );
  }

  String _getOweText(int index) {
    final split = _memberSplits[index];
    double amount = 0;

    switch (_selectedType) {
      case SplitType.amount:
        amount = split.amount ?? 0;
        break;
      case SplitType.percentage:
        amount = widget.totalAmount * (split.percentage ?? 0) / 100;
        break;
      case SplitType.shares:
        final totalShares = _memberSplits.fold<int>(0, (sum, s) => sum + (s.shares ?? 0));
        amount = totalShares > 0 
            ? widget.totalAmount * (split.shares ?? 0) / totalShares 
            : 0;
        break;
      case SplitType.equal:
        amount = widget.totalAmount / widget.members.length;
        break;
    }

    return 'Owes ${widget.currencySymbol}${amount.toStringAsFixed(2)}';
  }
}

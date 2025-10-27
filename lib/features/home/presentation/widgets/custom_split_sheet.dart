// Custom split configuration sheet
// Allows users to split expenses by amount, percentage, or shares
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/utils/household_ui_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';

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

/// Public, embeddable split editor used both inline and inside the bottom sheet
class CustomSplitEditor extends StatefulWidget {
  final List<HouseholdMember> members;
  final double totalAmount;
  final String currencySymbol;
  final void Function(SplitType splitType, List<MemberSplit> splits)? onChanged;

  const CustomSplitEditor({
    super.key,
    required this.members,
    required this.totalAmount,
    required this.currencySymbol,
    this.onChanged,
  });

  @override
  State<CustomSplitEditor> createState() => _CustomSplitEditorState();
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

class _CustomSplitEditorState extends State<CustomSplitEditor> {
  SplitType _selectedType = SplitType.amount;
  late List<MemberSplit> _memberSplits;
  late List<TextEditingController> _controllers;
  String? _validationError;
  Timer? _debounce;
  bool _isUpdatingProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _initializeSplits();
    _initializeControllers();
    // notify parent with initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _queueNotify());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
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

  void _initializeControllers() {
    _controllers = List.generate(
      widget.members.length,
      (index) => TextEditingController(text: _getFormattedValue(index)),
    );
  }

  String _getFormattedValue(int index) {
    final split = _memberSplits[index];
    switch (_selectedType) {
      case SplitType.amount:
        return split.amount?.toStringAsFixed(2) ?? '0.00';
      case SplitType.percentage:
        return split.percentage?.toStringAsFixed(1) ?? '0.0';
      case SplitType.shares:
        return split.shares?.toString() ?? '1';
      case SplitType.equal:
        return '';
    }
  }

  void _updateControllerText(int index, String newText) {
    if (_controllers[index].text != newText) {
      _isUpdatingProgrammatically = true;
      _controllers[index].text = newText;
      _isUpdatingProgrammatically = false;
    }
  }

  void _handleValueChange(int index, String text) {
    if (_isUpdatingProgrammatically) return;

    double? parsedDouble;
    int? parsedInt;

    switch (_selectedType) {
      case SplitType.amount:
        parsedDouble = double.tryParse(text);
        if (parsedDouble != null && parsedDouble > widget.totalAmount) {
          // Exceeds total - show error, don't auto-adjust
          setState(() {
            _memberSplits[index].amount = parsedDouble;
          });
          _validate();
          _queueNotify();
          return;
        }
        _memberSplits[index].amount = parsedDouble ?? 0;
        _autoAdjustOthers(index, SplitType.amount);
        break;

      case SplitType.percentage:
        parsedDouble = double.tryParse(text);
        if (parsedDouble != null && parsedDouble > 100) {
          // Exceeds 100% - show error, don't auto-adjust
          setState(() {
            _memberSplits[index].percentage = parsedDouble;
          });
          _validate();
          _queueNotify();
          return;
        }
        _memberSplits[index].percentage = parsedDouble ?? 0;
        _autoAdjustOthers(index, SplitType.percentage);
        break;

      case SplitType.shares:
        parsedInt = int.tryParse(text);
        setState(() {
          _memberSplits[index].shares = parsedInt ?? 0;
        });
        _validate();
        _queueNotify();
        break;

      case SplitType.equal:
        break;
    }
  }

  void _autoAdjustOthers(int editedIndex, SplitType type) {
    if (widget.members.length <= 1) {
      // Can't auto-adjust with only one member
      setState(() {});
      _validate();
      _queueNotify();
      return;
    }

    final otherIndices = List.generate(widget.members.length, (i) => i)
        .where((i) => i != editedIndex)
        .toList();

    switch (type) {
      case SplitType.amount:
        final editedAmount = _memberSplits[editedIndex].amount ?? 0;
        final remaining = widget.totalAmount - editedAmount;
        final perOther = remaining / otherIndices.length;

        setState(() {
          for (var i in otherIndices) {
            _memberSplits[i].amount = perOther;
            _updateControllerText(i, perOther.toStringAsFixed(2));
          }
        });
        break;

      case SplitType.percentage:
        final editedPercentage = _memberSplits[editedIndex].percentage ?? 0;
        final remaining = 100 - editedPercentage;
        final perOther = remaining / otherIndices.length;

        setState(() {
          for (var i in otherIndices) {
            _memberSplits[i].percentage = perOther;
            _updateControllerText(i, perOther.toStringAsFixed(1));
          }
        });
        break;

      case SplitType.shares:
      case SplitType.equal:
        // No auto-adjustment for shares or equal
        setState(() {});
        break;
    }

    _validate();
    _queueNotify();
  }

  void _validate() {
    String? error;

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
          error = context.l10n.splitAmountsMustEqual(
            widget.currencySymbol,
            widget.totalAmount.toStringAsFixed(2),
          );
        }
        break;

      case SplitType.percentage:
        final totalPercent = _memberSplits.fold<double>(
          0,
          (sum, split) => sum + (split.percentage ?? 0),
        );
        if ((totalPercent - 100).abs() > 0.01) {
          error = context.l10n.percentagesMustTotal100;
        }
        break;

      case SplitType.shares:
        final totalShares = _memberSplits.fold<int>(0, (sum, s) => sum + (s.shares ?? 0));
        if (totalShares <= 0) {
          error = 'At least one member must have a share greater than 0';
        }
        break;
    }
    setState(() => _validationError = error);
  }

  void _queueNotify() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged?.call(_selectedType, List<MemberSplit>.from(_memberSplits));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (Platform.isIOS && MediaQuery.of(context).viewInsets.bottom > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Text(context.l10n.done),
              ),
            ),
          ),


        // Split Type Selector
        Row(
          children: [
            _buildTypeChip(colorScheme, context.l10n.amount, SplitType.amount),
            const SizedBox(width: 8),
            _buildTypeChip(colorScheme, context.l10n.percent, SplitType.percentage),
            const SizedBox(width: 8),
            _buildTypeChip(colorScheme, context.l10n.share, SplitType.shares),
          ],
        ),

        const SizedBox(height: 16),

        // Member List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _memberSplits.length,
          itemBuilder: (context, index) {
            return _buildMemberRow(colorScheme, index);
          },
        ),

        // Validation Error
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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

        // No explicit Apply button; changes are propagated with debounce
      ],
    );
  }

  Widget _buildTypeChip(shadcnui.ColorScheme colorScheme, String label, SplitType type) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            // Update all controllers with new formatted values when type changes
            for (int i = 0; i < _controllers.length; i++) {
              _updateControllerText(i, _getFormattedValue(i));
            }
          });
          _validate();
          _queueNotify();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.muted.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: isSelected ? 2 : 0,
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
    final isSharesMode = _selectedType == SplitType.shares;
    final isIncluded = (memberSplit.shares ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (isSharesMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Checkbox.adaptive(
                value: isIncluded,
                onChanged: (val) {
                  setState(() {
                    final nextIncluded = val ?? false;
                    _memberSplits[index].shares = nextIncluded
                        ? ((memberSplit.shares ?? 0) == 0 ? 1 : memberSplit.shares)
                        : 0;
                    _updateControllerText(index, (_memberSplits[index].shares ?? 0).toString());
                  });
                  _validate();
                  _queueNotify();
                },
              ),
            ),
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
                  member.userName ?? member.userEmail ?? context.l10n.member,
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
              width: 110,
              child: _buildSplitInput(colorScheme, index, enabled: !isSharesMode || isIncluded),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitInput(shadcnui.ColorScheme colorScheme, int index, {bool enabled = true}) {
    String suffix = '';

    switch (_selectedType) {
      case SplitType.amount:
        suffix = widget.currencySymbol;
        break;
      case SplitType.percentage:
        suffix = '%';
        break;
      case SplitType.shares:
        suffix = '';
        break;
      case SplitType.equal:
        break;
    }

    return TextField(
      controller: _controllers[index],
      keyboardType: _selectedType == SplitType.shares
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.right,
      enabled: enabled,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: enabled ? colorScheme.foreground : colorScheme.mutedForeground,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: enabled ? colorScheme.muted.withOpacity(0.08) : colorScheme.muted.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.mutedForeground,
        ),
      ),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: (text) => _handleValueChange(index, text),
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

    return '${context.l10n.owes} ${widget.currencySymbol}${amount.toStringAsFixed(2)}';
  }
}

class _CustomSplitSheetState extends State<_CustomSplitSheet> {
  SplitType? _latestType;
  List<MemberSplit>? _latestSplits;
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
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: colorScheme.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.splitExpense,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  onPressed: () {
                    if (_latestType != null && _latestSplits != null) {
                      widget.onSave(_latestType!, _latestSplits!);
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: CustomSplitEditor(
                members: widget.members,
                totalAmount: widget.totalAmount,
                currencySymbol: widget.currencySymbol,
                onChanged: (type, splits) {
                  _latestType = type;
                  _latestSplits = splits;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

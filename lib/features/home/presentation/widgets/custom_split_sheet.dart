// Custom split configuration sheet
// Allows users to split expenses by amount, percentage, or shares
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/l10n/l10n.dart';

enum SplitType { equal, amount, percentage, shares }

class MemberSplit {
  final HouseholdMember member;
  double? amount;
  double? percentage;
  int? shares;
  bool includedInAmount;
  bool includedInPercentage;

  MemberSplit({
    required this.member,
    this.amount,
    this.percentage,
    this.shares,
    this.includedInAmount = true,
    this.includedInPercentage = true,
  });

  MemberSplit copyWith({
    double? amount,
    double? percentage,
    int? shares,
    bool? includedInAmount,
    bool? includedInPercentage,
  }) {
    return MemberSplit(
      member: member,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      includedInAmount: includedInAmount ?? this.includedInAmount,
      includedInPercentage: includedInPercentage ?? this.includedInPercentage,
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
        if (parsedDouble != null && parsedDouble < 0) parsedDouble = 0; // clamp negatives
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
        if (parsedDouble != null && parsedDouble < 0) parsedDouble = 0; // clamp negatives
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
    final allIndices = List.generate(widget.members.length, (i) => i);

    switch (type) {
      case SplitType.amount:
        if (!_memberSplits[editedIndex].includedInAmount) {
          _validate();
          _queueNotify();
          return;
        }
        final otherIndices = allIndices
            .where((i) => i != editedIndex && _memberSplits[i].includedInAmount)
            .toList();
        final editedAmount = _memberSplits[editedIndex].amount ?? 0;
        if (otherIndices.isEmpty) {
          setState(() {
            _memberSplits[editedIndex].amount = widget.totalAmount;
            _updateControllerText(editedIndex, widget.totalAmount.toStringAsFixed(2));
          });
          _validate();
          _queueNotify();
          return;
        }
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
        if (!_memberSplits[editedIndex].includedInPercentage) {
          _validate();
          _queueNotify();
          return;
        }
        final otherIndicesPct = allIndices
            .where((i) => i != editedIndex && _memberSplits[i].includedInPercentage)
            .toList();
        final editedPercentage = _memberSplits[editedIndex].percentage ?? 0;
        if (otherIndicesPct.isEmpty) {
          setState(() {
            _memberSplits[editedIndex].percentage = 100;
            _updateControllerText(editedIndex, 100.toStringAsFixed(1));
          });
          _validate();
          _queueNotify();
          return;
        }
        final remaining = 100 - editedPercentage;
        final perOther = remaining / otherIndicesPct.length;
        setState(() {
          for (var i in otherIndicesPct) {
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

  List<int> _includedIndicesForType(SplitType type) {
    switch (type) {
      case SplitType.amount:
        return List.generate(widget.members.length, (i) => i)
            .where((i) => _memberSplits[i].includedInAmount)
            .toList();
      case SplitType.percentage:
        return List.generate(widget.members.length, (i) => i)
            .where((i) => _memberSplits[i].includedInPercentage)
            .toList();
      case SplitType.shares:
        return List.generate(widget.members.length, (i) => i)
            .where((i) => (_memberSplits[i].shares ?? 0) > 0)
            .toList();
      case SplitType.equal:
        return List.generate(widget.members.length, (i) => i);
    }
  }

  void _redistributeAmongIncluded(SplitType type) {
    final included = _includedIndicesForType(type);
    if (type == SplitType.amount) {
      if (included.isEmpty) {
        setState(() {
          for (var i = 0; i < _memberSplits.length; i++) {
            _memberSplits[i].amount = 0;
            _updateControllerText(i, 0.toStringAsFixed(2));
          }
        });
        _validate();
        _queueNotify();
        return;
      }
      if (included.length == 1) {
        final only = included.first;
        setState(() {
          for (var i = 0; i < _memberSplits.length; i++) {
            _memberSplits[i].amount = i == only ? widget.totalAmount : 0;
            _updateControllerText(i, (_memberSplits[i].amount ?? 0).toStringAsFixed(2));
          }
        });
        _validate();
        _queueNotify();
        return;
      }
      final per = widget.totalAmount / included.length;
      double sumOthers = 0;
      setState(() {
        for (int k = 0; k < included.length; k++) {
          final idx = included[k];
          if (k < included.length - 1) {
            _memberSplits[idx].amount = per;
            sumOthers += per;
          } else {
            _memberSplits[idx].amount = widget.totalAmount - sumOthers;
          }
        }
        for (int i = 0; i < _memberSplits.length; i++) {
          if (!included.contains(i)) {
            _memberSplits[i].amount = 0;
          }
          _updateControllerText(i, (_memberSplits[i].amount ?? 0).toStringAsFixed(2));
        }
      });
    } else if (type == SplitType.percentage) {
      if (included.isEmpty) {
        setState(() {
          for (var i = 0; i < _memberSplits.length; i++) {
            _memberSplits[i].percentage = 0;
            _updateControllerText(i, 0.toStringAsFixed(1));
          }
        });
        _validate();
        _queueNotify();
        return;
      }
      if (included.length == 1) {
        final only = included.first;
        setState(() {
          for (var i = 0; i < _memberSplits.length; i++) {
            _memberSplits[i].percentage = i == only ? 100.0 : 0.0;
            _updateControllerText(i, (_memberSplits[i].percentage ?? 0).toStringAsFixed(1));
          }
        });
        _validate();
        _queueNotify();
        return;
      }
      final per = 100.0 / included.length;
      double sumOthers = 0;
      setState(() {
        for (int k = 0; k < included.length; k++) {
          final idx = included[k];
          if (k < included.length - 1) {
            _memberSplits[idx].percentage = per;
            sumOthers += per;
          } else {
            _memberSplits[idx].percentage = 100.0 - sumOthers;
          }
        }
        for (int i = 0; i < _memberSplits.length; i++) {
          if (!included.contains(i)) {
            _memberSplits[i].percentage = 0;
          }
          _updateControllerText(i, (_memberSplits[i].percentage ?? 0).toStringAsFixed(1));
        }
      });
    }
    _validate();
    _queueNotify();
  }

  bool _isMemberIncludedAt(int index) {
    switch (_selectedType) {
      case SplitType.amount:
        return _memberSplits[index].includedInAmount;
      case SplitType.percentage:
        return _memberSplits[index].includedInPercentage;
      case SplitType.shares:
        return (_memberSplits[index].shares ?? 0) > 0;
      case SplitType.equal:
        return true;
    }
  }

  void _setMemberIncludedAt(int index, bool included) {
    switch (_selectedType) {
      case SplitType.amount:
        setState(() {
          _memberSplits[index].includedInAmount = included;
          if (!included) {
            _memberSplits[index].amount = 0;
            _updateControllerText(index, 0.toStringAsFixed(2));
          }
        });
        _redistributeAmongIncluded(SplitType.amount);
        break;
      case SplitType.percentage:
        setState(() {
          _memberSplits[index].includedInPercentage = included;
          if (!included) {
            _memberSplits[index].percentage = 0;
            _updateControllerText(index, 0.toStringAsFixed(1));
          }
        });
        _redistributeAmongIncluded(SplitType.percentage);
        break;
      case SplitType.shares:
        setState(() {
          final nextIncluded = included;
          _memberSplits[index].shares = nextIncluded
              ? ((_memberSplits[index].shares ?? 0) == 0 ? 1 : _memberSplits[index].shares)
              : 0;
          _updateControllerText(index, (_memberSplits[index].shares ?? 0).toString());
        });
        _validate();
        _queueNotify();
        break;
      case SplitType.equal:
        break;
    }
  }

  void _validate() {
    String? error;

    // Validate based on split type
    switch (_selectedType) {
      case SplitType.equal:
        // No validation needed for equal splits
        break;

      case SplitType.amount:
        final includedCountAmt = _memberSplits.where((s) => s.includedInAmount).length;
        if (includedCountAmt == 0) {
          error = 'At least one member must be included';
          break;
        }
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
        final includedCountPct = _memberSplits.where((s) => s.includedInPercentage).length;
        if (includedCountPct == 0) {
          error = 'At least one member must be included';
          break;
        }
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
    final isDark = shadcnui.Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Entire split sheet with grey background
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Split Type Selector - minimal with pipe separators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTypeChip(colorScheme, context.l10n.amount, SplitType.amount),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '|',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground.withOpacity(0.3),
                      ),
                    ),
                  ),
                  _buildTypeChip(colorScheme, context.l10n.percent, SplitType.percentage),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '|',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground.withOpacity(0.3),
                      ),
                    ),
                  ),
                  _buildTypeChip(colorScheme, context.l10n.splitShare, SplitType.shares),
                ],
              ),

              const SizedBox(height: 16),

              // Member List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _memberSplits.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildMemberRow(colorScheme, index, isDark);
                },
              ),
            ],
          ),
        ),

        // Validation Error
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
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
      ],
    );
  }

  Widget _buildTypeChip(shadcnui.ColorScheme colorScheme, String label, SplitType type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isSelected ? colorScheme.primary : colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildMemberRow(shadcnui.ColorScheme colorScheme, int index, bool isDark) {
    final memberSplit = _memberSplits[index];
    final member = memberSplit.member;
    final showCheckbox = _selectedType == SplitType.shares ||
        _selectedType == SplitType.amount ||
        _selectedType == SplitType.percentage;
    final isIncluded = _isMemberIncludedAt(index);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          // More rounded checkbox
          if (showCheckbox)
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: shadcnui.Theme(
                data: shadcnui.Theme.of(context).copyWith(
                  radius: 0.8,
                ),
                child: shadcnui.Checkbox(
                  state: isIncluded
                      ? shadcnui.CheckboxState.checked
                      : shadcnui.CheckboxState.unchecked,
                  onChanged: (state) => _setMemberIncludedAt(
                    index,
                    state == shadcnui.CheckboxState.checked
                  ),
                ),
              ),
            ),

          // Member Info (no avatar per mockup)
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
                      fontSize: 13,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Split Input
          if (_selectedType == SplitType.equal)
            Text(
              '${widget.currencySymbol}${(widget.totalAmount / widget.members.length).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            )
          else
            SizedBox(
              width: 100,
              child: _buildSplitInput(colorScheme, index, enabled: isIncluded),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitInput(shadcnui.ColorScheme colorScheme, int index, {bool enabled = true}) {
    String suffix = '';

    switch (_selectedType) {
      case SplitType.amount:
        suffix = ' ${widget.currencySymbol}';
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
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: enabled ? colorScheme.foreground : colorScheme.mutedForeground.withOpacity(0.4),
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: false,
        border: InputBorder.none,
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: enabled ? colorScheme.foreground : colorScheme.mutedForeground.withOpacity(0.4),
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
    final isDark = shadcnui.Theme.of(context).brightness == Brightness.dark;

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
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.splitExpense,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colorScheme.mutedForeground),
                  iconSize: 24,
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

          // Content
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
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

// Custom split configuration sheet
// Allows users to split expenses by amount, percentage, or shares
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

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

List<MemberSplit> buildDefaultMemberSplits({
  required List<HouseholdMember> members,
  required double totalAmount,
}) {
  if (members.isEmpty) return <MemberSplit>[];
  final perMember = totalAmount / members.length;
  final percent = 100.0 / members.length;
  return members
      .map((member) => MemberSplit(
            member: member,
            amount: perMember,
            percentage: percent,
            shares: 1,
          ))
      .toList();
}

/// Shows custom split configuration sheet
void showCustomSplitSheet({
  required BuildContext context,
  required List<HouseholdMember> members,
  required double totalAmount,
  required String currencySymbol,
  required Function(SplitType splitType, List<MemberSplit> splits) onSave,
  SplitType? initialSplitType,
  List<MemberSplit>? initialSplits,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor:
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
    isScrollControlled: true,
    isDismissible: true,
    builder: (context) => _CustomSplitSheet(
      members: members,
      totalAmount: totalAmount,
      currencySymbol: currencySymbol,
      onSave: onSave,
      initialSplitType: initialSplitType,
      initialSplits: initialSplits,
    ),
  );
}

/// Public, embeddable split editor used both inline and inside the bottom sheet
class CustomSplitEditor extends StatefulWidget {
  final List<HouseholdMember> members;
  final double totalAmount;
  final String currencySymbol;
  final void Function(SplitType splitType, List<MemberSplit> splits)? onChanged;
  final SplitType? initialSplitType;
  final List<MemberSplit>? initialSplits;

  const CustomSplitEditor({
    super.key,
    required this.members,
    required this.totalAmount,
    required this.currencySymbol,
    this.onChanged,
    this.initialSplitType,
    this.initialSplits,
  });

  @override
  State<CustomSplitEditor> createState() => _CustomSplitEditorState();
}

class GroupSplitEditorSection extends StatelessWidget {
  final List<HouseholdMember> members;
  final String? selectedPayerUserId;
  final ValueChanged<String?> onPayerChanged;
  final double totalAmount;
  final String currencySymbol;
  final SplitType? initialSplitType;
  final List<MemberSplit>? initialSplits;
  final void Function(SplitType splitType, List<MemberSplit> splits) onSplitChanged;
  final bool showNotYetSplitBanner;
  final String? notYetSplitMessage;
  final Key? splitEditorKey;

  const GroupSplitEditorSection({
    super.key,
    required this.members,
    required this.selectedPayerUserId,
    required this.onPayerChanged,
    required this.totalAmount,
    required this.currencySymbol,
    required this.initialSplitType,
    required this.initialSplits,
    required this.onSplitChanged,
    this.showNotYetSplitBanner = false,
    this.notYetSplitMessage,
    this.splitEditorKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectivePayerId = members.any((m) => m.userId == selectedPayerUserId)
        ? selectedPayerUserId
        : (members.isNotEmpty ? members.first.userId : null);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (showNotYetSplitBanner && (notYetSplitMessage ?? '').isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notYetSplitMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.whoPaid,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectivePayerId,
                    items: members
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m.userId,
                            child: Text(
                              m.userName ?? m.userEmail ?? context.l10n.member,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onPayerChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CustomSplitEditor(
            key: splitEditorKey,
            members: members,
            totalAmount: totalAmount,
            currencySymbol: currencySymbol,
            initialSplitType: initialSplitType,
            initialSplits: initialSplits,
            onChanged: onSplitChanged,
          ),
        ],
      ),
    );
  }
}

class _CustomSplitSheet extends StatefulWidget {
  final List<HouseholdMember> members;
  final double totalAmount;
  final String currencySymbol;
  final Function(SplitType splitType, List<MemberSplit> splits) onSave;
  final SplitType? initialSplitType;
  final List<MemberSplit>? initialSplits;

  const _CustomSplitSheet({
    required this.members,
    required this.totalAmount,
    required this.currencySymbol,
    required this.onSave,
    this.initialSplitType,
    this.initialSplits,
  });

  @override
  State<_CustomSplitSheet> createState() => _CustomSplitSheetState();
}

class _CustomSplitEditorState extends State<CustomSplitEditor> {
  late SplitType _selectedType;
  late List<MemberSplit> _memberSplits;
  late List<TextEditingController> _controllers;
  String? _validationError;
  Timer? _debounce;
  bool _isUpdatingProgrammatically = false;

  @override
  void initState() {
    super.initState();
    // Initialize with provided values or defaults
    _selectedType = widget.initialSplitType ?? SplitType.amount;

    if (widget.initialSplits != null && widget.initialSplits!.isNotEmpty) {
      // Use provided initial splits
      _initializeSplitsFromInitial();
      debugPrint(
          '🔧 [SPLIT EDITOR] Initialized with provided splits: $_selectedType');
    } else {
      // Initialize with default equal splits
      _initializeSplits();
      debugPrint('🔧 [SPLIT EDITOR] Initialized with default equal splits');
    }

    _initializeControllers();
    // notify parent with initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _queueNotify());
  }

  @override
  void didUpdateWidget(covariant CustomSplitEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final membersChanged = _membersChanged(oldWidget.members, widget.members);
    final totalChanged = oldWidget.totalAmount != widget.totalAmount;
    final splitTypeChanged = widget.initialSplitType != null &&
        widget.initialSplitType != _selectedType &&
        widget.initialSplitType != oldWidget.initialSplitType;
    // When initialSplits become available AFTER the widget was first
    // built (e.g. loaded asynchronously from the backend for recurring
    // expenses), we must re-initialize from those splits instead of
    // keeping the default equal splits.
    final initialSplitsBecameAvailable =
        (oldWidget.initialSplits == null || oldWidget.initialSplits!.isEmpty) &&
            (widget.initialSplits != null && widget.initialSplits!.isNotEmpty);

    if (initialSplitsBecameAvailable) {
      for (final controller in _controllers) {
        controller.dispose();
      }
      _initializeSplitsFromInitial();
      _initializeControllers();
      _validationError = null;
      _validate();
      _queueNotify();
      return;
    }

    if (membersChanged || totalChanged || splitTypeChanged) {
      _reconcileSplits(splitTypeChanged: splitTypeChanged);
    }
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
    _memberSplits = buildDefaultMemberSplits(
      members: widget.members,
      totalAmount: widget.totalAmount,
    );
  }

  void _initializeControllers() {
    _controllers = List.generate(
      _memberSplits.length,
      (index) => TextEditingController(text: _getFormattedValue(index)),
    );
  }

  bool _membersChanged(
      List<HouseholdMember> previous, List<HouseholdMember> current) {
    if (previous.length != current.length) return true;

    final previousIds = previous.map((m) => m.userId).toList();
    final currentIds = current.map((m) => m.userId).toList();

    return !listEquals(previousIds, currentIds);
  }

  void _reconcileSplits({required bool splitTypeChanged}) {
    final existingByUserId = {
      for (final split in _memberSplits) split.member.userId: split,
    };
    final defaultsByUserId = {
      for (final split in buildDefaultMemberSplits(
        members: widget.members,
        totalAmount: widget.totalAmount,
      ))
        split.member.userId: split,
    };

    final updatedSplits = widget.members.map((member) {
      final existing = existingByUserId[member.userId];
      if (existing != null) {
        return MemberSplit(
          member: member,
          amount: existing.amount,
          percentage: existing.percentage,
          shares: existing.shares,
          includedInAmount: existing.includedInAmount,
          includedInPercentage: existing.includedInPercentage,
        );
      }

      final fallback = defaultsByUserId[member.userId];
      return MemberSplit(
        member: member,
        amount: fallback?.amount ?? 0,
        percentage: fallback?.percentage ?? 0,
        shares: fallback?.shares ?? 1,
        includedInAmount: fallback?.includedInAmount ?? true,
        includedInPercentage: fallback?.includedInPercentage ?? true,
      );
    }).toList();

    for (final controller in _controllers) {
      controller.dispose();
    }

    setState(() {
      if (splitTypeChanged && widget.initialSplitType != null) {
        _selectedType = widget.initialSplitType!;
      }
      _memberSplits = updatedSplits;
      _initializeControllers();
      _validationError = null;
    });

    _validate();
    _queueNotify();
  }

  void _initializeSplitsFromInitial() {
    if (widget.members.isEmpty) {
      _memberSplits = <MemberSplit>[];
      return;
    }

    final Map<String?, MemberSplit> byUserId = {
      for (final split in widget.initialSplits!) split.member.userId: split,
    };
    final defaultsByUserId = {
      for (final split in buildDefaultMemberSplits(
        members: widget.members,
        totalAmount: widget.totalAmount,
      ))
        split.member.userId: split,
    };

    _memberSplits = widget.members.map((member) {
      final existing = byUserId[member.userId];
      if (existing != null) {
        return MemberSplit(
          member: member,
          amount: existing.amount,
          percentage: existing.percentage,
          shares: existing.shares,
          includedInAmount: existing.includedInAmount,
          includedInPercentage: existing.includedInPercentage,
        );
      }

      // Fallback for new members that have no existing split line
      final fallback = defaultsByUserId[member.userId];
      return MemberSplit(
        member: member,
        amount: fallback?.amount ?? 0,
        percentage: fallback?.percentage ?? 0,
        shares: fallback?.shares ?? 1,
        includedInAmount: fallback?.includedInAmount ?? true,
        includedInPercentage: fallback?.includedInPercentage ?? true,
      );
    }).toList();
  }

  String _getFormattedValue(int index) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) {
      return '0.00';
    }
    final split = _memberSplits[index];
    switch (_selectedType) {
      case SplitType.amount:
        return split.amount?.toStringAsFixed(2) ?? '0.00';
      case SplitType.percentage:
        return split.percentage?.toStringAsFixed(1) ?? '0.0';
      case SplitType.shares:
        // `shares` must be > 0 when present (DB constraint); treat null as excluded (0).
        return split.shares?.toString() ?? '0';
      case SplitType.equal:
        return '';
    }
  }

  void _updateControllerText(int index, String newText) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _controllers.length) return;
    if (_controllers[index].text != newText) {
      _isUpdatingProgrammatically = true;
      _controllers[index].text = newText;
      _isUpdatingProgrammatically = false;
    }
  }

  void _handleValueChange(int index, String text) {
    if (_isUpdatingProgrammatically) return;
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) return;

    double? parsedDouble;
    int? parsedInt;

    switch (_selectedType) {
      case SplitType.amount:
        parsedDouble = double.tryParse(text);
        if (parsedDouble != null && parsedDouble < 0)
          parsedDouble = 0; // clamp negatives
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
        if (parsedDouble != null && parsedDouble < 0)
          parsedDouble = 0; // clamp negatives
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
        final normalizedShares =
            parsedInt != null && parsedInt > 0 ? parsedInt : null;
        setState(() {
          _memberSplits[index].shares = normalizedShares;
        });
        _validate();
        _queueNotify();
        break;

      case SplitType.equal:
        break;
    }
  }

  void _autoAdjustOthers(int editedIndex, SplitType type) {
    // Guard: use _memberSplits.length to match internal state, not widget.members.length
    if (_memberSplits.isEmpty ||
        editedIndex < 0 ||
        editedIndex >= _memberSplits.length) {
      _validate();
      _queueNotify();
      return;
    }
    final allIndices = List.generate(_memberSplits.length, (i) => i);

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
            _updateControllerText(
                editedIndex, widget.totalAmount.toStringAsFixed(2));
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
            .where((i) =>
                i != editedIndex && _memberSplits[i].includedInPercentage)
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
    // Use _memberSplits.length to match internal state, not widget.members.length
    final length = _memberSplits.length;
    switch (type) {
      case SplitType.amount:
        return List.generate(length, (i) => i)
            .where((i) => _memberSplits[i].includedInAmount)
            .toList();
      case SplitType.percentage:
        return List.generate(length, (i) => i)
            .where((i) => _memberSplits[i].includedInPercentage)
            .toList();
      case SplitType.shares:
        return List.generate(length, (i) => i)
            .where((i) => (_memberSplits[i].shares ?? 0) > 0)
            .toList();
      case SplitType.equal:
        return List.generate(length, (i) => i);
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
            _updateControllerText(
                i, (_memberSplits[i].amount ?? 0).toStringAsFixed(2));
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
          _updateControllerText(
              i, (_memberSplits[i].amount ?? 0).toStringAsFixed(2));
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
            _updateControllerText(
                i, (_memberSplits[i].percentage ?? 0).toStringAsFixed(1));
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
          _updateControllerText(
              i, (_memberSplits[i].percentage ?? 0).toStringAsFixed(1));
        }
      });
    }
    _validate();
    _queueNotify();
  }

  bool _isMemberIncludedAt(int index) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) return false;
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
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) return;
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
          final currentShares = _memberSplits[index].shares;
          _memberSplits[index].shares =
              nextIncluded ? (currentShares ?? 1) : null;
          _updateControllerText(
              index, (_memberSplits[index].shares ?? 0).toString());
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
        final includedCountAmt =
            _memberSplits.where((s) => s.includedInAmount).length;
        if (includedCountAmt == 0) {
          error = context.l10n.atLeastOneMember;
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
            widget.currencySymbol,
          );
        }
        break;

      case SplitType.percentage:
        final includedCountPct =
            _memberSplits.where((s) => s.includedInPercentage).length;
        if (includedCountPct == 0) {
          error = context.l10n.atLeastOneMember;
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
        final totalShares =
            _memberSplits.fold<int>(0, (sum, s) => sum + (s.shares ?? 0));
        if (totalShares <= 0) {
          error = context.l10n.memberMustHaveShare;
        }
        break;
    }
    setState(() => _validationError = error);
  }

  void _queueNotify() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged
          ?.call(_selectedType, List<MemberSplit>.from(_memberSplits));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entire split sheet with grey background
          Container(
            decoration: BoxDecoration(
              color: colorScheme.homeSplitSheetBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Split Type Selector - minimal with pipe separators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTypeChip(
                        colorScheme, context.l10n.amount, SplitType.amount),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '|',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    _buildTypeChip(colorScheme, context.l10n.percent,
                        SplitType.percentage),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '|',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    _buildTypeChip(
                        colorScheme, context.l10n.splitShare, SplitType.shares),
                  ],
                ),

                const SizedBox(height: 16),

                // Member List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _memberSplits.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildMemberRow(colorScheme, index);
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
                  color: colorScheme.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: colorScheme.destructive.withValues(alpha: 0.3)),
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
      ),
    );
  }

  Widget _buildTypeChip(ColorScheme colorScheme, String label, SplitType type) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          final previousType = _selectedType;
          _selectedType = type;
          _ensureValuesInitializedForType(
              nextType: type, previousType: previousType);
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

  void _ensureValuesInitializedForType({
    required SplitType nextType,
    required SplitType previousType,
  }) {
    if (_memberSplits.isEmpty) return;

    switch (nextType) {
      case SplitType.percentage:
        final hasAnyPercentage =
            _memberSplits.any((s) => (s.percentage ?? 0) > 0);
        if (hasAnyPercentage) return;

        final included = () {
          if (previousType == SplitType.amount) {
            return List<int>.generate(_memberSplits.length, (i) => i)
                .where((i) => _memberSplits[i].includedInAmount)
                .toList();
          }
          if (previousType == SplitType.shares) {
            return List<int>.generate(_memberSplits.length, (i) => i)
                .where((i) => (_memberSplits[i].shares ?? 0) > 0)
                .toList();
          }
          return List<int>.generate(_memberSplits.length, (i) => i)
              .where((i) => _memberSplits[i].includedInPercentage)
              .toList();
        }();

        final effectiveIncluded = included.isNotEmpty
            ? included
            : List<int>.generate(_memberSplits.length, (i) => i);

        for (int i = 0; i < _memberSplits.length; i++) {
          _memberSplits[i].includedInPercentage = effectiveIncluded.contains(i);
        }

        // Distribute percentages exactly using basis points (2 decimals).
        const totalBasisPoints = 10000; // 100.00%
        final per = totalBasisPoints ~/ effectiveIncluded.length;
        var remainder = totalBasisPoints - per * effectiveIncluded.length;

        for (int k = 0; k < effectiveIncluded.length; k++) {
          final idx = effectiveIncluded[k];
          final add = remainder > 0 ? 1 : 0;
          if (remainder > 0) remainder--;
          final basisPoints = per + add;
          _memberSplits[idx].percentage = basisPoints / 100.0;
        }

        for (int i = 0; i < _memberSplits.length; i++) {
          if (!effectiveIncluded.contains(i)) {
            _memberSplits[i].percentage = 0;
          }
        }
        break;

      case SplitType.shares:
        final hasAnyShares = _memberSplits.any((s) => (s.shares ?? 0) > 0);
        if (hasAnyShares) return;

        final included = () {
          if (previousType == SplitType.amount) {
            return List<int>.generate(_memberSplits.length, (i) => i)
                .where((i) => _memberSplits[i].includedInAmount)
                .toList();
          }
          if (previousType == SplitType.percentage) {
            return List<int>.generate(_memberSplits.length, (i) => i)
                .where((i) => _memberSplits[i].includedInPercentage)
                .toList();
          }
          return <int>[];
        }();

        final effectiveIncluded = included.isNotEmpty
            ? included
            : List<int>.generate(_memberSplits.length, (i) => i);

        for (int i = 0; i < _memberSplits.length; i++) {
          _memberSplits[i].shares = effectiveIncluded.contains(i) ? 1 : null;
        }
        break;

      case SplitType.amount:
      case SplitType.equal:
        // No-op: amount values are initialized at creation time, and equal has no per-member values.
        break;
    }
  }

  Widget _buildMemberRow(ColorScheme colorScheme, int index) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) {
      return const SizedBox.shrink();
    }
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
              padding: const EdgeInsets.only(right: 10),
              child: AdaptiveCheckbox(
                value: isIncluded,
                onChanged: (value) {
                  _setMemberIncludedAt(index, value ?? false);
                },
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
              '${widget.currencySymbol}${widget.members.isNotEmpty ? (widget.totalAmount / widget.members.length).toStringAsFixed(2) : '0.00'}',
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

  Widget _buildSplitInput(ColorScheme colorScheme, int index,
      {bool enabled = true}) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _controllers.length) {
      return const SizedBox.shrink();
    }
    String prefix = '';
    String suffix = '';

    switch (_selectedType) {
      case SplitType.amount:
        // Currency symbol before the amount, e.g. "$ 61.50"
        prefix = '${widget.currencySymbol} ';
        break;
      case SplitType.percentage:
        suffix = '%';
        break;
      case SplitType.shares:
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
        color: enabled
            ? colorScheme.foreground
            : colorScheme.mutedForeground.withValues(alpha: 0.4),
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: enabled
                ? colorScheme.mutedForeground.withValues(alpha: 0.4)
                : colorScheme.mutedForeground.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.mutedForeground.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: colorScheme.mutedForeground.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        prefixText: prefix.isNotEmpty ? prefix : null,
        prefixStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: enabled
              ? colorScheme.foreground
              : colorScheme.mutedForeground.withValues(alpha: 0.4),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: enabled
              ? colorScheme.foreground
              : colorScheme.mutedForeground.withValues(alpha: 0.4),
        ),
      ),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: (text) => _handleValueChange(index, text),
    );
  }

  String _getOweText(int index) {
    // Guard against out-of-bounds access
    if (index < 0 || index >= _memberSplits.length) {
      return '${context.l10n.owes} ${widget.currencySymbol}0.00';
    }
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
        final totalShares =
            _memberSplits.fold<int>(0, (sum, s) => sum + (s.shares ?? 0));
        amount = totalShares > 0
            ? widget.totalAmount * (split.shares ?? 0) / totalShares
            : 0;
        break;
      case SplitType.equal:
        amount = widget.members.isNotEmpty
            ? widget.totalAmount / widget.members.length
            : 0;
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
    final colorScheme = Theme.of(context).colorScheme;

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
              color: colorScheme.border.withValues(alpha: 0.5),
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
                  icon: Icon(Icons.close_rounded,
                      color: colorScheme.mutedForeground),
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
                initialSplitType: widget.initialSplitType,
                initialSplits: widget.initialSplits,
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

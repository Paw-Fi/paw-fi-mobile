// Unified transaction detail/confirmation sheet
// Handles BOTH existing expenses (ExpenseEntry) and new expenses (ParsedExpense)
// Always shows household sharing option

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_state.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/widgets/edit_transaction_bottom_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Format date with relative terms
String _formatRelativeDate(DateTime date, BuildContext context) {
  final now = DateTime.now();
  final localDate = toLocalTime(date);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

  if (dateOnly == today) {
    return context.l10n.today;
  } else if (dateOnly == yesterday) {
    return context.l10n.yesterday;
  } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
    return DateFormat('EEEE').format(localDate);
  } else {
    return DateFormat('EEEE, d MMMM yyyy').format(localDate);
  }
}

/// Shows unified transaction sheet
/// For existing expenses: shows details with option to change sharing
/// For new expenses: shows confirmation with option to choose sharing
void showUnifiedTransactionSheet(
  BuildContext context, {
  ExpenseEntry? existingExpense,
  ParsedExpense? newExpense,
  UserContact? contact,
  String? localImagePath,
}) {
  assert(existingExpense != null || newExpense != null, 
    'Must provide either existingExpense or newExpense');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    builder: (context) => _UnifiedTransactionSheet(
      existingExpense: existingExpense,
      newExpense: newExpense,
      contact: contact,
      localImagePath: localImagePath,
    ),
  );
}

class _UnifiedTransactionSheet extends ConsumerStatefulWidget {
  final ExpenseEntry? existingExpense;
  final ParsedExpense? newExpense;
  final UserContact? contact;
  final String? localImagePath;

  const _UnifiedTransactionSheet({
    this.existingExpense,
    this.newExpense,
    this.contact,
    this.localImagePath,
  });

  @override
  ConsumerState<_UnifiedTransactionSheet> createState() =>
      _UnifiedTransactionSheetState();
}

class _UnifiedTransactionSheetState
    extends ConsumerState<_UnifiedTransactionSheet> {
  bool _isSaving = false;
  final timeFormat = DateFormat('HH:mm');
  bool _isSharedWithHousehold = false;
  TimeOfDay _selectedTime = TimeOfDay.now();
  SplitType? _customSplitType;
  List<MemberSplit>? _customSplits;
  bool _isLoadingMembers = false;
  String? _membersError;
  List<HouseholdMember>? _householdMembers;
  ExpenseEntry? _currentExpense; // keeps live-updated expense for existing entries

  @override
  void initState() {
    super.initState();
    // Initialize time from existing expense or now
    if (widget.existingExpense != null) {
      _currentExpense = widget.existingExpense; // seed with initial
      final dateTime = toLocalTime(widget.existingExpense!.createdAt);
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      
      // Initialize share state from existing expense (shared if linked to a household or has a split group)
      _isSharedWithHousehold = widget.existingExpense!.householdId != null ||
                               widget.existingExpense!.splitGroupId != null;
    } else if (widget.newExpense != null) {
      // For new expenses, default to current local time (BE usually returns date-only)
      _selectedTime = TimeOfDay.now();
      // Auto-enable household sharing when in household view mode
      final vm = ref.read(viewModeProvider);
      if (vm.mode == ViewMode.household) {
        _isSharedWithHousehold = true; // safe to set local field in initState
        // Defer provider writes until after first frame to avoid modifying providers during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final selected = ref.read(selectedHouseholdProvider).householdId;
          if (selected != null) {
            ref.read(selectedHouseholdForSharingProvider.notifier).state = selected;
            _loadMembers(selected);
          }
        });
      }
    }
  }

  bool get isNewExpense => widget.newExpense != null;
  bool get isExistingExpense => widget.existingExpense != null;

  // Unified getters that work for both cases
  double get amount => isNewExpense
      ? widget.newExpense!.amount
      : (_currentExpense?.amount ?? widget.existingExpense!.amount);

  String get currency => isNewExpense
      ? widget.newExpense!.currency
      : ((_currentExpense?.currency ?? widget.existingExpense!.currency) ?? 'USD');

  String get currencySymbol => isNewExpense
      ? widget.newExpense!.currencySymbol
      : resolveCurrencySymbol(currency);

  String get category => isNewExpense
      ? widget.newExpense!.category
      : ((_currentExpense?.category ?? widget.existingExpense!.category) ?? 'other');

  DateTime get date => isNewExpense
      ? widget.newExpense!.date
      : (_currentExpense?.date ?? widget.existingExpense!.date);

  String? get description => isNewExpense
      ? widget.newExpense!.description
      : (_currentExpense?.rawText ?? widget.existingExpense!.rawText);

  String? get receiptImageUrl => _currentExpense?.receiptImageUrl ?? widget.existingExpense?.receiptImageUrl;

  // Generate note prefix like "I spent $XX on category"
  String _generateNotePrefix() {
    final displayAmount = (ref.read(pendingExpenseProvider)?.amount ?? amount);
    final displayCategory = (ref.read(pendingExpenseProvider)?.category ?? category);
    return 'I spent $currencySymbol${displayAmount.toStringAsFixed(2)} on $displayCategory';
  }

  @override
  Widget build(BuildContext context) {
    final theme = shadcnui.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHousehold = ref.watch(selectedHouseholdForSharingProvider);

    // For new expenses, use pending expense provider
    final pendingExpense = isNewExpense ? ref.watch(pendingExpenseProvider) : null;
    
    // Use pending expense if available (for live editing), otherwise use initial
    final displayAmount = pendingExpense?.amount ?? amount;
    final displayCategory = pendingExpense?.category ?? category;
    final displayDate = pendingExpense?.date ?? date;
    final displayDescription = pendingExpense?.description ?? description;

    // Update expense from providers if it's an existing expense
    if (isExistingExpense) {
      // Listen for optimistic/final updates of this expense and refresh UI
      final transactionEdit = ref.watch(transactionEditProvider);
      final edited = transactionEdit.optimisticUpdate;
      if (edited != null && edited.id == widget.existingExpense!.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentExpense = edited;
              final local = toLocalTime(edited.createdAt);
              _selectedTime = TimeOfDay(hour: local.hour, minute: local.minute);
            });
          }
        });
      }

      // Also listen to analyticsProvider reload to sync from backend
      final analytics = ref.watch(analyticsProvider);
      if (widget.existingExpense != null) {
        final id = widget.existingExpense!.id;
        final updated = analytics.allExpenses.firstWhere(
          (e) => e.id == id,
          orElse: () => _currentExpense ?? widget.existingExpense!,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentExpense = updated;
              final local = toLocalTime(updated.createdAt);
              _selectedTime = TimeOfDay(hour: local.hour, minute: local.minute);
            });
          }
        });
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8, right: 16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: colorScheme.foreground, size: 28),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Text(
                    isNewExpense ? context.l10n.confirmExpense : context.l10n.expenseDetails,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Large Amount
                  GestureDetector(
                    onTap: () => _handleEditAmount(displayAmount),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '-$currencySymbol${displayAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date and Time
                  Text(
                    '${_formatRelativeDate(displayDate, context)}, ${_selectedTime.format(context)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Household Sharing Toggle
                  householdsAsync.when(
                    data: (households) {
                      if (households.isEmpty) return const SizedBox();

                      return Column(
                        children: [
                          _buildSharingSection(
                            colorScheme,
                            households,
                            selectedHousehold,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),

                  // Details Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.details,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Card
                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.category,
                    value: displayCategory.substring(0, 1).toUpperCase() +
                        displayCategory.substring(1),
                    onTap: () => _handleEditCategory(displayCategory),
                  ),

                  const SizedBox(height: 12),

                  // Currency Card
                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.currency,
                    value: currency.toUpperCase(),
                    onTap: () => _handleEditCurrency(currency),
                    disabled: _isSharedWithHousehold,
                  ),

                  const SizedBox(height: 12),

                  // Date Card
                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.date,
                    value: _formatRelativeDate(displayDate, context),
                    onTap: () => _handleEditDate(displayDate),
                  ),

                  const SizedBox(height: 12),

                  // Time Card
                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.time,
                    value: _selectedTime.format(context),
                    onTap: () => _handleEditTime(),
                  ),

                  const SizedBox(height: 32),

                  // Notes Section - always show for new expenses with prefix
                  if (isNewExpense || (displayDescription != null && displayDescription.isNotEmpty)) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.notes,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  _buildNotesCard(
                    colorScheme: colorScheme,
                    notes: (() {
                      final notePrefix = _generateNotePrefix();
                      final desc = displayDescription;
                      if (desc == null) return notePrefix;
                      final trimmed = desc.trimLeft();
                      final isReceipt = trimmed.toLowerCase().startsWith('receipt:');
                      return isReceipt ? notePrefix : desc;
                    })(),
                    onTap: () => _handleEditDescription(displayDescription),
                  ),
                    const SizedBox(height: 32),
                  ],

                  // Receipt Section
                  if (widget.localImagePath != null ||
                      (receiptImageUrl != null && receiptImageUrl!.isNotEmpty)) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.receipt,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReceiptCard(
                      colorScheme: colorScheme,
                      localImagePath: widget.localImagePath,
                      receiptImageUrl: receiptImageUrl,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Save Button (only for new expenses)
                  if (isNewExpense)
                    SizedBox(
                      width: double.infinity,
                      child: shadcnui.PrimaryButton(
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(context.l10n.saveExpense),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingSection(
    shadcnui.ColorScheme colorScheme,
    List households,
    String? selectedHousehold,
  ) {
    // Auto-select first household when sharing is enabled but no selection exists yet
    if (_isSharedWithHousehold && households.isNotEmpty && selectedHousehold == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final firstId = households.first.id;
        ref.read(selectedHouseholdForSharingProvider.notifier).state = firstId;
        _loadMembers(firstId);
      });
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.muted.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle switch for sharing
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.shareWithHousehold,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Switch(
                value: _isSharedWithHousehold,
                onChanged: (value) {
                  setState(() {
                    _isSharedWithHousehold = value;
                    if (!value) {
                      // Clear household selection and custom splits
                      ref.read(selectedHouseholdForSharingProvider.notifier).state = null;
                      _customSplitType = null;
                      _customSplits = null;
                      _householdMembers = null;
                      _membersError = null;
                      _isLoadingMembers = false;
                    } else if (households.isNotEmpty) {
                      // Auto-select first household when toggling on
                      ref.read(selectedHouseholdForSharingProvider.notifier).state = households.first.id;
                      _loadMembers(households.first.id);
                    }
                  });
                },
              ),
            ],
          ),
          
          // Show household dropdown only when toggle is ON
          if (_isSharedWithHousehold && households.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.muted.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedHousehold ?? households.first.id,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: colorScheme.foreground),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                  items: households.map((h) {
                    return DropdownMenuItem<String>(
                      value: h.id,
                      child: Row(
                        children: [
                          // Cover photo
                          if (h.coverImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                h.coverImageUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: colorScheme.muted,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.home_rounded, size: 16, color: colorScheme.mutedForeground),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colorScheme.muted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              h.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(selectedHouseholdForSharingProvider.notifier).state = value;
                      // Reset custom splits when changing household
                      setState(() {
                        _customSplitType = null;
                        _customSplits = null;
                        _householdMembers = null;
                        _membersError = null;
                        _isLoadingMembers = false;
                      });
                      _loadMembers(value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Inline Split Editor (replaces previous button/secondary sheet)
            Builder(
              builder: (context) {
                if (_isLoadingMembers) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(context.l10n.loadingHouseholdMembers,
                            style: TextStyle(color: colorScheme.mutedForeground)),
                      ],
                    ),
                  );
                }
                if (_membersError != null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.destructive.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.destructive, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _membersError!,
                            style: TextStyle(color: colorScheme.destructive),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (_householdMembers == null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.selectHouseholdToConfigureSplit,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  );
                }

                final pendingExpense = isNewExpense ? ref.read(pendingExpenseProvider) : null;
                final currentAmount = pendingExpense?.amount ?? amount;

                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CustomSplitEditor(
                    members: _householdMembers!,
                    totalAmount: currentAmount,
                    currencySymbol: currencySymbol,
                    onChanged: (splitType, splits) {
                      setState(() {
                        _customSplitType = splitType;
                        _customSplits = splits;
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required shadcnui.ColorScheme colorScheme,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.currencyIsManagedByHousehold),
                  backgroundColor: colorScheme.muted,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: const BoxDecoration(),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: disabled ? colorScheme.mutedForeground.withOpacity(0.6) : colorScheme.mutedForeground,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: disabled ? colorScheme.mutedForeground : colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: disabled ? colorScheme.mutedForeground.withOpacity(0.4) : colorScheme.mutedForeground, size: 18),
          ],
        ),
      ),
    );
  }

  Future<T?> _showSelectionSheet<T>({
    required List<T> items,
    required String Function(T) getLabel,
    required T initial,
  }) async {
    if (Platform.isIOS) {
      int selectedIndex = items.indexOf(initial);
      if (selectedIndex < 0) selectedIndex = 0;
      return await showCupertinoModalPopup<T>(
        context: context,
        builder: (context) {
          T tempValue = items[selectedIndex];
          return Container(
            height: 320,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop<T>(context),
                        child: Text(context.l10n.cancel),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop<T>(context, tempValue),
                        child: Text(context.l10n.done),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 40,
                    onSelectedItemChanged: (i) {
                      tempValue = items[i];
                    },
                    children: items.map((e) => Center(child: Text(getLabel(e)))).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return await showModalBottomSheet<T>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final scheme = shadcnui.Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: scheme.border.withOpacity(0.4)),
                      itemBuilder: (context, i) {
                        final value = items[i];
                        final label = getLabel(value);
                        final selected = value == initial;
                        return ListTile(
                          title: Text(label, style: TextStyle(color: scheme.foreground)),
                          trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
                          onTap: () => Navigator.pop<T>(context, value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _handleEditCurrency(String currentCurrency) async {
    if (isExistingExpense) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditTransactionBottomSheet(
          expenseId: widget.existingExpense!.id,
          expense: widget.existingExpense!,
          field: EditField.currency,
          currentValue: currentCurrency,
        ),
      );
      return;
    }

    if (_isSharedWithHousehold) {
      final scheme = shadcnui.Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.currencyCannotBeChangedWhenSharing),
          backgroundColor: scheme.muted,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final options = getAvailableCurrencyOptions();
    final codes = options.keys.toList()..sort();
    final currentPending = ref.read(pendingExpenseProvider);
    final current = (currentPending?.currency ?? currentCurrency).toUpperCase();
    final initial = codes.contains(current) ? current : codes.first;

    final selected = await _showSelectionSheet<String>(
      items: codes,
      getLabel: (code) => '$code  ${options[code]}',
      initial: initial,
    );

    if (selected != null) {
      final current = ref.read(pendingExpenseProvider);
      if (current != null) {
        ref.read(pendingExpenseProvider.notifier).state = current.copyWith(
          currency: selected,
          currencySymbol: resolveCurrencySymbol(selected),
        );
      }
    }
  }

  Widget _buildNotesCard({
    required shadcnui.ColorScheme colorScheme,
    required String notes,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.muted.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                notes,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard({
    required shadcnui.ColorScheme colorScheme,
    String? localImagePath,
    String? receiptImageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: localImagePath != null
            ? Image.file(File(localImagePath), fit: BoxFit.cover, height: 200)
            : receiptImageUrl != null
                ? Image.network(
                    receiptImageUrl,
                    fit: BoxFit.cover,
                    height: 200,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: colorScheme.muted,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppTheme.success,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: colorScheme.muted,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported_outlined,
                                  size: 40,
                                  color: colorScheme.mutedForeground),
                              const SizedBox(height: 12),
                              Text(context.l10n.failedToLoadImage,
                                  style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox(),
      ),
    );
  }

  // Edit handlers
  void _handleEditAmount(double currentAmount) async {
    if (isExistingExpense) {
      // For existing expenses, use the edit bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditTransactionBottomSheet(
          expenseId: widget.existingExpense!.id,
          expense: widget.existingExpense!,
          field: EditField.amount,
          currentValue: widget.existingExpense!.amount,
        ),
      );
    } else {
      // For new expenses, simple dialog
      final controller =
          TextEditingController(text: currentAmount.toStringAsFixed(2));
      final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.editAmount),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.amount),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null && value > 0) {
                  Navigator.pop(context, value);
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (result != null) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(amount: result);
        }
      }
    }
  }

  void _handleEditCategory(String currentCategory) async {
    if (isExistingExpense) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditTransactionBottomSheet(
          expenseId: widget.existingExpense!.id,
          expense: widget.existingExpense!,
          field: EditField.category,
          currentValue: currentCategory,
        ),
      );
    } else {
      final categories = [
        'groceries',
        'food',
        'transport',
        'housing',
        'utilities',
        'entertainment',
        'healthcare',
        'education',
        'shopping',
        'travel',
        'income',
        'other'
      ];
      final initial = categories.contains(currentCategory) ? currentCategory : categories.first;
      final result = await _showSelectionSheet<String>(
        items: categories,
        getLabel: (c) => c[0].toUpperCase() + c.substring(1),
        initial: initial,
      );
      if (result != null) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(category: result);
        }
      }
    }
  }

  void _handleEditDate(DateTime currentDate) async {
    if (isExistingExpense) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditTransactionBottomSheet(
          expenseId: widget.existingExpense!.id,
          expense: widget.existingExpense!,
          field: EditField.date,
          currentValue: currentDate,
        ),
      );
    } else {
      DateTime? result;
      
      if (Platform.isIOS) {
        // Use Cupertino date picker for iOS
        result = await showCupertinoModalPopup<DateTime>(
          context: context,
          builder: (context) {
            DateTime tempDate = currentDate;
            return Container(
              height: 300,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  // Header with Done button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.separator.resolveFrom(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.cancel),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context, tempDate),
                          child: Text(context.l10n.done),
                        ),
                      ],
                    ),
                  ),
                  // Date picker
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: currentDate,
                      minimumDate: DateTime(2020),
                      maximumDate: DateTime.now(),
                      onDateTimeChanged: (DateTime value) {
                        tempDate = value;
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // Use Material date picker for Android
        result = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
      }
      
      if (result != null) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(date: result);
        }
      }
    }
  }

  void _handleEditTime() async {
    TimeOfDay? result;
    
    if (Platform.isIOS) {
      // Use Cupertino time picker for iOS
      final now = DateTime.now();
      final initialDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      final dateTime = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (context) {
          DateTime tempTime = initialDateTime;
          return Container(
            height: 300,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                // Header with Done button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.cancel),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context, tempTime),
                        child: Text(context.l10n.done),
                      ),
                    ],
                  ),
                ),
                // Time picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime value) {
                      tempTime = value;
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
      
      if (dateTime != null) {
        result = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      }
    } else {
      // Use Material time picker for Android
      result = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
    }
    
    if (result != null) {
      setState(() {
        _selectedTime = result!;
      });
    }
  }

  void _handleEditDescription(String? currentDescription) async {
    if (isExistingExpense) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditTransactionBottomSheet(
          expenseId: widget.existingExpense!.id,
          expense: widget.existingExpense!,
          field: EditField.description,
          currentValue: currentDescription,
        ),
      );
    } else {
      final colorScheme = shadcnui.Theme.of(context).colorScheme;
      final notePrefix = _generateNotePrefix();
      final initialDescription = () {
        if (currentDescription == null) return notePrefix;
        final trimmed = currentDescription.trimLeft();
        final isReceipt = trimmed.toLowerCase().startsWith('receipt:');
        return isReceipt ? notePrefix : currentDescription;
      }();
      final controller = TextEditingController(text: initialDescription);

      String? result;
      if (Platform.isIOS) {
        result = await showCupertinoModalPopup<String>(
          context: context,
          builder: (context) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CupertinoColors.separator.resolveFrom(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.l10n.cancel),
                          ),
                          Text(context.l10n.editNotes, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context, controller.text),
                            child: Text(context.l10n.save),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: CupertinoTextField(
                        controller: controller,
                        placeholder: context.l10n.addANote,
                        maxLines: 4,
                        autofocus: true,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 32,
                  height: 4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Text(
                    context.l10n.editNotes,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.l10n.addANote,
                      filled: true,
                      fillColor: colorScheme.muted.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 4,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: shadcnui.OutlineButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: shadcnui.PrimaryButton(
                          onPressed: () => Navigator.pop(context, controller.text),
                          child: Text(context.l10n.save),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      if (result != null) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(description: result);
        }
      }
    }
  }

  

  Future<void> _loadMembers(String householdId) async {
    setState(() {
      _isLoadingMembers = true;
      _membersError = null;
      _householdMembers = null;
    });
    try {
      final repository = ref.read(householdRepositoryProvider);
      final members = await repository.getHouseholdMembers(householdId);
      if (mounted) {
        setState(() {
          _householdMembers = members;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _membersError = '${context.l10n.errorLoadingMembers}: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final expense = ref.read(pendingExpenseProvider);
      final selectedHousehold = ref.read(selectedHouseholdForSharingProvider);

      if (expense == null) {
        throw Exception('No expense to save');
      }

      // Combine date with time
      final expenseDateTime = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Create updated expense with time
      final expenseWithTime = expense.copyWith(date: expenseDateTime);

      // Upload receipt image if available
      String? receiptUrl;
      if (widget.localImagePath != null) {
        final user = ref.read(authProvider);
        receiptUrl = await ref
            .read(expenseSaveNotifierProvider.notifier)
            .uploadReceiptImage(File(widget.localImagePath!), user.uid);
      }

      // Save expense with time and custom splits (if configured)
      await ref.read(expenseSaveNotifierProvider.notifier).saveExpense(
            expense: expenseWithTime,
            householdId: selectedHousehold,
            receiptImageUrl: receiptUrl,
            customSplitType: _customSplitType,
            customSplits: _customSplits,
          );

      // Clear pending expense, selection, and custom splits
      ref.read(pendingExpenseProvider.notifier).state = null;
      ref.read(selectedHouseholdForSharingProvider.notifier).state = null;
      
      if (!mounted) return;

      // Close modal
      Navigator.of(context).pop();

      // Show success toast with split info
      final splitInfo = _customSplitType != null 
          ? ' (${_customSplitType.toString().split('.').last} split)'
          : '';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selectedHousehold != null
              ? context.l10n.expenseSavedAndShared(splitInfo)
              : context.l10n.expenseSaved),
          backgroundColor: shadcnui.Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('❌ Error saving expense: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.failedToSave(error.toString())),
          backgroundColor: shadcnui.Theme.of(context).colorScheme.destructive,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

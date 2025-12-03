// Unified transaction detail/confirmation sheet
// Handles BOTH existing expenses (ExpenseEntry) and new expenses (ParsedExpense)
// Always shows household sharing option

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/auth/auth.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/destructive-adaptive-button.dart';
import 'package:moneko/shared/widgets/moneko-switch.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

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
    // Use localized date formatter for day names
    return DateFormat.EEEE(Localizations.localeOf(context).toString())
        .format(localDate);
  } else {
    // Use localized date formatter for full date
    return DateFormat.yMMMMd(Localizations.localeOf(context).toString())
        .format(localDate);
  }
}

/// Shows unified transaction sheet
/// For existing expenses: shows details with option to change sharing
/// For new expenses: shows confirmation with option to choose sharing
Future<void> showUnifiedTransactionSheet(
  BuildContext context, {
  ExpenseEntry? existingExpense,
  ParsedExpense? newExpense,
  UserContact? contact,
  String? localImagePath,
}) {
  assert(existingExpense != null || newExpense != null,
      'Must provide either existingExpense or newExpense');

  return showModalBottomSheet<void>(
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
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _localImagePath; // Track locally captured image for existing expenses
  final timeFormat = DateFormat('HH:mm');
  bool _isSharedWithHousehold = false;
  TimeOfDay _selectedTime = TimeOfDay.now();
  SplitType? _customSplitType;
  List<MemberSplit>? _customSplits;
  bool _isLoadingMembers = false;
  String? _membersError;
  List<HouseholdMember>? _householdMembers;
  String? _selectedPayerUserId;

  // Local edits (accumulated until save)
  double? _editedAmount;
  String? _editedCategory;
  String? _editedCurrency;
  DateTime? _editedDate;
  String? _editedDescription;

  /// Get localized category name
  String _getLocalizedCategory(String category) =>
      getCategoryTranslation(context, category);

  @override
  void initState() {
    super.initState();

    // DEBUG: Log expense ID for deep link testing
    if (widget.existingExpense != null) {
      debugPrint(
          '💸 [DEEP LINK TEST] Expense sheet opened for: ${widget.existingExpense!.id}');
      debugPrint(
          '🔗 [DEEP LINK TEST] Test with: moneko://expense/${widget.existingExpense!.id}');
    }

    // Initialize time from existing expense or now
    if (widget.existingExpense != null) {
      final dateTime = toLocalTime(widget.existingExpense!.createdAt);
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);

      // DEBUG: Log expense details for household sharing
      debugPrint(
          '🏠 [HOUSEHOLD SHARE] Expense ID: ${widget.existingExpense!.id}');
      debugPrint(
          '🏠 [HOUSEHOLD SHARE] householdId: ${widget.existingExpense!.householdId}');
      debugPrint(
          '🏠 [HOUSEHOLD SHARE] splitGroupId: ${widget.existingExpense!.splitGroupId}');

      // Initialize share state from existing expense (shared if linked to a household or has a split group)
      _isSharedWithHousehold = widget.existingExpense!.householdId != null ||
          widget.existingExpense!.splitGroupId != null;

      debugPrint(
          '🏠 [HOUSEHOLD SHARE] _isSharedWithHousehold set to: $_isSharedWithHousehold');

      // If expense is shared with a household, initialize the household selection and load members
      if (_isSharedWithHousehold &&
          widget.existingExpense!.householdId != null) {
        debugPrint(
            '🏠 [HOUSEHOLD SHARE] Initializing household selection: ${widget.existingExpense!.householdId}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(selectedHouseholdForSharingProvider.notifier).state =
                widget.existingExpense!.householdId;
            _loadMembers(widget.existingExpense!.householdId!);

            // Load existing split configuration if expense has a split group
            if (widget.existingExpense!.splitGroupId != null) {
              _loadExistingSplitConfiguration(
                  widget.existingExpense!.splitGroupId!);
            }
          }
        });
      }
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
            ref.read(selectedHouseholdForSharingProvider.notifier).state =
                selected;
            _loadMembers(selected);
          }
        });
      }
    }
  }

  bool get isNewExpense => widget.newExpense != null;
  bool get isExistingExpense => widget.existingExpense != null;

  // Unified getters that work for both cases - always check local edits first
  double get amount {
    if (_editedAmount != null) return _editedAmount!;
    if (isNewExpense) return widget.newExpense!.amount;
    return widget.existingExpense!.amount;
  }

  String get currency {
    if (_editedCurrency != null) return _editedCurrency!;
    if (isNewExpense) {
      // For new expenses, read from pendingExpenseProvider (which gets updated on edit)
      final pending = ref.read(pendingExpenseProvider);
      return pending?.currency ?? widget.newExpense!.currency;
    }
    return widget.existingExpense!.currency ?? 'USD';
  }

  String get currencySymbol {
    if (isNewExpense) {
      // For new expenses, read from pendingExpenseProvider (which gets updated on edit)
      final pending = ref.read(pendingExpenseProvider);
      return pending?.currencySymbol ?? widget.newExpense!.currencySymbol;
    }
    return resolveCurrencySymbol(currency);
  }

  String get category {
    if (_editedCategory != null) return _editedCategory!;
    if (isNewExpense) return widget.newExpense!.category;
    return widget.existingExpense!.category ?? 'other';
  }

  DateTime get date {
    if (_editedDate != null) return _editedDate!;
    if (isNewExpense) return widget.newExpense!.date;
    return widget.existingExpense!.date;
  }

  String? get description {
    if (_editedDescription != null) return _editedDescription;
    if (isNewExpense) return widget.newExpense!.description;
    return widget.existingExpense!.rawText;
  }

  String? get receiptImageUrl {
    final url = widget.existingExpense?.receiptImageUrl;
    debugPrint('🖼️ Receipt image URL from expense: $url');
    return url;
  }

  String? get effectiveImagePath {
    // For new expenses, use widget.localImagePath
    if (isNewExpense) return widget.localImagePath;
    // For existing expenses, use locally captured image first, then stored URL
    return _localImagePath ?? receiptImageUrl;
  }

  // Generate note prefix like "I spent $XX on category"
  String _generateNotePrefix() {
    final pending = ref.read(pendingExpenseProvider);
    final isIncomeMode =
        (isNewExpense && (pending?.isIncome ?? widget.newExpense!.isIncome));
    final displayAmount = (pending?.amount ?? amount);
    final displayCategory = (pending?.category ?? category);
    if (isIncomeMode) {
      return 'I earned $currencySymbol${displayAmount.toStringAsFixed(2)} ($displayCategory)';
    }
    return 'I spent $currencySymbol${displayAmount.toStringAsFixed(2)} on $displayCategory';
  }

  /// Handle adding a photo to existing expense
  Future<void> _handleAddPhoto() async {
    debugPrint('📷 Adding photo to existing expense...');

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        debugPrint('📷 Photo captured: ${photo.path}');
        setState(() {
          _localImagePath = photo.path;
        });
      } else {
        debugPrint('📷 Photo capture cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error capturing photo: $e');
      if (mounted) {
        AppToast.error(context, 'Failed to capture photo: $e');
      }
    }
  }

  /// Show full-screen image viewer with pinch-to-zoom
  void _showFullScreenImage(String? localImagePath, String? receiptImageUrl) {
    if (localImagePath == null && receiptImageUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          localImagePath: localImagePath,
          imageUrl: receiptImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedHousehold = ref.watch(selectedHouseholdForSharingProvider);

    // For new expenses, use pending expense provider
    final pendingExpense =
        isNewExpense ? ref.watch(pendingExpenseProvider) : null;

    // Use pending expense if available (for new expenses only), otherwise use local/initial
    final displayAmount =
        isNewExpense && pendingExpense != null ? pendingExpense.amount : amount;
    final displayCategory = isNewExpense && pendingExpense != null
        ? pendingExpense.category
        : category;
    final displayDate =
        isNewExpense && pendingExpense != null ? pendingExpense.date : date;
    final displayDescription = isNewExpense && pendingExpense != null
        ? pendingExpense.description
        : description;

    // Income mode for display (for new or existing items)
    final isIncomeMode = isNewExpense
        ? (pendingExpense?.isIncome ?? widget.newExpense!.isIncome)
        : ((widget.existingExpense?.type?.toLowerCase() == 'income'));

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
            padding:
                const EdgeInsets.only(left: 8, top: 4, bottom: 8, right: 16),
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
                    isNewExpense
                        ? (isIncomeMode
                            ? context.l10n.confirmIncome
                            : context.l10n.confirmExpense)
                        : context.l10n.expenseDetails,
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          '${isIncomeMode ? '+' : '-'}$currencySymbol${displayAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: isIncomeMode
                                ? const Color(0xFF10B981)
                                : colorScheme.foreground,
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
                            isIncomeMode,
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
                    value: _getLocalizedCategory(displayCategory),
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
                  if (isNewExpense ||
                      (displayDescription != null &&
                          displayDescription.isNotEmpty)) ...[
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
                        // Prefer AI-provided description when it matches the UI language;
                        // otherwise fall back to a localized, minimal description.
                        String? effective = displayDescription;
                        if (effective != null) {
                          final isReceipt = effective
                              .trimLeft()
                              .toLowerCase()
                              .startsWith('receipt:');
                          if (isReceipt) effective = null;
                        }
                        // Final fallback
                        return effective ??
                            getCategoryTranslation(context, displayCategory);
                      })(),
                      onTap: () => _handleEditDescription(displayDescription),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Receipt Section - Always show (with placeholder if no image)
                  () {
                    debugPrint(
                        '🖼️ Checking receipt display: effectiveImagePath=$effectiveImagePath');
                    return Container();
                  }(),
                  _buildReceiptCard(
                    colorScheme: colorScheme,
                    localImagePath:
                        isNewExpense ? effectiveImagePath : _localImagePath,
                    receiptImageUrl: isNewExpense ? null : receiptImageUrl,
                    onAddPhoto:
                        effectiveImagePath == null ? _handleAddPhoto : null,
                  ),
                  const SizedBox(height: 32),

                  // Save Button (for both new and existing expenses)
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryAdaptiveButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              isIncomeMode
                                  ? context.l10n.saveIncome
                                  : context.l10n.saveExpense,
                            ),
                    ),
                  ),

                  // Delete Button (only for existing expenses)
                  if (isExistingExpense) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: DestructiveAdaptiveButton(
                        onPressed: _isDeleting ? null : _handleDelete,
                        child: _isDeleting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                context.l10n.deleteExpense,
                              ),
                      ),
                    ),
                  ],

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
    ColorScheme colorScheme,
    List households,
    String? selectedHousehold,
    bool isIncomeMode,
  ) {
    // Auto-select first household when sharing is enabled but no selection exists yet
    if (_isSharedWithHousehold &&
        households.isNotEmpty &&
        selectedHousehold == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final firstId = households.first.id;
        ref.read(selectedHouseholdForSharingProvider.notifier).state = firstId;
        _loadMembers(firstId);
      });
    }
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.12),
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
              MonekoSwitch(
                value: _isSharedWithHousehold,
                onChanged: (value) {
                  setState(() {
                    _isSharedWithHousehold = value;
                    if (!value) {
                      // Clear household selection and custom splits
                      ref
                          .read(selectedHouseholdForSharingProvider.notifier)
                          .state = null;
                      _customSplitType = null;
                      _customSplits = null;
                      _householdMembers = null;
                      _membersError = null;
                      _isLoadingMembers = false;
                    } else if (households.isNotEmpty) {
                      // Auto-select first household when toggling on
                      ref
                          .read(selectedHouseholdForSharingProvider.notifier)
                          .state = households.first.id;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedHousehold ?? households.first.id,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down,
                      color: colorScheme.foreground),
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
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: colorScheme.muted,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.home_rounded,
                                      size: 16,
                                      color: colorScheme.mutedForeground),
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
                      ref
                          .read(selectedHouseholdForSharingProvider.notifier)
                          .state = value;
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
                      color: colorScheme.muted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(context.l10n.loadingHouseholdMembers,
                            style:
                                TextStyle(color: colorScheme.mutedForeground)),
                      ],
                    ),
                  );
                }
                if (_membersError != null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: colorScheme.destructive, size: 18),
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
                if (_householdMembers == null || _householdMembers!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.selectHouseholdToConfigureSplit,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  );
                }

                final pendingExpense =
                    isNewExpense ? ref.read(pendingExpenseProvider) : null;
                final currentAmount = pendingExpense?.amount ?? amount;

                // Ensure default payer selection
                _selectedPayerUserId ??= ref.read(authProvider).uid;

                // For income mode, we hide the custom split editor entirely
                if (isIncomeMode) {
                  return const SizedBox();
                }
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Who paid selector
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
                                    color: colorScheme.foreground),
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPayerUserId,
                                items: _householdMembers!
                                    .map((m) => DropdownMenuItem<String>(
                                          value: m.userId,
                                          child: Text(
                                              m.userName ??
                                                  m.userEmail ??
                                                  'Member',
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedPayerUserId = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomSplitEditor(
                        key: ValueKey(
                            'split_${_customSplitType}_${_customSplits?.length}'),
                        members: _householdMembers!,
                        totalAmount: currentAmount,
                        currencySymbol: currencySymbol,
                        initialSplitType: _customSplitType,
                        initialSplits: _customSplits,
                        onChanged: (splitType, splits) {
                          setState(() {
                            _customSplitType = splitType;
                            _customSplits = splits;
                          });
                        },
                      ),
                    ],
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
    required ColorScheme colorScheme,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled
          ? () {
              AppToast.info(context, context.l10n.currencyIsManagedByHousehold);
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
                      color: disabled
                          ? colorScheme.mutedForeground.withValues(alpha: 0.6)
                          : colorScheme.mutedForeground,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: disabled
                          ? colorScheme.mutedForeground
                          : colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: disabled
                    ? colorScheme.mutedForeground.withValues(alpha: 0.4)
                    : colorScheme.mutedForeground,
                size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEditCurrency(String currentCurrency) async {
    if (_isSharedWithHousehold) {
      AppToast.info(context, context.l10n.currencyCannotBeChangedWhenSharing);
      return;
    }

    final selected = await showCurrencyPicker(
      context: context,
      currentCurrency: currentCurrency,
    );

    if (selected != null) {
      if (isNewExpense) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state = current.copyWith(
            currency: selected,
            currencySymbol: resolveCurrencySymbol(selected),
          );
        }
      } else {
        setState(() {
          _editedCurrency = selected;
        });
      }
    }
  }

  Widget _buildNotesCard({
    required ColorScheme colorScheme,
    required String notes,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.muted.withValues(alpha: 0.08),
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
    required ColorScheme colorScheme,
    String? localImagePath,
    String? receiptImageUrl,
    VoidCallback? onAddPhoto,
  }) {
    // Show receipt title if there's an image or add photo option
    final hasImage = localImagePath != null || receiptImageUrl != null;
    final canAddPhoto = onAddPhoto != null;

    if (!hasImage && !canAddPhoto) {
      return const SizedBox(); // No image and no way to add one
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Receipt title
        if (hasImage || canAddPhoto) ...[
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
        ],

        // Image or placeholder
        GestureDetector(
          onTap: hasImage
              ? () => _showFullScreenImage(localImagePath, receiptImageUrl)
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.transparent : colorScheme.border,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: localImagePath != null
                  ? Image.file(File(localImagePath),
                      fit: BoxFit.cover, height: 200)
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
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
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
                      : _buildReceiptPlaceholder(colorScheme, onAddPhoto!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptPlaceholder(
      ColorScheme colorScheme, VoidCallback onAddPhoto) {
    return InkWell(
      onTap: onAddPhoto,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.addReceiptPhoto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tapToTakePhoto,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Edit handlers - update local state for both new and existing
  void _handleEditAmount(double currentAmount) async {
    final controller =
        TextEditingController(text: currentAmount.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editAmount),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: context.l10n.amount),
          autofocus: true,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
      if (isNewExpense) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(amount: result);
        }
      } else {
        setState(() {
          _editedAmount = result;
        });
      }
    }
  }

  void _handleEditCategory(String currentCategory) async {
    final isIncomeMode = isNewExpense
        ? (ref.read(pendingExpenseProvider)?.isIncome ??
            widget.newExpense!.isIncome)
        : ((widget.existingExpense?.type?.toLowerCase() == 'income'));

    final baseCategories =
        isIncomeMode ? getIncomeCategories() : getExpenseCategories();
    final normalizedCurrent = currentCategory.toLowerCase();
    final categories = () {
      if (!baseCategories.contains(normalizedCurrent)) {
        return [...baseCategories, normalizedCurrent];
      }
      return baseCategories;
    }();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return CategoryPickerBottomSheet(
          allCategories: categories,
          selectedCategories: <String>[normalizedCurrent],
          isSingleSelect: true,
          onChanged: (value) {
            final next = value.isNotEmpty ? value.first : null;
            if (next == null) return;

            if (isNewExpense) {
              final current = ref.read(pendingExpenseProvider);
              if (current != null) {
                ref.read(pendingExpenseProvider.notifier).state =
                    current.copyWith(category: next);
              }
            } else {
              setState(() {
                _editedCategory = next;
              });
            }
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  void _handleEditDate(DateTime currentDate) async {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      if (isNewExpense) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(date: result);
        }
      } else {
        setState(() {
          _editedDate = result;
        });
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final colorScheme = Theme.of(context).colorScheme;
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
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        Text(context.l10n.editNotes,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
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
                    fillColor: colorScheme.muted.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 4,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
                      child: AdaptiveButton(
                        onPressed: () => Navigator.pop(context),
                        style: AdaptiveButtonStyle.plain,
                        label: context.l10n.cancel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdaptiveButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        label: context.l10n.save,
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
      if (isNewExpense) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(description: result);
        }
      } else {
        setState(() {
          _editedDescription = result;
        });
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

  /// Map database SplitType to UI SplitType
  SplitType _mapSplitType(dynamic dbSplitType) {
    // dbSplitType is ExpenseSplitGroup.SplitType from expense_split.dart
    // We need to convert it to SplitType from custom_split_sheet.dart
    final typeString = dbSplitType.toString().split('.').last;
    switch (typeString) {
      case 'equal':
        return SplitType.equal;
      case 'amount':
        return SplitType.amount;
      case 'percentage':
        return SplitType.percentage;
      case 'shares':
        return SplitType.shares;
      default:
        return SplitType.amount; // fallback
    }
  }

  /// Load existing split configuration from database
  Future<void> _loadExistingSplitConfiguration(String splitGroupId) async {
    debugPrint(
        '🔄 [LOAD SPLIT] Loading existing split configuration for: $splitGroupId');

    try {
      final householdId = widget.existingExpense!.householdId;
      if (householdId == null) return;

      // Load splits for this household
      final splitsAsync = await ref.read(householdSplitsProvider(
        HouseholdSplitsParams(householdId: householdId),
      ).future);

      // Find the split group for this expense
      final splitGroup = splitsAsync.firstWhere(
        (g) => g.id == splitGroupId,
        orElse: () => throw Exception('Split group not found'),
      );

      debugPrint('🔄 [LOAD SPLIT] Found split group: ${splitGroup.splitType}');
      debugPrint(
          '🔄 [LOAD SPLIT] Split lines: ${splitGroup.splitLines?.length ?? 0}');

      if (splitGroup.splitLines == null || splitGroup.splitLines!.isEmpty) {
        debugPrint('⚠️ [LOAD SPLIT] No split lines found');
        return;
      }

      // Wait for members to load first (with timeout to prevent infinite loop)
      const maxWaitTime = Duration(seconds: 10);
      final waitStart = DateTime.now();
      while (_householdMembers == null && _isLoadingMembers) {
        if (DateTime.now().difference(waitStart) > maxWaitTime) {
          debugPrint('⚠️ [LOAD SPLIT] Timeout waiting for household members');
          return;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_householdMembers == null) {
        debugPrint('⚠️ [LOAD SPLIT] Members not loaded');
        return;
      }

      // Convert split lines to MemberSplit objects
      final memberSplits = <MemberSplit>[];
      for (final member in _householdMembers!) {
        final splitLine = splitGroup.splitLines!.firstWhere(
          (line) => line.userId == member.userId,
          orElse: () => throw Exception(
              'Split line not found for member ${member.userId}'),
        );

        memberSplits.add(MemberSplit(
          member: member,
          amount: splitLine.amountCents != null
              ? splitLine.amountCents! / 100.0
              : null,
          percentage: splitLine.percentage,
          shares: splitLine.shares,
          includedInAmount: true,
          includedInPercentage: true,
        ));

        debugPrint(
            '🔄 [LOAD SPLIT] Member ${member.userName ?? member.userEmail}: amountCents=${splitLine.amountCents}');
      }

      if (mounted) {
        // Map ExpenseSplitGroup.SplitType to CustomSplitSheet.SplitType
        final uiSplitType = _mapSplitType(splitGroup.splitType);

        setState(() {
          _customSplitType = uiSplitType;
          _customSplits = memberSplits;
        });
        debugPrint(
            '✅ [LOAD SPLIT] Initialized split editor with existing configuration: $uiSplitType');
      }
    } catch (error) {
      debugPrint('❌ [LOAD SPLIT] Error loading split configuration: $error');
    }
  }

  void _refreshHouseholdUiAfterExpenseChange(String householdId) {
    final homeFilter = ref.read(homeFilterProvider);
    final dateRange = getDateRangeFromFilter(
      homeFilter.dateRangeFilter,
      homeFilter.customStartDate,
      homeFilter.customEndDate,
    );

    ref.invalidate(householdExpensesProvider(
      HouseholdExpensesParams(householdId: householdId, limit: 500),
    ));
    ref.invalidate(householdSplitsProvider(
      HouseholdSplitsParams(householdId: householdId),
    ));
    ref.invalidate(householdBudgetsProvider(householdId));
    ref.invalidate(householdSummaryProvider(
      HouseholdSummaryParams(
        householdId: householdId,
        currency: homeFilter.selectedCurrency ?? 'USD',
        startDate: dateRange['from']!.toIso8601String(),
        endDate: dateRange['to']!.toIso8601String(),
      ),
    ));
    ref.invalidate(householdMembersProvider(householdId));

    ref.invalidate(pocketsProvider(PocketsScopeParams(
      scope: PocketsScopeType.household,
      householdId: householdId,
    )));
  }

  void _refreshPersonalUiAfterExpenseChange(String userId) {
    ref.read(analyticsProvider.notifier).refresh(userId);
    ref.invalidate(pocketsProvider(const PocketsScopeParams(
      scope: PocketsScopeType.personal,
    )));
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final user = ref.read(authProvider);
      final viewMode = ref.read(viewModeProvider);

      // ═══════════════════════════════════════════════════════════════
      // PERMISSION CHECK: User can only edit their own expenses
      // ═══════════════════════════════════════════════════════════════
      // When editing existing expenses, verify that the logged-in user
      // is the one who created the expense. This prevents users from
      // editing expenses logged by other household members.
      //
      // Security: Each expense has a userId field that identifies the creator.
      // We compare this with the current logged-in user's ID.
      //
      // Example scenario:
      //   - User A logs an expense in household
      //   - User B (another household member) views the expense list
      //   - User B tries to edit User A's expense
      //   - Result: Blocked with error message "You can only edit your own expenses"
      // ═══════════════════════════════════════════════════════════════
      if (isExistingExpense) {
        final ownerId = widget.existingExpense!.userId;
        if (ownerId != null && ownerId.isNotEmpty && ownerId != user.uid) {
          setState(() => _isSaving = false);
          if (!mounted) return;

          AppToast.error(context, context.l10n.cannotEditOthersExpenses);
          return;
        }
      }

      if (isNewExpense) {
        // NEW TRANSACTION (expense or income)
        final expense = ref.read(pendingExpenseProvider);
        final selectedHousehold = ref.read(selectedHouseholdForSharingProvider);

        if (expense == null) {
          throw Exception('No transaction to save');
        }

        // Combine date with time
        final expenseDateTime = DateTime(
          expense.date.year,
          expense.date.month,
          expense.date.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        if (expense.isIncome) {
          // Save INCOME
          final saved = await ref.read(incomeSaveProvider.notifier).saveIncome(
                userId: user.uid,
                amount: expense.amount,
                category:
                    expense.category.isNotEmpty ? expense.category : 'income',
                currency: expense.currency,
                date: expenseDateTime,
                description: expense.description,
                householdId: _isSharedWithHousehold
                    ? selectedHousehold
                    : null, // ✅ FIX: Only pass if toggle is ON
              );

          // Reset state
          ref.read(pendingExpenseProvider.notifier).state = null;
          ref.read(selectedHouseholdForSharingProvider.notifier).state = null;
          // Upload receipt image if available
          // Priority: 1) expense.localImagePath (from ParsedExpense), 2) widget.localImagePath (fallback)
          String? receiptUrl;
          final imagePathToUpload =
              expense.localImagePath ?? widget.localImagePath;

          if (imagePathToUpload != null) {
            debugPrint('📤 Uploading receipt image: $imagePathToUpload');
            receiptUrl = await ref
                .read(expenseSaveNotifierProvider.notifier)
                .uploadReceiptImage(File(imagePathToUpload), user.uid);
            debugPrint('📤 Receipt upload result: $receiptUrl');
          } else {
            debugPrint('📤 No local image path to upload');
          }

          // Ensure UI updates immediately
          if (viewMode.mode == ViewMode.household &&
              selectedHousehold != null) {
            _refreshHouseholdUiAfterExpenseChange(selectedHousehold);
          } else {
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          if (!mounted) return;

          Navigator.of(context).pop();
          if (saved != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(selectedHousehold != null
                    ? context.l10n.incomeSavedAndShared
                    : context.l10n.incomeSaved),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          // Save EXPENSE
          // Create updated expense with time
          final expenseWithTime = expense.copyWith(date: expenseDateTime);
          final l10n = context.l10n;

          // Upload receipt image if available
          String? receiptUrl;
          if (widget.localImagePath != null) {
            receiptUrl = await ref
                .read(expenseSaveNotifierProvider.notifier)
                .uploadReceiptImage(File(widget.localImagePath!), user.uid);
          }

          // ═══════════════════════════════════════════════════════════════
          // CRITICAL FIX: Only pass householdId if sharing toggle is ON
          // ═══════════════════════════════════════════════════════════
          // When _isSharedWithHousehold is false, we must pass null for householdId
          // This ensures the expense is saved as PERSONAL (household_id = null in DB)
          // which makes it appear in the personal page, not the household page.
          //
          // Before fix: Always passed selectedHousehold (even when toggle OFF)
          // After fix: Only pass selectedHousehold when _isSharedWithHousehold is true
          // ═══════════════════════════════════════════════════════════
          // Save expense with time and custom splits (if configured)
          await ref.read(expenseSaveNotifierProvider.notifier).saveExpense(
                expense: expenseWithTime,
                householdId: _isSharedWithHousehold
                    ? selectedHousehold
                    : null, // ✅ FIX: Only pass if toggle is ON
                receiptImageUrl: receiptUrl,
                customSplitType: _customSplitType,
                customSplits: _customSplits,
                payerUserId:
                    _isSharedWithHousehold ? _selectedPayerUserId : null,
              );

          AppToast.success(context, context.l10n.expenseSaved);

          // Ensure UI updates immediately and close sheet
          if (viewMode.mode == ViewMode.household &&
              selectedHousehold != null) {
            _refreshHouseholdUiAfterExpenseChange(selectedHousehold);
          } else {
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          if (!mounted) return;
          Navigator.of(context).pop();
        }
      } else {
        // EXISTING EXPENSE: Build updates map from local edits
        final Map<String, dynamic> updates = {};

        if (_editedAmount != null) {
          updates['amount_cents'] = (_editedAmount! * 100).round();
        }

        if (_editedCategory != null) {
          updates['category'] = _editedCategory;
        }

        if (_editedCurrency != null) {
          updates['currency'] = _editedCurrency;
        }

        if (_editedDescription != null) {
          updates['raw_text'] = _editedDescription;
        }

        // Handle date and time updates separately
        final finalDate = _editedDate ?? widget.existingExpense!.date;
        final expenseDateTime = DateTime(
          finalDate.year,
          finalDate.month,
          finalDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        // Backend expects date in YYYY-MM-DD format (local date)
        updates['date'] = DateFormat('yyyy-MM-dd').format(finalDate);

        // Send full datetime as created_at in UTC to preserve timezone consistency
        updates['created_at'] = expenseDateTime.toUtc().toIso8601String();

        // Handle receipt image upload for existing expenses
        if (_localImagePath != null) {
          debugPrint(
              '📤 Uploading new receipt image for existing expense: $_localImagePath');
          final receiptUrl = await ref
              .read(expenseSaveNotifierProvider.notifier)
              .uploadReceiptImage(File(_localImagePath!), user.uid);
          debugPrint('📤 New receipt upload result: $receiptUrl');

          if (receiptUrl != null) {
            updates['receipt_image_url'] = receiptUrl;
          }
        }

        // Only update if there are actual changes
        if (updates.isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }

        debugPrint('💾 Updating expense with: $updates');

        // Call update API (this already handles provider refresh internally)
        final success = await ref
            .read(transactionEditProvider.notifier)
            .updateExpense(widget.existingExpense!.id, updates);

        if (!mounted) return;

        if (success) {
          // Ensure UI refresh for current view mode
          if (viewMode.mode == ViewMode.household) {
            final currentHouseholdId =
                ref.read(selectedHouseholdProvider).householdId;
            if (currentHouseholdId != null) {
              _refreshHouseholdUiAfterExpenseChange(currentHouseholdId);
            }
          } else {
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          // Close the sheet so when user reopens it, they see fresh data
          Navigator.of(context).pop();

          AppToast.success(context, context.l10n.expenseUpdatedSuccessfully);
        } else {
          throw Exception('Failed to update expense');
        }
      }
    } catch (error) {
      debugPrint('❌ Error saving expense: $error');
      if (!mounted) return;

      AppToast.error(context, context.l10n.failedToSave(""));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final colorScheme = Theme.of(context).colorScheme;

    // Show platform-specific confirmation dialog
    bool? confirmed;

    if (Platform.isIOS) {
      // iOS-style dialog
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.deleteExpense),
          content: Text(
            context.l10n.confirmDeleteExpense,
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              isDestructiveAction: true,
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      );
    } else {
      // Android-style dialog
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_rounded,
                  color: colorScheme.destructive, size: 24),
              const SizedBox(width: 12),
              Text(context.l10n.deleteExpense),
            ],
          ),
          content: Text(
            context.l10n.confirmDeleteExpense,
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.mutedForeground,
              ),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.destructive,
                backgroundColor: colorScheme.destructive.withValues(alpha: 0.1),
              ),
              child: Text(context.l10n.delete,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final user = ref.read(authProvider);

      debugPrint('🗑️ Deleting expense: ${widget.existingExpense!.id}');

      // Call delete API
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': user.uid,
          'expenseId': widget.existingExpense!.id,
        },
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? 'Failed to delete expense');
      }

      debugPrint('✅ Expense deleted successfully');

      // Refresh analytics data (personal expenses)
      await ref.read(analyticsProvider.notifier).loadData(user.uid);
      ref.invalidate(pocketsProvider(const PocketsScopeParams(
        scope: PocketsScopeType.personal,
      )));

      // If this was a household expense, invalidate household providers
      final householdId = widget.existingExpense!.householdId;
      if (householdId != null) {
        debugPrint(
            '🔄 Invalidating household providers for household: $householdId');

        // Invalidate household list to update counts
        ref.invalidate(userHouseholdsProvider(user.uid));

        // Invalidate family providers so all parameterized instances refresh
        ref.invalidate(householdSummaryProvider);
        ref.invalidate(householdExpensesProvider);
        ref.invalidate(householdSplitsProvider);
        ref.invalidate(householdBudgetsProvider);

        ref.invalidate(pocketsProvider(PocketsScopeParams(
          scope: PocketsScopeType.household,
          householdId: householdId,
        )));

        debugPrint('✅ Invalidated household providers');
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      AppToast.success(context, context.l10n.expenseDeletedSuccessfully);
    } catch (error) {
      debugPrint('❌ Error deleting expense: $error');
      if (!mounted) return;

      AppToast.error(context, context.l10n.failedToDeleteExpense);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

/// Full-screen image viewer with pinch-to-zoom functionality
class _FullScreenImageViewer extends StatefulWidget {
  final String? localImagePath;
  final String? imageUrl;

  const _FullScreenImageViewer({
    this.localImagePath,
    this.imageUrl,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: widget.localImagePath != null
              ? Image.file(
                  File(widget.localImagePath!),
                  fit: BoxFit.contain,
                )
              : widget.imageUrl != null
                  ? Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const SizedBox(),
        ),
      ),
    );
  }
}

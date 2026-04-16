// Unified transaction detail/confirmation sheet
// Handles BOTH existing expenses (ExpenseEntry) and new expenses (ParsedExpense)
// Always shows household sharing option

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
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
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/home/presentation/utils/payer_resolver.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/destructive_text_button.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/utils/user_timezone.dart';

import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    as household_split;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/moneko_switch.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

/// Format date with relative terms
String _formatRelativeDate(
  DateTime date,
  BuildContext context,
) {
  final now = DateTime.now().toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);
  final localeName = intlSafeLocaleName(Localizations.localeOf(context));

  if (dateOnly == today) {
    return context.l10n.today;
  } else if (dateOnly == yesterday) {
    return context.l10n.yesterday;
  } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
    // Use localized date formatter for day names
    return DateFormat.EEEE(localeName).format(dateOnly);
  } else {
    // Use localized date formatter for full date
    return DateFormat.yMMMMd(localeName).format(dateOnly);
  }
}

class _AccountOption {
  final ActiveWalletType type;
  final String? householdId;
  final String label;
  final bool isPortfolio;

  const _AccountOption({
    required this.type,
    required this.label,
    this.householdId,
    this.isPortfolio = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _AccountOption) return false;
    return type == other.type && householdId == other.householdId;
  }

  @override
  int get hashCode => Object.hash(type, householdId);
}

class _AccountTarget {
  final String? householdId;
  final bool isPortfolio;

  const _AccountTarget({required this.householdId, required this.isPortfolio});
}

/// Shows unified transaction sheet
/// For existing expenses: shows details with option to change sharing
/// For new expenses: shows confirmation with option to choose sharing
Future<bool?> showUnifiedTransactionSheet(
  BuildContext context, {
  ExpenseEntry? existingExpense,
  ParsedExpense? newExpense,
  UserContact? contact,
  String? localImagePath,
}) {
  assert(existingExpense != null || newExpense != null,
      'Must provide either existingExpense or newExpense');

  return showModalBottomSheet<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: false,
    useSafeArea: true,
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
  ActiveWalletType _selectedAccountType = ActiveWalletType.personal;
  String? _selectedAccountHouseholdId;
  ActiveWalletType _lastNonHouseholdAccountType = ActiveWalletType.personal;
  String? _lastNonHouseholdHouseholdId;
  TimeOfDay _selectedTime = TimeOfDay.now();
  SplitType? _customSplitType;
  List<MemberSplit>? _customSplits;
  String? _initialSplitSignature;
  String? _loadedSplitGroupType;
  bool _isLoadingMembers = false;
  String? _membersError;
  List<HouseholdMember>? _householdMembers;
  String? _selectedPayerUserId;
  String? _resolvedSplitGroupId;
  bool _hasCheckedSplitGroup = false;
  String? _selectedFinancialAccountId;
  bool _hasManuallySelectedFinancialAccount = false;

  // Local edits (accumulated until save)
  double? _editedAmount;
  String? _editedCategory;
  String? _editedCurrency;
  DateTime? _editedDate;
  String? _editedDescription;

  void debugPrint(String? message, {int? wrapWidth}) {
    if (foundation.kDebugMode && _enableDebugLogs) {
      foundation.debugPrint(message, wrapWidth: wrapWidth);
    }
  }

  DateTime get _effectiveNow => DateTime.now().toLocal();

  DateTime _toDeviceWallTime(DateTime utcOrLocalInstant) {
    return utcOrLocalInstant.isUtc
        ? utcOrLocalInstant.toLocal()
        : utcOrLocalInstant;
  }

  /// Get localized category name
  String _getLocalizedCategory(String category) =>
      getCategoryTranslation(context, category);

  String _normalizeCategoryRemapKey(String? category) {
    final raw = (category ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    if (categoryColors.containsKey(raw)) return raw;
    if (!raw.contains(' ')) return normalizeCategory(raw);
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _selectedFinancialAccountId = widget.existingExpense?.walletId;
    // Default payer to the expense owner (fallback to current user) so we don't
    // incorrectly show the viewer as the payer before loading split data.
    final currentUserId = ref.read(authProvider).uid;
    _selectedPayerUserId = widget.existingExpense?.userId?.isNotEmpty == true
        ? widget.existingExpense!.userId
        : currentUserId;

    // Debug diagnostics (redacted)
    if (widget.existingExpense != null) {
      debugPrint('💸 [DEEP LINK TEST] Expense sheet opened');
      debugPrint('🔗 [DEEP LINK TEST] Deep link path available');
    }

    // Initialize time from existing expense or now
    if (widget.existingExpense != null) {
      final dateTime = _toDeviceWallTime(widget.existingExpense!.createdAt);
      _selectedTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);

      // DEBUG: Log expense details for household sharing
      debugPrint('🏠 [HOUSEHOLD SHARE] Existing expense context loaded');

      final scope = ref.read(householdScopeProvider);
      final existingHouseholdId = widget.existingExpense!.householdId;
      final isPortfolio = scope.isPortfolioId(existingHouseholdId);
      final hasHousehold =
          existingHouseholdId != null && existingHouseholdId.isNotEmpty;
      final isSharedSpace = hasHousehold && !isPortfolio;

      final defaultAccountType = () {
        if (isPortfolio && hasHousehold) return ActiveWalletType.portfolio;
        if (isSharedSpace) return ActiveWalletType.household;
        return ActiveWalletType.personal;
      }();

      _setAccountSelectionDefaults(defaultAccountType, existingHouseholdId);

      final existingSplitGroupId = widget.existingExpense!.splitGroupId?.trim();
      if (isSharedSpace &&
          existingSplitGroupId != null &&
          existingSplitGroupId.isNotEmpty) {
        _resolvedSplitGroupId = existingSplitGroupId;
        _hasCheckedSplitGroup = true;
      }

      debugPrint(
          '🏠 [HOUSEHOLD SHARE] _isSharedWithHousehold set to: $_isSharedWithHousehold');

      // If expense is shared with a household, initialize the household selection and load members
      if (isSharedSpace && widget.existingExpense!.householdId != null) {
        debugPrint('🏠 [HOUSEHOLD SHARE] Initializing household selection');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('🏠 [EDIT EXPENSE] postFrameCallback executing');
            final householdId = widget.existingExpense!.householdId!;
            debugPrint('🏠 [EDIT EXPENSE] Setting selected household state');
            ref.read(selectedHouseholdForSharingProvider.notifier).state =
                householdId;
            debugPrint('🏠 [EDIT EXPENSE] Loading household members');
            _loadMembers(householdId);

            _resolveSplitGroupIdForExistingExpense(loadSplitConfig: true);
          } else {
            debugPrint(
                '⚠️ [EDIT EXPENSE] Widget unmounted before postFrameCallback');
          }
        });
      }
    } else if (widget.newExpense != null) {
      // For new expenses, default to current local time (BE usually returns date-only)
      _selectedTime = TimeOfDay.now();

      final newExpense = widget.newExpense!;
      if (newExpense.payerUserId != null &&
          newExpense.payerUserId!.isNotEmpty) {
        _selectedPayerUserId = newExpense.payerUserId;
      }
      // Auto-enable household sharing when in household view mode
      final scope = ref.read(householdScopeProvider);
      debugPrint('🆕 [ADD EXPENSE] Initialized add flow');

      final defaultAccountType = () {
        switch (scope.activeAccountType) {
          case ActiveWalletType.personal:
            return ActiveWalletType.personal;
          case ActiveWalletType.portfolio:
            return scope.activeAccountHouseholdId != null
                ? ActiveWalletType.portfolio
                : ActiveWalletType.personal;
          case ActiveWalletType.household:
            return scope.activeAccountHouseholdId != null
                ? ActiveWalletType.household
                : ActiveWalletType.personal;
        }
      }();

      _setAccountSelectionDefaults(
        defaultAccountType,
        scope.activeAccountHouseholdId,
      );

      // Seed the dropdown with the main menu's currently selected household (if any)
      // BEFORE build to avoid the first-household fallback firing.
      final selectedState = ref.read(selectedHouseholdProvider);
      final selected = selectedState.householdId ?? selectedState.household?.id;
      debugPrint(
          '🆕 [ADD EXPENSE] Selected household present: ${selected != null}');

      // Defer provider state modification to after widget tree is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Seed the pending expense so edits/saves are consistent.
        ref.read(pendingExpenseProvider.notifier).state = newExpense;

        if (selected != null &&
            _selectedAccountHouseholdId == null &&
            _selectedAccountType == ActiveWalletType.household) {
          ref.read(selectedHouseholdForSharingProvider.notifier).state =
              selected;
          if (_isSharedWithHousehold) {
            debugPrint('🆕 [ADD EXPENSE] Sharing enabled; loading members');
            _loadMembers(selected);
          }
        } else if (selected == null) {
          debugPrint('⚠️ [ADD EXPENSE] No household selected in provider!');
        }
      });
    }
  }

  bool get isNewExpense => widget.newExpense != null;
  bool get isExistingExpense => widget.existingExpense != null;
  String? get _effectiveSplitGroupId {
    final existingHouseholdId = widget.existingExpense?.householdId;
    if (existingHouseholdId == null) return null;

    final householdScope = ref.read(householdScopeProvider);
    if (householdScope.isPortfolioId(existingHouseholdId)) {
      return null;
    }

    final targetHouseholdId = _resolveAccountTarget().householdId;
    if (targetHouseholdId != existingHouseholdId) {
      return null;
    }

    final resolved = _resolvedSplitGroupId;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final existing = widget.existingExpense?.splitGroupId;
    if (existing != null && existing.isNotEmpty) return existing;
    return null;
  }

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
    return widget.existingExpense!.currency ?? context.l10n.usd;
  }

  String get currencySymbol {
    if (isNewExpense) {
      // For new expenses, resolve the symbol from the canonical currency code
      // rather than trusting the raw currencySymbol from the parser.
      final pending = ref.read(pendingExpenseProvider);
      final code = pending?.currency ?? widget.newExpense!.currency;
      return resolveCurrencySymbol(code);
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
    debugPrint('🖼️ Receipt image detected on expense');
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
      return context.l10n.iEarnedAmountOnCategory(
        '$currencySymbol${formatLocalizedNumber(context, double.parse(displayAmount.toStringAsFixed(2)))}',
        displayCategory,
      );
    }
    return context.l10n.iSpentAmountOnCategory(
      currencySymbol,
      formatLocalizedNumber(
          context, double.parse(displayAmount.toStringAsFixed(2))),
      displayCategory,
    );
  }

  void _setAccountSelectionDefaults(
    ActiveWalletType type,
    String? householdId,
  ) {
    _selectedAccountType = type;
    _selectedAccountHouseholdId = householdId;
    if (type != ActiveWalletType.household) {
      _lastNonHouseholdAccountType = type;
      _lastNonHouseholdHouseholdId = householdId;
    }
    _isSharedWithHousehold = type == ActiveWalletType.household;
  }

  List<_AccountOption> _accountOptions(
    BuildContext context,
    List<Household> households,
  ) {
    final options = <_AccountOption>[
      _AccountOption(
        type: ActiveWalletType.personal,
        householdId: null,
        label: context.l10n.personalScope,
      ),
    ];

    for (final household in households) {
      final suffix = household.isPortfolio
          ? context.l10n.privateSpace
          : context.l10n.sharedSpace;
      options.add(
        _AccountOption(
          type: household.isPortfolio
              ? ActiveWalletType.portfolio
              : ActiveWalletType.household,
          householdId: household.id,
          label: '${household.name} · $suffix',
          isPortfolio: household.isPortfolio,
        ),
      );
    }

    return options;
  }

  _AccountOption _currentAccountOption() {
    return _AccountOption(
      type: _selectedAccountType,
      householdId: _selectedAccountHouseholdId,
      label: '',
      isPortfolio: _selectedAccountType == ActiveWalletType.portfolio,
    );
  }

  String _accountDisplayValue(
    BuildContext context,
    List<Household> households,
  ) {
    switch (_selectedAccountType) {
      case ActiveWalletType.personal:
        return context.l10n.personalScope;
      case ActiveWalletType.portfolio:
        final household =
            _findHousehold(households, _selectedAccountHouseholdId);
        return household?.name ?? context.l10n.privateSpace;
      case ActiveWalletType.household:
        final household =
            _findHousehold(households, _selectedAccountHouseholdId);
        return household?.name ?? context.l10n.tapToSet;
    }
  }

  Household? _findHousehold(List<Household> households, String? id) {
    if (id == null) return null;
    for (final household in households) {
      if (household.id == id) return household;
    }
    return null;
  }

  bool _isPortfolioHousehold(List<Household> households, String? householdId) {
    if (householdId == null) return false;
    for (final household in households) {
      if (household.id == householdId) {
        return household.isPortfolio;
      }
    }
    return false;
  }

  _AccountTarget _resolveAccountTarget() {
    final existingHouseholdId = widget.existingExpense?.householdId;
    final selectedSharingId = ref.read(selectedHouseholdForSharingProvider);
    final householdScope = ref.read(householdScopeProvider);

    switch (_selectedAccountType) {
      case ActiveWalletType.personal:
        return const _AccountTarget(householdId: null, isPortfolio: false);
      case ActiveWalletType.portfolio:
        final fallbackPortfolioId = _selectedAccountHouseholdId ??
            existingHouseholdId ??
            householdScope.activeAccountHouseholdId;
        if (fallbackPortfolioId == null ||
            !householdScope.isPortfolioId(fallbackPortfolioId)) {
          return const _AccountTarget(householdId: null, isPortfolio: false);
        }
        return _AccountTarget(
            householdId: fallbackPortfolioId, isPortfolio: true);
      case ActiveWalletType.household:
        final fallbackHouseholdId = _selectedAccountHouseholdId ??
            selectedSharingId ??
            existingHouseholdId;
        if (fallbackHouseholdId == null ||
            householdScope.isPortfolioId(fallbackHouseholdId)) {
          return const _AccountTarget(householdId: null, isPortfolio: false);
        }
        return _AccountTarget(
          householdId: fallbackHouseholdId,
          isPortfolio: false,
        );
    }
  }

  void _applyAccountSelection(_AccountOption option) {
    final isHouseholdSelection = option.type == ActiveWalletType.household;
    if (isHouseholdSelection &&
        (option.householdId == null || option.householdId!.isEmpty)) {
      return;
    }
    setState(() {
      _selectedAccountType = option.type;
      _selectedAccountHouseholdId = option.householdId;
      _isSharedWithHousehold = isHouseholdSelection;
      _selectedFinancialAccountId = null;
      _hasManuallySelectedFinancialAccount = false;
      if (!isHouseholdSelection) {
        _lastNonHouseholdAccountType = option.type;
        _lastNonHouseholdHouseholdId = option.householdId;
      }
    });

    if (isHouseholdSelection) {
      if (option.householdId != null) {
        ref.read(selectedHouseholdForSharingProvider.notifier).state =
            option.householdId;
        _loadMembers(option.householdId!);

        if (isExistingExpense &&
            widget.existingExpense?.householdId == option.householdId) {
          _resolveSplitGroupIdForExistingExpense(loadSplitConfig: true);
        } else {
          _clearSharingData();
        }
      }
    } else {
      ref.read(selectedHouseholdForSharingProvider.notifier).state = null;
      _clearSharingData();
    }
  }

  Future<void> _handleEditSpace({required List<Household> households}) async {
    final options = _accountOptions(context, households);
    if (options.length <= 1) return;
    final current = _currentAccountOption();
    final initial = options.contains(current) ? current : options.first;

    final selected = await showTransactionSelectionSheet<_AccountOption>(
      context: context,
      items: options,
      getLabel: (option) => option.label,
      initial: initial,
    );

    if (selected == null || selected == current) return;
    _applyAccountSelection(selected);
  }

  void _clearSharingData() {
    _customSplitType = null;
    _customSplits = null;
    _initialSplitSignature = null;
    _loadedSplitGroupType = null;
    _resolvedSplitGroupId = null;
    _hasCheckedSplitGroup = false;
    _householdMembers = null;
    _membersError = null;
    _isLoadingMembers = false;
  }

  String? _resolveDefaultHouseholdId(
    List<Household> householdList,
    SelectedHouseholdState selectedState,
  ) {
    final selectedId = selectedState.householdId ?? selectedState.household?.id;
    if (selectedId != null &&
        householdList.any((household) => household.id == selectedId)) {
      return selectedId;
    }
    return householdList.isNotEmpty ? householdList.first.id : null;
  }

  /// Handle adding a photo to existing expense
  Future<void> _handleAddPhoto() async {
    if (ref.read(previewModeProvider).isActive) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.info(
          context,
          context.l10n.previewMockReceiptNoted,
        );
      }
      return;
    }

    debugPrint('📷 Adding photo to existing expense...');

    try {
      final XFile? photo = await pickImageWithGuard(
        picker: _imagePicker,
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        debugPrint('📷 Photo captured');
        setState(() {
          _localImagePath = photo.path;
        });
      } else {
        debugPrint('📷 Photo capture cancelled');
      }
    } catch (e) {
      debugPrint('❌ Error capturing photo: $e');
      if (mounted) {
        AppToast.error(
          context,
          '${context.l10n.failedToCapturePhoto}: $e',
          duration: const Duration(seconds: 6),
        );
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

  Widget _buildSpacePlaceholder(ColorScheme colorScheme, String value) {
    return MonekoInput(
      child: Column(
        children: [
          MonekoDisclosureRow(
            label: context.l10n.space,
            value: value,
            onTap: () {},
            isFirst: true,
            isLast: true,
            isValuePlaceholder: true,
          ),
        ],
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
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final accountTarget = _resolveAccountTarget();
    final scopedAccountsAsync =
        ref.watch(walletsByHouseholdIdProvider(accountTarget.householdId));
    final scopedAccounts =
        scopedAccountsAsync.valueOrNull ?? const <WalletEntity>[];
    _syncSelectedFinancialAccountWithScope(scopedAccounts);

    // For new expenses, use pending expense provider
    final pendingExpense =
        isNewExpense ? ref.watch(pendingExpenseProvider) : null;

    final userCategoryLists = ref.watch(userCategoryListsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

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
    final displayBreakdown = isNewExpense
        ? (pendingExpense?.breakdown ?? widget.newExpense?.breakdown)
        : widget.existingExpense?.breakdown;
    final breakdownItems = (displayBreakdown ?? const <String>[])
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    // Income mode for display (for new or existing items)
    final isIncomeMode = isNewExpense
        ? (pendingExpense?.isIncome ?? widget.newExpense!.isIncome)
        : ((widget.existingExpense?.type?.toLowerCase() == 'income'));

    final accountAndSharingSection = householdsAsync.when(
      data: (householdsData) {
        final households = householdsData.cast<Household>();
        return Column(
          children: [
            _buildSpaceSection(
              colorScheme,
              households,
              scopedAccountsAsync,
              scopedAccounts,
            ),
            const SizedBox(height: 24),
            if (_selectedAccountType == ActiveWalletType.household &&
                households.isNotEmpty)
              _buildSharingSection(
                colorScheme,
                households,
                selectedHousehold,
                selectedHouseholdState,
                isIncomeMode,
              ),
            if (households.isNotEmpty) const SizedBox(height: 24),
          ],
        );
      },
      loading: () => Column(
        children: [
          _buildSpacePlaceholder(colorScheme, context.l10n.loading),
          const SizedBox(height: 24),
        ],
      ),
      error: (_, __) => Column(
        children: [
          _buildSpacePlaceholder(colorScheme, context.l10n.tapToSet),
          const SizedBox(height: 24),
        ],
      ),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Scaffold(
        // Wrap content in Scaffold to get background color filling the sheet
        backgroundColor: Colors.transparent,
        body: PopScope(
          canPop: !_isSaving && !_isDeleting,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Sheet Drag Handle
              const ModalSheetHandle(),

              // Header with Circle Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    IconButton(
                      onPressed: _isSaving || _isDeleting
                          ? null
                          : () => Navigator.pop(context),
                      icon:
                          Icon(Icons.close, color: colorScheme.mutedForeground),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.muted.withValues(alpha: 0.2),
                      ),
                    ),

                    // Title
                    Text(
                      isNewExpense
                          ? (isIncomeMode
                              ? context.l10n.income
                              : context.l10n.expense)
                          : context.l10n.details,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    // Check Button
                    IconButton(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(Icons.check, color: colorScheme.primary),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 24),
                  child: Column(
                    children: [
                      // Amount & Date Hero Section
                      GestureDetector(
                        onTap: () => _handleEditAmount(displayAmount),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Text(
                              '${isIncomeMode ? '+' : ''}$currencySymbol${formatLocalizedNumber(context, double.parse(displayAmount.toStringAsFixed(2)))}',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w600,
                                color: isIncomeMode
                                    ? colorScheme
                                        .primary // Use primary for positive/income typically, or custom Green if design system mandates
                                    : colorScheme.onSurface,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatRelativeDate(displayDate, context)} • ${_selectedTime.format(context)}',
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      accountAndSharingSection,

                      // Metadata Group (Apple-style List)
                      MonekoInput(
                        child: Column(
                          children: [
                            MonekoDisclosureRow(
                              label: context.l10n.category,
                              value: _getLocalizedCategory(displayCategory),
                              onTap: () => _handleEditCategory(
                                  displayCategory, userCategoryLists),
                              isFirst: true,
                            ),
                            _buildDivider(colorScheme),
                            MonekoDisclosureRow(
                              label: context.l10n.currency,
                              value: currency.toUpperCase(),
                              onTap: () => _handleEditCurrency(currency),
                            ),
                            _buildDivider(colorScheme),
                            MonekoDisclosureRow(
                              label: context.l10n.date,
                              value: DateFormat.yMMMMd(
                                intlSafeLocaleName(
                                    Localizations.localeOf(context)),
                              ).format(DateTime(
                                displayDate.year,
                                displayDate.month,
                                displayDate.day,
                              )),
                              onTap: () => _handleEditDate(displayDate),
                            ),
                            _buildDivider(colorScheme),
                            MonekoDisclosureRow(
                              label: context.l10n.time,
                              value: _selectedTime.format(context),
                              onTap: () => _handleEditTime(),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Notes Group
                      MonekoInput(
                        child: InkWell(
                          onTap: () =>
                              _handleEditDescription(displayDescription),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 70, // Fixed label width
                                  child: Text(
                                    context.l10n.notes,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayDescription?.isNotEmpty == true
                                        ? displayDescription!
                                        : context.l10n.addANote,
                                    textAlign: TextAlign.start,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          (displayDescription?.isEmpty ?? true)
                                              ? colorScheme.onSurface
                                                  .withValues(alpha: 0.3)
                                              : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (breakdownItems.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildBreakdownSection(
                          context: context,
                          colorScheme: colorScheme,
                          breakdown: breakdownItems,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Receipt Section
                      _buildReceiptSection(
                        colorScheme: colorScheme,
                        localImagePath:
                            isNewExpense ? effectiveImagePath : _localImagePath,
                        receiptImageUrl: isNewExpense ? null : receiptImageUrl,
                        onAddPhoto:
                            effectiveImagePath == null ? _handleAddPhoto : null,
                      ),

                      const SizedBox(height: 32),

                      // Actions
                      if (isExistingExpense)
                        DestructiveAdaptiveButton(
                          onPressed: _isDeleting ? null : _handleDelete,
                          isLoading: _isDeleting,
                          child: Text(isIncomeMode
                              ? context.l10n.deleteIncome
                              : context.l10n.deleteExpense),
                        ),

                      // Bottom spacer for scroll
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 0,
      color: colorScheme.onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _buildReceiptSection({
    required ColorScheme colorScheme,
    String? localImagePath,
    String? receiptImageUrl,
    VoidCallback? onAddPhoto,
  }) {
    final hasImage = localImagePath != null || receiptImageUrl != null;

    // If no image and no add capability, hide perfectly.
    if (!hasImage && onAddPhoto == null) return const SizedBox.shrink();

    return MonekoInput(
      padding: const EdgeInsets.all(4), // Little padding for the image inside
      child: hasImage
          ? GestureDetector(
              onTap: () =>
                  _showFullScreenImage(localImagePath, receiptImageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: localImagePath != null
                    ? Image.file(
                        File(localImagePath),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: receiptImageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 200,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
              ),
            )
          : InkWell(
              onTap: onAddPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.addReceiptPhoto,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBreakdownSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required List<String> breakdown,
  }) {
    return AdaptiveExpansionTile(
      iconColor: colorScheme.mutedForeground,
      collapsedIconColor: colorScheme.mutedForeground,
      initiallyExpanded: false,
      title: Text(
        context.l10n.breakdown,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      children: [
        for (final item in breakdown)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpaceSection(
    ColorScheme colorScheme,
    List<Household> households,
    AsyncValue<List<WalletEntity>> scopedAccountsAsync,
    List<WalletEntity> scopedAccounts,
  ) {
    final value = _accountDisplayValue(context, households);

    return MonekoInput(
      child: Column(
        children: [
          MonekoDisclosureRow(
            label: context.l10n.space,
            value: value,
            onTap: () => _handleEditSpace(households: households),
            isFirst: true,
          ),
          _buildDivider(colorScheme),
          MonekoDisclosureRow(
            label: context.l10n.wallet,
            value: scopedAccountsAsync.when(
              data: (_) => _selectedFinancialAccountLabel(
                context,
                scopedAccounts,
              ),
              loading: () => context.l10n.loading,
              error: (_, __) => context.l10n.tapToSet,
            ),
            onTap: () => _handleEditFinancialAccount(
              scopedAccounts,
            ),
            isValuePlaceholder: scopedAccounts.isEmpty,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String? _resolveDefaultFinancialAccountId(List<WalletEntity> accounts) {
    for (final account in accounts) {
      if (account.isDefault) return account.id;
    }
    return accounts.isNotEmpty ? accounts.first.id : null;
  }

  String _selectedFinancialAccountLabel(
    BuildContext context,
    List<WalletEntity> accounts,
  ) {
    if (accounts.isEmpty) return context.l10n.tapToSet;

    final selectedId = _selectedFinancialAccountId;
    if (selectedId != null) {
      for (final account in accounts) {
        if (account.id == selectedId) return account.name;
      }
    }

    final fallbackId = _resolveDefaultFinancialAccountId(accounts);
    if (fallbackId != null) {
      for (final account in accounts) {
        if (account.id == fallbackId) return account.name;
      }
    }

    return accounts.first.name;
  }

  Future<void> _handleEditFinancialAccount(List<WalletEntity> accounts) async {
    if (accounts.isEmpty) return;

    final initialId = _selectedFinancialAccountId ??
        _resolveDefaultFinancialAccountId(accounts);
    final initial = accounts.firstWhere(
      (account) => account.id == initialId,
      orElse: () => accounts.first,
    );

    final selected = await showTransactionSelectionSheet<WalletEntity>(
      context: context,
      items: accounts,
      getLabel: (account) => account.name,
      initial: initial,
    );

    if (selected == null || selected.id == _selectedFinancialAccountId) return;

    setState(() {
      _selectedFinancialAccountId = selected.id;
      _hasManuallySelectedFinancialAccount = true;
    });
  }

  void _syncSelectedFinancialAccountWithScope(List<WalletEntity> accounts) {
    final desiredId = () {
      if (accounts.isEmpty) return null;

      final currentId = _selectedFinancialAccountId;
      final currentExists = currentId != null &&
          accounts.any((account) => account.id == currentId);

      if (isExistingExpense) {
        if (currentExists) return currentId;

        final boundWalletId = widget.existingExpense?.walletId;
        if (boundWalletId != null &&
            accounts.any((account) => account.id == boundWalletId)) {
          return boundWalletId;
        }

        return _resolveDefaultFinancialAccountId(accounts);
      }

      if (_hasManuallySelectedFinancialAccount && currentExists) {
        return currentId;
      }

      return _resolveDefaultFinancialAccountId(accounts);
    }();

    if (desiredId == _selectedFinancialAccountId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedFinancialAccountId == desiredId) return;
      setState(() {
        _selectedFinancialAccountId = desiredId;
      });
    });
  }

  Widget _buildSharingSection(
    ColorScheme colorScheme,
    List<Household> households,
    String? selectedHousehold,
    SelectedHouseholdState selectedHouseholdState,
    bool isIncomeMode,
  ) {
    final householdList =
        households.where((h) => !h.isPortfolio).toList(growable: false);

    if (householdList.isEmpty) {
      if (_selectedAccountType == ActiveWalletType.household) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyAccountSelection(
            _AccountOption(
              type: _lastNonHouseholdAccountType,
              householdId: _lastNonHouseholdHouseholdId,
              label: '',
              isPortfolio:
                  _lastNonHouseholdAccountType == ActiveWalletType.portfolio,
            ),
          );
        });
      }
      return const SizedBox();
    }
    // Auto-select household only if no valid selection exists.
    final hasValidSelection = selectedHousehold != null &&
        householdList.any((h) => h.id == selectedHousehold);

    if (_isSharedWithHousehold &&
        householdList.isNotEmpty &&
        !hasValidSelection) {
      debugPrint(
          '🏠 [SHARE SECTION] No valid selected household found; using header selection');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentSelection = ref.read(selectedHouseholdForSharingProvider);
        final isCurrentValid = currentSelection != null &&
            currentSelection.isNotEmpty &&
            householdList.any((h) => h.id == currentSelection);
        if (isCurrentValid) return;
        final preferredId = _resolveDefaultHouseholdId(
              householdList,
              selectedHouseholdState,
            ) ??
            householdList.first.id;
        ref.read(selectedHouseholdForSharingProvider.notifier).state =
            preferredId;
        if (!_isPortfolioHousehold(households, preferredId)) {
          _loadMembers(preferredId);
        }
      });
    }

    return MonekoInput(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle switch for sharing
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.shareWithHousehold,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                AdaptiveSwitch(
                  value: _selectedAccountType == ActiveWalletType.household,
                  onChanged: (value) {
                    debugPrint(
                        '🔀 [SHARE TOGGLE] User toggled sharing to: $value');
                    if (!value) {
                      final fallbackType = _lastNonHouseholdAccountType ==
                              ActiveWalletType.household
                          ? ActiveWalletType.personal
                          : _lastNonHouseholdAccountType;
                      final fallbackId =
                          fallbackType == ActiveWalletType.personal
                              ? null
                              : _lastNonHouseholdHouseholdId;
                      _applyAccountSelection(
                        _AccountOption(
                          type: fallbackType,
                          householdId: fallbackId,
                          label: '',
                          isPortfolio:
                              fallbackType == ActiveWalletType.portfolio,
                        ),
                      );
                      return;
                    }

                    final preferredId = _selectedAccountHouseholdId ??
                        ref.read(selectedHouseholdForSharingProvider) ??
                        _resolveDefaultHouseholdId(
                          householdList,
                          selectedHouseholdState,
                        ) ??
                        householdList.first.id;

                    debugPrint(
                        '🔀 [SHARE TOGGLE] Selecting household: $preferredId');
                    _applyAccountSelection(
                      _AccountOption(
                        type: ActiveWalletType.household,
                        householdId: preferredId,
                        label: '',
                        isPortfolio: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Show household dropdown only when toggle is ON
          if (_selectedAccountType == ActiveWalletType.household &&
              householdList.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: hasValidSelection
                      ? selectedHousehold
                      : (_resolveDefaultHouseholdId(
                            householdList,
                            selectedHouseholdState,
                          ) ??
                          householdList.first.id),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down,
                      color: colorScheme.foreground),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                  items: householdList.map((h) {
                    return DropdownMenuItem<String>(
                      value: h.id,
                      child: Row(
                        children: [
                          // Cover photo
                          if (h.coverImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: h.coverImageUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
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
                    debugPrint(
                        '🔄 [HOUSEHOLD DROPDOWN] User changed household to: $value');
                    if (value != null) {
                      setState(() {
                        _selectedAccountHouseholdId = value;
                        _selectedFinancialAccountId = null;
                        _hasManuallySelectedFinancialAccount = false;
                      });
                      ref
                          .read(selectedHouseholdForSharingProvider.notifier)
                          .state = value;
                      // Reset custom splits when changing household
                      debugPrint(
                          '🔄 [HOUSEHOLD DROPDOWN] Resetting splits and members');
                      setState(() {
                        _customSplitType = null;
                        _customSplits = null;
                        _initialSplitSignature = null;
                        _loadedSplitGroupType = null;
                        _resolvedSplitGroupId = null;
                        _hasCheckedSplitGroup = false;
                        _householdMembers = null;
                        _membersError = null;
                        _isLoadingMembers = false;
                      });
                      final isPortfolioSelection =
                          _isPortfolioHousehold(households, value);
                      if (!isPortfolioSelection) {
                        debugPrint(
                            '🔄 [HOUSEHOLD DROPDOWN] Calling _loadMembers for: $value');
                        _loadMembers(value);
                      }

                      // If user navigated back to the original household while
                      // editing an existing shared expense, restore the split config.
                      if (isExistingExpense &&
                          widget.existingExpense?.householdId == value) {
                        _resolveSplitGroupIdForExistingExpense(
                            loadSplitConfig: true);
                      }
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
                final activeHouseholdId =
                    selectedHousehold ?? widget.existingExpense?.householdId;
                final isPortfolioSelection =
                    _isPortfolioHousehold(households, activeHouseholdId);
                final isSharedSpace =
                    _selectedAccountType == ActiveWalletType.household &&
                        activeHouseholdId != null &&
                        !isPortfolioSelection;

                if (!isSharedSpace) {
                  return const SizedBox();
                }

                if (isPortfolioSelection) {
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

                // Check if this is an existing expense with household but no split group
                final isExistingWithoutSplit = isExistingExpense &&
                    widget.existingExpense!.householdId != null &&
                    _hasCheckedSplitGroup &&
                    _effectiveSplitGroupId == null;

                // For income mode, we hide the custom split editor entirely
                if (isIncomeMode) {
                  return const SizedBox();
                }
                return GroupSplitEditorSection(
                  members: _householdMembers!,
                  selectedPayerUserId: _selectedPayerUserId,
                  onPayerChanged: (v) => setState(() {
                    _selectedPayerUserId = v;
                    debugPrint(
                        '👥 [UI] Who paid changed to: $_selectedPayerUserId');
                  }),
                  totalAmount: currentAmount,
                  currencySymbol: currencySymbol,
                  initialSplitType: _customSplitType,
                  initialSplits: _customSplits,
                  splitEditorKey: ValueKey(
                    'split_${_customSplitType}_${_customSplits?.length}',
                  ),
                  showNotYetSplitBanner: isExistingWithoutSplit,
                  notYetSplitMessage: context.l10n.notYetSplitBanner,
                  onSplitChanged: (splitType, splits) {
                    setState(() {
                      _customSplitType = splitType;
                      _customSplits = splits;
                    });
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleEditCurrency(String currentCurrency) async {
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

  // Edit handlers - update local state for both new and existing
  void _handleEditAmount(double currentAmount) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.editAmount,
      description: null,
      confirmLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: currentAmount.toStringAsFixed(2),
        placeholder: context.l10n.amount,
        isRequired: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validationPattern: RegExp(r'^[0-9]+(\.[0-9]{0,2})?$'),
        validationMessage: context.l10n.pleaseEnterValidAmount,
      ),
    );

    if (result != null && result.confirmed && result.text != null) {
      final parsed = double.tryParse(result.text!.replaceAll(',', ''));
      if (parsed == null || parsed <= 0) return;

      if (isNewExpense) {
        final current = ref.read(pendingExpenseProvider);
        if (current != null) {
          ref.read(pendingExpenseProvider.notifier).state =
              current.copyWith(amount: parsed);
        }
      } else {
        setState(() {
          _editedAmount = parsed;
        });
      }
    }
  }

  void _handleEditCategory(
      String currentCategory, UserCategoryLists? lists) async {
    final isIncomeMode = isNewExpense
        ? (ref.read(pendingExpenseProvider)?.isIncome ??
            widget.newExpense!.isIncome)
        : ((widget.existingExpense?.type?.toLowerCase() == 'income'));

    final baseCategories = isIncomeMode
        ? (lists?.incomeCategories ?? getIncomeCategories())
        : (lists?.expenseCategories ?? getExpenseCategories());
    final next = await showCategoryPicker(
      context: context,
      currentCategory: currentCategory,
      isIncome: isIncomeMode,
      allCategories: baseCategories,
      onCreateCategory: (name) => createUserCustomCategory(
        ref: ref,
        name: name,
        isIncome: isIncomeMode,
      ),
    );

    if (next == null) return;
    if (isNewExpense) {
      final current = ref.read(pendingExpenseProvider);
      if (current != null) {
        ref.read(pendingExpenseProvider.notifier).state =
            current.copyWith(category: next);
      }
      return;
    }

    setState(() {
      _editedCategory = next;
    });
  }

  void _handleEditDate(DateTime currentDate) async {
    DateTime? result;

    if (Platform.isIOS) {
      final colorScheme = Theme.of(context).colorScheme;
      // Use Cupertino date picker for iOS
      result = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (context) {
          DateTime tempDate = currentDate;
          return Container(
            height: 300,
            color: colorScheme.sheetBackground,
            child: Column(
              children: [
                // Header with Done button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.sheetBorder,
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
                    maximumDate: _effectiveNow,
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
        lastDate: _effectiveNow,
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
      final colorScheme = Theme.of(context).colorScheme;
      // Use Cupertino time picker for iOS
      final now = _effectiveNow;
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
            color: colorScheme.sheetBackground,
            child: Column(
              children: [
                // Header with Done button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.sheetBorder,
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
            color: colorScheme.sheetBackground,
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
                      color: colorScheme.sheetBorder,
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
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.sheetBackground,
        builder: (context) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground,
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
                  color: colorScheme.sheetBorder,
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
    debugPrint('👥 [LOAD MEMBERS] Starting member load');
    debugPrint(
        '👥 [LOAD MEMBERS] Existing payer selection present: ${_selectedPayerUserId != null}');

    setState(() {
      _isLoadingMembers = true;
      _membersError = null;
      _householdMembers = null;
    });

    debugPrint('👥 [LOAD MEMBERS] Set loading state, cleared members');

    try {
      final repository = ref.read(householdRepositoryProvider);
      debugPrint('👥 [LOAD MEMBERS] Fetching members from repository...');
      final members = await repository.getHouseholdMembers(householdId);
      debugPrint('👥 [LOAD MEMBERS] Fetched ${members.length} members');

      if (mounted) {
        // If AI provided a payer hint (e.g. "paid by Bob"), resolve it to a
        // concrete household member userId once members are available.
        if (isNewExpense) {
          final pending = ref.read(pendingExpenseProvider) ?? widget.newExpense;
          final hint = pending?.payerHint;
          if (hint != null && hint.trim().isNotEmpty) {
            final resolved = resolveHouseholdPayerUserIdFromHint(
              members: members,
              hint: hint,
            );

            if (resolved != null && resolved.isNotEmpty) {
              final current = _selectedPayerUserId;
              final currentIsValid =
                  current != null && members.any((m) => m.userId == current);
              final currentIsDefault = current == ref.read(authProvider).uid;
              if (!currentIsValid || currentIsDefault) {
                _selectedPayerUserId = resolved;
              }
            }
          }
        }

        // Validate that _selectedPayerUserId exists in members
        // This is critical for the "Who paid" dropdown to work correctly
        final currentPayerId = _selectedPayerUserId;
        final payerExists = members.any((m) => m.userId == currentPayerId);

        debugPrint('👥 [LOAD MEMBERS] Current payer selection present');
        debugPrint('👥 [LOAD MEMBERS] Payer exists in members: $payerExists');

        String? validPayerId = currentPayerId;

        if (!payerExists) {
          // Current payer not in household members
          // For ADD action: Default to first member
          // For EDIT action: This shouldn't happen, but fallback to first member
          if (members.isNotEmpty) {
            validPayerId = members.first.userId;
            debugPrint(
                '⚠️ [LOAD MEMBERS] Payer not found; defaulting to first member');
          } else {
            validPayerId = null;
            debugPrint(
                '⚠️ [LOAD MEMBERS] No members found! Cannot set default payer.');
          }
        } else {
          debugPrint('✅ [LOAD MEMBERS] Current payer is valid');
        }

        setState(() {
          _householdMembers = members;
          _selectedPayerUserId = validPayerId;
        });

        debugPrint(
            '✅ [LOAD MEMBERS] Successfully loaded and set ${members.length} members');
        debugPrint('✅ [LOAD MEMBERS] Final payer selection set');
      } else {
        debugPrint('⚠️ [LOAD MEMBERS] Widget unmounted, skipping state update');
      }
    } catch (error) {
      debugPrint('❌ [LOAD MEMBERS] Error loading members: $error');
      if (mounted) {
        setState(() {
          _membersError = '${context.l10n.errorLoadingMembers}: $error';
        });
        debugPrint('❌ [LOAD MEMBERS] Set error state: $_membersError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
        debugPrint(
            '👥 [LOAD MEMBERS] Finished loading (isLoadingMembers = false)');
      }
    }
  }

  Future<String?> _resolveSplitGroupIdForExistingExpense({
    bool loadSplitConfig = false,
  }) async {
    final expense = widget.existingExpense;
    if (expense == null) return null;

    final accountTarget = _resolveAccountTarget();
    final isSharedSpace =
        accountTarget.householdId != null && !accountTarget.isPortfolio;
    if (!isSharedSpace) {
      _markSplitCheck();
      return null;
    }

    final existingId = expense.splitGroupId?.trim();
    if (existingId != null && existingId.isNotEmpty) {
      _markSplitCheck(resolvedId: existingId);
      if (loadSplitConfig) {
        await _loadExistingSplitConfiguration(existingId);
      }
      return existingId;
    }

    final householdId = expense.householdId;
    if (householdId == null || householdId.isEmpty) {
      _markSplitCheck();
      return null;
    }

    // For recently created expenses, the split group may not be available yet
    // because _persistAiTransactions runs asynchronously. Retry a few times.
    final isRecentlyCreated =
        DateTime.now().toUtc().difference(expense.createdAt.toUtc()).inSeconds <
            15;
    final maxAttempts = isRecentlyCreated ? 5 : 1;

    try {
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        if (!mounted) return null;

        if (attempt > 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return null;
          ref.invalidate(householdSplitsProvider(
            HouseholdSplitsParams(householdId: householdId),
          ));
        }

        final splits = await ref.read(householdSplitsProvider(
          HouseholdSplitsParams(householdId: householdId),
        ).future);

        household_split.ExpenseSplitGroup? match;
        for (final group in splits) {
          if (group.expenseId == expense.id) {
            match = group;
            break;
          }
        }

        if (match != null) {
          debugPrint(
              '🔎 [RESOLVE SPLIT] Found split group ${match.id} for expense ${expense.id} (attempt $attempt)');
          _markSplitCheck(resolvedId: match.id);
          if (loadSplitConfig) {
            await _loadExistingSplitConfiguration(match.id);
          }
          return match.id;
        }

        if (attempt < maxAttempts) {
          debugPrint(
              '🔎 [RESOLVE SPLIT] No split group yet for expense ${expense.id}, retrying ($attempt/$maxAttempts)...');
        }
      }

      debugPrint(
          '🔎 [RESOLVE SPLIT] No split group found for expense ${expense.id} after $maxAttempts attempt(s)');
      _markSplitCheck();
      return null;
    } catch (error) {
      debugPrint('❌ [RESOLVE SPLIT] Failed to resolve split group: $error');
      return null;
    }
  }

  void _markSplitCheck({String? resolvedId}) {
    final sanitized = resolvedId?.trim();
    if (mounted) {
      setState(() {
        _hasCheckedSplitGroup = true;
        if (sanitized != null && sanitized.isNotEmpty) {
          _resolvedSplitGroupId = sanitized;
        }
      });
    } else {
      _hasCheckedSplitGroup = true;
      if (sanitized != null && sanitized.isNotEmpty) {
        _resolvedSplitGroupId = sanitized;
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

  SplitType _normalizeUiSplitTypeForEditor(SplitType type) {
    // The editor UI currently exposes Amount / Percent / Share. Represent Equal
    // splits as Amount so users see a selected chip and can edit amounts.
    return type == SplitType.equal ? SplitType.amount : type;
  }

  String _buildSplitSignature(SplitType type, List<MemberSplit> splits) {
    final effectiveType = _normalizeUiSplitTypeForEditor(type);
    final entries = splits.map((split) {
      final userId = split.member.userId;
      switch (effectiveType) {
        case SplitType.amount:
          final cents = ((split.amount ?? 0) * 100).round();
          return MapEntry(userId, cents.toString());
        case SplitType.percentage:
          final basisPoints =
              ((split.percentage ?? 0) * 100).round(); // 100.00% = 10000
          return MapEntry(userId, basisPoints.toString());
        case SplitType.shares:
          final shares = (split.shares ?? 0) > 0 ? split.shares : null;
          return MapEntry(userId, shares?.toString() ?? 'n');
        case SplitType.equal:
          // Normalized above, but keep a safe fallback.
          final cents = ((split.amount ?? 0) * 100).round();
          return MapEntry(userId, cents.toString());
      }
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return '${effectiveType.name}|${entries.map((e) => '${e.key}:${e.value}').join(',')}';
  }

  /// Load existing split configuration from database
  Future<void> _loadExistingSplitConfiguration(String splitGroupId) async {
    debugPrint('🔄 [LOAD SPLIT] Loading existing split configuration');

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

      if (mounted) {
        setState(() {
          _selectedPayerUserId = splitGroup.payerUserId;
        });
      }

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

      final dbSplitType = splitGroup.splitType.toString().split('.').last;
      final uiSplitType = _normalizeUiSplitTypeForEditor(
        _mapSplitType(splitGroup.splitType),
      );

      final splitLinesByUserId = <String, household_split.ExpenseSplitLine>{};
      for (final line in splitGroup.splitLines!) {
        splitLinesByUserId[line.userId] = line;
      }

      final totalGroupCents = splitGroup.totalAmountCents;

      // Convert split lines to MemberSplit objects. Be resilient to:
      // - members joining after the split was created (no line)
      // - legacy invalid shares values (0)
      final memberSplits = <MemberSplit>[];
      for (final member in _householdMembers!) {
        final splitLine = splitLinesByUserId[member.userId];
        final amountCents = splitLine?.amountCents ?? 0;

        double? percentage = splitLine?.percentage;
        if (dbSplitType == 'percentage' && percentage == null) {
          percentage = totalGroupCents > 0
              ? (amountCents * 100.0) / totalGroupCents
              : 0.0;
        }

        int? shares = splitLine?.shares;
        // Legacy/defensive: treat <= 0 as excluded.
        if ((shares ?? 0) <= 0) shares = null;
        // Defensive: if a shares split line has cents but no shares, show it as included.
        if (dbSplitType == 'shares' && shares == null && amountCents > 0) {
          shares = 1;
        }

        final bool included = switch (dbSplitType) {
          // Equal splits: treat existing lines as included; new members (missing line) default excluded.
          'equal' => splitLine != null,
          'amount' => amountCents > 0,
          'percentage' => (percentage ?? 0) > 0 || amountCents > 0,
          'shares' => (shares ?? 0) > 0 || amountCents > 0,
          _ => amountCents > 0,
        };

        memberSplits.add(
          MemberSplit(
            member: member,
            amount: amountCents / 100.0,
            percentage: percentage,
            shares: shares,
            // Persist inclusion across type switches in the editor.
            includedInAmount: included,
            includedInPercentage: included,
          ),
        );

        debugPrint('🔄 [LOAD SPLIT] Split line mapped for member');
      }

      if (!mounted) return;

      final signature = _buildSplitSignature(uiSplitType, memberSplits);
      debugPrint(
        '✅ [LOAD SPLIT] Applying split state: type=$uiSplitType count=${memberSplits.length}',
      );
      debugPrint(
        '✅ [LOAD SPLIT] Existing split state present: ${_customSplits != null}',
      );
      setState(() {
        _customSplitType = uiSplitType;
        _customSplits = memberSplits;
        _initialSplitSignature ??= signature;
        _loadedSplitGroupType ??= dbSplitType;
      });

      debugPrint(
        '✅ [LOAD SPLIT] Initialized split editor with existing configuration',
      );
      debugPrint(
        '✅ [LOAD SPLIT] Split state updated',
      );
    } catch (error) {
      debugPrint('❌ [LOAD SPLIT] Error loading split configuration: $error');
    }
  }

  void _refreshHouseholdUiAfterExpenseChange(String householdId) {
    debugPrint('🔄 [REFRESH] Starting household UI refresh');

    // CRITICAL: Invalidate RequestDeduplicator cache FIRST
    // This ensures fresh data is fetched, not the 30-second cached data
    debugPrint('🗑️ [REFRESH] Invalidating RequestDeduplicator cache...');
    ref.read(cacheInvalidatorProvider).invalidateHouseholdData(householdId);

    debugPrint(
        '🗑️ [REFRESH] Invalidating ALL provider families (this catches all parameter combinations)...');
    // CRITICAL: Invalidate the ENTIRE provider families, not just specific params
    // This ensures ALL widgets watching these providers refresh, regardless of their parameters
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(cachedHouseholdExpensesProvider);
    ref.invalidate(householdSplitsProvider);
    ref.invalidate(cachedHouseholdSplitsProvider);
    ref.invalidate(householdBudgetsProvider);
    ref.invalidate(householdMembersProvider);

    debugPrint('🗑️ [REFRESH] Invalidating pockets provider...');
    ref.invalidate(pocketsProvider);
    ref.invalidate(pocketDetailsProvider);
    ref.read(walletActionsProvider).refreshAccountData();

    // Keep currency selector counts up-to-date.
    ref.invalidate(currencyTransactionCountsProvider);

    debugPrint(
        '✅ [REFRESH] Household UI refresh complete - all provider families invalidated');
  }

  void _refreshPersonalUiAfterExpenseChange(String userId) {
    debugPrint('👤 [REFRESH] Refreshing personal UI after expense change');
    ref.read(analyticsProvider.notifier).refresh(userId);

    // CRITICAL: Invalidate ALL pocket providers, not just personal scope
    // This ensures all months and all scopes refresh with new data
    debugPrint('🗑️ [REFRESH] Invalidating ALL pockets provider families...');
    ref.invalidate(pocketsProvider);
    ref.invalidate(pocketDetailsProvider);
    ref.read(walletActionsProvider).refreshAccountData();

    // Keep currency selector counts up-to-date.
    ref.invalidate(currencyTransactionCountsProvider);

    debugPrint('✅ [REFRESH] Personal UI refresh complete');
  }

  Future<void> _handleSave() async {
    if (ref.read(previewModeProvider).isActive) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.success(
          context,
          widget.existingExpense != null
              ? context.l10n.previewMockUpdatesApplied
              : context.l10n.previewMockExpenseCreated,
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    var dialogOpen = false;
    showBlockingProcessingDialog(
      context: toastContext,
      message: context.l10n.saving,
    );
    dialogOpen = true;

    void closeDialog() {
      if (!dialogOpen) return;
      if (rootNavigator.canPop()) rootNavigator.pop();
      dialogOpen = false;
    }

    try {
      final user = ref.read(authProvider);
      final viewMode = ref.read(viewModeProvider);
      final householdScope = ref.read(householdScopeProvider);
      final accountTarget = _resolveAccountTarget();
      final preferredTimezone =
          ref.read(analyticsProvider).contact?.preferredTimezone;
      final availableAccounts = ref
              .read(walletsByHouseholdIdProvider(accountTarget.householdId))
              .valueOrNull ??
          const <WalletEntity>[];
      var selectedFinancialAccountId =
          _selectedFinancialAccountId ?? widget.existingExpense?.walletId;
      final hasSelectedFinancialAccount = selectedFinancialAccountId != null &&
          availableAccounts.any(
            (account) => account.id == selectedFinancialAccountId,
          );
      if (!hasSelectedFinancialAccount) {
        selectedFinancialAccountId =
            _resolveDefaultFinancialAccountId(availableAccounts);
      }

      if (isNewExpense) {
        // NEW TRANSACTION (expense or income)
        final expense = ref.read(pendingExpenseProvider);

        final effectiveHouseholdId = accountTarget.householdId;
        final isEffectivePortfolio = accountTarget.isPortfolio;
        final isSharedHousehold =
            _selectedAccountType == ActiveWalletType.household &&
                effectiveHouseholdId != null;
        if (isEffectivePortfolio) {
          _selectedPayerUserId = ref.read(authProvider).uid;
          _customSplitType = null;
          _customSplits = null;
        }

        if (expense == null) {
          throw Exception(context.l10n.noTransactionToSave);
        }

        if (expense.amount <= 0) {
          closeDialog();
          AppToast.error(
            toastContext,
            context.l10n.pleaseEnterAValidAmountGreaterThan0,
          );
          return;
        }

        // Combine extracted date (calendar day) with the selected time in local timezone.
        final expenseLocalDate = DateTime(
          expense.date.year,
          expense.date.month,
          expense.date.day,
        );
        final expenseDateTime = DateTime(
          expenseLocalDate.year,
          expenseLocalDate.month,
          expenseLocalDate.day,
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
                householdId: effectiveHouseholdId,
                accountId: selectedFinancialAccountId,
              );

          if (saved == null) {
            final incomeState = ref.read(incomeSaveProvider);
            final error = incomeState.whenOrNull(error: (e, _) => e);
            if (!mounted) {
              closeDialog();
              return;
            }
            closeDialog();
            AppToast.error(
              toastContext,
              context.l10n.failedToSave(
                error?.toString() ?? context.l10n.income,
              ),
              duration: const Duration(seconds: 5),
            );
            return;
          }

          // Reset state after successful save
          ref.read(pendingExpenseProvider.notifier).state = null;
          ref.read(selectedHouseholdForSharingProvider.notifier).state = null;
          // Upload receipt image if available
          // Priority: 1) expense.localImagePath (from ParsedExpense), 2) widget.localImagePath (fallback)
          final imagePathToUpload =
              expense.localImagePath ?? widget.localImagePath;

          if (imagePathToUpload != null) {
            debugPrint(' Uploading receipt image');
            await ref
                .read(expenseSaveNotifierProvider.notifier)
                .uploadReceiptImage(File(imagePathToUpload), user.uid);
            debugPrint(' Receipt upload completed');
          } else {
            debugPrint(' No local image path to upload');
          }

          //
          debugPrint(' Triggering comprehensive UI refresh...');

          // Refresh the household where income was saved (if shared)
          if (effectiveHouseholdId != null) {
            debugPrint(' Refreshing saved household UI');
            _refreshHouseholdUiAfterExpenseChange(effectiveHouseholdId);
          }

          // ALSO refresh the current view
          final currentScope = ref.read(householdScopeProvider);
          final currentHouseholdId = currentScope.selectedHouseholdId;

          if (currentScope.isHouseholdView && currentHouseholdId != null) {
            debugPrint(' Also refreshing CURRENT household view');
            if (currentHouseholdId != effectiveHouseholdId) {
              _refreshHouseholdUiAfterExpenseChange(currentHouseholdId);
            }
          } else {
            debugPrint(' Also refreshing CURRENT personal view');
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          if (!mounted) {
            closeDialog();
            return;
          }

          closeDialog();
          Navigator.of(context).pop(true);
          AppToast.success(
            toastContext,
            isSharedHousehold
                ? context.l10n.incomeSavedAndShared
                : context.l10n.incomeSaved,
            duration: const Duration(seconds: 3),
          );
        } else {
          // Save EXPENSE
          // Create updated expense with time
          final expenseWithTime = expense.copyWith(date: expenseDateTime);

          // Upload receipt image if available
          String? receiptUrl;
          if (widget.localImagePath != null) {
            receiptUrl = await ref
                .read(expenseSaveNotifierProvider.notifier)
                .uploadReceiptImage(File(widget.localImagePath!), user.uid);
          }

          //
          // When _isSharedWithHousehold is false, we must pass null for householdId
          // This ensures the expense is saved as PERSONAL (household_id = null in DB)
          // which makes it appear in the personal page, not the household page.
          //
          // Before fix: Always passed selectedHousehold (even when toggle OFF)
          // After fix: Only pass selectedHousehold when _isSharedWithHousehold is true
          //
          // Save expense with time and custom splits (if configured)
          debugPrint(' Saving expense with current view mode');
          await ref.read(expenseSaveNotifierProvider.notifier).saveExpense(
                expense: expenseWithTime,
                householdId: effectiveHouseholdId,
                accountId: selectedFinancialAccountId,
                receiptImageUrl: receiptUrl,
                customSplitType: _customSplitType,
                customSplits: _customSplits,
                payerUserId: (isSharedHousehold && !isEffectivePortfolio)
                    ? _selectedPayerUserId
                    : null,
              );

          debugPrint(' Expense saved successfully');
          if (!mounted) {
            closeDialog();
            return;
          }
          closeDialog();
          AppToast.success(
            toastContext,
            context.l10n.expenseSaved,
            duration: const Duration(seconds: 5),
          );

          //
          // The user might be viewing household mode while adding a personal expense,
          // or vice versa. We need to refresh:
          // 1. The household where expense was saved (if shared)
          // 2. The current view mode (personal or household)
          // This ensures ALL affected UIs update correctly.
          //

          debugPrint(' Triggering comprehensive UI refresh...');
          debugPrint('    Expense shared: $_isSharedWithHousehold');
          debugPrint('    Household selected: ${effectiveHouseholdId != null}');
          debugPrint('    Current view mode: ${viewMode.mode}');
          debugPrint(
              '    Payer selection present: ${_selectedPayerUserId != null}');
          debugPrint('    Custom split type: $_customSplitType');
          debugPrint(
              '    Custom splits count: ${_customSplits?.length ?? 0} (null means default equal)');

          // Step 1: Refresh the household where expense was saved (if shared)
          if (effectiveHouseholdId != null) {
            debugPrint(' Refreshing saved household UI');
            _refreshHouseholdUiAfterExpenseChange(effectiveHouseholdId);
          }

          // Step 2: ALSO refresh the current view (household or personal)
          // This is critical because user might be viewing a different mode
          final currentScope = ref.read(householdScopeProvider);
          final currentHouseholdId = currentScope.selectedHouseholdId;

          if (currentScope.isHouseholdView && currentHouseholdId != null) {
            // Currently viewing household mode - refresh it
            debugPrint(' Also refreshing CURRENT household view');
            if (currentHouseholdId != effectiveHouseholdId) {
              // Different household than where we saved - need to refresh it too
              _refreshHouseholdUiAfterExpenseChange(currentHouseholdId);
            }
          } else {
            // Currently viewing personal mode - refresh it
            debugPrint(' Also refreshing CURRENT personal view');
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          debugPrint(' All UI refresh triggers completed');
          debugPrint(' Closing transaction sheet');
          if (!mounted) {
            closeDialog();
            return;
          }
          closeDialog();
          Navigator.of(context).pop(true);
        }
      } else {
        // EXISTING EXPENSE: Build updates map from local edits
        await _resolveSplitGroupIdForExistingExpense();
        final Map<String, dynamic> updates = {};
        final accountTarget = _resolveAccountTarget();
        final targetHouseholdId = accountTarget.householdId;
        final targetIsPortfolio = accountTarget.isPortfolio;
        final isSharedSpace = targetHouseholdId != null && !targetIsPortfolio;
        final originalHouseholdId = widget.existingExpense!.householdId;
        final originalIsPortfolio = originalHouseholdId != null &&
            householdScope.isPortfolioId(originalHouseholdId);

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
          final trimmedDescription = _editedDescription!.trim();
          updates['raw_text'] =
              trimmedDescription.isEmpty ? null : trimmedDescription;
        }

        updates['account_id'] = selectedFinancialAccountId;

        // Handle date and time updates separately
        final finalDate = _editedDate ?? widget.existingExpense!.date;
        final finalLocalDate = DateTime(
          finalDate.year,
          finalDate.month,
          finalDate.day,
        );
        final finalDateOnly = DateTime(
          finalLocalDate.year,
          finalLocalDate.month,
          finalLocalDate.day,
        );
        final expenseDateTime = DateTime(
          finalDateOnly.year,
          finalDateOnly.month,
          finalDateOnly.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        // Backend expects date in YYYY-MM-DD format (local date)
        updates['date'] = DateFormat('yyyy-MM-dd').format(finalDateOnly);

        // Persist created_at as the UTC instant represented by the selected
        // device-local date/time.
        final createdAtUtc = utcInstantFromEffectiveLocalDateTime(
          localDateTimeWall: expenseDateTime,
          preferredTimezone: preferredTimezone,
        );
        updates['created_at'] = createdAtUtc.toUtc().toIso8601String();

        // For existing household expenses without a split group, we may need to
        // create the first split group using the inline CustomSplitEditor.
        // For expenses that already have a split group, we may instead send an
        // update payload to adjust the existing split configuration.
        final existingSplitGroupId = _effectiveSplitGroupId;
        final sameSharedHousehold = isSharedSpace &&
            originalHouseholdId != null &&
            targetHouseholdId == originalHouseholdId &&
            !originalIsPortfolio;
        // Persist payer changes for shared expenses even without split edits
        if (isSharedSpace) {
          final payer = _selectedPayerUserId ?? ref.read(authProvider).uid;
          updates['payer_user_id'] = payer;
          updates['payerUserId'] = payer; // compatibility with edge fn
        }

        final canCreateSplitGroupForTarget = !sameSharedHousehold ||
            (existingSplitGroupId == null && _hasCheckedSplitGroup);
        final shouldCreateSplitGroupForExisting = isSharedSpace &&
            canCreateSplitGroupForTarget &&
            _customSplitType != null &&
            _customSplits != null &&
            _customSplits!.isNotEmpty;

        final hasExistingSplitGroup =
            sameSharedHousehold && existingSplitGroupId != null;

        final householdChanged = originalHouseholdId != targetHouseholdId;
        final portfolioChanged = targetHouseholdId != null &&
            targetIsPortfolio != originalIsPortfolio;
        if (householdChanged || portfolioChanged) {
          updates['household_id'] = targetHouseholdId;
        }

        // Handle receipt image upload for existing expenses
        if (_localImagePath != null) {
          debugPrint(' Uploading new receipt image for existing expense');
          final receiptUrl = await ref
              .read(expenseSaveNotifierProvider.notifier)
              .uploadReceiptImage(File(_localImagePath!), user.uid);
          debugPrint(' New receipt upload completed');

          if (receiptUrl != null) {
            updates['receipt_image_url'] = receiptUrl;
          }
        }

        // Build optional extra body for split creation or update
        Map<String, dynamic>? extraBody;
        if (targetIsPortfolio && targetHouseholdId != null) {
          extraBody = {'isPortfolio': true};
        }
        if (shouldCreateSplitGroupForExisting) {
          final splitTypeStr = _customSplitType!.toString().split('.').last;
          extraBody = {
            'householdId': targetHouseholdId,
            'isPortfolio': targetIsPortfolio,
            'customSplits': {
              'splitType': splitTypeStr,
              'memberSplits': _customSplits!.map((split) {
                final memberUserId = split.member.userId;
                final member = <String, dynamic>{
                  'userId': memberUserId,
                };
                switch (_customSplitType!) {
                  case SplitType.amount:
                    member['amount'] = split.amount;
                    break;
                  case SplitType.percentage:
                    member['percentage'] = split.percentage;
                    break;
                  case SplitType.shares:
                    member['shares'] = split.shares;
                    break;
                  case SplitType.equal:
                    break;
                }
                return member;
              }).toList(),
            },
            'payerUserId': _selectedPayerUserId ?? ref.read(authProvider).uid,
          };
        } else if (hasExistingSplitGroup) {
          final amountCentsChanged = updates.containsKey('amount_cents');

          final hasLoadedSplitConfig = _initialSplitSignature != null;
          final hasCurrentSplitConfig = _customSplitType != null &&
              _customSplits != null &&
              _customSplits!.isNotEmpty;

          final currentSignature = hasCurrentSplitConfig
              ? _buildSplitSignature(_customSplitType!, _customSplits!)
              : null;
          final splitChanged = hasLoadedSplitConfig &&
              currentSignature != null &&
              currentSignature != _initialSplitSignature;

          final shouldSendSplitUpdate = hasLoadedSplitConfig &&
              hasCurrentSplitConfig &&
              (amountCentsChanged || splitChanged);

          // If the amount changed we must update split lines to stay consistent.
          // If we can't load the split config, fail fast instead of corrupting state.
          if (amountCentsChanged && !shouldSendSplitUpdate) {
            if (!mounted) {
              closeDialog();
              return;
            }
            closeDialog();
            AppToast.error(
              toastContext,
              context.l10n.errorLoadingSplits,
              duration: const Duration(seconds: 5),
            );
            return;
          }

          if (shouldSendSplitUpdate) {
            final currentType = _customSplitType!;
            final preserveEqualSplitType = _loadedSplitGroupType == 'equal' &&
                currentType == SplitType.amount &&
                amountCentsChanged &&
                !splitChanged;

            final splitTypeStr = preserveEqualSplitType
                ? 'equal'
                : currentType.toString().split('.').last;
            extraBody = {
              'splitUpdate': {
                'splitType': splitTypeStr,
                'memberSplits': preserveEqualSplitType
                    ? _customSplits!
                        .map((split) => {'userId': split.member.userId})
                        .toList()
                    : _customSplits!.map((split) {
                        final memberUserId = split.member.userId;
                        final member = <String, dynamic>{
                          'userId': memberUserId,
                        };
                        switch (currentType) {
                          case SplitType.amount:
                            member['amount'] = split.amount;
                            break;
                          case SplitType.percentage:
                            member['percentage'] = split.percentage;
                            break;
                          case SplitType.shares:
                            member['shares'] = split.shares;
                            break;
                          case SplitType.equal:
                            break;
                        }
                        return member;
                      }).toList(),
              },
            };
          }
        }

        // Only update if there are actual changes or we need to create a split
        final originalDate = widget.existingExpense!.date;
        final originalLocalDate = DateTime(
          originalDate.year,
          originalDate.month,
          originalDate.day,
        );
        final originalCreatedAtLocal =
            _toDeviceWallTime(widget.existingExpense!.createdAt);
        final originalTime = TimeOfDay(
          hour: originalCreatedAtLocal.hour,
          minute: originalCreatedAtLocal.minute,
        );
        final hasDateEdit = _editedDate != null ||
            originalLocalDate.year != finalDateOnly.year ||
            originalLocalDate.month != finalDateOnly.month ||
            originalLocalDate.day != finalDateOnly.day ||
            originalTime.hour != _selectedTime.hour ||
            originalTime.minute != _selectedTime.minute;

        if (!hasDateEdit) {
          updates.remove('date');
          updates.remove('created_at');
        }

        if (updates.isEmpty && extraBody == null) {
          if (!mounted) {
            closeDialog();
            return;
          }
          closeDialog();
          Navigator.of(context).pop();
          return;
        }

        final originalCategoryForRemap =
            _normalizeCategoryRemapKey(widget.existingExpense!.category);
        final String? nextCategoryForRemap = updates.containsKey('category')
            ? _normalizeCategoryRemapKey(updates['category']?.toString())
            : null;
        final shouldPromptCategoryRemap = updates.containsKey('category') &&
            nextCategoryForRemap != null &&
            nextCategoryForRemap.trim().isNotEmpty &&
            nextCategoryForRemap != originalCategoryForRemap &&
            originalCategoryForRemap != 'other' &&
            originalCategoryForRemap != 'uncategorized';

        debugPrint(
            ' Updating expense with changed fields=${updates.keys.toList()} hasExtraBody=${extraBody != null}');

        // Call update API (this already handles provider refresh internally)
        final success =
            await ref.read(transactionEditProvider.notifier).updateExpense(
                  widget.existingExpense!.id,
                  updates,
                  extraBody: extraBody,
                );
        debugPrint(
          '🧪 updateExpense result: success=$success updates=${updates.keys.toList()}',
        );

        if (!mounted) {
          closeDialog();
          return;
        }

        if (success) {
          //
          debugPrint(' Triggering comprehensive UI refresh...');

          final editedHouseholdId = targetHouseholdId;

          // Refresh the scope where the expense now exists.
          if (editedHouseholdId != null) {
            debugPrint(' Refreshing expense household UI');
            _refreshHouseholdUiAfterExpenseChange(editedHouseholdId);
          } else {
            debugPrint(' Refreshing expense personal UI');
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          // ALSO refresh the current view
          final currentScope = ref.read(householdScopeProvider);
          final currentHouseholdId = currentScope.selectedHouseholdId;

          if (currentScope.isHouseholdView && currentHouseholdId != null) {
            debugPrint(' Also refreshing CURRENT household view');
            if (currentHouseholdId != editedHouseholdId) {
              _refreshHouseholdUiAfterExpenseChange(currentHouseholdId);
            }
          } else {
            debugPrint(' Also refreshing CURRENT personal view');
            _refreshPersonalUiAfterExpenseChange(user.uid);
          }

          if (originalHouseholdId != editedHouseholdId) {
            if (originalHouseholdId != null &&
                originalHouseholdId != currentHouseholdId &&
                originalHouseholdId != editedHouseholdId) {
              debugPrint(' Refreshing PREVIOUS household view');
              _refreshHouseholdUiAfterExpenseChange(originalHouseholdId);
            } else if (originalHouseholdId == null &&
                currentScope.isHouseholdView &&
                editedHouseholdId != null) {
              debugPrint(' Refreshing PREVIOUS personal view');
              _refreshPersonalUiAfterExpenseChange(user.uid);
            }
          }

          // Close the sheet so when user reopens it, they see fresh data
          closeDialog();

          final remapToCategory = nextCategoryForRemap;
          if (shouldPromptCategoryRemap && remapToCategory != null) {
            await _handleCategoryRemapPrompt(
              toastContext: toastContext,
              userId: user.uid,
              transactionType:
                  (widget.existingExpense?.type?.toLowerCase() == 'income')
                      ? 'income'
                      : 'expense',
              fromCategory: originalCategoryForRemap,
              toCategory: remapToCategory,
            );
            if (!mounted) return;
            Navigator.of(context).pop(true);
            return;
          }

          Navigator.of(context).pop(true);

          AppToast.success(
            toastContext,
            context.l10n.expenseUpdatedSuccessfully,
            duration: const Duration(seconds: 4),
          );
        } else {
          // Surface the raw error from the edit provider (which contains the
          // backend/FunctionException message) instead of a generic exception.
          final editState = ref.read(transactionEditProvider);
          debugPrint(
            '🧪 updateExpense failure state: error=${editState.error}',
          );
          final message = ErrorHandler.getUserFriendlyMessage(
            editState.error ?? context.l10n.failedToUpdateExpense,
            context: BackendErrorContext.updateExpense,
          );

          closeDialog();
          AppToast.error(
            toastContext,
            message,
            duration: const Duration(seconds: 5),
          );
          return;
        }
      }
    } catch (error) {
      debugPrint(' Error saving expense: $error');
      if (!mounted) {
        closeDialog();
        return;
      }

      closeDialog();
      AppToast.error(
        toastContext,
        ErrorHandler.getUserFriendlyMessage(
          error,
          context: BackendErrorContext.updateExpense,
        ),
        duration: const Duration(seconds: 5),
      );
    } finally {
      closeDialog();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleCategoryRemapPrompt({
    required BuildContext toastContext,
    required String userId,
    required String transactionType,
    required String fromCategory,
    required String toCategory,
  }) async {
    final fromLabel = getCategoryTranslation(toastContext, fromCategory);
    final toLabel = getCategoryTranslation(toastContext, toCategory);

    final result = await MonekoAlertDialog.show(
      context: toastContext,
      title: toastContext.l10n.updateCategoryPreferenceTitle,
      description: toastContext.l10n.updateCategoryPreferenceDescription(
        toLabel,
        fromLabel,
      ),
      confirmLabel: toastContext.l10n.yes,
      cancelLabel: toastContext.l10n.no,
      barrierDismissible: true,
    );

    if (!toastContext.mounted) return;

    if (result?.confirmed == true) {
      final saved = await saveUserCategoryRemapPreferenceForUser(
        userId: userId,
        fromCategory: fromCategory,
        toCategory: toCategory,
        transactionType: transactionType,
      );

      if (saved) {
        AppToast.success(
          toastContext,
          toastContext.l10n.preferenceUpdatedSuccessfully,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      AppToast.success(
        toastContext,
        toastContext.l10n.expenseUpdatedSuccessfully,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    AppToast.success(
      toastContext,
      toastContext.l10n.expenseUpdatedSuccessfully,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _handleDelete() async {
    if (ref.read(previewModeProvider).isActive) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.info(
          context,
          context.l10n.previewDeletionSkipped,
        );
      }
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    final confirmedResult = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.deleteExpense,
      description: context.l10n.confirmDeleteExpense,
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
    );

    if (confirmedResult?.confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final user = ref.read(authProvider);

      debugPrint(' Deleting expense');

      // Capture l10n before async call
      final failedToDeleteExpenseMsg = context.l10n.failedToDeleteExpense;

      // Call delete API
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': user.uid,
          'expenseIds': widget.existingExpense!.id,
        },
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? failedToDeleteExpenseMsg);
      }

      debugPrint(' Expense deleted successfully');

      // Refresh analytics data (personal expenses)
      await ref.read(analyticsProvider.notifier).loadData(user.uid);

      // CRITICAL: Always invalidate ALL pocket providers (all scopes, all months)
      // This ensures pockets page refreshes regardless of personal/household mode
      debugPrint(' Invalidating ALL pockets provider families...');
      ref.invalidate(pocketsProvider);
      ref.invalidate(pocketDetailsProvider);
      ref.read(walletActionsProvider).refreshAccountData();
      ref.invalidate(currencyTransactionCountsProvider);

      // If this was a household expense, invalidate household providers
      final householdId = widget.existingExpense!.householdId;
      if (householdId != null) {
        debugPrint(' Invalidating household providers for selected household');

        // Clear cached data first
        ref.read(cacheInvalidatorProvider).invalidateHouseholdData(householdId);

        // Invalidate household list to update counts
        ref.invalidate(userHouseholdsProvider(user.uid));

        // Invalidate ALL provider families so all parameterized instances refresh
        ref.invalidate(householdExpensesProvider);
        ref.invalidate(cachedHouseholdExpensesProvider);
        ref.invalidate(householdSplitsProvider);
        ref.invalidate(cachedHouseholdSplitsProvider);
        ref.invalidate(householdBudgetsProvider);
        ref.invalidate(householdMembersProvider);

        debugPrint(' Invalidated household providers');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }

      AppToast.success(
        toastContext,
        context.l10n.expenseDeletedSuccessfully,
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      debugPrint(' Error deleting expense: $error');
      AppToast.error(
        toastContext,
        ErrorHandler.getUserFriendlyMessage(
          error,
          context: BackendErrorContext.deleteExpense,
        ),
        duration: const Duration(seconds: 5),
      );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.appBackground,
        iconTheme: IconThemeData(color: colorScheme.foreground),
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
                  ? CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.foreground,
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 64,
                                color: colorScheme.mutedForeground,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.failedToLoadImage,
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
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

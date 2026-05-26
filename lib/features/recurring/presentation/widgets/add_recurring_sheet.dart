import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/shared/widgets/moneko_list_picker.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/destructive_text_button.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    hide SplitType;
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/recurring/presentation/utils/reminder_before_affixes.dart';

// Prevent accidental PII/financial logging.
// Enable explicitly with: --dart-define=MONEKO_DEBUG_LOGS=true
const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

String _normalizeCategoryRemapKey(String? category) {
  final raw = (category ?? '').trim().toLowerCase();
  if (raw.isEmpty) return '';
  if (categoryColors.containsKey(raw)) return raw;
  if (!raw.contains(' ')) return normalizeCategory(raw);
  return raw;
}

class _RecurringAccountOption {
  final ActiveWalletType type;
  final String? householdId;
  final String label;
  final bool isPortfolio;

  const _RecurringAccountOption({
    required this.type,
    required this.label,
    this.householdId,
    this.isPortfolio = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _RecurringAccountOption) return false;
    return type == other.type && householdId == other.householdId;
  }

  @override
  int get hashCode => Object.hash(type, householdId);
}

class AddRecurringSheet extends HookConsumerWidget {
  final String type; // 'expense' or 'income'
  final RecurringTransaction? existingTransaction; // For editing

  const AddRecurringSheet({
    super.key,
    required this.type,
    this.existingTransaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedType =
        useState<String>(type == 'income' ? 'income' : 'expense');
    final isExpense = selectedType.value == 'expense';
    final isEditing = existingTransaction != null;
    // Ensure custom category style overrides are loaded for display widgets.
    ref.watch(userCategoryConfigProvider);

    final txn = existingTransaction;
    final amountText = txn != null
        ? (txn.amount == txn.amount.toInt()
            ? txn.amount.toInt().toString()
            : txn.amount.toString())
        : '';
    final amountController = useTextEditingController(text: amountText);
    final descriptionController = useTextEditingController(
      text: existingTransaction?.description ?? '',
    );
    final merchantController = useTextEditingController(
      text: existingTransaction?.merchant ?? '',
    );

    // Rebuild when amount changes so splits can use the latest value
    useListenable(amountController);
    useListenable(descriptionController);
    useListenable(merchantController);
    final currentAmountText = amountController.text;

    final selectedCategory = useState<String?>(existingTransaction?.category);
    final selectedFrequency = useState<String>(
      existingTransaction?.recurrenceRule?.frequency ?? 'monthly',
    );

    // Default currency:
    // - Edit: use the existing transaction's currency
    // - Add: use the current home header selected currency (fallback to USD)
    final homeFilterState = ref.read(homeFilterProvider);
    final defaultCurrencyForNew =
        homeFilterState.selectedCurrency?.toUpperCase() ?? 'USD';
    final selectedCurrency = useState<String>(
      existingTransaction?.currency ?? defaultCurrencyForNew,
    );
    // For edit mode, prefer the row's `date` column (date-only) as the source
    // of truth for the user-selected calendar day. `recurrence_rule.anchor_date`
    // has historically been susceptible to timezone drift depending on backend
    // serialization.
    final startDate = useState<DateTime>(() {
      final existing = existingTransaction;
      if (existing == null) {
        final preferredTimezone =
            ref.read(analyticsProvider).contact?.preferredTimezone;
        final today = effectiveToday(preferredTimezone: preferredTimezone);
        return DateTime(today.year, today.month, today.day);
      }
      final d = existing.date;
      return DateTime(d.year, d.month, d.day);
    }());
    final hasEndDate = useState<bool>(
      existingTransaction?.recurrenceRule?.endDate != null,
    );
    final endDate = useState<DateTime?>(() {
      final existingEndDate = existingTransaction?.recurrenceRule?.endDate;
      if (existingEndDate == null) return null;
      return DateTime(
        existingEndDate.year,
        existingEndDate.month,
        existingEndDate.day,
      );
    }());
    final customInterval = useState<int?>(
      existingTransaction?.recurrenceRule?.interval,
    );

    // Reminder: on edit, initialize from recurrenceRule.reminder; on add, use defaults
    final existingRule = existingTransaction?.recurrenceRule;
    final hasReminder = useState<bool>(
      isEditing ? (existingRule?.reminderEnabled ?? false) : true,
    );
    final reminderValue = useState<int>(
      existingRule?.reminderValue ?? 1,
    );
    final reminderUnit = useState<String>(
      existingRule?.reminderUnit ?? 'days',
    );
    final reminderBeforeAffixes = resolveReminderBeforeAffixes(
      before: context.l10n.before,
      beforePrefix: context.l10n.beforePrefix,
      beforeSuffix: context.l10n.beforeSuffix,
    );
    final isLoading = useState<bool>(false);

    // View mode / household selection for default sharing behaviour
    final householdScope = ref.watch(householdScopeProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.uid.isNotEmpty ? authState.uid : null;

    final existingHouseholdId = existingTransaction?.householdId;
    final isExistingPortfolio = existingHouseholdId != null &&
        householdScope.isPortfolioId(existingHouseholdId);

    final initialAccountType = () {
      if (isExistingPortfolio) {
        return ActiveWalletType.portfolio;
      }
      if (existingHouseholdId != null) {
        return ActiveWalletType.household;
      }
      return householdScope.activeAccountType;
    }();
    final initialAccountHouseholdId =
        existingHouseholdId ?? householdScope.activeAccountHouseholdId;
    final selectedAccountType = useState<ActiveWalletType>(initialAccountType);
    final selectedAccountHouseholdId =
        useState<String?>(initialAccountHouseholdId);

    // Sharing + split state (expenses only)
    final isSharedWithHousehold = useState<bool>(
      selectedAccountType.value == ActiveWalletType.household &&
          selectedAccountHouseholdId.value != null,
    );
    final selectedHouseholdId = useState<String?>(
      selectedAccountType.value == ActiveWalletType.household
          ? selectedAccountHouseholdId.value
          : null,
    );
    // Initialize payer to current user for ADD mode + household sharing
    final selectedPayerUserId = useState<String?>(
      existingTransaction?.payerUserId ??
          (!isEditing &&
                  selectedAccountType.value == ActiveWalletType.household &&
                  selectedAccountHouseholdId.value != null
              ? currentUserId
              : null),
    );
    final customSplitType = useState<SplitType?>(null);
    final customSplits = useState<List<MemberSplit>?>(null);
    final initialSplitSignature = useRef<String?>(null);

    final householdsAsync = currentUserId != null
        ? ref.watch(userHouseholdsProvider(currentUserId))
        : const AsyncValue<List<Household>>.data([]);
    final selectedFinancialAccountId =
        useState<String?>(existingTransaction?.accountId);
    final hasManuallySelectedFinancialAccount = useState<bool>(false);
    final availableHouseholds =
        householdsAsync.valueOrNull ?? const <Household>[];
    final shareableHouseholds = availableHouseholds
        .where((household) => !household.isPortfolio)
        .toList(growable: false);
    final portfolioHouseholds = availableHouseholds
        .where((household) => household.isPortfolio)
        .toList(growable: false);

    Household? findHouseholdById(String? householdId) {
      if (householdId == null) return null;
      for (final household in availableHouseholds) {
        if (household.id == householdId) return household;
      }
      return null;
    }

    List<_RecurringAccountOption> buildAccountOptions() {
      final options = <_RecurringAccountOption>[
        _RecurringAccountOption(
          type: ActiveWalletType.personal,
          label: context.l10n.personalScope,
        ),
      ];

      for (final household in availableHouseholds) {
        final isPortfolio = household.isPortfolio;
        options.add(
          _RecurringAccountOption(
            type: isPortfolio
                ? ActiveWalletType.portfolio
                : ActiveWalletType.household,
            householdId: household.id,
            isPortfolio: isPortfolio,
            label: isPortfolio
                ? '${household.name} · ${context.l10n.privateSpace}'
                : '${household.name} · ${context.l10n.sharedSpace}',
          ),
        );
      }

      return options;
    }

    _RecurringAccountOption currentAccountOption() {
      return _RecurringAccountOption(
        type: selectedAccountType.value,
        householdId: selectedAccountType.value == ActiveWalletType.personal
            ? null
            : selectedAccountHouseholdId.value,
        label: '',
        isPortfolio: selectedAccountType.value == ActiveWalletType.portfolio,
      );
    }

    String accountDisplayValue() {
      if (householdsAsync.isLoading &&
          selectedAccountType.value != ActiveWalletType.personal) {
        return context.l10n.loading;
      }

      switch (selectedAccountType.value) {
        case ActiveWalletType.personal:
          return context.l10n.personalScope;
        case ActiveWalletType.portfolio:
          final household = findHouseholdById(selectedAccountHouseholdId.value);
          return household?.name ?? context.l10n.privateSpace;
        case ActiveWalletType.household:
          final household = findHouseholdById(selectedAccountHouseholdId.value);
          return household?.name ?? context.l10n.tapToSet;
      }
    }

    void clearSplitConfig() {
      customSplitType.value = null;
      customSplits.value = null;
      initialSplitSignature.value = null;
    }

    Future<void> handleEditSpace() async {
      if (householdsAsync.isLoading) return;

      final options = buildAccountOptions();
      if (options.length <= 1) return;

      final current = currentAccountOption();
      final initial = options.contains(current) ? current : options.first;

      final selected =
          await showTransactionSelectionSheet<_RecurringAccountOption>(
        context: context,
        items: options,
        getLabel: (option) => option.label,
        initial: initial,
      );

      if (selected == null || selected == current) return;

      final previousHouseholdId = selectedHouseholdId.value;
      final nextHouseholdId = selected.type == ActiveWalletType.household
          ? selected.householdId
          : null;

      selectedAccountType.value = selected.type;
      selectedAccountHouseholdId.value = selected.householdId;
      selectedFinancialAccountId.value = null;
      hasManuallySelectedFinancialAccount.value = false;

      if (selected.type == ActiveWalletType.household) {
        isSharedWithHousehold.value = nextHouseholdId != null;
        selectedHouseholdId.value = nextHouseholdId;
        if (previousHouseholdId != nextHouseholdId) {
          clearSplitConfig();
        }
        selectedPayerUserId.value ??=
            existingTransaction?.payerUserId ?? currentUserId;
      } else {
        isSharedWithHousehold.value = false;
        selectedHouseholdId.value = null;
        if (previousHouseholdId != null) {
          clearSplitConfig();
        }
      }
    }

    final canShowSharingSection = currentUserId != null &&
        selectedAccountType.value == ActiveWalletType.household &&
        selectedAccountHouseholdId.value != null;
    final walletScopeHouseholdId = switch (selectedAccountType.value) {
      ActiveWalletType.personal => null,
      ActiveWalletType.portfolio => selectedAccountHouseholdId.value,
      ActiveWalletType.household => selectedHouseholdId.value,
    };

    final scopedAccountsAsync =
        ref.watch(walletsByHouseholdIdProvider(walletScopeHouseholdId));
    final scopedAccounts =
        scopedAccountsAsync.valueOrNull ?? const <WalletEntity>[];

    useEffect(() {
      if (scopedAccounts.isEmpty) {
        if (selectedFinancialAccountId.value != null) {
          selectedFinancialAccountId.value = null;
        }
        hasManuallySelectedFinancialAccount.value = false;
        return null;
      }

      final currentId = selectedFinancialAccountId.value;
      final hasCurrent = currentId != null &&
          scopedAccounts.any((account) => account.id == currentId);
      final defaultId = () {
        for (final account in scopedAccounts) {
          if (account.isDefault) return account.id;
        }
        return scopedAccounts.first.id;
      }();

      String? desiredId;

      if (isEditing) {
        if (hasCurrent) {
          desiredId = currentId;
        } else {
          final boundId = existingTransaction?.accountId;
          if (boundId != null &&
              scopedAccounts.any((account) => account.id == boundId)) {
            desiredId = boundId;
          } else {
            desiredId = defaultId;
          }
        }
      } else {
        if (hasManuallySelectedFinancialAccount.value && hasCurrent) {
          desiredId = currentId;
        } else {
          desiredId = defaultId;
        }
      }

      if (selectedFinancialAccountId.value != desiredId) {
        selectedFinancialAccountId.value = desiredId;
      }
      return null;
    }, [
      scopedAccounts,
      isEditing,
      existingTransaction?.accountId,
      hasManuallySelectedFinancialAccount.value,
    ]);

    useEffect(() {
      String? resolvePreferredHouseholdId(List<Household> households) {
        if (households.isEmpty) return null;
        final preferredIds = <String?>[
          existingHouseholdId,
          selectedAccountHouseholdId.value,
          householdScope.activeAccountHouseholdId,
        ];
        for (final candidateId in preferredIds) {
          if (candidateId != null &&
              households.any((household) => household.id == candidateId)) {
            return candidateId;
          }
        }
        return households.first.id;
      }

      switch (selectedAccountType.value) {
        case ActiveWalletType.personal:
          if (selectedAccountHouseholdId.value != null) {
            selectedAccountHouseholdId.value = null;
          }
          if (selectedHouseholdId.value != null) {
            clearSplitConfig();
            selectedHouseholdId.value = null;
          }
          if (isSharedWithHousehold.value) {
            isSharedWithHousehold.value = false;
          }
          return null;
        case ActiveWalletType.portfolio:
          final resolvedPortfolioId = resolvePreferredHouseholdId(
            portfolioHouseholds,
          );
          if (selectedAccountHouseholdId.value != resolvedPortfolioId) {
            selectedAccountHouseholdId.value = resolvedPortfolioId;
          }
          if (selectedHouseholdId.value != null) {
            clearSplitConfig();
            selectedHouseholdId.value = null;
          }
          if (isSharedWithHousehold.value) {
            isSharedWithHousehold.value = false;
          }
          return null;
        case ActiveWalletType.household:
          final resolvedHouseholdId = resolvePreferredHouseholdId(
            shareableHouseholds,
          );
          if (selectedAccountHouseholdId.value != resolvedHouseholdId) {
            selectedAccountHouseholdId.value = resolvedHouseholdId;
          }
          if (selectedHouseholdId.value != resolvedHouseholdId) {
            if (selectedHouseholdId.value != null &&
                selectedHouseholdId.value != resolvedHouseholdId) {
              clearSplitConfig();
            }
            selectedHouseholdId.value = resolvedHouseholdId;
          }
          final shouldShare = resolvedHouseholdId != null;
          if (isSharedWithHousehold.value != shouldShare) {
            isSharedWithHousehold.value = shouldShare;
          }
          if (shouldShare) {
            selectedPayerUserId.value ??=
                existingTransaction?.payerUserId ?? currentUserId;
          }
          return null;
      }
    }, [
      selectedAccountType.value,
      shareableHouseholds,
      portfolioHouseholds,
      householdScope.activeAccountHouseholdId,
      existingHouseholdId,
      existingTransaction?.payerUserId,
      currentUserId,
    ]);

    final membersAsync =
        (selectedAccountType.value == ActiveWalletType.household &&
                isSharedWithHousehold.value &&
                selectedHouseholdId.value != null)
            ? ref.watch(householdMembersProvider(selectedHouseholdId.value!))
            : const AsyncValue<List<HouseholdMember>>.data([]);

    useEffect(() {
      hasManuallySelectedFinancialAccount.value = false;
      return null;
    }, [walletScopeHouseholdId]);

    // When editing a shared recurring EXPENSE, load existing split configuration
    // from the household split groups so the inline split editor reflects the
    // latest backend state.
    useEffect(() {
      if (!isEditing || !isExpense) {
        return null;
      }
      if (existingTransaction?.householdId == null) {
        _debugPrint(
            '🏠 [RECURRING LOAD SPLIT] Skipping - existing transaction is personal');
        return null;
      }
      if (!isSharedWithHousehold.value) {
        _debugPrint(
            '🏠 [RECURRING LOAD SPLIT] Skipping - isSharedWithHousehold is FALSE');
        return null;
      }
      if (selectedHouseholdId.value != existingTransaction?.householdId) {
        _debugPrint(
            '🏠 [RECURRING LOAD SPLIT] Skipping - target household differs from original household');
        return null;
      }

      if (!membersAsync.hasValue) {
        _debugPrint(
            '👥 [RECURRING LOAD SPLIT] Members not loaded yet, waiting for next rebuild');
        return null;
      }

      final members = membersAsync.value;
      if (members == null || members.isEmpty) {
        _debugPrint(
            '👥 [RECURRING LOAD SPLIT] No household members available, aborting split load');
        return null;
      }

      Future.microtask(() async {
        final householdId = existingTransaction!.householdId!;
        final expenseId = existingTransaction!.id;
        _debugPrint(
            '🔄 [RECURRING LOAD SPLIT] Loading split configuration for recurring expense: $expenseId (household=$householdId)');

        try {
          // IMPORTANT: For the recurring edit sheet we always want
          // the freshest split data from the backend, not a
          // potentially stale cached snapshot. Use the base
          // householdSplitsProvider here (no RequestDeduplicator),
          // which is exactly what happens after a full app restart
          // when you see the correct 500/900 amounts.
          final effectiveSplits = await ref.read(
            householdSplitsProvider(
              HouseholdSplitsParams(householdId: householdId),
            ).future,
          );

          _debugPrint(
              '🔄 [RECURRING LOAD SPLIT] Retrieved ${effectiveSplits.length} split groups for household=$householdId');

          final matchingGroups =
              effectiveSplits.where((g) => g.expenseId == expenseId).toList();

          if (matchingGroups.isEmpty) {
            _debugPrint(
                '⚠️ [RECURRING LOAD SPLIT] No split group found for expenseId=$expenseId');
            return;
          }

          // If there are multiple groups (should be rare), prefer the newest
          matchingGroups.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
          );
          final splitGroup = matchingGroups.first;

          _debugPrint(
              '✅ [RECURRING LOAD SPLIT] Using split group ${splitGroup.id} type=${splitGroup.splitType} lines=${splitGroup.splitLines?.length ?? 0}');

          final lines = splitGroup.splitLines;
          if (lines == null || lines.isEmpty) {
            _debugPrint(
                '⚠️ [RECURRING LOAD SPLIT] Split group has no lines, aborting');
            return;
          }

          final memberSplits = <MemberSplit>[];
          for (final member in members) {
            ExpenseSplitLine? matchingLine;
            for (final line in lines) {
              if (line.userId == member.userId) {
                matchingLine = line;
                break;
              }
            }

            if (matchingLine == null) {
              _debugPrint(
                  '⚠️ [RECURRING LOAD SPLIT] No split line found for member ${member.userId}');
              continue;
            }

            memberSplits.add(
              MemberSplit(
                member: member,
                amount: matchingLine.amountCents != null
                    ? matchingLine.amountCents! / 100.0
                    : null,
                percentage: matchingLine.percentage,
                shares: matchingLine.shares,
                includedInAmount: true,
                includedInPercentage: true,
              ),
            );

            _debugPrint(
              '   [RECURRING LOAD SPLIT] Member ${member.userName ?? member.userEmail}: amountCents=${matchingLine.amountCents}',
            );
          }

          if (memberSplits.isEmpty) {
            _debugPrint(
                '⚠️ [RECURRING LOAD SPLIT] No usable member splits after mapping');
            return;
          }

          final uiSplitType =
              _mapDbSplitTypeToUiSplitType(splitGroup.splitType);

          customSplitType.value = uiSplitType;
          customSplits.value = memberSplits;
          initialSplitSignature.value =
              _buildSplitSignature(uiSplitType, memberSplits);

          if (selectedPayerUserId.value == null &&
              splitGroup.payerUserId.isNotEmpty) {
            selectedPayerUserId.value = splitGroup.payerUserId;
          }

          _debugPrint(
              '✅ [RECURRING LOAD SPLIT] Initialized split editor for recurring expense $expenseId with type=$uiSplitType, members=${memberSplits.length}, payer=${selectedPayerUserId.value}');
        } catch (error, stackTrace) {
          _debugPrint(
              '❌ [RECURRING LOAD SPLIT] Error loading split configuration: $error');
          _debugPrint('   Stack: $stackTrace');
        }
      });

      return null;
    }, [
      isEditing,
      isExpense,
      existingTransaction?.id,
      existingTransaction?.householdId,
      selectedHouseholdId.value,
      isSharedWithHousehold.value,
      membersAsync,
    ]);

    // Parsed amount used for split editor defaults
    final parsedAmount = double.tryParse(amountController.text.trim());
    final hasAmountForSplit = parsedAmount != null && parsedAmount > 0;
    final previousAmountRef = useRef<double?>(
      isEditing ? existingTransaction?.amount : null,
    );
    useEffect(() {
      if (previousAmountRef.value == null && hasAmountForSplit) {
        previousAmountRef.value = parsedAmount;
      }
      return null;
    }, [hasAmountForSplit]);

    // Initialize payer when household mode is active on mount
    useEffect(() {
      _debugPrint('🏠 [ADD RECURRING] Initializing payer for household mode');
      _debugPrint('   isEditing: $isEditing');
      _debugPrint('   isSharedWithHousehold: ${isSharedWithHousehold.value}');
      _debugPrint('   selectedHouseholdId: ${selectedHouseholdId.value}');

      // For EDIT mode, we must NOT blindly override the payer with the
      // current user. The authoritative source for payer on shared
      // recurring expenses is the split group, which is loaded
      // asynchronously in the RECURRENT LOAD SPLIT effect above.
      // Only seed from existingTransaction.payerUserId when it is
      // actually present.
      if (isEditing &&
          isSharedWithHousehold.value &&
          selectedHouseholdId.value != null &&
          selectedPayerUserId.value == null &&
          existingTransaction?.payerUserId != null) {
        _debugPrint(
            '   Setting payer from existing transaction: ${existingTransaction!.payerUserId}');
        selectedPayerUserId.value = existingTransaction!.payerUserId;
      }

      // Only for ADD mode in household mode
      if (!isEditing &&
          selectedAccountType.value == ActiveWalletType.household &&
          isSharedWithHousehold.value &&
          selectedHouseholdId.value != null &&
          selectedPayerUserId.value == null &&
          currentUserId != null) {
        _debugPrint('   Setting payer to current user: $currentUserId');
        selectedPayerUserId.value = currentUserId;
      }
      return null;
    }, [
      isEditing,
      selectedAccountType.value,
      isSharedWithHousehold.value,
      selectedHouseholdId.value,
      selectedPayerUserId.value,
      currentUserId,
      existingTransaction?.payerUserId,
    ]);

    // Whenever the amount changes for NEW recurring expenses, clear any
    // previously configured custom splits so the split editor can
    // re-initialize based on the new total. For EDIT mode, we must
    // preserve the current split configuration so user edits are
    // actually sent to the backend.
    useEffect(() {
      if (!isEditing) {
        customSplitType.value = null;
        customSplits.value = null;
      }
      return null;
    }, [currentAmountText]);

    useEffect(() {
      if (!isEditing) return null;
      if (!hasAmountForSplit) return null;
      if (customSplitType.value != SplitType.amount) return null;
      final splits = customSplits.value;
      if (splits == null || splits.isEmpty) return null;

      final currentTotal = parsedAmount;
      final previousTotal = previousAmountRef.value;
      previousAmountRef.value = currentTotal;
      if (previousTotal == null ||
          (previousTotal - currentTotal).abs() < 0.01) {
        return null;
      }

      customSplits.value = rescaleAmountSplits(
        splits: splits,
        previousTotal: previousTotal,
        newTotal: currentTotal,
      );
      return null;
    }, [parsedAmount, customSplitType.value]);

    Future<void> handleSave() async {
      final l10n = context.l10n;
      if (selectedCategory.value == null) {
        _debugPrint('🔴 Error: No category selected');
        AppToast.error(context, context.l10n.pleaseSelectCategory);
        return;
      }

      final amountText = amountController.text.trim();
      if (amountText.isEmpty) {
        AppToast.error(context, context.l10n.pleaseEnterAmount);
        return;
      }

      final amountCents = tryParseMoneyToCents(amountText);
      final amount = amountCents == null ? null : centsToAmount(amountCents);
      if (amount == null || amountCents == null || amountCents <= 0) {
        AppToast.error(context, context.l10n.pleaseEnterValidAmount);
        return;
      }

      if (ref.read(previewModeProvider).isActive) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
        AppToast.success(
          context,
          isEditing
              ? context.l10n.previewRecurringUpdatedForDemo
              : context.l10n.previewRecurringScheduledForDemo,
        );
        return;
      }

      if (isExpense &&
          isSharedWithHousehold.value &&
          customSplitType.value == SplitType.amount &&
          customSplits.value != null &&
          customSplits.value!.isNotEmpty) {
        final isValid = isAmountSplitTotalValid(
          type: customSplitType.value!,
          splits: customSplits.value!,
          totalAmount: amount,
        );
        if (!isValid) {
          final currencySymbol = resolveCurrencySymbol(selectedCurrency.value);
          AppToast.error(
            context,
            context.l10n.splitAmountsMustEqual(
              currencySymbol,
              amount.toStringAsFixed(2),
              currencySymbol,
            ),
          );
          return;
        }
      }

      final originalCategoryForRemap =
          _normalizeCategoryRemapKey(existingTransaction?.category);
      final selectedCategoryForRemap =
          _normalizeCategoryRemapKey(selectedCategory.value);
      final shouldPromptCategoryRemap = isEditing &&
          selectedCategoryForRemap.isNotEmpty &&
          selectedCategoryForRemap != originalCategoryForRemap &&
          originalCategoryForRemap != 'other' &&
          originalCategoryForRemap != 'uncategorized';

      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final toastContext = rootNavigator.context;
      isLoading.value = true;
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
        final userId = ref.read(authProvider).uid;
        if (userId.isEmpty) {
          AppToast.error(toastContext, context.l10n.userNotAuthenticated);
          isLoading.value = false;
          closeDialog();
          return;
        }

        RecurringTransaction? result;
        final effectiveHouseholdId = switch (selectedAccountType.value) {
          ActiveWalletType.personal => null,
          ActiveWalletType.portfolio => selectedAccountHouseholdId.value,
          ActiveWalletType.household => selectedHouseholdId.value,
        };

        final isPortfolioScope =
            selectedAccountType.value == ActiveWalletType.portfolio ||
                (effectiveHouseholdId != null &&
                    householdScope.isPortfolioId(effectiveHouseholdId));
        final selectedAccountId = selectedFinancialAccountId.value ??
            (() {
              for (final account in scopedAccounts) {
                if (account.isDefault) return account.id;
              }
              return scopedAccounts.isNotEmpty ? scopedAccounts.first.id : null;
            })();
        // Only household-group accounts support shared splits.
        final shareWithHousehold =
            selectedAccountType.value == ActiveWalletType.household &&
                !isPortfolioScope &&
                isSharedWithHousehold.value &&
                selectedHouseholdId.value != null;
        final activeHouseholdId = effectiveHouseholdId;
        final originalHouseholdId = existingTransaction?.householdId;
        final hasSplitConfig = customSplitType.value != null &&
            customSplits.value != null &&
            customSplits.value!.isNotEmpty;
        final currentSplitSignature = hasSplitConfig
            ? _buildSplitSignature(
                customSplitType.value!,
                customSplits.value!,
              )
            : null;
        final initialSignature = initialSplitSignature.value;
        final sameSharedHousehold = shareWithHousehold &&
            originalHouseholdId != null &&
            originalHouseholdId == activeHouseholdId;
        final existingSplitGroupId = existingTransaction?.splitGroupId;
        final amountChanged = isEditing &&
            existingTransaction != null &&
            (existingTransaction!.amount - amount).abs() > 0.0001;
        final currencyChanged = isEditing &&
            existingTransaction != null &&
            existingTransaction!.currency.toUpperCase() !=
                selectedCurrency.value.toUpperCase();
        final splitConfigChanged = initialSignature != null &&
            currentSplitSignature != null &&
            currentSplitSignature != initialSignature;
        final shouldCreateSplitGroup = shareWithHousehold &&
            hasSplitConfig &&
            (!sameSharedHousehold || existingSplitGroupId == null);
        final shouldSendSplitUpdate = shareWithHousehold &&
            hasSplitConfig &&
            sameSharedHousehold &&
            existingSplitGroupId != null &&
            (amountChanged || currencyChanged || splitConfigChanged);
        _debugPrint(
            '💾 [RECURRING SAVE] share=$shareWithHousehold hh=$activeHouseholdId payer=${selectedPayerUserId.value}');
        _debugPrint('   Custom split type: ${customSplitType.value}');
        _debugPrint(
            '   Custom splits count: ${customSplits.value?.length ?? 0}');

        if (isExpense) {
          if (isEditing) {
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringExpense(
                  userId: userId,
                  expenseId: existingTransaction!.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  merchant: merchantController.text.trim().isEmpty
                      ? null
                      : merchantController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  previousHouseholdId: existingTransaction?.householdId,
                  customSplitType:
                      (shouldCreateSplitGroup || shouldSendSplitUpdate)
                          ? customSplitType.value
                          : null,
                  customSplits:
                      (shouldCreateSplitGroup || shouldSendSplitUpdate)
                          ? customSplits.value
                          : null,
                  payerUserId: shareWithHousehold
                      ? (selectedPayerUserId.value ?? userId)
                      : null,
                  accountId: selectedAccountId,
                );
          } else {
            // CREATE new expense
            final saveFuture = ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringExpense(
                  userId: userId,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  merchant: merchantController.text.trim().isEmpty
                      ? null
                      : merchantController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  customSplitType:
                      shareWithHousehold ? customSplitType.value : null,
                  customSplits: shareWithHousehold ? customSplits.value : null,
                  payerUserId: shareWithHousehold
                      ? (selectedPayerUserId.value ?? userId)
                      : null,
                  accountId: selectedAccountId,
                );
            final providerContainer = ProviderScope.containerOf(
              context,
              listen: false,
            );
            isLoading.value = false;
            if (context.mounted) {
              closeDialog();
              Navigator.of(context).pop(true);
              AppToast.success(
                toastContext,
                l10n.recurringExpenseAddedSuccessfully,
              );
            }
            unawaited(saveFuture.then((saved) {
              if (saved != null) {
                providerContainer
                    .read(walletActionsProvider)
                    .refreshAccountData();
                providerContainer.invalidate(pocketDetailsProvider);
                return;
              }
              if (!toastContext.mounted) return;
              AppToast.error(
                toastContext,
                l10n.failedToSaveRecurringTransaction,
              );
            }));
            return;
          }
        } else {
          if (isEditing) {
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringIncome(
                  userId: userId,
                  expenseId: existingTransaction!.id,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  merchant: merchantController.text.trim().isEmpty
                      ? null
                      : merchantController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  accountId: selectedAccountId,
                );
          } else {
            // CREATE new income
            final saveFuture = ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringIncome(
                  userId: userId,
                  amount: amount,
                  category: selectedCategory.value!,
                  currency: selectedCurrency.value,
                  startDate: startDate.value,
                  frequency: selectedFrequency.value,
                  endDate: hasEndDate.value ? endDate.value : null,
                  interval: customInterval.value,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  merchant: merchantController.text.trim().isEmpty
                      ? null
                      : merchantController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  accountId: selectedAccountId,
                );
            final providerContainer = ProviderScope.containerOf(
              context,
              listen: false,
            );
            isLoading.value = false;
            if (context.mounted) {
              closeDialog();
              Navigator.of(context).pop(true);
              AppToast.success(
                toastContext,
                l10n.recurringIncomeAddedSuccessfully,
              );
            }
            unawaited(saveFuture.then((saved) {
              if (saved != null) {
                providerContainer
                    .read(walletActionsProvider)
                    .refreshAccountData();
                providerContainer.invalidate(pocketDetailsProvider);
                return;
              }
              if (!toastContext.mounted) return;
              AppToast.error(
                toastContext,
                l10n.failedToSaveRecurringTransaction,
              );
            }));
            return;
          }
        }

        isLoading.value = false;

        if (result != null) {
          _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _debugPrint('✅ [SAVE RECURRING] Transaction saved successfully');
          _debugPrint('   Transaction ID: ${result.id}');
          _debugPrint('   Type: ${result.type}');
          _debugPrint('   Category: ${result.category}');
          _debugPrint('   Amount: ${result.amount} ${result.currency}');
          _debugPrint('   HouseholdId: ${result.householdId}');
          _debugPrint(
              '   Has RecurrenceRule: ${result.recurrenceRule != null}');
          _debugPrint(
              '   Frequency: ${result.recurrenceRule?.frequency ?? "one-time"}');

          // Get current view mode to determine which scope to refresh
          final currentScope = ref.read(householdScopeProvider);
          final currentHouseholdId = currentScope.activeAccountHouseholdId;

          _debugPrint(
              '🔄 [REFRESH] Current view mode: ${currentScope.activeAccountType}');
          _debugPrint('🔄 [REFRESH] Current household ID: $currentHouseholdId');
          _debugPrint(
              '🔄 [REFRESH] Transaction household ID (activeHouseholdId): $activeHouseholdId');

          // CRITICAL: Force refresh based on CURRENT VIEW MODE
          // This ensures the page the user is viewing refreshes immediately
          if (currentScope.activeAccountType != ActiveWalletType.personal &&
              currentHouseholdId != null) {
            _debugPrint(
                '🏠 [REFRESH] Refreshing HOUSEHOLD view for: $currentHouseholdId');

            // Invalidate RequestDeduplicator cache for household data
            ref
                .read(cacheInvalidatorProvider)
                .invalidateHouseholdData(currentHouseholdId);
            // Mirror unified_transaction_sheet: invalidate the full
            // household split provider families so ALL consumers
            // (recurring sheet, dashboard, etc.) are forced to
            // reload from the backend.
            ref.invalidate(householdSplitsProvider);
            ref.invalidate(cachedHouseholdSplitsProvider);

            // Force refresh (not invalidate) to reload data while keeping state
            _debugPrint(
                '   🔄 Forcing refresh of recurringTransactionsProvider($currentHouseholdId)');
            await ref
                .read(
                    recurringTransactionsProvider(currentHouseholdId).notifier)
                .refresh(userId);

            _debugPrint(
                '   ♻️  Invalidating pocketsProvider family (household view)');
            ref.invalidate(pocketsProvider);
          } else {
            _debugPrint('👤 [REFRESH] Refreshing PERSONAL view');

            // Force refresh (not invalidate) to reload data while keeping state
            _debugPrint(
                '   🔄 Forcing refresh of recurringTransactionsProvider(null)');
            await ref
                .read(recurringTransactionsProvider(null).notifier)
                .refresh(userId);

            _debugPrint(
                '   ♻️  Invalidating pocketsProvider family (personal view)');
            ref.invalidate(pocketsProvider);
          }

          // ALSO refresh the scope where the transaction is actually stored (if different from current view)
          // This ensures consistency across all scopes
          if (activeHouseholdId != null &&
              activeHouseholdId != currentHouseholdId) {
            _debugPrint(
                '🔄 [REFRESH] Also refreshing transaction storage scope: $activeHouseholdId');
            ref
                .read(cacheInvalidatorProvider)
                .invalidateHouseholdData(activeHouseholdId);
            // Ensure all household split consumers for this scope
            // also reload, not just the cached provider.
            ref.invalidate(householdSplitsProvider);
            ref.invalidate(cachedHouseholdSplitsProvider);

            _debugPrint(
                '   🔄 Forcing refresh of recurringTransactionsProvider($activeHouseholdId)');
            await ref
                .read(recurringTransactionsProvider(activeHouseholdId).notifier)
                .refresh(userId);

            _debugPrint(
                '   ♻️  Invalidating pocketsProvider family (transaction household scope)');
            ref.invalidate(pocketsProvider);
          } else if (activeHouseholdId == null &&
              currentScope.activeAccountType != ActiveWalletType.personal) {
            // Transaction is personal but we're in household view - also refresh personal scope
            _debugPrint(
                '🔄 [REFRESH] Also refreshing personal scope (transaction is personal)');

            _debugPrint(
                '   🔄 Forcing refresh of recurringTransactionsProvider(null)');
            await ref
                .read(recurringTransactionsProvider(null).notifier)
                .refresh(userId);

            _debugPrint(
                '   ♻️  Invalidating pocketsProvider family (personal scope)');
            ref.invalidate(pocketsProvider);
          }

          final previousHouseholdId = existingTransaction?.householdId;
          if (isEditing && previousHouseholdId != activeHouseholdId) {
            if (previousHouseholdId != null &&
                previousHouseholdId != currentHouseholdId &&
                previousHouseholdId != activeHouseholdId) {
              _debugPrint(
                  '🔄 [REFRESH] Refreshing previous household scope: $previousHouseholdId');
              ref
                  .read(cacheInvalidatorProvider)
                  .invalidateHouseholdData(previousHouseholdId);
              ref.invalidate(householdSplitsProvider);
              ref.invalidate(cachedHouseholdSplitsProvider);
              await ref
                  .read(
                    recurringTransactionsProvider(previousHouseholdId).notifier,
                  )
                  .refresh(userId);
              ref.invalidate(pocketsProvider);
            } else if (previousHouseholdId == null &&
                currentScope.activeAccountType != ActiveWalletType.personal &&
                activeHouseholdId != null) {
              _debugPrint(
                  '🔄 [REFRESH] Refreshing previous personal scope after move');
              await ref
                  .read(recurringTransactionsProvider(null).notifier)
                  .refresh(userId);
              ref.invalidate(pocketsProvider);
            }
          }

          ref.read(walletActionsProvider).refreshAccountData();
          ref.invalidate(pocketDetailsProvider);

          // Keep currency selector counts up-to-date.
          ref.invalidate(currencyTransactionCountsProvider);

          _debugPrint(
              '✅ [REFRESH] All providers refreshed/invalidated successfully');
          _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          if (context.mounted) {
            closeDialog();
            Navigator.of(context).pop(true);
            final successMsg = isExpense
                ? (isEditing
                    ? l10n.recurringExpenseUpdatedSuccessfully
                    : l10n.recurringExpenseAddedSuccessfully)
                : (isEditing
                    ? l10n.recurringIncomeUpdatedSuccessfully
                    : l10n.recurringIncomeAddedSuccessfully);

            if (shouldPromptCategoryRemap) {
              unawaited(
                _handleCategoryRemapPrompt(
                  toastContext: toastContext,
                  userId: userId,
                  transactionType: selectedType.value,
                  fromCategory: originalCategoryForRemap,
                  toCategory: selectedCategoryForRemap,
                  fallbackSuccessMessage: successMsg,
                ),
              );
              return;
            }

            AppToast.success(toastContext, successMsg);
          }
        } else {
          Object? saveError;
          final saveState = ref.read(recurringTransactionSaveProvider);

          saveState.when(
            data: (_) {},
            loading: () {},
            error: (err, _) {
              saveError = err;
            },
          );

          final msg = ErrorHandler.getUserFriendlyMessage(
            saveError ?? l10n.failedToSaveRecurringTransaction,
            context: BackendErrorContext.saveRecurring,
          );

          if (context.mounted) {
            closeDialog();
            AppToast.error(toastContext, msg);
          }
        }
      } catch (e) {
        isLoading.value = false;
        if (!context.mounted) {
          return;
        }

        Object? saveError;
        final saveState = ref.read(recurringTransactionSaveProvider);

        saveState.when(
          data: (_) {},
          loading: () {},
          error: (err, _) {
            saveError = err;
          },
        );

        final msg = ErrorHandler.getUserFriendlyMessage(
          saveError ?? e,
          context: BackendErrorContext.saveRecurring,
        );

        closeDialog();
        AppToast.error(toastContext, msg);
      } finally {
        closeDialog();
      }
    }

    Future<void> handleDelete() async {
      if (!isEditing || existingTransaction == null) return;

      final l10n = context.l10n;
      final deleteEntireSeriesLabel = l10n.deleteEntireSeries.trim().isEmpty
          ? l10n.delete
          : l10n.deleteEntireSeries;
      final skipNextOccurrenceLabel = l10n.skipNextOccurrence.trim().isEmpty
          ? l10n.skip
          : l10n.skipNextOccurrence;

      MonekoAlertDialogAction? choice;

      await AdaptiveAlertDialog.show(
        context: context,
        title: l10n.deleteRecurringTransaction,
        message: l10n.deleteRecurringChoiceDescription,
        actions: [
          AlertAction(
            title: skipNextOccurrenceLabel,
            style: AlertActionStyle.destructive,
            onPressed: () async {
              choice = MonekoAlertDialogAction.secondary;
              Navigator.pop(context);
            },
          ),
          AlertAction(
            title: deleteEntireSeriesLabel,
            style: AlertActionStyle.cancel,
            onPressed: () async {
              choice = MonekoAlertDialogAction.confirm;
              Navigator.pop(context);
            },
          ),
          AlertAction(
            title: l10n.cancel,
            style: AlertActionStyle.secondary,
            onPressed: () async {
              choice = MonekoAlertDialogAction.cancel;
              Navigator.pop(context);
            },
          ),
        ],
      );

      if (choice == null || choice == MonekoAlertDialogAction.cancel) {
        return;
      }

      if (!context.mounted) return;

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        AppToast.error(context, l10n.userNotAuthenticated);
        return;
      }

      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final toastContext = rootNavigator.context;
      var dialogOpen = false;

      void closeDialog() {
        if (!dialogOpen) return;
        if (rootNavigator.canPop()) rootNavigator.pop();
        dialogOpen = false;
      }

      final isSkipOccurrence = choice == MonekoAlertDialogAction.secondary;

      showBlockingProcessingDialog(
        context: toastContext,
        message: isSkipOccurrence
            ? '${l10n.skipNextOccurrence}...'
            : '${l10n.delete}...',
      );
      dialogOpen = true;

      try {
        final notifier = ref.read(
          recurringTransactionsProvider(existingTransaction!.householdId)
              .notifier,
        );

        late final DeleteRecurringResult result;
        if (isSkipOccurrence) {
          final preferredTimezone =
              ref.read(analyticsProvider).contact?.preferredTimezone;
          final userNow = effectiveNow(preferredTimezone: preferredTimezone);
          final nextDate =
              existingTransaction!.getNextSkippableOccurrence(userNow);
          if (nextDate == null) {
            closeDialog();
            AppToast.error(
                toastContext, l10n.failedToDeleteRecurringTransaction);
            return;
          }
          result = await notifier.skipOccurrence(
            user.uid,
            existingTransaction!.id,
            nextDate,
          );
        } else {
          result = await notifier.deleteRecurring(
            user.uid,
            existingTransaction!.id,
          );
        }

        if (!context.mounted) return;

        closeDialog();

        if (result.success) {
          ref.read(walletActionsProvider).refreshAccountData();
          ref.invalidate(pocketDetailsProvider);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
          AppToast.success(
            toastContext,
            isSkipOccurrence
                ? l10n.occurrenceSkipped
                : l10n.recurringTransactionDeleted,
          );
          return;
        }

        if (result.error == 'preview_mode_blocked') {
          return;
        }

        final message =
            (result.error != null && result.error!.trim().isNotEmpty)
                ? result.error!
                : l10n.failedToDeleteRecurringTransaction;
        AppToast.error(toastContext, message);
      } catch (e) {
        closeDialog();
        if (!context.mounted) return;
        AppToast.error(toastContext, ErrorHandler.getUserFriendlyMessage(e));
      } finally {
        closeDialog();
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PopScope(
          canPop: !isLoading.value,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Sheet Drag Handle
                const ModalSheetHandle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Text(
                        isEditing
                            ? (isExpense
                                ? context.l10n.editRecurringExpense
                                : context.l10n.editRecurringIncome)
                            : (isExpense
                                ? context.l10n.addRecurringExpense
                                : context.l10n.addRecurringIncome),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: isLoading.value ? null : handleSave,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: isLoading.value
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.check,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
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
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MonekoInput(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (selectedType.value != 'expense') {
                                      selectedType.value = 'expense';
                                      selectedCategory.value = null;
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isExpense
                                          ? colorScheme.primary
                                          : colorScheme.surface
                                              .withValues(alpha: 0.0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      context.l10n.expenses,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isExpense
                                            ? colorScheme.primaryForeground
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (selectedType.value != 'income') {
                                      selectedType.value = 'income';
                                      selectedCategory.value = null;
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !isExpense
                                          ? colorScheme.primary
                                          : colorScheme.surface
                                              .withValues(alpha: 0.0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      context.l10n.income,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: !isExpense
                                            ? colorScheme.primaryForeground
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),

                        // Detail cards grouped in single section
                        MonekoInput(
                          child: Column(
                            children: [
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.amount,
                                value: amountController.text.trim().isEmpty
                                    ? '0.00'
                                    : amountController.text.trim(),
                                isFirst: true,
                                onTap: () async {
                                  final isIncomeMode = !isExpense;
                                  final displayCategory =
                                      selectedCategory.value ?? 'other';
                                  final categoryColor =
                                      getCategoryColor(displayCategory);
                                  final categoryIcon =
                                      getCategoryIcon(displayCategory);
                                  final localizedCategory =
                                      getCategoryTranslation(
                                          context, displayCategory);
                                  final displayMerchant =
                                      merchantController.text.trim();
                                  final displayDescription =
                                      descriptionController.text.trim();
                                  final effectiveTitle =
                                      displayDescription.isNotEmpty
                                          ? displayDescription
                                          : (displayMerchant.isNotEmpty
                                              ? displayMerchant
                                              : null);

                                  final header = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isIncomeMode
                                                  ? colorScheme.success
                                                      .withValues(alpha: 0.12)
                                                  : colorScheme.destructive
                                                      .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                color: isIncomeMode
                                                    ? colorScheme.success
                                                        .withValues(alpha: 0.2)
                                                    : colorScheme.destructive
                                                        .withValues(alpha: 0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isIncomeMode
                                                        ? colorScheme.success
                                                        : colorScheme
                                                            .destructive,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isIncomeMode
                                                      ? context.l10n.income
                                                      : context.l10n.expense,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isIncomeMode
                                                        ? colorScheme.success
                                                        : colorScheme
                                                            .destructive,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: categoryColor.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                color: categoryColor.withValues(
                                                    alpha: 0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  categoryIcon,
                                                  size: 12,
                                                  color: categoryColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  localizedCategory,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.foreground,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (effectiveTitle != null &&
                                          effectiveTitle.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          effectiveTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.foreground,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                      ],
                                    ],
                                  );

                                  final value = await showCalculatorKeypadSheet(
                                    context: context,
                                    initialValue:
                                        amountController.text.trim().isEmpty
                                            ? ''
                                            : amountController.text.trim(),
                                    prefix: resolveCurrencySymbol(
                                        selectedCurrency.value),
                                    header: header,
                                  );
                                  if (value != null) {
                                    amountController.text = value;
                                  }
                                },
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.space,
                                value: accountDisplayValue(),
                                isValuePlaceholder: householdsAsync.isLoading &&
                                    selectedAccountType.value !=
                                        ActiveWalletType.personal,
                                onTap: handleEditSpace,
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.wallet,
                                value: () {
                                  if (scopedAccountsAsync.isLoading) {
                                    return context.l10n.loading;
                                  }
                                  if (scopedAccounts.isEmpty) {
                                    return context.l10n.tapToSet;
                                  }
                                  final currentId =
                                      selectedFinancialAccountId.value;
                                  if (currentId != null) {
                                    for (final account in scopedAccounts) {
                                      if (account.id == currentId) {
                                        return account.name;
                                      }
                                    }
                                  }
                                  final fallback = scopedAccounts.firstWhere(
                                    (account) => account.isDefault,
                                    orElse: () => scopedAccounts.first,
                                  );
                                  return fallback.name;
                                }(),
                                isValuePlaceholder: scopedAccounts.isEmpty,
                                onTap: () async {
                                  if (scopedAccounts.isEmpty) return;
                                  final currentId =
                                      selectedFinancialAccountId.value;
                                  final initial = scopedAccounts.firstWhere(
                                    (account) => account.id == currentId,
                                    orElse: () => scopedAccounts.first,
                                  );
                                  final selected =
                                      await showTransactionSelectionSheet<
                                          WalletEntity>(
                                    context: context,
                                    items: scopedAccounts,
                                    getLabel: (account) => account.name,
                                    initial: initial,
                                  );
                                  if (selected != null) {
                                    selectedFinancialAccountId.value =
                                        selected.id;
                                    hasManuallySelectedFinancialAccount.value =
                                        true;
                                  }
                                },
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.category,
                                value: selectedCategory.value != null
                                    ? getCategoryTranslation(
                                        context, selectedCategory.value!)
                                    : context.l10n.selectCategory,
                                isValuePlaceholder:
                                    selectedCategory.value == null,
                                onTap: () async {
                                  final isIncomeMode = !isExpense;
                                  UserCategoryLists? lists;
                                  try {
                                    lists = await ref.read(
                                      userCategoryListsProvider.future,
                                    );
                                  } catch (_) {
                                    lists = null;
                                  }
                                  if (!context.mounted) return;

                                  final categories = isIncomeMode
                                      ? (lists?.incomeCategories ??
                                          getIncomeCategories())
                                      : (lists?.expenseCategories ??
                                          getExpenseCategories());

                                  final result = await showCategoryPicker(
                                    context: context,
                                    // When no category is selected, pass an empty string so
                                    // the picker shows with no preselection. Existing
                                    // transactions still pass their actual category.
                                    currentCategory:
                                        selectedCategory.value ?? '',
                                    isIncome: isIncomeMode,
                                    allCategories: categories,
                                    onCreateCategory: (name) =>
                                        createUserCustomCategory(
                                      ref: ref,
                                      name: name,
                                      isIncome: isIncomeMode,
                                    ),
                                  );
                                  if (result != null) {
                                    selectedCategory.value = result;
                                  }
                                },
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: isExpense
                                    ? context.l10n.merchant
                                    : context.l10n.source,
                                value: merchantController.text.trim().isEmpty
                                    ? (isExpense
                                        ? context.l10n.addMerchant
                                        : context.l10n.addSource)
                                    : merchantController.text.trim(),
                                isValuePlaceholder:
                                    merchantController.text.trim().isEmpty,
                                onTap: () async {
                                  final result = await MonekoAlertDialog.show(
                                    context: context,
                                    title: isExpense
                                        ? context.l10n.merchantOptional
                                        : context.l10n.sourceOptional,
                                    description: null,
                                    confirmLabel: context.l10n.save,
                                    cancelLabel: context.l10n.cancel,
                                    inputConfig: MonekoAlertDialogInputConfig(
                                      initialValue:
                                          merchantController.text.trim(),
                                      placeholder: isExpense
                                          ? context.l10n.addMerchant
                                          : context.l10n.addSource,
                                      isRequired: false,
                                    ),
                                  );

                                  if (!context.mounted ||
                                      result == null ||
                                      !result.confirmed ||
                                      result.text == null) {
                                    return;
                                  }

                                  merchantController.text = result.text!.trim();
                                },
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.currency,
                                value: selectedCurrency.value.toUpperCase(),
                                isLast: true,
                                onTap: () async {
                                  final result = await showCurrencyPicker(
                                    context: context,
                                    currentCurrency: selectedCurrency.value,
                                  );
                                  if (result != null) {
                                    selectedCurrency.value = result;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Frequency and date settings grouped in single section
                        MonekoInput(
                          child: Column(
                            children: [
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.frequency,
                                value: formatRecurrenceSelectionLabel(
                                  context,
                                  frequency: selectedFrequency.value,
                                  interval: customInterval.value,
                                ),
                                isFirst: true,
                                onTap: () async {
                                  final result = await showRecurrencePicker(
                                    context: context,
                                    currentFrequency: selectedFrequency.value,
                                    currentInterval: customInterval.value,
                                  );
                                  if (result == null) return;

                                  selectedFrequency.value = result.frequency;
                                  final interval = result.interval;
                                  customInterval.value =
                                      (interval != null && interval > 1)
                                          ? interval
                                          : null;
                                },
                              ),
                              _buildDivider(colorScheme),
                              _buildDetailCard(
                                colorScheme: colorScheme,
                                label: context.l10n.startDate,
                                value: formatLocalizedDate(
                                    context, startDate.value,
                                    includeYear: true),
                                onTap: () async {
                                  final result =
                                      await showTransactionDatePicker(
                                    context: context,
                                    currentDate: startDate.value,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (result != null) {
                                    startDate.value = result;
                                  }
                                },
                              ),
                              _buildDivider(colorScheme),
                              // End date toggle row
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.l10n.setEndDate,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    AdaptiveSwitch(
                                      value: hasEndDate.value,
                                      onChanged: (value) {
                                        hasEndDate.value = value;
                                        if (!value) {
                                          endDate.value = null;
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // End date picker (if enabled)
                              if (hasEndDate.value) ...[
                                _buildDivider(colorScheme),
                                _buildDetailCard(
                                  colorScheme: colorScheme,
                                  label: context.l10n.endDate,
                                  value: endDate.value != null
                                      ? formatLocalizedDate(
                                          context, endDate.value!,
                                          includeYear: true)
                                      : context.l10n.selectEndDate,
                                  isValuePlaceholder: endDate.value == null,
                                  isLast: !hasEndDate.value,
                                  onTap: () async {
                                    final result =
                                        await showTransactionDatePicker(
                                      context: context,
                                      currentDate: endDate.value ??
                                          startDate.value
                                              .add(const Duration(days: 365)),
                                      firstDate: startDate.value,
                                      lastDate: DateTime(2030),
                                    );
                                    if (result != null) {
                                      endDate.value = DateTime(
                                        result.year,
                                        result.month,
                                        result.day,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Reminder section - 3 rows
                        MonekoInput(
                          child: Column(
                            children: [
                              // Row 1: Title + switch
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      context.l10n.setReminder,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    AdaptiveSwitch(
                                      value: hasReminder.value,
                                      onChanged: (value) {
                                        hasReminder.value = value;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Row 2: Configuration (when enabled)
                              if (hasReminder.value) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (reminderBeforeAffixes
                                          .prefix.isNotEmpty) ...[
                                        Text(
                                          reminderBeforeAffixes.prefix,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      // Value picker
                                      GestureDetector(
                                        onTap: () async {
                                          final numbers = List.generate(
                                              31, (index) => index + 1);
                                          final result =
                                              await MonekoListPicker.show<int>(
                                            context: context,
                                            items: numbers,
                                            labelBuilder: (number) =>
                                                number.toString(),
                                            initial: reminderValue.value,
                                          );
                                          if (result != null) {
                                            reminderValue.value = result;
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.muted
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                reminderValue.value.toString(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.foreground,
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color:
                                                    colorScheme.mutedForeground,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Unit picker
                                      GestureDetector(
                                        onTap: () async {
                                          final result =
                                              await showTransactionSelectionSheet<
                                                  String>(
                                            context: context,
                                            items: ['days'],
                                            getLabel: (unit) {
                                              if (unit == 'days') {
                                                return context.l10n.days;
                                              }
                                              return unit;
                                            },
                                            initial: reminderUnit.value,
                                          );
                                          if (result != null) {
                                            reminderUnit.value = result;
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: colorScheme.muted
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                reminderUnit.value == 'days'
                                                    ? context.l10n.days
                                                    : context.l10n.hours,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: colorScheme.foreground,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color:
                                                    colorScheme.mutedForeground,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (reminderBeforeAffixes
                                          .suffix.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          reminderBeforeAffixes.suffix,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              // Row 3: Helper text (when enabled)
                              if (hasReminder.value) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16, bottom: 12),
                                  child: Text(
                                    context.l10n
                                        .youWillBeNotifiedBeforeEachOccurrence(
                                      reminderValue.value,
                                      reminderUnit.value == 'days'
                                          ? context.l10n.days
                                          : context.l10n.hours,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.mutedForeground,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Sharing section (for household expenses)
                        if (canShowSharingSection && isExpense) ...[
                          const SizedBox(height: 20),
                          if (!hasAmountForSplit)
                            Text(
                              context.l10n.pleaseEnterAmount,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                              ),
                            )
                          else if (shareableHouseholds.isNotEmpty)
                            _buildSharingAndSplitSection(
                              context: context,
                              colorScheme: colorScheme,
                              households: shareableHouseholds,
                              isSharedWithHousehold: isSharedWithHousehold,
                              selectedHouseholdId: selectedHouseholdId,
                              membersAsync: membersAsync,
                              selectedPayerUserId: selectedPayerUserId,
                              customSplitType: customSplitType,
                              customSplits: customSplits,
                              amountController: amountController,
                              currencySymbol:
                                  resolveCurrencySymbol(selectedCurrency.value),
                              isEditing: isEditing,
                              currentUserId: currentUserId,
                              showSharingControls: false,
                            ),
                        ],

                        // Additional Info section - Notes
                        const SizedBox(height: 20),
                        MonekoInput(
                          child: InkWell(
                            onTap: () async {
                              final result = await MonekoAlertDialog.show(
                                context: context,
                                title: context.l10n.descriptionOptional,
                                description: null,
                                confirmLabel: context.l10n.save,
                                cancelLabel: context.l10n.cancel,
                                inputConfig: MonekoAlertDialogInputConfig(
                                  initialValue:
                                      descriptionController.text.trim(),
                                  placeholder: context.l10n.addANote,
                                  isRequired: false,
                                  keyboardType: TextInputType.multiline,
                                ),
                              );

                              if (!context.mounted ||
                                  result == null ||
                                  !result.confirmed ||
                                  result.text == null) {
                                return;
                              }

                              descriptionController.text = result.text!.trim();
                            },
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
                                      descriptionController.text.trim().isEmpty
                                          ? context.l10n.addANote
                                          : descriptionController.text.trim(),
                                      textAlign: TextAlign.start,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: descriptionController.text
                                                .trim()
                                                .isEmpty
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

                        // Save button
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading.value
                                ? null
                                : () {
                                    handleSave();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.primaryForeground,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading.value
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? context
                                            .l10n.updateRecurringTransaction
                                        : context.l10n.addRecurringTransaction,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        if (isEditing) ...[
                          const SizedBox(height: 12),
                          DestructiveAdaptiveButton(
                            onPressed: isLoading.value ? null : handleDelete,
                            child:
                                Text(context.l10n.deleteRecurringTransaction),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCategoryRemapPrompt({
    required BuildContext toastContext,
    required String userId,
    required String transactionType,
    required String fromCategory,
    required String toCategory,
    required String fallbackSuccessMessage,
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

    if (result?.confirmed != true) {
      AppToast.success(toastContext, fallbackSuccessMessage);
      return;
    }

    final saved = await saveUserCategoryRemapPreferenceForUser(
      userId: userId,
      transactionType: transactionType,
      fromCategory: fromCategory,
      toCategory: toCategory,
    );

    if (!toastContext.mounted) return;

    if (saved) {
      AppToast.success(
        toastContext,
        toastContext.l10n.preferenceUpdatedSuccessfully,
      );
      return;
    }

    AppToast.success(toastContext, fallbackSuccessMessage);
  }

  Widget _buildDetailCard({
    required ColorScheme colorScheme,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isValuePlaceholder = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return MonekoDisclosureRow(
      label: label,
      value: value,
      onTap: onTap,
      isFirst: isFirst,
      isLast: isLast,
      isValuePlaceholder: isValuePlaceholder,
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

  /// Full sharing + split editor section for recurring expenses
  Widget _buildSharingAndSplitSection({
    required BuildContext context,
    required ColorScheme colorScheme,
    required List<Household> households,
    required ValueNotifier<bool> isSharedWithHousehold,
    required ValueNotifier<String?> selectedHouseholdId,
    required AsyncValue<List<HouseholdMember>> membersAsync,
    required ValueNotifier<String?> selectedPayerUserId,
    required ValueNotifier<SplitType?> customSplitType,
    required ValueNotifier<List<MemberSplit>?> customSplits,
    required TextEditingController amountController,
    required String currencySymbol,
    required bool isEditing,
    required String? currentUserId,
    bool showSharingControls = true,
  }) {
    if (households.isEmpty) {
      if (isSharedWithHousehold.value) {
        isSharedWithHousehold.value = false;
      }
      selectedHouseholdId.value = null;
      customSplitType.value = null;
      customSplits.value = null;
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSharingControls) ...[
          MonekoInput(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        value: isSharedWithHousehold.value,
                        onChanged: (value) {
                          if (!value) {
                            isSharedWithHousehold.value = false;
                            selectedHouseholdId.value = null;
                            customSplitType.value = null;
                            customSplits.value = null;
                            return;
                          }
                          if (households.isEmpty) return;
                          isSharedWithHousehold.value = true;
                          final currentId = selectedHouseholdId.value;
                          if (currentId == null ||
                              !households.any((h) => h.id == currentId)) {
                            selectedHouseholdId.value = households.first.id;
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (isSharedWithHousehold.value)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: () {
                          final currentId = selectedHouseholdId.value;
                          if (currentId != null &&
                              households.any((h) => h.id == currentId)) {
                            return currentId;
                          }
                          return households.first.id;
                        }(),
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: colorScheme.onSurface,
                        ),
                        items: households
                            .map(
                              (h) => DropdownMenuItem<String>(
                                value: h.id,
                                child: Text(
                                  h.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          selectedHouseholdId.value = value;
                          customSplitType.value = null;
                          customSplits.value = null;
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isSharedWithHousehold.value)
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
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

              final totalAmount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              // Initialize payer if not set.
              if (selectedPayerUserId.value == null && members.isNotEmpty) {
                if (!isEditing) {
                  // For ADD mode: prefer current user if they're a member.
                  final isCurrentUserMember = currentUserId != null &&
                      members.any((m) => m.userId == currentUserId);
                  selectedPayerUserId.value = isCurrentUserMember
                      ? currentUserId
                      : members.first.userId;
                }
                // For EDIT mode we intentionally do NOT override here.
                // The authoritative value should come from:
                // - existingTransaction.payerUserId (seeded in the
                //   initialization effect above), or
                // - the split group loader which reads payerUserId from
                //   the backend. This avoids clobbering the real payer with
                //   an arbitrary default like the first member.
              }
              if (selectedPayerUserId.value != null &&
                  !members.any((m) => m.userId == selectedPayerUserId.value)) {
                selectedPayerUserId.value =
                    members.isNotEmpty ? members.first.userId : null;
              }

              return GroupSplitEditorSection(
                members: members,
                selectedPayerUserId: selectedPayerUserId.value,
                onPayerChanged: (v) => selectedPayerUserId.value = v,
                totalAmount: totalAmount,
                currencySymbol: currencySymbol,
                initialSplitType: customSplitType.value,
                initialSplits: customSplits.value,
                splitEditorKey: ValueKey(
                  'recurring_split_${selectedHouseholdId.value}_${members.length}_${(totalAmount * 100).round()}',
                ),
                onSplitChanged: (splitType, splits) {
                  customSplitType.value = splitType;
                  customSplits.value = splits;
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  /// Map database SplitType (from expense_split.dart) to UI SplitType
  SplitType _mapDbSplitTypeToUiSplitType(dynamic dbSplitType) {
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
        return SplitType.amount;
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
}

Future<bool?> showAddRecurringSheet(
  BuildContext context, {
  required String type,
  RecurringTransaction? existingTransaction,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AddRecurringSheet(
        type: type,
        existingTransaction: existingTransaction,
      ),
    ),
  );
}

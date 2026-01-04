import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    hide SplitType;
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/moneko_switch.dart';
import 'package:moneko/features/utils/currency.dart';

/// Modern bottom sheet for adding/editing recurring transactions
/// Apple-inspired design with clean animations and intuitive UX
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

    final amountController = useTextEditingController(
      text: existingTransaction?.amount.toString() ?? '',
    );
    final descriptionController = useTextEditingController(
      text: existingTransaction?.description ?? '',
    );
    final sourceController = useTextEditingController(
      text: existingTransaction?.source ?? '',
    );
    final amountFocusNode = useFocusNode();

    // Rebuild when amount changes so splits can use the latest value
    useListenable(amountController);
    useListenable(amountFocusNode);
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
    final startDate = useState<DateTime>(
      existingTransaction?.recurrenceRule?.anchorDate ?? DateTime.now(),
    );
    final hasEndDate = useState<bool>(
      existingTransaction?.recurrenceRule?.endDate != null,
    );
    final endDate = useState<DateTime?>(
      existingTransaction?.recurrenceRule?.endDate,
    );
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
    final isLoading = useState<bool>(false);

    // View mode / household selection for default sharing behaviour
    final viewMode = ref.watch(viewModeProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final user = supabase.auth.currentUser;

    // Sharing + split state (expenses only)
    final isSharedWithHousehold = useState<bool>(
      existingTransaction != null
          ? (existingTransaction!.householdId != null)
          : (viewMode.mode == ViewMode.household &&
              selectedHouseholdState.householdId != null),
    );
    final selectedHouseholdId = useState<String?>(
      existingTransaction?.householdId ??
          (viewMode.mode == ViewMode.household
              ? selectedHouseholdState.householdId
              : null),
    );
    // Initialize payer to current user for ADD mode + household sharing
    final selectedPayerUserId = useState<String?>(
      existingTransaction?.payerUserId ??
          (!isEditing &&
                  viewMode.mode == ViewMode.household &&
                  selectedHouseholdState.householdId != null
              ? user?.id
              : null),
    );
    final customSplitType = useState<SplitType?>(null);
    final customSplits = useState<List<MemberSplit>?>(null);

    final householdsAsync = user != null
        ? ref.watch(userHouseholdsProvider(user.id))
        : const AsyncValue<List<Household>>.data([]);

    final membersAsync =
        (isSharedWithHousehold.value && selectedHouseholdId.value != null)
            ? ref.watch(householdMembersProvider(selectedHouseholdId.value!))
            : const AsyncValue<List<HouseholdMember>>.data([]);

    // When editing a shared recurring EXPENSE, load existing split configuration
    // from the household split groups so the inline split editor reflects the
    // latest backend state.
    useEffect(() {
      if (!isEditing || !isExpense) {
        return null;
      }
      if (existingTransaction?.householdId == null) {
        debugPrint(
            '🏠 [RECURRING LOAD SPLIT] Skipping - existing transaction is personal');
        return null;
      }
      if (!isSharedWithHousehold.value) {
        debugPrint(
            '🏠 [RECURRING LOAD SPLIT] Skipping - isSharedWithHousehold is FALSE');
        return null;
      }

      if (!membersAsync.hasValue) {
        debugPrint(
            '👥 [RECURRING LOAD SPLIT] Members not loaded yet, waiting for next rebuild');
        return null;
      }

      final members = membersAsync.value;
      if (members == null || members.isEmpty) {
        debugPrint(
            '👥 [RECURRING LOAD SPLIT] No household members available, aborting split load');
        return null;
      }

      Future.microtask(() async {
        final householdId = existingTransaction!.householdId!;
        final expenseId = existingTransaction!.id;
        debugPrint(
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

          debugPrint(
              '🔄 [RECURRING LOAD SPLIT] Retrieved ${effectiveSplits.length} split groups for household=$householdId');

          final matchingGroups = effectiveSplits
              .where((g) => g.expenseId == expenseId)
              .toList();

          if (matchingGroups.isEmpty) {
            debugPrint(
                '⚠️ [RECURRING LOAD SPLIT] No split group found for expenseId=$expenseId');
            return;
          }

          // If there are multiple groups (should be rare), prefer the newest
          matchingGroups.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
          );
          final splitGroup = matchingGroups.first;

          debugPrint(
              '✅ [RECURRING LOAD SPLIT] Using split group ${splitGroup.id} type=${splitGroup.splitType} lines=${splitGroup.splitLines?.length ?? 0}');

          final lines = splitGroup.splitLines;
          if (lines == null || lines.isEmpty) {
            debugPrint(
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
              debugPrint(
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

            debugPrint(
              '   [RECURRING LOAD SPLIT] Member ${member.userName ?? member.userEmail}: amountCents=${matchingLine.amountCents}',
            );
          }

          if (memberSplits.isEmpty) {
            debugPrint(
                '⚠️ [RECURRING LOAD SPLIT] No usable member splits after mapping');
            return;
          }

          final uiSplitType =
              _mapDbSplitTypeToUiSplitType(splitGroup.splitType);

          customSplitType.value = uiSplitType;
          customSplits.value = memberSplits;

          if (selectedPayerUserId.value == null &&
              splitGroup.payerUserId.isNotEmpty) {
            selectedPayerUserId.value = splitGroup.payerUserId;
          }

          debugPrint(
              '✅ [RECURRING LOAD SPLIT] Initialized split editor for recurring expense $expenseId with type=$uiSplitType, members=${memberSplits.length}, payer=${selectedPayerUserId.value}');
        } catch (error, stackTrace) {
          debugPrint(
              '❌ [RECURRING LOAD SPLIT] Error loading split configuration: $error');
          debugPrint('   Stack: $stackTrace');
        }
      });

      return null;
    }, [
      isEditing,
      isExpense,
      existingTransaction?.id,
      existingTransaction?.householdId,
      isSharedWithHousehold.value,
      membersAsync,
    ]);

    // Parsed amount used for split editor defaults
    final parsedAmount = double.tryParse(amountController.text.trim());
    final hasAmountForSplit = parsedAmount != null && parsedAmount > 0;

    // Track when amount flips from empty -> has value so we can auto-set sharing once
    final hasAmountEverBeenSet = useRef(false);
    if (hasAmountForSplit && !hasAmountEverBeenSet.value) {
      hasAmountEverBeenSet.value = true;
    }

    // Initialize payer when household mode is active on mount
    useEffect(() {
      debugPrint('🏠 [ADD RECURRING] Initializing payer for household mode');
      debugPrint('   isEditing: $isEditing');
      debugPrint('   viewMode: ${viewMode.mode}');
      debugPrint('   isSharedWithHousehold: ${isSharedWithHousehold.value}');
      debugPrint('   selectedHouseholdId: ${selectedHouseholdId.value}');
      
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
        debugPrint('   Setting payer from existing transaction: ${existingTransaction!.payerUserId}');
        selectedPayerUserId.value = existingTransaction!.payerUserId;
      }

      // Only for ADD mode in household mode
      if (!isEditing && 
          viewMode.mode == ViewMode.household && 
          isSharedWithHousehold.value &&
          selectedHouseholdId.value != null &&
          selectedPayerUserId.value == null &&
          user?.id != null) {
        debugPrint('   Setting payer to current user: ${user!.id}');
        selectedPayerUserId.value = user.id;
      }
      return null;
    }, []);
    
    // When amount becomes available for the first time in ADD mode, ensure sharing defaults to view mode
    // CRITICAL FIX: Always set sharing state based on view mode, not just the first time
    // This ensures the toggle properly reflects the current mode when it becomes visible
    useEffect(() {
      if (isEditing) return null;
      if (!hasAmountForSplit) return null;

      final shouldBeShared = viewMode.mode == ViewMode.household;

      // Always update when amount is present to ensure correct state
      // Previous logic only updated if hasAmountEverBeenSet, but this could miss cases
      // where the state got out of sync
      debugPrint(
          '🔄 [ADD RECURRING] Amount present; ensuring isSharedWithHousehold matches view mode');
      debugPrint('   Should be shared (view mode only): $shouldBeShared');
      debugPrint('   ViewMode: ${viewMode.mode}');
      debugPrint('   HouseholdId (selected state): ${selectedHouseholdState.householdId}');
      debugPrint('   Current isSharedWithHousehold: ${isSharedWithHousehold.value}');
      debugPrint('   HouseholdId (selected local): ${selectedHouseholdId.value}');

      // If in household mode but no household selected yet, pick one from available households
      if (shouldBeShared && selectedHouseholdId.value == null) {
        final households = householdsAsync.valueOrNull;
        if (households != null && households.isNotEmpty) {
          selectedHouseholdId.value =
              selectedHouseholdState.householdId ?? households.first.id;
          debugPrint('   ✅ [ADD RECURRING] Auto-selected householdId: ${selectedHouseholdId.value}');
        } else {
          debugPrint('   ⚠️ [ADD RECURRING] No households available to auto-select');
        }
      }

      final resolvedShouldShare = shouldBeShared &&
          (selectedHouseholdState.householdId != null ||
              selectedHouseholdId.value != null);
      debugPrint('   Resolved shouldShare (after household pick): $resolvedShouldShare');
      
      // Only update if it doesn't match the expected state
      // This prevents unnecessary rebuilds but ensures correctness
      if (isSharedWithHousehold.value != resolvedShouldShare) {
        debugPrint('   ⚠️ State mismatch! Correcting to: $resolvedShouldShare');
        isSharedWithHousehold.value = resolvedShouldShare;
        if (resolvedShouldShare) {
          selectedPayerUserId.value ??= existingTransaction?.payerUserId ?? user?.id;
        } else if (viewMode.mode != ViewMode.household) {
          selectedHouseholdId.value = null;
        }
      }
      
      // Mark that we've processed the amount at least once
      if (!hasAmountEverBeenSet.value) {
        hasAmountEverBeenSet.value = true;
      }
      
      return null;
    }, [hasAmountForSplit, viewMode.mode, selectedHouseholdState.householdId, householdsAsync.value]);

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

    Future<void> handleSave() async {
      final l10n = context.l10n;
      if (selectedCategory.value == null) {
        debugPrint('🔴 Error: No category selected');
        AppToast.error(context, context.l10n.pleaseSelectCategory);
        return;
      }

      final amountText = amountController.text.trim();
      if (amountText.isEmpty) {
        AppToast.error(context, context.l10n.pleaseEnterAmount);
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        AppToast.error(context, context.l10n.pleaseEnterValidAmount);
        return;
      }

      isLoading.value = true;

      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          AppToast.error(context, context.l10n.userNotAuthenticated);
          isLoading.value = false;
          return;
        }

        RecurringTransaction? result;

        // Determine sharing/splitting configuration
        final shareWithHousehold =
            isSharedWithHousehold.value && selectedHouseholdId.value != null;
        final activeHouseholdId =
            shareWithHousehold ? selectedHouseholdId.value : null;
        debugPrint('💾 [RECURRING SAVE] share=$shareWithHousehold hh=$activeHouseholdId payer=${selectedPayerUserId.value}');
        debugPrint('   Custom split type: ${customSplitType.value}');
        debugPrint(
            '   Custom splits count: ${customSplits.value?.length ?? 0}');

        if (isExpense) {
          if (isEditing) {
            // UPDATE existing expense
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringExpense(
                  userId: user.id,
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
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  previousHouseholdId: existingTransaction?.householdId,
                  customSplitType:
                      shareWithHousehold ? customSplitType.value : null,
                  customSplits: shareWithHousehold ? customSplits.value : null,
                  payerUserId: shareWithHousehold
                      ? (selectedPayerUserId.value ?? user.id)
                      : null,
                );
          } else {
            // CREATE new expense
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringExpense(
                  userId: user.id,
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
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                  customSplitType:
                      shareWithHousehold ? customSplitType.value : null,
                  customSplits: shareWithHousehold ? customSplits.value : null,
                  payerUserId: shareWithHousehold
                      ? (selectedPayerUserId.value ?? user.id)
                      : null,
                );
          }
        } else {
          if (isEditing) {
            // UPDATE existing income
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .updateRecurringIncome(
                  userId: user.id,
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
                  source: sourceController.text.trim().isEmpty
                      ? null
                      : sourceController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                );
          } else {
            // CREATE new income
            result = await ref
                .read(recurringTransactionSaveProvider.notifier)
                .saveRecurringIncome(
                  userId: user.id,
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
                  source: sourceController.text.trim().isEmpty
                      ? null
                      : sourceController.text.trim(),
                  hasReminder: hasReminder.value,
                  reminderValue: hasReminder.value ? reminderValue.value : null,
                  reminderUnit: hasReminder.value ? reminderUnit.value : null,
                  householdId: activeHouseholdId,
                );
          }
        }

        isLoading.value = false;

        if (result != null) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('✅ [SAVE RECURRING] Transaction saved successfully');
          debugPrint('   Transaction ID: ${result.id}');
          debugPrint('   Type: ${result.type}');
          debugPrint('   Category: ${result.category}');
          debugPrint('   Amount: ${result.amount} ${result.currency}');
          debugPrint('   HouseholdId: ${result.householdId}');
          debugPrint('   Has RecurrenceRule: ${result.recurrenceRule != null}');
          debugPrint('   Frequency: ${result.recurrenceRule?.frequency ?? "one-time"}');
          
          // Get current view mode to determine which scope to refresh
          final currentViewMode = ref.read(viewModeProvider);
          final currentHouseholdId = ref.read(selectedHouseholdProvider).householdId;
          
          debugPrint('🔄 [REFRESH] Current view mode: ${currentViewMode.mode}');
          debugPrint('🔄 [REFRESH] Current household ID: $currentHouseholdId');
          debugPrint('🔄 [REFRESH] Transaction household ID (activeHouseholdId): $activeHouseholdId');
          
          // CRITICAL: Force refresh based on CURRENT VIEW MODE
          // This ensures the page the user is viewing refreshes immediately
          if (currentViewMode.mode == ViewMode.household && currentHouseholdId != null) {
            debugPrint('🏠 [REFRESH] Refreshing HOUSEHOLD view for: $currentHouseholdId');
            
            // Invalidate RequestDeduplicator cache for household data
            ref.read(cacheInvalidatorProvider).invalidateHouseholdData(currentHouseholdId);
            // Mirror unified_transaction_sheet: invalidate the full
            // household split provider families so ALL consumers
            // (recurring sheet, dashboard, etc.) are forced to
            // reload from the backend.
            ref.invalidate(householdSplitsProvider);
            ref.invalidate(cachedHouseholdSplitsProvider);
            
            // Force refresh (not invalidate) to reload data while keeping state
            debugPrint('   🔄 Forcing refresh of recurringTransactionsProvider($currentHouseholdId)');
            await ref.read(recurringTransactionsProvider(currentHouseholdId).notifier)
                .refresh(user.id);
            
            debugPrint('   ♻️  Invalidating pocketsProvider family (household view)');
            ref.invalidate(pocketsProvider);
          } else {
            debugPrint('👤 [REFRESH] Refreshing PERSONAL view');
            
            // Force refresh (not invalidate) to reload data while keeping state
            debugPrint('   🔄 Forcing refresh of recurringTransactionsProvider(null)');
            await ref.read(recurringTransactionsProvider(null).notifier)
                .refresh(user.id);
            
            debugPrint('   ♻️  Invalidating pocketsProvider family (personal view)');
            ref.invalidate(pocketsProvider);
          }
          
          // ALSO refresh the scope where the transaction is actually stored (if different from current view)
          // This ensures consistency across all scopes
          if (activeHouseholdId != null && activeHouseholdId != currentHouseholdId) {
            debugPrint('🔄 [REFRESH] Also refreshing transaction storage scope: $activeHouseholdId');
            ref.read(cacheInvalidatorProvider).invalidateHouseholdData(activeHouseholdId);
            // Ensure all household split consumers for this scope
            // also reload, not just the cached provider.
            ref.invalidate(householdSplitsProvider);
            ref.invalidate(cachedHouseholdSplitsProvider);
            
            debugPrint('   🔄 Forcing refresh of recurringTransactionsProvider($activeHouseholdId)');
            await ref.read(recurringTransactionsProvider(activeHouseholdId).notifier)
                .refresh(user.id);
            
            debugPrint('   ♻️  Invalidating pocketsProvider family (transaction household scope)');
            ref.invalidate(pocketsProvider);
          } else if (activeHouseholdId == null && currentViewMode.mode == ViewMode.household) {
            // Transaction is personal but we're in household view - also refresh personal scope
            debugPrint('🔄 [REFRESH] Also refreshing personal scope (transaction is personal)');
            
            debugPrint('   🔄 Forcing refresh of recurringTransactionsProvider(null)');
            await ref.read(recurringTransactionsProvider(null).notifier)
                .refresh(user.id);
            
            debugPrint('   ♻️  Invalidating pocketsProvider family (personal scope)');
            ref.invalidate(pocketsProvider);
          }

          // Keep currency selector counts up-to-date.
          ref.invalidate(currencyTransactionCountsProvider);
          
          debugPrint('✅ [REFRESH] All providers refreshed/invalidated successfully');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          if (context.mounted) {
            Navigator.of(context).pop();
            final successMsg = isExpense
                ? (isEditing
                    ? l10n.recurringExpenseUpdatedSuccessfully
                    : l10n.recurringExpenseAddedSuccessfully)
                : (isEditing
                    ? l10n.recurringIncomeUpdatedSuccessfully
                    : l10n.recurringIncomeAddedSuccessfully);
            AppToast.success(context, successMsg);
          }
        } else {
          // Surface raw backend/provider error message if available.
          String? detailedError;
          final saveState = ref.read(recurringTransactionSaveProvider);

          saveState.when(
            data: (_) {},
            loading: () {},
            error: (err, _) {
              detailedError = err.toString();
            },
          );

          final msg = (detailedError != null && detailedError!.trim().isNotEmpty)
              ? detailedError!
              : 'Failed to save recurring transaction';

          if (context.mounted) {
            AppToast.error(context, msg);
          }
        }
      } catch (e) {
        isLoading.value = false;
        if (!context.mounted) {
          return;
        }

        String? detailedError;
        final saveState = ref.read(recurringTransactionSaveProvider);

        saveState.when(
          data: (_) {},
          loading: () {},
          error: (err, _) {
            detailedError = err.toString();
          },
        );

        final msg = (detailedError != null && detailedError!.trim().isNotEmpty)
            ? detailedError!
            : e.toString();

        AppToast.error(context, msg);
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height *
            0.85, // Limit to 85% of screen height
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? (isExpense
                              ? context.l10n.editRecurringExpense
                              : context.l10n.editRecurringIncome)
                          : (isExpense
                              ? context.l10n.addRecurringExpense
                              : context.l10n.addRecurringIncome),
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isLoading.value ? null : handleSave,
                    icon: isLoading.value
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.foreground,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.check_rounded,
                            color: colorScheme.foreground,
                          ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type toggle
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.muted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.l10n.expenses,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isExpense
                                        ? Colors.white
                                        : colorScheme.foreground,
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !isExpense
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.l10n.income,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: !isExpense
                                        ? Colors.white
                                        : colorScheme.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Amount input
                    _buildLabel(context.l10n.amount, colorScheme),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      focusNode: amountFocusNode,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () => amountFocusNode.unfocus(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          color: colorScheme.mutedForeground,
                        ),
                        filled: true,
                        fillColor: colorScheme.muted.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.controlBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.controlBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                          ),
                        ),
                        suffixIcon: amountFocusNode.hasFocus
                            ? IconButton(
                                icon: Icon(
                                  Icons.check_rounded,
                                  color: colorScheme.primary,
                                ),
                                splashRadius: 18,
                                onPressed: () => amountFocusNode.unfocus(),
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.category,
                    value: selectedCategory.value != null
                        ? getCategoryTranslation(
                            context, selectedCategory.value!)
                        : context.l10n.selectCategory,
                    onTap: () async {
                      final result = await showCategoryPicker(
                        context: context,
                        // When no category is selected, pass an empty string so
                        // the picker shows with no preselection. Existing
                        // transactions still pass their actual category.
                        currentCategory: selectedCategory.value ?? '',
                        isIncome: !isExpense,
                      );
                      if (result != null) {
                        selectedCategory.value = result;
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Currency selector
                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.currency,
                    value: selectedCurrency.value.toUpperCase(),
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

                  const SizedBox(height: 20),

                  // Household sharing + split (expenses only)
                  if (user != null) ...[
                    householdsAsync.when(
                      data: (households) {
                        if (!hasAmountForSplit) {
                          // Require an amount before configuring splits
                          return Text(
                            context.l10n.pleaseEnterAmount,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                            ),
                          );
                        }

                        if (households.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        if (!isExpense) {
                          // For income: only allow sharing toggle, no split editor
                          return _buildSharingToggleOnly(
                            context,
                            colorScheme,
                            households,
                            isSharedWithHousehold,
                            selectedHouseholdId,
                          );
                        }

                        return _buildSharingAndSplitSection(
                          context: context,
                          colorScheme: colorScheme,
                          households: households,
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
                          currentUserId: user.id,
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.frequency,
                    value: () {
                      // Get the label for the current frequency
                      final freq =
                          getDefaultFrequencyOptions(context).firstWhere(
                        (f) => f.value == selectedFrequency.value,
                        orElse: () => getDefaultFrequencyOptions(
                            context)[3], // Default to 'monthly'
                      );
                      return freq.label;
                    }(),
                    onTap: () async {
                      final result = await showFrequencyPicker(
                        context: context,
                        currentFrequency: selectedFrequency.value,
                      );
                      if (result != null) {
                        selectedFrequency.value = result;
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildDetailCard(
                    colorScheme: colorScheme,
                    label: context.l10n.startDate,
                    value: formatLocalizedDate(context, startDate.value,
                        includeYear: true),
                    onTap: () async {
                      final result = await showTransactionDatePicker(
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

                  const SizedBox(height: 20),

                  // End date toggle (clickable container)
                  GestureDetector(
                    onTap: () {
                      hasEndDate.value = !hasEndDate.value;
                      if (!hasEndDate.value) {
                        endDate.value = null;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.muted.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.controlBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: hasEndDate.value,
                            activeColor: colorScheme.primary,
                            onChanged: (value) {
                              final checked = value ?? false;
                              hasEndDate.value = checked;
                              if (!checked) {
                                endDate.value = null;
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.setEndDate,
                              style: TextStyle(
                                color: colorScheme.foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // End date picker (if enabled)
                  if (hasEndDate.value) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      colorScheme: colorScheme,
                      label: context.l10n.endDate,
                      value: endDate.value != null
                          ? formatLocalizedDate(context, endDate.value!,
                              includeYear: true)
                          : context.l10n.selectEndDate,
                      onTap: () async {
                        final result = await showTransactionDatePicker(
                          context: context,
                          currentDate: endDate.value ??
                              startDate.value.add(const Duration(days: 365)),
                          firstDate: startDate.value,
                          lastDate: DateTime(2030),
                        );
                        if (result != null) {
                          endDate.value = result;
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Description
                  _buildLabel(context.l10n.descriptionOptional, colorScheme),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    style: TextStyle(
                      color: colorScheme.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.addANote,
                      hintStyle: TextStyle(
                        color: colorScheme.mutedForeground,
                      ),
                      filled: true,
                      fillColor: colorScheme.muted.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.controlBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.controlBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  // Source (for income only)
                  if (!isExpense) ...[
                    const SizedBox(height: 20),
                    _buildLabel(context.l10n.sourceOptional, colorScheme),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sourceController,
                      style: TextStyle(
                        color: colorScheme.foreground,
                      ),
                      decoration: InputDecoration(
                        hintText: context.l10n.companyNameClientNameExample,
                        hintStyle: TextStyle(
                          color: colorScheme.mutedForeground,
                        ),
                        filled: true,
                        fillColor: colorScheme.muted.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.controlBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.controlBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Reminder toggle (clickable container)
                  GestureDetector(
                    onTap: () {
                      hasReminder.value = !hasReminder.value;
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.muted.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.controlBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: hasReminder.value,
                            activeColor: colorScheme.primary,
                            onChanged: (value) {
                              hasReminder.value = value ?? false;
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.setReminder,
                              style: TextStyle(
                                color: colorScheme.foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reminder configuration (if enabled)
                  if (hasReminder.value) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        // Detect word order based on language
                        final lang = Localizations.localeOf(context)
                            .languageCode
                            .toLowerCase();
                        final useSOV = {
                          'zh',
                          'ja',
                          'ko',
                          'hi',
                          'ur',
                          'tr',
                          'fa'
                        }.contains(lang);

                        // Build UI components
                        final valueInput = SizedBox(
                          width: 80,
                          child: TextField(
                            controller: TextEditingController(
                              text: reminderValue.value.toString(),
                            ),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                            decoration: InputDecoration(
                              hintText: '1',
                              hintStyle: TextStyle(
                                color: colorScheme.mutedForeground,
                              ),
                              filled: true,
                              fillColor:
                                  colorScheme.muted.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      colorScheme.controlBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      colorScheme.controlBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                reminderValue.value = parsed;
                              }
                            },
                          ),
                        );

                        final unitPicker = GestureDetector(
                          onTap: () async {
                            final result =
                                await showTransactionSelectionSheet<String>(
                              context: context,
                              items: ['days'],
                              getLabel: (unit) {
                                if (unit == 'days') return context.l10n.days;
                                if (unit == 'hours') return context.l10n.hours;
                                return unit;
                              },
                              initial: reminderUnit.value,
                            );
                            if (result != null) {
                              reminderUnit.value = result;
                            }
                          },
                          child: IntrinsicWidth(
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 80), // Minimum width
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.muted.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      colorScheme.controlBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: colorScheme.mutedForeground,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        // Arrange based on word order
                        List<Widget> rowChildren;
                        if (useSOV) {
                          // SOV languages: beforePrefix [value][unit]beforeSuffix
                          // Chinese: 在 2天之前
                          rowChildren = [
                            Text(
                              context.l10n.beforePrefix,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            valueInput,
                            const SizedBox(width: 12),
                            unitPicker,
                            const SizedBox(width: 12),
                            Text(
                              context.l10n.beforeSuffix,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ];
                        } else {
                          // Default SVO: [value] [unit] before
                          // English: 2 days before
                          rowChildren = [
                            valueInput,
                            const SizedBox(width: 12),
                            unitPicker,
                            const SizedBox(width: 12),
                            Text(
                              context.l10n.before,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ];
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: rowChildren,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.youWillBeNotifiedBeforeEachOccurrence(
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
                  ],

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
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading.value
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
                              isEditing
                                  ? context.l10n.updateRecurringTransaction
                                  : context.l10n.addRecurringTransaction,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLabel(String text, ColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        color: colorScheme.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDetailCard({
    required ColorScheme colorScheme,
    required String label,
    required String value,
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
          border: Border.all(
            color: colorScheme.controlBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.mutedForeground,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Simple sharing toggle used for incomes (no split editor)
  Widget _buildSharingToggleOnly(
    BuildContext context,
    ColorScheme colorScheme,
    List<Household> households,
    ValueNotifier<bool> isSharedWithHousehold,
    ValueNotifier<String?> selectedHouseholdId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.controlBorder,
        ),
      ),
      child: Row(
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
            value: isSharedWithHousehold.value,
            activeColor: colorScheme.primary,
            onChanged: (value) {
              if (!value) {
                isSharedWithHousehold.value = false;
                return;
              }
              if (households.isEmpty) return;
              isSharedWithHousehold.value = true;
              selectedHouseholdId.value ??= households.first.id;
            },
          ),
        ],
      ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle + household dropdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.controlBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.shareWithHousehold,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSharedWithHousehold.value)
                      DropdownButtonHideUnderline(
                        child: IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth:
                                  200, // Maximum width to prevent overflow
                            ),
                            child: DropdownButton<String>(
                              value: selectedHouseholdId.value ??
                                  households.first.id,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: colorScheme.foreground,
                              ),
                              items: households
                                  .map(
                                    (h) => DropdownMenuItem<String>(
                                      value: h.id,
                                      child: Text(
                                        h.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                selectedHouseholdId.value = value;
                                // Reset splits when switching households
                                customSplitType.value = null;
                                customSplits.value = null;
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              MonekoSwitch(
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
                  selectedHouseholdId.value ??= households.first.id;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isSharedWithHousehold.value)
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Text(
                  context.l10n.selectHouseholdToConfigureSplit,
                  style: TextStyle(color: colorScheme.mutedForeground),
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

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.muted.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
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
                              value: selectedPayerUserId.value,
                              items: members
                                  .map(
                                    (m) => DropdownMenuItem<String>(
                                      value: m.userId,
                                      child: Text(
                                        m.userName ??
                                            m.userEmail ??
                                            context.l10n.member,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => selectedPayerUserId.value = v,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomSplitEditor(
                      key: ValueKey(
                        'recurring_split_${selectedHouseholdId.value}_${members.length}_${(totalAmount * 100).round()}',
                      ),
                      members: members,
                      totalAmount: totalAmount,
                      currencySymbol: currencySymbol,
                      initialSplitType: customSplitType.value,
                      initialSplits: customSplits.value,
                      onChanged: (splitType, splits) {
                        customSplitType.value = splitType;
                        customSplits.value = splits;
                      },
                    ),
                  ],
                ),
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
}

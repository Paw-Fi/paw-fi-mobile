import 'dart:async';

import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_lineage_mutations.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/utils/pocket_budget_amount_steps.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/rounded_logo_picker.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

const _pocketRolloverHelpPreferenceKey = 'has_seen_pocket_rollover_help';

String _newPocketLifecycleOperationId() {
  final values =
      List<int>.generate(16, (_) => math.Random.secure().nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex =
      values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class EditPocketEnvelopeSheet extends HookConsumerWidget {
  const EditPocketEnvelopeSheet({
    super.key,
    required this.scopeParams,
    this.existingEnvelope,
    this.template,
    this.initialCategories = const [],
    required this.totalBudget,
    required this.unallocatedBudget,
    required this.budgetId,
    this.allPockets = const [],
    this.onDeleteCompleted,
    this.onSaveOffline,
    this.confirmController,
  });

  static Future<void> show({
    required BuildContext context,
    required PocketsScopeParams scopeParams,
    PocketEnvelope? existingEnvelope,
    PocketTemplate? template,
    List<String> initialCategories = const [],
    required double totalBudget,
    required double unallocatedBudget,
    required String? budgetId,
    List<PocketEnvelope> allPockets = const [],
    VoidCallback? onDeleteCompleted,
    ValueChanged<PocketTemplate>? onSaveOffline,
  }) {
    final confirmController = MonekoSheetConfirmController();
    final sheet = MonekoBottomSheet.show<void>(
      context: context,
      title: existingEnvelope != null
          ? context.l10n.editPocket
          : context.l10n.addPocket,
      isScrollControlled: true,
      onClose: () => Navigator.pop(context),
      confirmController: confirmController,
      builder: (context) => EditPocketEnvelopeSheet(
        scopeParams: scopeParams,
        existingEnvelope: existingEnvelope,
        template: template,
        initialCategories: initialCategories,
        totalBudget: totalBudget,
        unallocatedBudget: unallocatedBudget,
        budgetId: budgetId,
        allPockets: allPockets,
        onDeleteCompleted: onDeleteCompleted,
        onSaveOffline: onSaveOffline,
        confirmController: confirmController,
      ),
    );
    sheet.whenComplete(confirmController.dispose);
    return sheet;
  }

  final PocketsScopeParams scopeParams;
  final PocketEnvelope? existingEnvelope;
  final PocketTemplate? template;
  final List<String> initialCategories;
  final double totalBudget;
  final double unallocatedBudget;
  final String? budgetId;
  final List<PocketEnvelope> allPockets;
  final VoidCallback? onDeleteCompleted;
  final ValueChanged<PocketTemplate>? onSaveOffline;
  final MonekoSheetConfirmController? confirmController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = existingEnvelope != null;
    final selectedCurrency = scopeParams.currency?.trim().isNotEmpty == true
        ? scopeParams.currency!.trim()
        : 'USD';

    final nameController = useTextEditingController(
      text: existingEnvelope?.name ?? template?.name ?? '',
    );
    useListenable(nameController);

    final initialAmountText = existingEnvelope != null
        ? formatAmount(centsToAmount(existingEnvelope!.budgetAmountCents))
        : '';
    final amountController = useTextEditingController(text: initialAmountText);
    useListenable(amountController);

    final selectedCategories = useState<List<String>>(
      existingEnvelope == null
          ? (template?.suggestedCategories ?? initialCategories)
          : (initialCategories.isNotEmpty ? initialCategories : []),
    );

    // Helper to extract hex from template color
    String? getTemplateColorHex() {
      if (template?.color == null) return null;
      // Convert to ARGB32 int first (replaces deprecated .value)
      // Note: toARGB32() returns int in 0xAARRGGBB format
      // We need #RRGGBB
      final value = (template!.color!.r * 255).round() << 16 |
          (template!.color!.g * 255).round() << 8 |
          (template!.color!.b * 255).round();

      final hex = value.toRadixString(16).padLeft(6, '0');
      return '#$hex';
    }

    final selectedColor =
        useState<String?>(existingEnvelope?.color ?? getTemplateColorHex());

    final selectedLogoUrl = useState<String?>(existingEnvelope?.logoUrl);
    final selectedIcon = useState<String?>(
      existingEnvelope?.logoUrl != null &&
              existingEnvelope?.logoUrl?.isNotEmpty == true
          ? null
          : (existingEnvelope?.icon ?? template?.iconName),
    );
    final isLoading = useState<bool>(false);
    final prefs = ref.read(sharedPreferencesProvider);
    final rolloverEnabled = useState<bool>(
      existingEnvelope?.rolloverEnabled ?? false,
    );
    final rolloverNegative = useState<bool>(
      existingEnvelope?.rolloverNegative ?? false,
    );
    final hasSeenRolloverHelp = useState<bool>(
      prefs.getBool(_pocketRolloverHelpPreferenceKey) ?? false,
    );
    final rolloverCapController = useTextEditingController(
      text: existingEnvelope?.rolloverCapCents == null
          ? ''
          : formatAmount(centsToAmount(existingEnvelope!.rolloverCapCents!)),
    );
    useListenable(rolloverCapController);
    final pocketsState = ref.watch(pocketsProvider(scopeParams));
    final lineageMetadata = existingEnvelope?.rolloverGroupId == null
        ? null
        : pocketsState
            .pocketLineageMetadataById[existingEnvelope!.rolloverGroupId!];
    final fundingPolicy = useState<String>('decide_each_cycle');
    final fundingTargetController = useTextEditingController();
    useListenable(fundingTargetController);
    final currency = selectedCurrency;
    final allocationStepCents = pocketBudgetAdjustmentStepCents(currency);
    final totalBudgetCents = quantizePocketBudgetAmountCents(
      (totalBudget * 100).round(),
      stepCents: allocationStepCents,
    );
    final maxBudgetCents = math.max(0, totalBudgetCents);
    final viewedMonth = scopeParams.periodMonth ?? DateTime.now();
    final monthStart = financialCycleStartForDate(
      viewedMonth,
      startDay: scopeParams.normalizedFinancialMonthStartDay,
    );
    final periodMonth =
        '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}-01';
    final previewAmountCents = quantizePocketBudgetAmountCents(
      (tryParseMoneyToCents(amountController.text) ??
              existingEnvelope?.budgetAmountCents ??
              0)
          .clamp(0, maxBudgetCents)
          .toInt(),
      stepCents: allocationStepCents,
    );
    final previewShare =
        maxBudgetCents > 0 ? (previewAmountCents / maxBudgetCents) * 100 : 0.0;
    final sliderPercent = previewShare.clamp(0.0, 100.0);
    final siblingPockets = allPockets
        .where((pocket) => pocket.id != existingEnvelope?.id)
        .toList(growable: false);

    final previewSiblingAmounts = siblingPockets
        .map((pocket) => pocket.budgetAmountCents)
        .toList(growable: false);
    final previewAllocatedCents = previewAmountCents +
        previewSiblingAmounts.fold<int>(0, (sum, amount) => sum + amount);
    final previewExceededBudgetCents =
        math.max(0, previewAllocatedCents - totalBudgetCents);
    void setRolloverEnabled(bool value) {
      rolloverEnabled.value = value;
      if (value && !hasSeenRolloverHelp.value) {
        hasSeenRolloverHelp.value = true;
        unawaited(
          prefs
              .setBool(_pocketRolloverHelpPreferenceKey, true)
              .then<void>((_) {}),
        );
      }
      if (!value) {
        rolloverNegative.value = false;
      }
    }

    useEffect(() {
      if (!isEditing) return null;
      final categories = pocketsState.envelopeCategories[existingEnvelope!.id];
      if (categories != null) selectedCategories.value = categories;
      return null;
    }, [
      isEditing ? existingEnvelope!.id : null,
      pocketsState.envelopeCategories
    ]);

    useEffect(() {
      final metadata = lineageMetadata;
      if (metadata == null) return null;
      fundingPolicy.value = metadata.fundingPolicy;
      fundingTargetController.text = metadata.fundingTargetCents == null
          ? ''
          : formatAmount(centsToAmount(metadata.fundingTargetCents!));
      return null;
    }, [lineageMetadata?.lineageId, lineageMetadata?.revision]);

    final lists = ref.watch(userCategoryListsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
    final allCategories = lists?.expenseCategories ?? getExpenseCategories();
    final builtinExpenseCategories = getExpenseCategories().toSet();
    final customExpenseCategories = allCategories
        .where(
          (category) =>
              !builtinExpenseCategories.contains(category) &&
              category != 'other' &&
              category != 'uncategorized',
        )
        .toList(growable: false);

    String formatLocalizedAmount(num value) {
      final normalized = double.parse(formatAmount(value.toDouble()));
      return formatLocalizedNumber(context, normalized);
    }

    String normalizeEnteredAmountText(String value) {
      final amountCents = tryParseMoneyToCents(value);
      if (amountCents == null) {
        return value;
      }

      final normalizedCents = quantizePocketBudgetAmountCents(
        amountCents.clamp(0, maxBudgetCents).toInt(),
        stepCents: allocationStepCents,
      );
      return formatAmount(centsToAmount(normalizedCents));
    }

    Future<void> handleSave() async {
      final l10n = context.l10n;
      FocusScope.of(context).unfocus();
      final name = nameController.text.trim();

      if (name.isEmpty) {
        AppToast.error(context, l10n.pleaseEnterPocketName);
        return;
      }

      final amountCents = tryParseMoneyToCents(amountController.text);
      if (amountCents == null) {
        AppToast.error(context, l10n.pleaseEnterAmount);
        return;
      }
      final clampedAmountCents = quantizePocketBudgetAmountCents(
        amountCents.clamp(0, maxBudgetCents).toInt(),
        stepCents: allocationStepCents,
      );
      final rolloverEnabledValue = rolloverEnabled.value;
      final rolloverNegativeValue =
          rolloverEnabledValue && rolloverNegative.value;
      int? rolloverCapCentsValue;
      if (rolloverEnabledValue) {
        final capText = rolloverCapController.text.trim();
        if (capText.isNotEmpty) {
          final parsedCapCents = tryParseMoneyToCents(capText);
          if (parsedCapCents == null || parsedCapCents < 0) {
            AppToast.error(context, l10n.pocketRolloverInvalidCapError);
            return;
          }
          rolloverCapCentsValue = parsedCapCents;
        }
      }
      final existingCarryCents = rolloverEnabledValue
          ? (existingEnvelope?.rolloverFromPreviousCents ?? 0)
          : 0;
      final optimisticRolloverBreakdown = calculatePocketRolloverBreakdownCents(
        baseBudgetCents: clampedAmountCents,
        spentCents: ((existingEnvelope?.spent ?? 0) * 100).round(),
        incomingRolloverCents: existingCarryCents,
        rolloverEnabled: rolloverEnabledValue,
        rolloverNegative: rolloverNegativeValue,
        rolloverCapCents: rolloverCapCentsValue,
        openingRolloverCents: 0,
      );

      if (selectedCategories.value.isEmpty) {
        AppToast.info(context, l10n.pleaseSelectCategory);
        return;
      }
      final existingLineage = lineageMetadata;
      if (isEditing && existingLineage == null) {
        AppToast.info(context, l10n.pocketLifecycleLoading);
        return;
      }
      final selectedFundingPolicy = fundingPolicy.value;
      final fundingTargetCents = selectedFundingPolicy == 'decide_each_cycle'
          ? null
          : tryParseMoneyToCents(fundingTargetController.text);
      if (selectedFundingPolicy != 'decide_each_cycle' &&
          (fundingTargetCents == null || fundingTargetCents < 0)) {
        AppToast.error(context, l10n.pocketFundingAmountRequired);
        return;
      }

      if (ref.read(previewModeProvider).isActive) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.success(
          context,
          existingEnvelope != null
              ? l10n.previewPocketUpdated
              : l10n.previewPocketCreated,
        );
        return;
      }

      // Offline mode: Return data directly without DB calls
      if (onSaveOffline != null) {
        final derivedWeight =
            totalBudgetCents > 0 ? clampedAmountCents / totalBudgetCents : 0.0;
        final newTemplate = PocketTemplate(
          name: name,
          weight: derivedWeight,
          iconName: selectedIcon.value ?? 'category',
          suggestedCategories: selectedCategories.value,
          color: selectedColor.value != null
              ? Color(int.parse(selectedColor.value!.replaceFirst('#', ''),
                      radix: 16) +
                  0xFF000000)
              : null,
        );
        onSaveOffline!(newTemplate);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        AppToast.info(context, l10n.userNotAuthenticated);
        return;
      }

      final isScopedToHousehold =
          scopeParams.scope != PocketsScopeType.personal;
      final householdId = scopeParams.householdId;

      if (isScopedToHousehold && householdId == null) {
        AppToast.info(context, l10n.pleaseSelectHouseholdFirst);
        return;
      }

      if (budgetId == null) {
        AppToast.info(context, l10n.pleaseSetMonthlyBudgetFirst);
        return;
      }

      if (context.mounted) {
        isLoading.value = true;
      }

      final previousPocketsState = ref.read(pocketsProvider(scopeParams));
      String? queuedMutationId;
      try {
        // Lifecycle snapshots own only this pocket. Rebalancing sibling rows
        // through the legacy monthly save would race this revisioned mutation.
        final rebalancedSiblingAmounts = siblingPockets
            .map((pocket) => pocket.budgetAmountCents)
            .toList(growable: false);
        final optimisticEnvelopeId = isEditing
            ? existingEnvelope!.id
            : 'optimistic-pocket-${DateTime.now().microsecondsSinceEpoch}';
        final rebalancedByPocketId = <String, int>{
          for (var index = 0; index < siblingPockets.length; index++)
            siblingPockets[index].id: rebalancedSiblingAmounts[index],
        };
        final shouldWriteRolloverFields = rolloverEnabledValue ||
            rolloverNegativeValue ||
            rolloverCapCentsValue != null ||
            existingEnvelope?.hasRolloverFields == true;
        final optimisticPockets = <PocketEnvelope>[
          for (final pocket in allPockets)
            if (pocket.id == existingEnvelope?.id)
              PocketEnvelope(
                id: pocket.id,
                name: name,
                budgetAmountCents: clampedAmountCents,
                spent: pocket.spent,
                currency: selectedCurrency,
                icon: selectedIcon.value,
                color: selectedColor.value,
                logoUrl: selectedLogoUrl.value,
                budgetId: budgetId,
                householdId: pocket.householdId,
                rolloverGroupId: pocket.rolloverGroupId,
                rolloverEnabled: rolloverEnabledValue,
                rolloverNegative: rolloverNegativeValue,
                rolloverCapCents: rolloverCapCentsValue,
                openingRolloverCents: 0,
                rolloverFromPreviousCents:
                    optimisticRolloverBreakdown.rolloverFromPreviousCents,
                hasRolloverFields: shouldWriteRolloverFields,
                availableBudgetCents:
                    optimisticRolloverBreakdown.availableBudgetCents,
                remainingCents: optimisticRolloverBreakdown.remainingCents,
                lastUpdated: DateTime.now(),
              )
            else
              pocket.copyWith(
                budgetAmountCents:
                    rebalancedByPocketId[pocket.id] ?? pocket.budgetAmountCents,
                currency: selectedCurrency,
                budgetId: budgetId,
              ),
          if (isEditing &&
              !allPockets.any((pocket) => pocket.id == existingEnvelope!.id))
            PocketEnvelope(
              id: existingEnvelope!.id,
              name: name,
              budgetAmountCents: clampedAmountCents,
              spent: existingEnvelope!.spent,
              currency: selectedCurrency,
              icon: selectedIcon.value,
              color: selectedColor.value,
              logoUrl: selectedLogoUrl.value,
              budgetId: budgetId,
              householdId: existingEnvelope!.householdId,
              rolloverGroupId: existingEnvelope!.rolloverGroupId,
              rolloverEnabled: rolloverEnabledValue,
              rolloverNegative: rolloverNegativeValue,
              rolloverCapCents: rolloverCapCentsValue,
              openingRolloverCents: 0,
              rolloverFromPreviousCents:
                  optimisticRolloverBreakdown.rolloverFromPreviousCents,
              hasRolloverFields: shouldWriteRolloverFields,
              availableBudgetCents:
                  optimisticRolloverBreakdown.availableBudgetCents,
              remainingCents: optimisticRolloverBreakdown.remainingCents,
              lastUpdated: DateTime.now(),
            ),
          if (!isEditing)
            PocketEnvelope(
              id: optimisticEnvelopeId,
              name: name,
              budgetAmountCents: clampedAmountCents,
              spent: 0,
              currency: selectedCurrency,
              icon: selectedIcon.value,
              color: selectedColor.value,
              logoUrl: selectedLogoUrl.value,
              budgetId: budgetId,
              householdId: scopeParams.scope == PocketsScopeType.personal
                  ? null
                  : householdId,
              rolloverEnabled: rolloverEnabledValue,
              rolloverNegative: rolloverNegativeValue,
              rolloverCapCents: rolloverCapCentsValue,
              openingRolloverCents: 0,
              rolloverFromPreviousCents:
                  optimisticRolloverBreakdown.rolloverFromPreviousCents,
              hasRolloverFields: shouldWriteRolloverFields,
              availableBudgetCents:
                  optimisticRolloverBreakdown.availableBudgetCents,
              remainingCents: optimisticRolloverBreakdown.remainingCents,
              lastUpdated: DateTime.now(),
            ),
        ];
        final pocketsNotifier = ref.read(pocketsProvider(scopeParams).notifier);
        pocketsNotifier.applyOptimisticPockets(
          pockets: optimisticPockets,
          totalBudget: totalBudget,
          budgetId: budgetId,
        );
        queuedMutationId = _newPocketLifecycleOperationId();
        final database = await ref.read(localDatabaseProvider.future);
        await database.enqueueMutation(
          clientMutationId: queuedMutationId,
          entityType: 'pocket_lineage',
          entityId: existingLineage?.lineageId ?? optimisticEnvelopeId,
          operation: 'save_pocket_lineage_lifecycle',
          payload: buildPocketLineageLifecyclePayload(
            userId: user.uid,
            scope: scopeParams.scope,
            householdId: householdId,
            lineageId: existingLineage?.lineageId,
            expectedRevision: existingLineage?.revision,
            budgetMonth: periodMonth,
            currency: selectedCurrency,
            operationId: queuedMutationId,
            name: name,
            icon: selectedIcon.value,
            color: selectedColor.value,
            logoUrl: selectedLogoUrl.value,
            rolloverEnabled: rolloverEnabledValue,
            rolloverNegative: rolloverNegativeValue,
            rolloverCapCents: rolloverCapCentsValue,
            fundingPolicy: selectedFundingPolicy,
            fundingTargetCents: fundingTargetCents,
            categories: selectedCategories.value,
            currentAmountCents: clampedAmountCents,
          ),
        );

        if (isScopedToHousehold && householdId != null) {
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(householdId);
        }

        unawaited(ref.read(mobileOutboxDrainerProvider).drain());

        if (context.mounted) {
          Navigator.of(context).pop();
          final message =
              isEditing ? l10n.budgetUpdated : l10n.budgetCreatedSuccessfully;
          AppToast.success(context, message);
        }
      } catch (e) {
        if (queuedMutationId != null && shouldKeepQueuedPocketsMutation(e)) {
          if (context.mounted) {
            Navigator.of(context).pop();
            AppToast.info(context, context.l10n.offlineSyncMessage);
          }
          return;
        }
        if (queuedMutationId != null && isMissingRolloverColumnError(e)) {
          final database = await ref.read(localDatabaseProvider.future);
          await database.markMutationCancelled(
            clientMutationId: queuedMutationId,
            error: e,
          );
        }
        ref
            .read(pocketsProvider(scopeParams).notifier)
            .restoreOptimisticPockets(previousPocketsState);
        if (context.mounted) {
          AppToast.error(
            context,
            isMissingRolloverColumnError(e)
                ? rolloverBackendUnavailableMessage
                : ErrorHandler.getUserFriendlyMessage(e),
          );
        }
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    Future<void> handleDelete() async {
      if (!isEditing) return;

      if (ref.read(previewModeProvider).isActive) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.info(
          context,
          context.l10n.previewPocketRemovalSkipped,
        );
        return;
      }

      final l10n = context.l10n;
      final metadata = lineageMetadata;
      if (metadata == null) {
        AppToast.info(context, l10n.pocketLifecycleLoading);
        return;
      }
      if (!context.mounted) return;

      if (budgetId == null || budgetId!.trim().isEmpty) {
        AppToast.error(context, l10n.pleaseSetMonthlyBudgetFirst);
        return;
      }

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        AppToast.info(context, l10n.userNotAuthenticated);
        return;
      }

      late final int balanceCents;
      try {
        final preview = await supabase.rpc(
          'preview_pocket_lineage_retirement_v1',
          params: <String, dynamic>{
            'p_user_id': user.uid,
            'p_scope': pocketsScopeRpcValue(scopeParams.scope),
            'p_household_id': scopeParams.householdId,
            'p_lineage_id': metadata.lineageId,
            'p_effective_month': periodMonth,
          },
        );
        balanceCents =
            (preview is Map ? preview['balance_cents'] as num? : null)
                    ?.toInt() ??
                0;
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
        return;
      }
      if (!context.mounted) return;
      final retirement = await _selectPocketRetirementDisposition(
        context: context,
        balanceCents: balanceCents,
        candidates: allPockets
            .where((pocket) =>
                pocket.id != existingEnvelope!.id &&
                pocket.rolloverGroupId?.trim().isNotEmpty == true)
            .toList(growable: false),
      );
      if (retirement == null || !context.mounted) return;

      if (context.mounted) {
        isLoading.value = true;
      }
      final previousPocketsState = ref.read(pocketsProvider(scopeParams));
      String? queuedMutationId;
      try {
        final remainingPockets = allPockets
            .where((pocket) => pocket.id != existingEnvelope!.id)
            .toList(growable: false);
        final optimisticRemaining = <PocketEnvelope>[
          for (final pocket in remainingPockets)
            pocket.copyWith(currency: selectedCurrency, budgetId: budgetId),
        ];
        final pocketsNotifier = ref.read(pocketsProvider(scopeParams).notifier);
        pocketsNotifier.applyOptimisticPockets(
          pockets: optimisticRemaining,
          totalBudget: totalBudget,
          budgetId: budgetId,
        );
        queuedMutationId =
            'mobile:pocket_lineage_retire_${metadata.lineageId}_${DateTime.now().microsecondsSinceEpoch}';
        final database = await ref.read(localDatabaseProvider.future);
        await database.enqueueMutation(
          clientMutationId: queuedMutationId,
          entityType: 'pocket_lineage',
          entityId: metadata.lineageId,
          operation: 'retire_pocket_lineage',
          payload: buildPocketLineageRetirementPayload(
            userId: user.uid,
            scope: scopeParams.scope,
            householdId: scopeParams.householdId,
            metadata: metadata,
            effectiveMonth: periodMonth,
            disposition: retirement.disposition,
            targetLineageId: retirement.targetLineageId,
          ),
        );

        final isScopedToHousehold =
            scopeParams.scope != PocketsScopeType.personal;
        final householdId = scopeParams.householdId;
        if (isScopedToHousehold && householdId != null) {
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(householdId);
        }

        unawaited(ref.read(mobileOutboxDrainerProvider).drain());

        if (context.mounted) {
          Navigator.of(context).pop(); // close sheet
          onDeleteCompleted?.call();
          AppToast.info(context, l10n.pocketRetirementQueued);
        }
      } catch (e) {
        ref
            .read(pocketsProvider(scopeParams).notifier)
            .restoreOptimisticPockets(previousPocketsState);
        if (context.mounted) {
          AppToast.error(context, l10n.failedToDeletePocket);
        }
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    confirmController?.attach(handleSave);
    useEffect(() => confirmController?.detach, [confirmController]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        confirmController?.setLoading(isLoading.value);
      });
      return null;
    }, [confirmController, isLoading.value]);

    return PopScope(
      canPop: !isLoading.value,
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirmController == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: MonekoSheetConfirmButton(
                      onPressed: handleSave,
                      isLoading: isLoading.value,
                    ),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.pocketNameLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: nameController,
                        placeholder: context.l10n.pocketNamePlaceholder,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.pocketCategoriesLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor:
                                colorScheme.surface.withValues(alpha: 0.0),
                            builder: (sheetContext) {
                              return CategoryPickerBottomSheet(
                                title: context.l10n.selectCategoriesMultiple,
                                allCategories: allCategories,
                                customCategories: customExpenseCategories,
                                selectedCategories: selectedCategories.value,
                                onChanged: (value) {
                                  selectedCategories.value =
                                      List<String>.from(value);
                                },
                              );
                            },
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: selectedCategories.value.isEmpty
                                    ? Text(
                                        context.l10n.tapToSelectCategories,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.mutedForeground,
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final cat
                                              in selectedCategories.value)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                getCategoryTranslation(
                                                    context, cat),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.pocketColorLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ColorSelectionSwatchRow(
                        selectedHex: selectedColor.value,
                        onChanged: (color) => selectedColor.value = color,
                        presetColors: AppTheme.pocketPresetColors,
                        sweepColors: AppTheme.pocketColorSweep,
                        fallbackColor: AppTheme.pocketDefaultBlue,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.pocketIconLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pocketIconNames.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final selectedHex = selectedColor.value;
                            final selectedColorValue = selectedHex != null
                                ? Color(int.parse(
                                        selectedHex.replaceFirst('#', ''),
                                        radix: 16) +
                                    0xFF000000)
                                : colorScheme.primary;

                            if (index == 0) {
                              return RoundedLogoPicker(
                                logoUrl: selectedLogoUrl.value,
                                storagePathPrefix:
                                    StorageConfig.pocketLogosPath,
                                onChanged: (value) {
                                  selectedLogoUrl.value = value;
                                  if (value != null) {
                                    selectedIcon.value = null;
                                  }
                                },
                                fallbackIcon: getPocketIconData(
                                  selectedIcon.value ?? 'category',
                                ),
                                accentColor: selectedColorValue,
                                enabled:
                                    !ref.read(previewModeProvider).isActive,
                              );
                            }

                            final iconName = pocketIconNames[index - 1];

                            final iconData = getPocketIconData(iconName);
                            final isSelected = selectedLogoUrl.value == null &&
                                selectedIcon.value == iconName;

                            return GestureDetector(
                              onTap: () {
                                selectedIcon.value = iconName;
                                selectedLogoUrl.value = null;
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColorValue.withValues(
                                          alpha: 0.1)
                                      : colorScheme.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? selectedColorValue
                                        : colorScheme.border,
                                  ),
                                ),
                                child: Icon(
                                  iconData,
                                  color: isSelected
                                      ? selectedColorValue
                                      : colorScheme.mutedForeground,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.budgetAmount,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () async {
                                final hexColor =
                                    selectedColor.value ?? '#6B7280';
                                final pocketColor = Color(int.parse(
                                        hexColor.replaceFirst('#', ''),
                                        radix: 16) +
                                    0xFF000000);
                                final iconName =
                                    selectedIcon.value ?? 'category';
                                final iconData = getPocketIconData(iconName);
                                final displayName =
                                    nameController.text.trim().isEmpty
                                        ? context.l10n.thisPocketFallback
                                        : nameController.text.trim();

                                final header = Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: pocketColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color:
                                          pocketColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        iconData,
                                        size: 12,
                                        color: pocketColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                final value = await showCalculatorKeypadSheet(
                                  context: context,
                                  initialValue: amountController.text,
                                  prefix: resolveCurrencySymbol(currency),
                                  header: header,
                                );
                                if (value != null) {
                                  final normalizedValue =
                                      normalizeEnteredAmountText(
                                    value,
                                  );
                                  amountController.value = TextEditingValue(
                                    text: normalizedValue,
                                    selection: TextSelection.collapsed(
                                      offset: normalizedValue.length,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.sheetElementBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colorScheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        amountController.text.isNotEmpty
                                            ? '${resolveCurrencySymbol(currency)}${amountController.text}'
                                            : context.l10n.tapToSet,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              amountController.text.isNotEmpty
                                                  ? colorScheme.onSurface
                                                  : colorScheme.onSurface
                                                      .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${previewShare.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.mutedForeground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: AdaptiveSlider(
                                value: sliderPercent,
                                min: 0,
                                max: 100,
                                divisions: 100,
                                onChanged:
                                    (maxBudgetCents <= 0 || isLoading.value)
                                        ? null
                                        : (value) {
                                            final pct = value.clamp(0.0, 100.0);
                                            final newCents =
                                                quantizePocketBudgetAmountCents(
                                              ((pct / 100.0) * maxBudgetCents)
                                                  .round()
                                                  .clamp(0, maxBudgetCents)
                                                  .toInt(),
                                              stepCents: allocationStepCents,
                                            );
                                            amountController.value =
                                                TextEditingValue(
                                              text: formatAmount(
                                                  centsToAmount(newCents)),
                                            );
                                          },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${resolveCurrencySymbol(currency)}0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.mutedForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${resolveCurrencySymbol(currency)}${formatLocalizedNumber(context, double.parse(formatAmount(totalBudget)))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.mutedForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: previewExceededBudgetCents > 0
                                  ? Padding(
                                      key: const ValueKey(
                                          'budget_exceeded_warning'),
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: colorScheme.error,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${context.l10n.budgetExceededByLabel} ${formatLocalizedAmount(previewExceededBudgetCents / 100.0)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('no_budget_warning'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _BudgetDistributionPreview(
                        totalBudget: totalBudget,
                        otherPockets: siblingPockets,
                        otherPocketAmountsCents: previewSiblingAmounts,
                        currentAmountCents: previewAmountCents,
                        currentPocketColor: selectedColor.value,
                        currentPocketName: nameController.text.trim().isEmpty
                            ? context.l10n.thisPocketFallback
                            : nameController.text.trim(),
                        colorScheme: colorScheme,
                        showUnassignedBudget: true,
                      ),
                      const SizedBox(height: 16),
                      _RolloverSettingsSection(
                        colorScheme: colorScheme,
                        currency: currency,
                        rolloverEnabled: rolloverEnabled.value,
                        rolloverNegative: rolloverNegative.value,
                        rolloverCapController: rolloverCapController,
                        onRolloverEnabledChanged:
                            isLoading.value ? null : setRolloverEnabled,
                        onRolloverNegativeChanged: isLoading.value
                            ? null
                            : (value) => rolloverNegative.value = value,
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.pocketFundingTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '${lineageMetadata?.lineageId}:${fundingPolicy.value}',
                                ),
                                initialValue: fundingPolicy.value,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'decide_each_cycle',
                                    child: Text(context
                                        .l10n.pocketFundingDecideEachCycle),
                                  ),
                                  DropdownMenuItem(
                                    value: 'refill_to',
                                    child: Text(
                                        context.l10n.pocketFundingRefillTo),
                                  ),
                                  DropdownMenuItem(
                                    value: 'add_every_cycle',
                                    child: Text(context
                                        .l10n.pocketFundingAddEveryCycle),
                                  ),
                                ],
                                onChanged:
                                    isLoading.value || lineageMetadata == null
                                        ? null
                                        : (value) => fundingPolicy.value =
                                            value ?? 'decide_each_cycle',
                              ),
                              if (fundingPolicy.value != 'decide_each_cycle')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: CustomTextField(
                                    controller: fundingTargetController,
                                    placeholder:
                                        context.l10n.pocketFundingAmount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: PlainAdaptiveButton(
                            onPressed: isLoading.value ? null : handleDelete,
                            child: Text(
                              context.l10n.delete,
                              style: TextStyle(
                                color: colorScheme.destructive,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
    );
  }
}

class _PocketRetirementChoice {
  const _PocketRetirementChoice({
    required this.disposition,
    this.targetLineageId,
  });

  final PocketRetirementDisposition disposition;
  final String? targetLineageId;
}

Future<_PocketRetirementChoice?> _selectPocketRetirementDisposition({
  required BuildContext context,
  required int balanceCents,
  required List<PocketEnvelope> candidates,
}) {
  final amount = formatAmount(centsToAmount(balanceCents.abs()));
  if (balanceCents == 0) {
    return showDialog<_PocketRetirementChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.pocketRetirementTitle),
        content: Text(context.l10n.pocketRetirementZeroDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _PocketRetirementChoice(
                disposition: PocketRetirementDisposition.retireZero,
              ),
            ),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  return showDialog<_PocketRetirementChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(balanceCents > 0
          ? context.l10n.pocketRetirementPositiveTitle(amount)
          : context.l10n.pocketRetirementNegativeTitle(amount)),
      children: [
        if (balanceCents > 0)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              context,
              const _PocketRetirementChoice(
                disposition: PocketRetirementDisposition.releasePositive,
              ),
            ),
            child: Text(context.l10n.pocketRetirementRelease),
          ),
        for (final candidate in candidates)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              context,
              _PocketRetirementChoice(
                disposition: balanceCents > 0
                    ? PocketRetirementDisposition.transferPositive
                    : PocketRetirementDisposition.coverNegative,
                targetLineageId: candidate.rolloverGroupId,
              ),
            ),
            child: Text(
              balanceCents > 0
                  ? context.l10n.pocketRetirementTransferTo(candidate.name)
                  : context.l10n.pocketRetirementCoverFrom(candidate.name),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ],
    ),
  );
}

class _RolloverSettingsSection extends StatelessWidget {
  const _RolloverSettingsSection({
    required this.colorScheme,
    required this.currency,
    required this.rolloverEnabled,
    required this.rolloverNegative,
    required this.rolloverCapController,
    required this.onRolloverEnabledChanged,
    required this.onRolloverNegativeChanged,
  });

  final ColorScheme colorScheme;
  final String currency;
  final bool rolloverEnabled;
  final bool rolloverNegative;
  final TextEditingController rolloverCapController;
  final ValueChanged<bool>? onRolloverEnabledChanged;
  final ValueChanged<bool>? onRolloverNegativeChanged;

  @override
  Widget build(BuildContext context) {
    final currencySymbol = resolveCurrencySymbol(currency);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rolloverEnabled ? colorScheme.primary : colorScheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.replay_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.pocketRolloverSettingsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.pocketRolloverSettingsDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AdaptiveSwitch(
                value: rolloverEnabled,
                onChanged: onRolloverEnabledChanged,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: rolloverEnabled
                  ? Padding(
                      key: const ValueKey('rollover_settings_enabled'),
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.sheetElementBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorScheme.border),
                            ),
                            child: Text(
                              context.l10n.pocketRolloverSettingsExample(
                                  currencySymbol),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n
                                          .pocketRolloverCarryOverspendingLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rolloverNegative
                                          ? context.l10n
                                              .pocketRolloverOverspendingEnabledDescription
                                          : context.l10n
                                              .pocketRolloverOverspendingDisabledDescription,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AdaptiveSwitch(
                                value: rolloverNegative,
                                onChanged: onRolloverNegativeChanged,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.l10n.pocketRolloverMaximumLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: rolloverCapController,
                            placeholder:
                                context.l10n.pocketRolloverUnlimitedPlaceholder,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefixIcon: _CurrencyPrefix(
                              symbol: currencySymbol,
                              colorScheme: colorScheme,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('rollover_settings_disabled'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPrefix extends StatelessWidget {
  const _CurrencyPrefix({
    required this.symbol,
    required this.colorScheme,
  });

  final String symbol;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1.0,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _BudgetDistributionPreview extends StatelessWidget {
  const _BudgetDistributionPreview({
    required this.totalBudget,
    required this.otherPockets,
    required this.otherPocketAmountsCents,
    required this.currentAmountCents,
    required this.currentPocketColor,
    required this.currentPocketName,
    required this.colorScheme,
    required this.showUnassignedBudget,
  });

  final double totalBudget;
  final List<PocketEnvelope> otherPockets;
  final List<int> otherPocketAmountsCents;
  final int currentAmountCents;
  final String? currentPocketColor;
  final String currentPocketName;
  final ColorScheme colorScheme;
  final bool showUnassignedBudget;

  @override
  Widget build(BuildContext context) {
    if (totalBudget <= 0) return const SizedBox.shrink();
    final l10n = context.l10n;

    final totalBudgetCents = (totalBudget * 100).round();
    final unassignedColor = colorScheme.surfaceContainerHighest;
    final rawSegments = <_Segment>[
      for (var index = 0; index < otherPockets.length; index++)
        _Segment(
          label: otherPockets[index].name.isEmpty
              ? context.l10n.pocketSegmentLabel
              : otherPockets[index].name,
          share: totalBudgetCents > 0
              ? (math.max(0, otherPocketAmountsCents[index]) /
                      totalBudgetCents) *
                  100
              : 0.0,
          color: _hexOrPrimary(otherPockets[index].color, colorScheme),
        ),
      _Segment(
        label: currentPocketName.isEmpty
            ? context.l10n.thisPocketSegmentLabel
            : currentPocketName,
        share: totalBudgetCents > 0
            ? (math.max(0, currentAmountCents) / totalBudgetCents) * 100
            : 0.0,
        color: _hexOrPrimary(currentPocketColor, colorScheme),
        isCurrent: true,
      ),
    ];
    final totalAllocatedShare =
        rawSegments.fold<double>(0.0, (sum, segment) => sum + segment.share);
    final unassignedShare =
        (100.0 - totalAllocatedShare).clamp(0.0, 100.0).toDouble();
    final visibleSegments = <_Segment>[];
    var remainingCapacity = 100.0;
    for (final segment in rawSegments) {
      if (remainingCapacity <= 0) break;
      final visibleShare =
          segment.share.clamp(0.0, remainingCapacity).toDouble();
      if (visibleShare > 0) {
        visibleSegments.add(segment.copyWith(share: visibleShare));
        remainingCapacity -= visibleShare;
      }
    }
    if (showUnassignedBudget && unassignedShare > 0) {
      visibleSegments.add(_Segment(
        label: l10n.unassigned,
        share: unassignedShare,
        color: unassignedColor,
        isUnassigned: true,
      ));
    }
    final legendSegments = <_Segment>[
      ...rawSegments.where((segment) => segment.share > 0),
      if (showUnassignedBudget && unassignedShare > 0)
        _Segment(
          label: l10n.unassigned,
          share: unassignedShare,
          color: unassignedColor,
          isUnassigned: true,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.budgetImpactTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  for (final seg in visibleSegments)
                    if (seg.share > 0)
                      Flexible(
                        flex: math.max(1, (seg.share * 10).round()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: seg.color,
                            border: seg.isUnassigned
                                ? Border.all(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.12),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  if (!showUnassignedBudget && remainingCapacity > 0)
                    Flexible(
                      flex: math.max(1, (remainingCapacity * 10).round()),
                      child: Container(
                        color: colorScheme.surface.withValues(alpha: 0.0),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final seg in legendSegments)
                _LegendItem(
                  color: seg.color,
                  label: seg.label,
                  colorScheme: colorScheme,
                  outlined: seg.isUnassigned,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment {
  const _Segment({
    required this.label,
    required this.share,
    required this.color,
    this.isCurrent = false,
    this.isUnassigned = false,
  });

  final String label;
  final double share;
  final Color color;
  final bool isCurrent;
  final bool isUnassigned;

  _Segment copyWith({double? share}) {
    return _Segment(
      label: label,
      share: share ?? this.share,
      color: color,
      isCurrent: isCurrent,
      isUnassigned: isUnassigned,
    );
  }
}

Color _hexOrPrimary(String? hex, ColorScheme scheme) {
  if (hex == null || hex.isEmpty) return scheme.primary;
  try {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  } catch (_) {
    return scheme.primary;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.colorScheme,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final ColorScheme colorScheme;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: outlined
                ? Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.35),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

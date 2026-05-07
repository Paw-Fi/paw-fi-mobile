import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/utils/pocket_budget_amount_steps.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

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
  });

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

  Future<bool?> _confirmDelete(BuildContext context, AppLocalizations l10n) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.pocketDeleteTitle),
          content: Text(l10n.pocketDeleteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

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
    final amountFocusNode = useFocusNode();
    useListenable(amountFocusNode);
    useListenable(amountController);

    useEffect(() {
      void onFocusChange() {
        if (!amountFocusNode.hasFocus) {
          final amountCents = tryParseMoneyToCents(amountController.text);
          if (amountCents == null) {
            return;
          }

          final totalBudgetCents = (totalBudget * 100).round();
          final maxBudgetCents = math.max(0, totalBudgetCents);
          final clampedCents = quantizePocketBudgetAmountCents(
            amountCents.clamp(0, maxBudgetCents).toInt(),
            stepCents: pocketBudgetAdjustmentStepCents(selectedCurrency),
          );
          amountController.text = formatAmount(centsToAmount(clampedCents));
        }
      }

      amountFocusNode.addListener(onFocusChange);
      return () => amountFocusNode.removeListener(onFocusChange);
    }, [amountFocusNode, totalBudget, selectedCurrency]);

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

    final selectedIcon =
        useState<String?>(existingEnvelope?.icon ?? template?.iconName);
    final isLoading = useState<bool>(false);
    final currency = selectedCurrency;
    final totalBudgetCents = (totalBudget * 100).round();
    final maxBudgetCents = math.max(0, totalBudgetCents);
    final allocationStepCents = pocketBudgetAdjustmentStepCents(currency);
    final viewedMonth = scopeParams.periodMonth ?? DateTime.now();
    final monthStart = DateTime(viewedMonth.year, viewedMonth.month, 1);
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

    bool shouldRebalanceSiblingBudgets(int currentAmountCents) {
      if (siblingPockets.isEmpty) {
        return false;
      }

      if (!isEditing) {
        return true;
      }

      return existingEnvelope!.budgetAmountCents != currentAmountCents;
    }

    List<int> buildRebalancedSiblingAmounts(int currentAmountCents) {
      final siblingAmounts = siblingPockets
          .map((pocket) => pocket.budgetAmountCents)
          .toList(growable: false);

      if (!shouldRebalanceSiblingBudgets(currentAmountCents)) {
        return siblingAmounts;
      }

      return rebalanceSiblingPocketBudgetAmounts(
        siblingAmountsCents: siblingAmounts,
        targetPocketAmountCents: currentAmountCents,
        totalBudgetCents: totalBudgetCents,
        allocationStepCents: allocationStepCents,
      );
    }

    final previewSiblingAmounts =
        buildRebalancedSiblingAmounts(previewAmountCents);

    useEffect(() {
      if (!isEditing) {
        return null;
      }

      Future(() async {
        try {
          final res = await supabase
              .from('envelope_category_links')
              .select('category')
              .eq('envelope_id', existingEnvelope!.id);
          final list = (res as List)
              .map((row) => (row['category'] as String).toLowerCase())
              .toSet()
              .toList();
          selectedCategories.value = list;
        } catch (_) {
          // ignore load errors, user can still edit categories manually
        }
      });

      return null;
    }, [isEditing ? existingEnvelope!.id : null]);

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
      final normalized = double.parse(value.toStringAsFixed(0));
      return formatLocalizedNumber(context, normalized);
    }

    Future<void> persistPocketAmount({
      required String envelopeId,
      required int amountCents,
      required String resolvedBudgetId,
      required String nowIso,
      bool includeDisplayFields = false,
      String? resolvedName,
      String? resolvedColor,
      String? resolvedIcon,
    }) async {
      final payload = <String, dynamic>{
        'budget_id': resolvedBudgetId,
        'budget_amount_cents': amountCents,
        'updated_at': nowIso,
        'household_id': scopeParams.scope == PocketsScopeType.personal
            ? null
            : scopeParams.householdId,
        'currency': selectedCurrency,
      };

      if (includeDisplayFields) {
        payload['name'] = resolvedName;
        payload['color'] = resolvedColor;
        payload['icon'] = resolvedIcon;
      }

      await supabase
          .from('budget_envelopes')
          .update(payload)
          .eq('id', envelopeId);

      await supabase.from('envelope_allocations').upsert(
        <String, dynamic>{
          'envelope_id': envelopeId,
          'period_month': periodMonth,
          'amount_cents': amountCents,
          'carryover_policy': 'carryover',
          'updated_at': nowIso,
        },
        onConflict: 'envelope_id,period_month',
      );
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

      if (selectedCategories.value.isEmpty) {
        AppToast.info(context, l10n.pleaseSelectCategory);
        return;
      }

      if (ref.read(previewModeProvider).isActive) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.success(
          context,
          existingEnvelope != null
              ? 'Preview: pocket updated for demo (not saved).'
              : 'Preview: pocket created for demo (not saved).',
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
      try {
        final nowIso = DateTime.now().toIso8601String();
        final originalAmountCents = existingEnvelope?.budgetAmountCents ?? 0;
        final rebalancedSiblingAmounts =
            buildRebalancedSiblingAmounts(clampedAmountCents);
        final optimisticEnvelopeId = isEditing
            ? existingEnvelope!.id
            : 'optimistic-pocket-${DateTime.now().microsecondsSinceEpoch}';
        final rebalancedByPocketId = <String, int>{
          for (var index = 0; index < siblingPockets.length; index++)
            siblingPockets[index].id: rebalancedSiblingAmounts[index],
        };
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
                budgetId: budgetId,
                householdId: pocket.householdId,
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
              budgetId: budgetId,
              householdId: existingEnvelope!.householdId,
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
              budgetId: budgetId,
              householdId: scopeParams.scope == PocketsScopeType.personal
                  ? null
                  : householdId,
              lastUpdated: DateTime.now(),
            ),
        ];
        ref.read(pocketsProvider(scopeParams).notifier).applyOptimisticPockets(
              pockets: optimisticPockets,
              totalBudget: totalBudget,
              budgetId: budgetId,
            );

        Future<void> persistSiblingAllocations() async {
          for (var index = 0; index < siblingPockets.length; index++) {
            final pocket = siblingPockets[index];
            final rebalancedAmount = rebalancedSiblingAmounts[index];
            if (pocket.budgetAmountCents == rebalancedAmount) {
              continue;
            }

            await persistPocketAmount(
              envelopeId: pocket.id,
              amountCents: rebalancedAmount,
              resolvedBudgetId: budgetId!,
              nowIso: nowIso,
            );
          }
        }

        String envelopeId;
        if (isEditing) {
          envelopeId = existingEnvelope!.id;

          if (clampedAmountCents > originalAmountCents) {
            await persistSiblingAllocations();
          }

          await persistPocketAmount(
            envelopeId: envelopeId,
            amountCents: clampedAmountCents,
            resolvedBudgetId: budgetId!,
            nowIso: nowIso,
            includeDisplayFields: true,
            resolvedName: name,
            resolvedColor: selectedColor.value,
            resolvedIcon: selectedIcon.value,
          );

          if (clampedAmountCents < originalAmountCents) {
            await persistSiblingAllocations();
          }

          await supabase
              .from('envelope_category_links')
              .delete()
              .eq('envelope_id', envelopeId);
        } else {
          final insertRes = await supabase
              .from('budget_envelopes')
              .insert(<String, dynamic>{
                'user_id': user.uid,
                'budget_id': budgetId,
                'name': name,
                'budget_amount_cents': 0,
                'household_id': scopeParams.scope == PocketsScopeType.personal
                    ? null
                    : householdId,
                'currency': selectedCurrency,
                'color': selectedColor.value,
                'icon': selectedIcon.value,
              })
              .select('id')
              .maybeSingle();

          final id = insertRes != null ? insertRes['id'] as String? : null;
          if (id == null) {
            throw Exception('Failed to create envelope');
          }
          envelopeId = id;

          await persistSiblingAllocations();
          await persistPocketAmount(
            envelopeId: envelopeId,
            amountCents: clampedAmountCents,
            resolvedBudgetId: budgetId!,
            nowIso: nowIso,
          );
        }

        final linksPayload = selectedCategories.value
            .map((category) => <String, dynamic>{
                  'envelope_id': envelopeId,
                  'category': category,
                })
            .toList();

        if (linksPayload.isNotEmpty) {
          await supabase.from('envelope_category_links').insert(linksPayload);
        }

        // CRITICAL: Invalidate RequestDeduplicator cache for household data
        if (isScopedToHousehold && householdId != null) {
          debugPrint(
              '🗑️ [POCKET SAVE] Invalidating household cache for: $householdId');
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(householdId);
        }

        // CRITICAL: Invalidate ALL pocket providers (all scopes, all months)
        // This ensures pockets page refreshes in all views, not just current month/scope
        debugPrint(
            '🗑️ [POCKET SAVE] Invalidating ALL pockets provider families...');
        ref.invalidate(pocketsProvider);

        debugPrint(
            '✅ [POCKET SAVE] Pocket saved and all providers invalidated');

        if (context.mounted) {
          Navigator.of(context).pop();
          final message =
              isEditing ? l10n.budgetUpdated : l10n.budgetCreatedSuccessfully;
          AppToast.success(context, message);
        }
      } catch (e) {
        ref
            .read(pocketsProvider(scopeParams).notifier)
            .restoreOptimisticPockets(previousPocketsState);
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
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
          'Preview: pocket removal skipped (demo data only).',
        );
        return;
      }

      final l10n = context.l10n;
      final confirmed = await _confirmDelete(context, l10n);
      if (confirmed != true) return;

      if (context.mounted) {
        isLoading.value = true;
      }
      final previousPocketsState = ref.read(pocketsProvider(scopeParams));
      try {
        final remainingPockets = allPockets
            .where((pocket) => pocket.id != existingEnvelope!.id)
            .toList(growable: false);
        final rebalancedRemainingAmounts = remainingPockets.isEmpty
            ? const <int>[]
            : rebalancePocketBudgetAmounts(
                currentAmountsCents: remainingPockets
                    .map((pocket) => pocket.budgetAmountCents)
                    .toList(growable: false),
                newTotalBudgetCents: totalBudgetCents,
                allocationStepCents: allocationStepCents,
              );
        final nowIso = DateTime.now().toIso8601String();
        final optimisticRemaining = <PocketEnvelope>[
          for (var index = 0; index < remainingPockets.length; index++)
            remainingPockets[index].copyWith(
              budgetAmountCents: rebalancedRemainingAmounts[index],
              currency: selectedCurrency,
              budgetId: budgetId,
            ),
        ];
        ref.read(pocketsProvider(scopeParams).notifier).applyOptimisticPockets(
              pockets: optimisticRemaining,
              totalBudget: totalBudget,
              budgetId: budgetId,
            );

        await supabase
            .from('budget_envelopes')
            .delete()
            .eq('id', existingEnvelope!.id);

        for (var index = 0; index < remainingPockets.length; index++) {
          final pocket = remainingPockets[index];
          final rebalancedAmount = rebalancedRemainingAmounts[index];
          if (pocket.budgetAmountCents == rebalancedAmount) {
            continue;
          }

          await persistPocketAmount(
            envelopeId: pocket.id,
            amountCents: rebalancedAmount,
            resolvedBudgetId: budgetId!,
            nowIso: nowIso,
          );
        }

        // CRITICAL: Invalidate RequestDeduplicator cache for household data
        final isScopedToHousehold =
            scopeParams.scope != PocketsScopeType.personal;
        final householdId = scopeParams.householdId;
        if (isScopedToHousehold && householdId != null) {
          debugPrint(
              '🗑️ [POCKET DELETE] Invalidating household cache for: $householdId');
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(householdId);
        }

        // CRITICAL: Invalidate ALL pocket providers (all scopes, all months)
        // This ensures pockets page refreshes in all views, not just current month/scope
        debugPrint(
            '🗑️ [POCKET DELETE] Invalidating ALL pockets provider families...');
        ref.invalidate(pocketsProvider);

        debugPrint(
            '✅ [POCKET DELETE] Pocket deleted and all providers invalidated');

        if (context.mounted) {
          Navigator.of(context).pop(); // close sheet
          onDeleteCompleted?.call();
          AppToast.success(context, l10n.pocketDeleted);
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: PopScope(
        canPop: !isLoading.value,
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Sheet Drag Handle
                const ModalSheetHandle(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing
                              ? context.l10n.editPocket
                              : context.l10n.addPocket,
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
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.sheetElementBackground,
                              borderRadius: BorderRadius.circular(12),
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
                        Builder(builder: (context) {
                          const presetColors = AppTheme.pocketPresetColors;
                          return SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: presetColors.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // Check if current selected color is one of the presets
                                  bool isCustomColor = false;
                                  if (selectedColor.value != null) {
                                    isCustomColor = true;
                                    for (final preset in presetColors) {
                                      String two(int n) =>
                                          n.toRadixString(16).padLeft(2, '0');
                                      int toByte(double x) =>
                                          (x * 255.0).round() & 0xff;
                                      final hex =
                                          '#${two(toByte(preset.r))}${two(toByte(preset.g))}${two(toByte(preset.b))}';
                                      if (selectedColor.value!.toLowerCase() ==
                                          hex.toLowerCase()) {
                                        isCustomColor = false;
                                        break;
                                      }
                                    }
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      final currentColor = selectedColor
                                                  .value !=
                                              null
                                          ? Color(int.parse(
                                                  selectedColor.value!
                                                      .substring(1, 7),
                                                  radix: 16) +
                                              0xFF000000)
                                          : AppTheme
                                              .pocketDefaultBlue; // Default blue

                                      AdaptiveColorPicker.show(
                                        context: context,
                                        startingColor: currentColor,
                                        onColorChanged: (color) {
                                          String two(int n) => n
                                              .toRadixString(16)
                                              .padLeft(2, '0');
                                          int toByte(double x) =>
                                              (x * 255.0).round() & 0xff;
                                          final hex =
                                              '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                                          selectedColor.value = hex;
                                        },
                                        label: context.l10n.selectColor,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isCustomColor &&
                                                selectedColor.value != null
                                            ? Color(int.parse(
                                                    selectedColor.value!
                                                        .substring(1, 7),
                                                    radix: 16) +
                                                0xFF000000)
                                            : null,
                                        gradient: isCustomColor
                                            ? null
                                            : const SweepGradient(
                                                colors:
                                                    AppTheme.pocketColorSweep,
                                              ),
                                        shape: BoxShape.circle,
                                        border: isCustomColor
                                            ? Border.all(
                                                color: colorScheme.foreground,
                                                width: 2)
                                            : Border.all(
                                                color: colorScheme.border),
                                        boxShadow: const [
                                          // Shadow removed as requested
                                        ],
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: isCustomColor
                                            ? Icon(Icons.check,
                                                key: const ValueKey('check'),
                                                color: colorScheme
                                                    .primaryForeground,
                                                size: 20)
                                            : Icon(Icons.colorize,
                                                key: const ValueKey('colorize'),
                                                color: colorScheme
                                                    .primaryForeground,
                                                size: 20),
                                      ),
                                    ),
                                  );
                                }
                                final color = presetColors[index - 1];
                                String two(int n) =>
                                    n.toRadixString(16).padLeft(2, '0');
                                int toByte(double x) =>
                                    (x * 255.0).round() & 0xff;
                                final hex =
                                    '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                                final isSelected =
                                    selectedColor.value?.toLowerCase() ==
                                        hex.toLowerCase();

                                return GestureDetector(
                                  onTap: () => selectedColor.value = hex,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: colorScheme.foreground,
                                              width: 2)
                                          : null,
                                      boxShadow: const [
                                        // Shadow removed as requested
                                      ],
                                    ),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: isSelected
                                          ? Icon(Icons.check,
                                              key: const ValueKey('selected'),
                                              color:
                                                  colorScheme.primaryForeground,
                                              size: 20)
                                          : const SizedBox(
                                              key: ValueKey('unselected')),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
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
                            itemCount: pocketIconNames.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final iconName = pocketIconNames[index];
                              final selectedHex = selectedColor.value;
                              final selectedColorValue = selectedHex != null
                                  ? Color(int.parse(
                                          selectedHex.replaceFirst('#', ''),
                                          radix: 16) +
                                      0xFF000000)
                                  : colorScheme.primary;

                              final iconData = getPocketIconData(iconName);
                              final isSelected = selectedIcon.value == iconName;

                              return GestureDetector(
                                onTap: () => selectedIcon.value = iconName,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
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
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      iconData,
                                      key: ValueKey(isSelected),
                                      color: isSelected
                                          ? selectedColorValue
                                          : colorScheme.mutedForeground,
                                      size: 20,
                                    ),
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
                            color: colorScheme.sheetElementBackground,
                            borderRadius: BorderRadius.circular(20),
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
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 200,
                                        child: TextField(
                                          controller: amountController,
                                          focusNode: amountFocusNode,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textInputAction: TextInputAction.done,
                                          onEditingComplete: () =>
                                              amountFocusNode.unfocus(),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.foreground,
                                            letterSpacing: -0.5,
                                          ),
                                          decoration: InputDecoration(
                                            prefixText:
                                                resolveCurrencySymbol(currency),
                                            prefixStyle: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: colorScheme.foreground,
                                              letterSpacing: -0.5,
                                            ),
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: colorScheme.foreground,
                                                  width: 1),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: colorScheme.foreground,
                                                  width: 2),
                                            ),
                                            suffixIcon: amountFocusNode.hasFocus
                                                ? IconButton(
                                                    icon: Icon(
                                                      Icons.check_rounded,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                    splashRadius: 18,
                                                    onPressed: () =>
                                                        amountFocusNode
                                                            .unfocus(),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                                  Text(
                                    '${resolveCurrencySymbol(currency)}${formatLocalizedNumber(context, double.parse(formatAmount(totalBudget)))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.mutedForeground,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  activeTrackColor: colorScheme.primary,
                                  inactiveTrackColor:
                                      colorScheme.border.withValues(alpha: 0.6),
                                  thumbColor: colorScheme.primary,
                                  overlayColor: colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  valueIndicatorColor: colorScheme.primary,
                                  valueIndicatorTextStyle: TextStyle(
                                    color: colorScheme.primaryForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Slider(
                                  value: sliderPercent,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label: '${sliderPercent.toStringAsFixed(0)}%',
                                  semanticFormatterCallback: (value) =>
                                      '${value.toStringAsFixed(0)} percent',
                                  onChanged: (maxBudgetCents <= 0 ||
                                          isLoading.value)
                                      ? null
                                      : (value) {
                                          if (amountFocusNode.hasFocus) {
                                            amountFocusNode.unfocus();
                                          }

                                          final pct = value.clamp(0.0, 100.0);
                                          final newCents =
                                              quantizePocketBudgetAmountCents(
                                            ((pct / 100.0) * maxBudgetCents)
                                                .round()
                                                .clamp(0, maxBudgetCents)
                                                .toInt(),
                                            stepCents: allocationStepCents,
                                          );
                                          final formatted = formatAmount(
                                            centsToAmount(newCents),
                                          );
                                          amountController.value =
                                              TextEditingValue(
                                            text: formatted,
                                            selection: TextSelection.collapsed(
                                              offset: formatted.length,
                                            ),
                                          );
                                        },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              if (unallocatedBudget < 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 16, color: colorScheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${context.l10n.budgetExceededByLabel} ${formatLocalizedAmount(unallocatedBudget.abs())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
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
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryAdaptiveButton(
                            onPressed: isLoading.value ? null : handleSave,
                            child: isLoading.value
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        colorScheme.primaryForeground,
                                      ),
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? context.l10n.saveChanges
                                        : context.l10n.save,
                                  ),
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 16),
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
  });

  final double totalBudget;
  final List<PocketEnvelope> otherPockets;
  final List<int> otherPocketAmountsCents;
  final int currentAmountCents;
  final String? currentPocketColor;
  final String currentPocketName;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (totalBudget <= 0) return const SizedBox.shrink();

    final totalBudgetCents = (totalBudget * 100).round();
    final currentShare = totalBudgetCents > 0
        ? (currentAmountCents.clamp(0, totalBudgetCents) / totalBudgetCents) *
            100
        : 0.0;

    // Build segments with calculated shares
    final segments = <_Segment>[
      for (var index = 0; index < otherPockets.length; index++)
        _Segment(
          label: otherPockets[index].name.isEmpty
              ? context.l10n.pocketSegmentLabel
              : otherPockets[index].name,
          share: totalBudgetCents > 0
              ? (otherPocketAmountsCents[index] / totalBudgetCents) * 100
              : 0.0,
          color: _hexOrPrimary(otherPockets[index].color, colorScheme),
        ),
      _Segment(
        label: currentPocketName.isEmpty
            ? context.l10n.thisPocketSegmentLabel
            : currentPocketName,
        share: currentShare,
        color: _hexOrPrimary(currentPocketColor, colorScheme),
        isCurrent: true,
      ),
    ];

    // Since we're showing calculated shares, they should always add up to 100
    final totalRebalanced =
        segments.fold<double>(0.0, (sum, s) => sum + s.share);
    final remaining = (100.0 - totalRebalanced).clamp(0, 100);

    // For display, segments should already be balanced to 100%
    final normalizedSegments = segments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(20),
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
                  for (final seg in normalizedSegments)
                    if (seg.share > 0)
                      Flexible(
                        flex: math.max(1, (seg.share * 10).round()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: seg.color,
                        ),
                      ),
                  if (remaining > 0)
                    Flexible(
                      flex: math.max(1, (remaining * 10).round()),
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
              for (final seg in normalizedSegments)
                _LegendItem(
                  color: seg.color,
                  label: seg.label,
                  colorScheme: colorScheme,
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
  });

  final String label;
  final double share;
  final Color color;
  final bool isCurrent;

  _Segment copyWith({double? share}) {
    return _Segment(
      label: label,
      share: share ?? this.share,
      color: color,
      isCurrent: isCurrent,
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
  });

  final Color color;
  final String label;
  final ColorScheme colorScheme;

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

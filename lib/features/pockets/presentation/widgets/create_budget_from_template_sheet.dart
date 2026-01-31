import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class PocketEntry {
  final String id;
  final String name;
  final Color color;
  final List<String> categories;
  final double amount;
  final String? iconName;

  PocketEntry({
    required this.id,
    required this.name,
    required this.color,
    required this.categories,
    required this.amount,
    this.iconName,
  });

  PocketEntry copyWith({
    String? name,
    Color? color,
    List<String>? categories,
    double? amount,
    String? iconName,
  }) {
    return PocketEntry(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      categories: categories ?? this.categories,
      amount: amount ?? this.amount,
      iconName: iconName ?? this.iconName,
    );
  }

  // Convert back to PocketTemplate with calculated weight
  PocketTemplate toTemplate(double totalBudget) {
    return PocketTemplate(
      name: name,
      weight: totalBudget > 0 ? amount / totalBudget : 0,
      color: color,
      suggestedCategories: categories,
      iconName: iconName ?? 'wallet',
    );
  }
}

class CreateBudgetFromTemplateSheet extends HookConsumerWidget {
  const CreateBudgetFromTemplateSheet({
    super.key,
    required this.scopeParams,
  });

  final PocketsScopeParams scopeParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final templateTitleMap = _templateTitleMap(l10n);
    final templateDescriptionMap = _templateDescriptionMap(l10n);

    // -- State --
    final budgetController = useTextEditingController(text: '');
    final budgetFocusNode = useFocusNode();
    final selectedTemplate =
        useState<BudgetTemplate>(BudgetTemplates.all.first);
    final isSubmitting = useState(false);

    // Get selected currency
    final currencyCode =
        ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';
    final currencySymbol = resolveCurrencySymbol(currencyCode);

    // We store the editable pockets here
    final pockets = useState<List<PocketEntry>>([]);

    // Auto-focus the budget input field when the sheet opens
    useEffect(() {
      Future.microtask(() => budgetFocusNode.requestFocus());
      return null;
    }, []);

    // Initialize pockets when template changes
    // We only want to do this when the *user selects a new template*, not on every rebuild.
    // So we watch selectedTemplate.value.
    useEffect(() {
      final totalStr = budgetController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final currentTotal = double.tryParse(totalStr) ?? 0.0;

      pockets.value = selectedTemplate.value.pockets.map((t) {
        // Use the template's predefined color and icon directly
        // This ensures the visual design intent of the template is preserved
        final pocketColor = t.color ?? _fallbackPocketColor(scheme, t.name);

        return PocketEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString() +
              Random().nextInt(1000).toString(), // temporary ID
          name: t.name,
          color: pocketColor,
          categories: t.suggestedCategories,
          amount: currentTotal * t.weight,
          iconName: t.iconName,
        );
      }).toList();
      return null;
    }, [selectedTemplate.value]);

    // Derived total from pockets
    final totalFromPockets =
        pockets.value.fold(0.0, (sum, p) => sum + p.amount);

    // Sync Budget Controller <-> Pockets Sum
    // If user edits the Budget Controller -> Update Pockets proportionally
    useEffect(() {
      void onBudgetChanged() {
        if (budgetFocusNode.hasFocus) {
          final text = budgetController.text.replaceAll(RegExp(r'[^0-9.]'), '');
          final newTotal = double.tryParse(text) ?? 0.0;

          // Avoid infinite loops or tiny updates
          if ((newTotal - totalFromPockets).abs() < 0.01) return;

          // If current total is 0, we can't use ratios. Use template weights.
          if (totalFromPockets == 0) {
            pockets.value = pockets.value.map((p) {
              // Find original template weight if possible, or just split evenly?
              // Better: Look up from current selected template.
              final templatePocket = selectedTemplate.value.pockets.firstWhere(
                  (tp) => tp.name == p.name,
                  orElse: () => selectedTemplate.value.pockets.first);
              return p.copyWith(amount: newTotal * templatePocket.weight);
            }).toList();
          } else {
            // Scale existing amounts
            final ratio = newTotal / totalFromPockets;
            pockets.value = pockets.value
                .map((p) => p.copyWith(amount: p.amount * ratio))
                .toList();
          }
        }
      }

      budgetController.addListener(onBudgetChanged);
      return () => budgetController.removeListener(onBudgetChanged);
    }, [
      budgetController,
      pockets.value,
      totalFromPockets,
      selectedTemplate.value
    ]);

    // If user edits a Pocket (so totalFromPockets changes) -> Update Budget Controller
    // Only if Budget Controller is NOT focused.
    useEffect(() {
      if (!budgetFocusNode.hasFocus) {
        final currentControllerValue = double.tryParse(
                budgetController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
        if ((currentControllerValue - totalFromPockets).abs() > 0.01) {
          // Format elegantly
          final formatted =
              totalFromPockets == 0 ? '0' : formatAmount(totalFromPockets);
          budgetController.text = formatted;
        }
      }
      return null;
    }, [totalFromPockets]); // Run whenever the sum changes

    final isValid = totalFromPockets > 0;

    Future<void> handleSubmit() async {
      if (!isValid || isSubmitting.value) return;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final toastContext = rootNavigator.context;
      isSubmitting.value = true;
      var dialogOpen = false;
      showBlockingProcessingDialog(
        context: toastContext,
        message: l10n.saving,
      );
      dialogOpen = true;

      void closeDialog() {
        if (!dialogOpen) return;
        if (rootNavigator.canPop()) rootNavigator.pop();
        dialogOpen = false;
      }

      try {
        final notifier = ref.read(pocketsProvider(scopeParams).notifier);

        final finalTemplates =
            pockets.value.map((p) => p.toTemplate(totalFromPockets)).toList();

        await notifier.createBudgetFromTemplate(
          totalBudget: totalFromPockets,
          pockets: finalTemplates,
        );
        closeDialog();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        AppToast.success(toastContext, l10n.budgetCreatedSuccessfully);
      } catch (e) {
        closeDialog();
        AppToast.error(toastContext, ErrorHandler.getUserFriendlyMessage(e));
      } finally {
        closeDialog();
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: scheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: scheme.sheetBorder, width: 1),
      ),
      child: PopScope(
        canPop: !isSubmitting.value,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: isSubmitting.value
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: scheme.mutedForeground),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.muted.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.createFromTemplate,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isValid && !isSubmitting.value ? handleSubmit : null,
                    icon: Icon(Icons.check, color: scheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.createFromTemplateDesc,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Budget Input
                      Text(
                        l10n.monthlyBudget,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: budgetController,
                        focusNode: budgetFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                        decoration: InputDecoration(
                          prefixText: currencySymbol,
                          prefixStyle: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: scheme.mutedForeground,
                          ),
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(
                              color: scheme.mutedForeground
                                  .withValues(alpha: 0.3)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Template Selector
                      Text(
                        'Select Strategy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120, // Slightly more compact
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: BudgetTemplates.all.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final template = BudgetTemplates.all[index];
                            final isSelected =
                                selectedTemplate.value.id == template.id;
                            final templateTitle =
                                templateTitleMap[template.translationKeyName] ??
                                    l10n.createFromTemplate;
                            final templateDescription = templateDescriptionMap[
                                    template.translationKeyDescription] ??
                                l10n.createFromTemplateDesc;

                            return GestureDetector(
                              onTap: () {
                                if (!isSelected) {
                                  selectedTemplate.value = template;
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 150,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? scheme.primary.withValues(alpha: 0.1)
                                      : scheme.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.outline.withValues(alpha: 0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _getIconData(template.iconName),
                                      size: 24,
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.mutedForeground,
                                    ),
                                    const Spacer(),
                                    Text(
                                      templateTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.foreground,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                    ),
                                    Text(
                                      templateDescription,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.mutedForeground,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Pocket Breakdown
                      Text(
                        'Customize Pockets',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List of editable pockets
                      ...pockets.value.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pocket = entry.value;

                        return _PocketRow(
                          key: ValueKey(
                              pocket.id), // Important for focus stability
                          entry: pocket,
                          totalBudget: totalFromPockets,
                          currencySymbol: currencySymbol,
                          onAmountChanged: (newAmount) {
                            final newPockets = [...pockets.value];
                            newPockets[index] =
                                pocket.copyWith(amount: newAmount);
                            pockets.value = newPockets;
                          },
                          onRemove: () {
                            final newPockets = [...pockets.value];
                            newPockets.removeAt(index);
                            pockets.value = newPockets;
                          },
                          onEdit: () {
                            // Create a temporary PocketEnvelope to pass as "existing"
                            final tempEnvelope = PocketEnvelope(
                              id: pocket.id,
                              name: pocket.name,
                              budgetAmountCents: (pocket.amount * 100).round(),
                              spent: 0,
                              currency:
                                  'USD', // Placeholder, sheet uses provider
                              icon: pocket.iconName,
                              color:
                                  '#${(pocket.color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(pocket.color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(pocket.color.b * 255).round().toRadixString(16).padLeft(2, '0')}',
                              lastUpdated: DateTime.now(),
                            );

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor:
                                  scheme.surface.withValues(alpha: 0.0),
                              builder: (context) => EditPocketEnvelopeSheet(
                                scopeParams: scopeParams,
                                existingEnvelope: tempEnvelope,
                                totalBudget: totalFromPockets,
                                unallocatedBudget:
                                    0, // In builder, we just assume 0 or let user adjust
                                budgetId: null,
                                initialCategories: pocket.categories,
                                onSaveOffline: (newTemplate) {
                                  final newPockets = [...pockets.value];
                                  // Update pocket with new details from template
                                  // Recalculate amount based on new weight and current total budget
                                  newPockets[index] = pocket.copyWith(
                                    name: newTemplate.name,
                                    color: newTemplate.color,
                                    categories: newTemplate.suggestedCategories,
                                    iconName: newTemplate.iconName,
                                    amount:
                                        totalFromPockets * newTemplate.weight,
                                  );
                                  pockets.value = newPockets;
                                },
                              ),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: scheme.sheetBackground,
                border: Border(top: BorderSide(color: scheme.sheetBorder)),
              ),
              child: PrimaryAdaptiveButton(
                onPressed: !isValid || isSubmitting.value ? null : handleSubmit,
                child: isSubmitting.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.createBudget),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _fallbackPocketColor(ColorScheme scheme, String seed) {
  final palette = <Color>[
    scheme.secondary,
    scheme.tertiary,
    scheme.primary,
    scheme.error,
  ];
  return palette[seed.hashCode.abs() % palette.length];
}

Map<String, String> _templateTitleMap(AppLocalizations l10n) => {
      'templateBalancedTitle': l10n.templateBalancedTitle,
      'templateRentHeavyTitle': l10n.templateRentHeavyTitle,
      'template_couple_dink_title': l10n.template_couple_dink_title,
      'template_couple_fire_title': l10n.template_couple_fire_title,
      'template_couple_debt_title': l10n.template_couple_debt_title,
      'template_couple_foodies_title': l10n.template_couple_foodies_title,
      'template_couple_home_title': l10n.template_couple_home_title,
      'template_couple_travel_title': l10n.template_couple_travel_title,
      'template_family_bal_title': l10n.template_family_bal_title,
      'template_family_single_title': l10n.template_family_single_title,
      'template_family_pets_title': l10n.template_family_pets_title,
      'template_family_health_title': l10n.template_family_health_title,
      'template_family_active_title': l10n.template_family_active_title,
      'template_family_host_title': l10n.template_family_host_title,
      'template_mates_split_title': l10n.template_mates_split_title,
      'template_mates_party_title': l10n.template_mates_party_title,
      'template_mates_nomads_title': l10n.template_mates_nomads_title,
      'template_mates_student_title': l10n.template_mates_student_title,
      'template_mates_communal_title': l10n.template_mates_communal_title,
      'template_mates_min_title': l10n.template_mates_min_title,
      'template_pers_freelancer_title': l10n.template_pers_freelancer_title,
      'template_pers_student_title': l10n.template_pers_student_title,
      'template_pers_luxury_title': l10n.template_pers_luxury_title,
      'template_pers_car_title': l10n.template_pers_car_title,
      'template_pers_bio_title': l10n.template_pers_bio_title,
      'template_pers_gamer_title': l10n.template_pers_gamer_title,
    };

Map<String, String> _templateDescriptionMap(AppLocalizations l10n) => {
      'templateBalancedDesc': l10n.templateBalancedDesc,
      'templateRentHeavyDesc': l10n.templateRentHeavyDesc,
      'template_couple_dink_desc': l10n.template_couple_dink_desc,
      'template_couple_fire_desc': l10n.template_couple_fire_desc,
      'template_couple_debt_desc': l10n.template_couple_debt_desc,
      'template_couple_foodies_desc': l10n.template_couple_foodies_desc,
      'template_couple_home_desc': l10n.template_couple_home_desc,
      'template_couple_travel_desc': l10n.template_couple_travel_desc,
      'template_family_bal_desc': l10n.template_family_bal_desc,
      'template_family_single_desc': l10n.template_family_single_desc,
      'template_family_pets_desc': l10n.template_family_pets_desc,
      'template_family_health_desc': l10n.template_family_health_desc,
      'template_family_active_desc': l10n.template_family_active_desc,
      'template_family_host_desc': l10n.template_family_host_desc,
      'template_mates_split_desc': l10n.template_mates_split_desc,
      'template_mates_party_desc': l10n.template_mates_party_desc,
      'template_mates_nomads_desc': l10n.template_mates_nomads_desc,
      'template_mates_student_desc': l10n.template_mates_student_desc,
      'template_mates_communal_desc': l10n.template_mates_communal_desc,
      'template_mates_min_desc': l10n.template_mates_min_desc,
      'template_pers_freelancer_desc': l10n.template_pers_freelancer_desc,
      'template_pers_student_desc': l10n.template_pers_student_desc,
      'template_pers_luxury_desc': l10n.template_pers_luxury_desc,
      'template_pers_car_desc': l10n.template_pers_car_desc,
      'template_pers_bio_desc': l10n.template_pers_bio_desc,
      'template_pers_gamer_desc': l10n.template_pers_gamer_desc,
    };

IconData _getIconData(String name) {
  switch (name) {
    case 'home':
      return Icons.home;
    case 'home_work':
      return Icons.home_work;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet;
    case 'savings':
      return Icons.savings;
    case 'credit_card':
      return Icons.credit_card;
    case 'restaurant':
      return Icons.restaurant;
    case 'flight':
      return Icons.flight;
    case 'family_restroom':
      return Icons.family_restroom;
    case 'warning':
      return Icons.warning;
    case 'pets':
      return Icons.pets;
    case 'medical_services':
      return Icons.medical_services;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'celebration':
      return Icons.celebration;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'party_mode':
      return Icons.party_mode;
    case 'wifi':
      return Icons.wifi;
    case 'school':
      return Icons.school;
    case 'group':
      return Icons.group;
    case 'remove':
      return Icons.remove;
    case 'work':
      return Icons.work;
    case 'diamond':
      return Icons.diamond;
    case 'directions_car':
      return Icons.directions_car;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'sports_esports':
      return Icons.sports_esports;
    default:
      return Icons.help_outline;
  }
}

class _PocketRow extends HookWidget {
  const _PocketRow({
    super.key,
    required this.entry,
    required this.totalBudget,
    required this.currencySymbol,
    required this.onAmountChanged,
    required this.onEdit,
    required this.onRemove,
  });

  final PocketEntry entry;
  final double totalBudget;
  final String currencySymbol;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final controller =
        useTextEditingController(text: formatAmount(entry.amount));
    final focusNode = useFocusNode();

    // Sync external amount change to controller (if not focused)
    useEffect(() {
      if (!focusNode.hasFocus) {
        final textVal = double.tryParse(
                controller.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
        // Only update if significantly different to avoid cursor jumps or formatting wars
        if ((textVal - entry.amount).abs() > 0.01) {
          controller.text = formatAmount(entry.amount);
        }
      }
      return null;
    }, [entry.amount]);

    // Handle user edits
    useEffect(() {
      void listener() {
        if (focusNode.hasFocus) {
          final val = double.tryParse(
                  controller.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;
          onAmountChanged(val);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller, focusNode]);

    final share = totalBudget > 0 ? (entry.amount / totalBudget) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (entry.iconName != null) ...[
                Icon(
                  _getIconData(entry.iconName!),
                  size: 24,
                  color: entry.color,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                      ),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textAlign: TextAlign.end,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.foreground,
                  ),
                  decoration: InputDecoration(
                    prefixText: currencySymbol,
                    prefixStyle: TextStyle(
                      color: scheme.mutedForeground,
                      fontWeight: FontWeight.bold,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: scheme.border),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: scheme.destructive.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              backgroundColor: scheme.muted,
              valueColor: AlwaysStoppedAnimation(entry.color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

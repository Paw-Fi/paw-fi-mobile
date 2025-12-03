import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/plain-adaptive-button.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

class EditPocketEnvelopeSheet extends HookConsumerWidget {
  const EditPocketEnvelopeSheet({
    super.key,
    required this.scopeParams,
    this.existingEnvelope,
    required this.totalBudget,
    required this.unallocatedBudget,
    required this.budgetId,
    this.allPockets = const [],
    this.onDeleteCompleted,
  });

  final PocketsScopeParams scopeParams;
  final PocketEnvelope? existingEnvelope;
  final double totalBudget;
  final double unallocatedBudget;
  final String? budgetId;
  final List<PocketEnvelope> allPockets;
  final VoidCallback? onDeleteCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = existingEnvelope != null;
    final selectedCurrency =
        ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';

    final nameController = useTextEditingController(
      text: existingEnvelope?.name ?? '',
    );
    final percentageController = useTextEditingController(
      text: existingEnvelope != null
          ? existingEnvelope!.percentage.toStringAsFixed(1)
          : '',
    );

    useListenable(percentageController);
    useListenable(nameController);

    final effectiveMax = 100.0;

    final currentPct = double.tryParse(percentageController.text) ?? 0.0;
    final sliderValue = useState<double>(currentPct.clamp(0, effectiveMax));

    useEffect(() {
      final val = double.tryParse(percentageController.text);
      if (val != null && val != sliderValue.value) {
        sliderValue.value = val.clamp(0, effectiveMax);
      }
      return null;
    }, [percentageController.text]);

    final selectedCategories = useState<List<String>>(<String>[]);
    final selectedColor = useState<String?>(existingEnvelope?.color);
    final selectedIcon = useState<String?>(existingEnvelope?.icon);
    final isLoading = useState<bool>(false);
    final currency = selectedCurrency;

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

    final allCategories = getExpenseCategories();

    Future<void> handleSave() async {
      final l10n = context.l10n;
      final name = nameController.text.trim();
      final percentageText = percentageController.text.trim();

      if (name.isEmpty) {
        AppToast.error(context, l10n.pleaseEnterPocketName);
        return;
      }

      if (percentageText.isEmpty) {
        AppToast.error(context, l10n.pleaseEnterPocketPercentage);
        return;
      }

      final percentage = double.tryParse(percentageText);
      if (percentage == null || percentage < 0 || percentage > 100) {
        AppToast.error(context, l10n.pleaseEnterValidPocketPercentage);
        return;
      }

      if (selectedCategories.value.isEmpty) {
        AppToast.info(context, l10n.pleaseSelectCategory);
        return;
      }

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        AppToast.info(context, l10n.userNotAuthenticated);
        return;
      }

      final isHousehold = scopeParams.scope == PocketsScopeType.household;
      final householdId = scopeParams.householdId;

      if (isHousehold && householdId == null) {
        AppToast.info(context, l10n.pleaseSelectHouseholdFirst);
        return;
      }

      if (budgetId == null) {
        AppToast.info(context, l10n.pleaseSetMonthlyBudgetFirst);
        return;
      }

      isLoading.value = true;

      try {
        // Rebalance percentages so total always equals 100
        final others = allPockets
            .where((p) => isEditing ? p.id != existingEnvelope!.id : true)
            .toList();
        var desiredPct =
            double.parse(percentage.clamp(0, 100).toStringAsFixed(2));
        var targetOtherTotal = (100 - desiredPct).clamp(0, 100);
        final totalOther =
            others.fold<double>(0.0, (sum, p) => sum + p.percentage);

        final adjustedOthers = <String, double>{};
        if (others.isEmpty) {
          desiredPct = 100;
          targetOtherTotal = 0;
        } else if (totalOther <= 0) {
          final even = targetOtherTotal / others.length;
          var remaining = targetOtherTotal;
          for (var i = 0; i < others.length; i++) {
            final pct = i == others.length - 1 ? remaining : even;
            remaining -= pct;
            adjustedOthers[others[i].id] = double.parse(pct.toStringAsFixed(2));
          }
        } else {
          final factor = targetOtherTotal / totalOther;
          var remaining = targetOtherTotal;
          for (var i = 0; i < others.length; i++) {
            final raw = (others[i].percentage * factor).clamp(0, 100);
            final pct = i == others.length - 1
                ? remaining
                : double.parse(raw.toStringAsFixed(2));
            remaining -= pct;
            adjustedOthers[others[i].id] =
                double.parse(pct.clamp(0, 100).toStringAsFixed(2));
          }
        }

        String envelopeId;
        if (isEditing) {
          envelopeId = existingEnvelope!.id;

          await supabase.from('budget_envelopes').update(<String, dynamic>{
            'name': name,
            'budget_id': budgetId,
            'budget_percentage': desiredPct,
            'updated_at': DateTime.now().toIso8601String(),
            'color': selectedColor.value,
            'icon': selectedIcon.value,
            'household_id': isHousehold ? householdId : null,
            'currency': selectedCurrency,
          }).eq('id', envelopeId);

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
                'budget_percentage': desiredPct,
                'household_id': isHousehold ? householdId : null,
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
        }

        // Persist redistributed percentages for other envelopes
        final nowIso = DateTime.now().toIso8601String();
        for (final entry in adjustedOthers.entries) {
          await supabase.from('budget_envelopes').update(<String, dynamic>{
            'budget_percentage': entry.value,
            'budget_id': budgetId,
            'household_id': isHousehold ? householdId : null,
            'currency': selectedCurrency,
            'updated_at': nowIso,
          }).eq('id', entry.key);
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

        ref.invalidate(pocketsProvider(scopeParams));

        if (context.mounted) {
          Navigator.of(context).pop();
          final message =
              isEditing ? l10n.budgetUpdated : l10n.budgetCreatedSuccessfully;
          AppToast.success(context, message);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, l10n.failedToSave(e.toString()));
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> handleDelete() async {
      if (!isEditing) return;

      final l10n = context.l10n;
      final navigator = Navigator.of(context);

      AdaptiveAlertDialog.show(
        context: context,
        title: l10n.pocketDeleteTitle,
        message: l10n.pocketDeleteMessage,
        icon: 'trash.fill',
        actions: [
          AlertAction(
            title: l10n.cancel,
            onPressed: () {
              navigator.pop(false);
            },
          ),
          AlertAction(
            title: l10n.delete,
            style: AlertActionStyle.destructive,
            onPressed: () async {
              isLoading.value = true;
              try {
                await supabase
                    .from('budget_envelopes')
                    .delete()
                    .eq('id', existingEnvelope!.id);

                ref.invalidate(pocketsProvider(scopeParams));

                if (context.mounted) {
                  // First close the confirmation dialog, then the bottom sheet.
                  navigator.pop();
                  navigator.pop();

                  onDeleteCompleted?.call();
                  AppToast.success(context, l10n.pocketDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  AppToast.error(context, l10n.failedToDeletePocket);
                }
              } finally {
                isLoading.value = false;
              }
            },
          ),
        ],
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
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
                          backgroundColor: Colors.transparent,
                          builder: (sheetContext) {
                            return CategoryPickerBottomSheet(
                              allCategories: allCategories,
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
                          color: colorScheme.card,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withOpacity(0.1),
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
                      final presetColors = [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.deepPurple,
                        Colors.indigo,
                        Colors.blue,
                        Colors.lightBlue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lightGreen,
                        Colors.lime,
                        Colors.yellow,
                        Colors.amber,
                        Colors.orange,
                        Colors.deepOrange,
                        Colors.brown,
                        Colors.grey,
                        Colors.blueGrey,
                      ];
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
                                  final currentColor = selectedColor.value !=
                                          null
                                      ? Color(int.parse(
                                              selectedColor.value!
                                                  .substring(1, 7),
                                              radix: 16) +
                                          0xFF000000)
                                      : const Color(0xFF007AFF); // Default blue

                                  AdaptiveColorPicker.show(
                                    context: context,
                                    startingColor: currentColor,
                                    onColorChanged: (color) {
                                      String two(int n) =>
                                          n.toRadixString(16).padLeft(2, '0');
                                      int toByte(double x) =>
                                          (x * 255.0).round() & 0xff;
                                      final hex =
                                          '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                                      selectedColor.value = hex;
                                    },
                                    label: context.l10n.selectColor,
                                  );
                                },
                                child: Container(
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
                                            colors: [
                                              Colors.red,
                                              Colors.yellow,
                                              Colors.green,
                                              Colors.cyan,
                                              Colors.blue,
                                              Colors.purpleAccent,
                                              Colors.red
                                            ],
                                          ),
                                    shape: BoxShape.circle,
                                    border: isCustomColor
                                        ? Border.all(
                                            color: colorScheme.foreground,
                                            width: 2)
                                        : Border.all(color: colorScheme.border),
                                    boxShadow: [
                                      // Shadow removed as requested
                                    ],
                                  ),
                                  child: isCustomColor
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : const Icon(Icons.colorize,
                                          color: Colors.white, size: 20),
                                ),
                              );
                            }
                            final color = presetColors[index - 1];
                            String two(int n) =>
                                n.toRadixString(16).padLeft(2, '0');
                            int toByte(double x) => (x * 255.0).round() & 0xff;
                            final hex =
                                '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                            final isSelected =
                                selectedColor.value?.toLowerCase() ==
                                    hex.toLowerCase();

                            return GestureDetector(
                              onTap: () => selectedColor.value = hex,
                              child: Container(
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
                                  boxShadow: [
                                    // Shadow removed as requested
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 20)
                                    : null,
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
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final iconName = pocketIconNames[index];
                          final selectedHex = selectedColor.value;
                          final selectedColorValue = selectedHex != null
                              ? Color(int.parse(
                                      selectedHex.replaceFirst('#', ''),
                                      radix: 16) +
                                  0xFF000000)
                              : colorScheme.primary;

                          IconData iconData;
                          switch (iconName) {
                            case 'shopping_bag':
                              iconData = Icons.shopping_bag;
                              break;
                            case 'restaurant':
                              iconData = Icons.restaurant;
                              break;
                            case 'directions_car':
                              iconData = Icons.directions_car;
                              break;
                            case 'home':
                              iconData = Icons.home;
                              break;
                            case 'flight':
                              iconData = Icons.flight;
                              break;
                            case 'medical_services':
                              iconData = Icons.medical_services;
                              break;
                            case 'school':
                              iconData = Icons.school;
                              break;
                            case 'pets':
                              iconData = Icons.pets;
                              break;
                            case 'sports_esports':
                              iconData = Icons.sports_esports;
                              break;
                            case 'fitness_center':
                              iconData = Icons.fitness_center;
                              break;
                            case 'local_cafe':
                              iconData = Icons.local_cafe;
                              break;
                            case 'local_bar':
                              iconData = Icons.local_bar;
                              break;
                            case 'movie':
                              iconData = Icons.movie;
                              break;
                            case 'music_note':
                              iconData = Icons.music_note;
                              break;
                            case 'savings':
                              iconData = Icons.savings;
                              break;
                            case 'account_balance':
                              iconData = Icons.account_balance;
                              break;
                            default:
                              iconData = Icons.category;
                          }

                          final isSelected = selectedIcon.value == iconName;

                          return GestureDetector(
                            onTap: () => selectedIcon.value = iconName,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColorValue.withOpacity(0.1)
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatCurrency(
                                        totalBudget *
                                            (sliderValue.value / 100.0),
                                        currency),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.foreground,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${sliderValue.value.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.mutedForeground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                formatCurrency(totalBudget, currency),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 6,
                              activeTrackColor: colorScheme.primary,
                              inactiveTrackColor:
                                  colorScheme.primary.withOpacity(0.1),
                              thumbColor: colorScheme.surface,
                              overlayColor:
                                  colorScheme.primary.withOpacity(0.1),
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12, elevation: 4),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24),
                            ),
                            child: Slider(
                              value: sliderValue.value,
                              min: 0,
                              max: effectiveMax,
                              divisions: 20,
                              onChanged: (value) {
                                sliderValue.value = value;
                                percentageController.text =
                                    value.toStringAsFixed(1);
                              },
                            ),
                          ),
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
                                      '${context.l10n.budgetExceededByLabel} ${(unallocatedBudget.abs()).toStringAsFixed(0)}',
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
                      allPockets: allPockets,
                      currentPocketId: existingEnvelope?.id,
                      currentAllocation: sliderValue.value,
                      currentPocketColor: selectedColor.value,
                      currentPocketName: nameController.text.trim().isEmpty
                          ? context.l10n.thisPocketFallback
                          : nameController.text.trim(),
                      currency: currency,
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
    );
  }
}

class _BudgetDistributionPreview extends StatelessWidget {
  const _BudgetDistributionPreview({
    required this.totalBudget,
    required this.allPockets,
    required this.currentPocketId,
    required this.currentAllocation,
    required this.currentPocketColor,
    required this.currentPocketName,
    required this.currency,
    required this.colorScheme,
  });

  final double totalBudget;
  final List<PocketEnvelope> allPockets;
  final String? currentPocketId;
  final double currentAllocation;
  final String? currentPocketColor;
  final String currentPocketName;
  final String currency;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (totalBudget <= 0) return const SizedBox.shrink();

    // Calculate rebalanced percentages (what will actually be saved)
    final otherPockets =
        allPockets.where((p) => p.id != currentPocketId).toList();
    final desiredPct = currentAllocation.clamp(0, 100);
    final targetOtherTotal = (100 - desiredPct).clamp(0, 100);
    final totalOther =
        otherPockets.fold<double>(0.0, (sum, p) => sum + p.percentage);

    // Calculate adjusted percentages for other pockets
    final rebalancedOthers = <String, double>{};
    if (otherPockets.isEmpty) {
      // Only current pocket, it gets 100%
    } else if (totalOther <= 0) {
      // Distribute evenly among other pockets
      final even = targetOtherTotal / otherPockets.length;
      for (var p in otherPockets) {
        rebalancedOthers[p.id] = even;
      }
    } else {
      // Proportionally reduce other pockets
      final factor = targetOtherTotal / totalOther;
      for (var p in otherPockets) {
        rebalancedOthers[p.id] = (p.percentage * factor).clamp(0, 100);
      }
    }

    // Build segments with rebalanced percentages
    final segments = <_Segment>[
      for (final p in otherPockets)
        _Segment(
          label: p.name.isEmpty ? context.l10n.pocketSegmentLabel : p.name,
          percentage: rebalancedOthers[p.id] ?? 0,
          color: _hexOrPrimary(p.color, colorScheme),
        ),
      _Segment(
        label: currentPocketName.isEmpty
            ? context.l10n.thisPocketSegmentLabel
            : currentPocketName,
        percentage: (otherPockets.isEmpty ? 100 : desiredPct).toDouble(),
        color: _hexOrPrimary(currentPocketColor, colorScheme),
        isCurrent: true,
      ),
    ];

    // Since we're showing rebalanced percentages, they should always add up to 100
    final totalRebalanced =
        segments.fold<double>(0.0, (sum, s) => sum + s.percentage);
    final remaining = (100.0 - totalRebalanced).clamp(0, 100);

    // For display, segments should already be balanced to 100%
    final normalizedSegments = segments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
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
                    if (seg.percentage > 0)
                      Flexible(
                        flex: (seg.percentage * 10).round(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: seg.color,
                        ),
                      ),
                  if (remaining > 0)
                    Flexible(
                      flex: remaining.clamp(0, 100).round(),
                      child: Container(color: Colors.transparent),
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
    required this.percentage,
    required this.color,
    this.isCurrent = false,
  });

  final String label;
  final double percentage;
  final Color color;
  final bool isCurrent;

  _Segment copyWith({double? percentage}) {
    return _Segment(
      label: label,
      percentage: percentage ?? this.percentage,
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

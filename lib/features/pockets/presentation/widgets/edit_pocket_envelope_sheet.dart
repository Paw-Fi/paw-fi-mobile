import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:moneko/core/theme/app_theme.dart';

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
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

const _presetIcons = [
  'shopping_bag',
  'restaurant',
  'directions_car',
  'home',
  'flight',
  'medical_services',
  'school',
  'pets',
  'sports_esports',
  'fitness_center',
  'local_cafe',
  'local_bar',
  'movie',
  'music_note',
  'savings',
  'account_balance',
];

class EditPocketEnvelopeSheet extends HookConsumerWidget {
  const EditPocketEnvelopeSheet({
    super.key,
    required this.scopeParams,
    this.existingEnvelope,
    required this.totalBudget,
    required this.unallocatedBudget,
    this.allPockets = const [],
  });

  final PocketsScopeParams scopeParams;
  final PocketEnvelope? existingEnvelope;
  final double totalBudget;
  final double unallocatedBudget;
  final List<PocketEnvelope> allPockets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = existingEnvelope != null;
    final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;

    final nameController = useTextEditingController(
      text: existingEnvelope?.name ?? '',
    );
    final percentageController = useTextEditingController(
      text: existingEnvelope != null
          ? existingEnvelope!.percentage.toStringAsFixed(1)
          : '',
    );

    useListenable(percentageController);

    // Calculate current percentage and remaining
    final currentPercentage = existingEnvelope?.percentage ?? 0.0;
    final totalAllocated =
        allPockets.fold<double>(0.0, (sum, p) => sum + p.percentage);
    final remainingPercentage = 100.0 - (totalAllocated - currentPercentage);

    final effectiveMax = remainingPercentage.clamp(0.0, 100.0);

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
        AppToast.info(context, 'Please enter a name');
        return;
      }

      if (percentageText.isEmpty) {
        AppToast.info(context, 'Please enter a percentage');
        return;
      }

      final percentage = double.tryParse(percentageText);
      if (percentage == null || percentage < 0 || percentage > 100) {
        AppToast.info(context, 'Please enter a valid percentage (0-100)');
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
        AppToast.info(context, 'Select a household first');
        return;
      }

      isLoading.value = true;

      try {
        String envelopeId;
        if (isEditing) {
          envelopeId = existingEnvelope!.id;

          await supabase.from('budget_envelopes').update(<String, dynamic>{
            'name': name,
            'budget_percentage': percentage,
            'updated_at': DateTime.now().toIso8601String(),
            'color': selectedColor.value,
            'icon': selectedIcon.value,
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
                'name': name,
                'budget_percentage': percentage,
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
          AppToast.info(context, message);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.info(context, 'Failed to save envelope: ${e.toString()}');
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> handleDelete() async {
      if (!isEditing) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Envelope?'),
          content: const Text(
              'This will remove the envelope and its category links. Your expenses will not be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: colorScheme.destructive),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      isLoading.value = true;
      try {
        await supabase
            .from('budget_envelopes')
            .delete()
            .eq('id', existingEnvelope!.id);

        ref.invalidate(pocketsProvider(scopeParams));

        if (context.mounted) {
          Navigator.of(context).pop();
          AppToast.info(context, 'Envelope deleted');
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.info(context, 'Failed to delete envelope: ${e.toString()}');
        }
      } finally {
        isLoading.value = false;
      }
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
                      isEditing ? 'Edit envelope' : 'Add envelope',
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
                      'Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: nameController,
                      placeholder: 'Envelope name',
                    ),
                    const SizedBox(height: 20),
                    _BudgetDistributionPreview(
                      totalBudget: totalBudget,
                      allPockets: allPockets,
                      currentPocketId: existingEnvelope?.id,
                      currentAllocation: sliderValue.value,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.budgetAmount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Allocation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${((sliderValue.value / (totalBudget > 0 ? totalBudget : 1)).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}% of budget',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 120,
                                child: CustomTextField(
                                  controller: percentageController,
                                  keyboardType: TextInputType.number,
                                  placeholder: '0',
                                  textAlign: TextAlign.end,
                                  onChanged: (value) {
                                    final val = double.tryParse(value);
                                    if (val != null) {
                                      sliderValue.value =
                                          val.clamp(0, effectiveMax);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                              divisions: 100,
                              onChanged: (value) {
                                sliderValue.value = value;
                                percentageController.text =
                                    value.toStringAsFixed(1);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              Text(
                                '${effectiveMax.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
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
                                      'Budget exceeded by ${(unallocatedBudget.abs()).toStringAsFixed(0)}',
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
                    Text(
                      'Categories',
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
                                      'Tap to select categories',
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
                      'Color',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        final currentColor = selectedColor.value != null
                            ? Color(int.parse(
                                    selectedColor.value!.substring(1, 7),
                                    radix: 16) +
                                0xFF000000)
                            : const Color(0xFF007AFF); // Default blue

                        if (PlatformInfo.isIOS) {
                          // iOS: Use native iOS color picker
                          final iosColorPickerController =
                              IOSColorPickerController();
                          iosColorPickerController.showIOSCustomColorPicker(
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
                            context: context,
                          );
                        } else {
                          // Android/Other: Use flutter_colorpicker
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('Select color'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: currentColor,
                                    onColorChanged: (color) {
                                      String two(int n) =>
                                          n.toRadixString(16).padLeft(2, '0');
                                      int toByte(double x) =>
                                          (x * 255.0).round() & 0xff;
                                      final hex =
                                          '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                                      selectedColor.value = hex;
                                    },
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Done'),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: selectedColor.value != null
                              ? Color(int.parse(
                                      selectedColor.value!.substring(1, 7),
                                      radix: 16) +
                                  0xFF000000)
                              : const Color(0xFF007AFF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.border,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.colorize,
                            color: Colors.white.withOpacity(0.8),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Icon',
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
                        itemCount: _presetIcons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final iconName = _presetIcons[index];

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
                                    ? colorScheme.primary.withOpacity(0.1)
                                    : colorScheme.card,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.border,
                                ),
                              ),
                              child: Icon(
                                iconData,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.mutedForeground,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
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
                        child: AdaptiveButton.child(
                          onPressed: isLoading.value ? null : handleDelete,
                          child: Text(
                            'Delete Envelope',
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
    required this.colorScheme,
  });

  final double totalBudget;
  final List<PocketEnvelope> allPockets;
  final String? currentPocketId;
  final double currentAllocation;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (totalBudget <= 0) return const SizedBox.shrink();

    // Calculate other pockets' total percentage
    final otherPocketsTotal = allPockets
        .where((p) => p.id != currentPocketId)
        .fold(0.0, (sum, p) => sum + p.percentage);

    final totalAllocated = otherPocketsTotal + currentAllocation;
    final remaining = 100.0 - totalAllocated;
    final isOverBudget = remaining < 0;

    // Calculate percentages for the bar
    final otherPct = (otherPocketsTotal / 100.0).clamp(0.0, 1.0);
    final currentPct = (currentAllocation / 100.0).clamp(0.0, 1.0);
    // If over budget, we scale down to fit or just show full bar with warning
    // Let's stick to a simple stacked bar where 100% is totalBudget.

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
                'Budget Impact',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              Text(
                isOverBudget
                    ? 'Over by ${(remaining.abs()).toStringAsFixed(0)}'
                    : '${remaining.toStringAsFixed(0)} remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOverBudget
                      ? colorScheme.error
                      : colorScheme.mutedForeground,
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
                  // Other Pockets Segment
                  if (otherPct > 0)
                    Flexible(
                      flex: (otherPct * 1000).toInt(),
                      child: Container(
                        color: colorScheme.muted.withOpacity(0.3),
                      ),
                    ),
                  // Current Pocket Segment (Animated)
                  if (currentPct > 0)
                    Flexible(
                      flex: (currentPct * 1000).toInt(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        color: isOverBudget
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                  // Remaining Space (Implicit via Flex)
                  if (!isOverBudget && (1.0 - otherPct - currentPct) > 0)
                    Flexible(
                      flex: ((1.0 - otherPct - currentPct) * 1000).toInt(),
                      child: Container(color: Colors.transparent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendItem(
                color: colorScheme.muted.withOpacity(0.3),
                label: 'Others',
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              _LegendItem(
                color: isOverBudget ? colorScheme.error : colorScheme.primary,
                label: 'This Pocket',
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
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

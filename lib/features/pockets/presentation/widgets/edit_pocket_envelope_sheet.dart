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

const _presetColors = [
  '#FF3B30', // Red
  '#FF9500', // Orange
  '#FFCC00', // Yellow
  '#34C759', // Green
  '#00C7BE', // Teal
  '#30B0C7', // Cyan
  '#32ADE6', // Blue
  '#007AFF', // Royal Blue
  '#5856D6', // Purple
  '#AF52DE', // Magenta
  '#FF2D55', // Pink
  '#A2845E', // Brown
];

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
  });

  final PocketsScopeParams scopeParams;
  final PocketEnvelope? existingEnvelope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = existingEnvelope != null;
    final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency;

    final nameController = useTextEditingController(
      text: existingEnvelope?.name ?? '',
    );
    final amountController = useTextEditingController(
      text: existingEnvelope != null
          ? existingEnvelope!.limit.toStringAsFixed(0)
          : '',
    );

    useListenable(amountController);

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
      final amountText = amountController.text.trim();

      if (name.isEmpty) {
        AppToast.info('Please enter a name');
        return;
      }

      if (amountText.isEmpty) {
        AppToast.info(l10n.pleaseEnterAmount);
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        AppToast.info(l10n.pleaseEnterValidAmount);
        return;
      }

      if (selectedCategories.value.isEmpty) {
        AppToast.info(l10n.pleaseSelectCategory);
        return;
      }

      final user = ref.read(authProvider);
      if (user.uid.isEmpty) {
        AppToast.info(l10n.userNotAuthenticated);
        return;
      }

      final isHousehold = scopeParams.scope == PocketsScopeType.household;
      final householdId = scopeParams.householdId;

      if (isHousehold && householdId == null) {
        AppToast.info('Select a household first');
        return;
      }

      isLoading.value = true;

      try {
        final cents = (amount * 100).round();
        String envelopeId;

        if (isEditing) {
          envelopeId = existingEnvelope!.id;

          await supabase.from('budget_envelopes').update(<String, dynamic>{
            'name': name,
            'monthly_target_cents': cents,
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
                'monthly_target_cents': cents,
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
          AppToast.info(message);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.info('Failed to save envelope: ${e.toString()}');
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
          AppToast.info('Envelope deleted');
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.info('Failed to delete envelope: ${e.toString()}');
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
                    Text(
                      context.l10n.budgetAmount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      placeholder: '0.00',
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
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _presetColors.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final colorHex = _presetColors[index];
                                final color = Color(int.parse(
                                        colorHex.substring(1, 7),
                                        radix: 16) +
                                    0xFF000000);
                                final isSelected =
                                    selectedColor.value == colorHex;

                                return GestureDetector(
                                  onTap: () => selectedColor.value = colorHex,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: colorScheme.foreground,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: ThemeData
                                                        .estimateBrightnessForColor(
                                                            color) ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            final currentColor = selectedColor.value != null
                                ? Color(int.parse(
                                        selectedColor.value!.substring(1, 7),
                                        radix: 16) +
                                    0xFF000000)
                                : Colors.blue;

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
                                          String two(int n) => n
                                              .toRadixString(16)
                                              .padLeft(2, '0');
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.card,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.border),
                            ),
                            child: Icon(
                              Icons.colorize,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
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

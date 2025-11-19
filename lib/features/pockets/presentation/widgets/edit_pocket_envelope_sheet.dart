import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

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

          await supabase
              .from('budget_envelopes')
              .update(<String, dynamic>{
            'name': name,
            'monthly_target_cents': cents,
            'updated_at': DateTime.now().toIso8601String(),
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
          }).select('id').maybeSingle();

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
          await supabase
              .from('envelope_category_links')
              .insert(linksPayload);
        }

        ref.invalidate(pocketsProvider(scopeParams));

        if (context.mounted) {
          Navigator.of(context).pop();
          final message = isEditing
              ? l10n.budgetUpdated
              : l10n.budgetCreatedSuccessfully;
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
                          ? 'Edit envelope'
                          : 'Add envelope',
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
                    if (selectedCategories.value.isEmpty)
                      Text(
                        'No categories selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat in selectedCategories.value)
                            Chip(
                              label: Text(
                                getCategoryTranslation(context, cat),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                selectedCategories.value = List.of(
                                  selectedCategories.value,
                                )..remove(cat);
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AdaptiveButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) {
                              return CategoryPickerBottomSheet(
                                allCategories: allCategories,
                                selectedCategories:
                                    selectedCategories.value,
                                onChanged: (value) {
                                  selectedCategories.value =
                                      List<String>.from(value);
                                },
                              );
                            },
                          );
                        },
                        label: 'Choose categories',
                        style: AdaptiveButtonStyle.filled,
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

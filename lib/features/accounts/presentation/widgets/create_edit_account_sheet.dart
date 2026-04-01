import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class CreateEditAccountResult {
  final String name;
  final String icon;
  final String color;
  final int openingBalanceCents;
  final int? goalAmountCents;
  final bool isDefault;

  const CreateEditAccountResult({
    required this.name,
    required this.icon,
    required this.color,
    required this.openingBalanceCents,
    required this.goalAmountCents,
    required this.isDefault,
  });
}

Future<CreateEditAccountResult?> showCreateEditAccountSheet(
  BuildContext context, {
  AccountEntity? initial,
}) {
  return showModalBottomSheet<CreateEditAccountResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _CreateEditAccountSheet(initial: initial),
  );
}

class _CreateEditAccountSheet extends HookConsumerWidget {
  const _CreateEditAccountSheet({required this.initial});

  final AccountEntity? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = initial != null;
    final nameController = useTextEditingController(text: initial?.name ?? '');
    final goalController = useTextEditingController(
      text: initial?.goalAmountCents == null
          ? ''
          : formatAmount(centsToAmount(initial!.goalAmountCents!)),
    );
    final openingController = useTextEditingController(
      text: isEditing
          ? formatAmount(centsToAmount(initial!.currentBalanceCents))
          : '',
    );
    final selectedIcon = useState<String>(initial?.icon ?? 'wallet');
    final selectedColor = useState<String>(initial?.color ?? '#6B7280');
    final isDefault = useState<bool>(initial?.isDefault ?? false);

    Future<void> handleSave() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        AppToast.error(context, context.l10n.pleaseEnterPocketName);
        return;
      }

      final openingCents =
          (tryParseMoneyToCents(openingController.text) ?? 0).toInt();
      final goalRaw = goalController.text.trim();
      final goalCents =
          goalRaw.isEmpty ? null : (tryParseMoneyToCents(goalRaw) ?? 0).toInt();

      Navigator.of(context).pop(
        CreateEditAccountResult(
          name: name,
          icon: selectedIcon.value,
          color: selectedColor.value,
          openingBalanceCents: openingCents,
          goalAmountCents: goalCents,
          isDefault: isDefault.value,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      onPressed: handleSave,
                      icon: Icon(
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
                        context.l10n.pocketColorLabel,
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
                          itemCount: AppTheme.pocketPresetColors.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return GestureDetector(
                                onTap: () {
                                  AdaptiveColorPicker.show(
                                    context: context,
                                    startingColor: parseAccountColor(
                                      selectedColor.value,
                                      AppTheme.pocketDefaultBlue,
                                    ),
                                    onColorChanged: (color) {
                                      String two(int n) =>
                                          n.toRadixString(16).padLeft(2, '0');
                                      int toByte(double x) =>
                                          (x * 255.0).round() & 0xff;
                                      selectedColor.value =
                                          '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                                    },
                                    label: context.l10n.selectColor,
                                  );
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const SweepGradient(
                                      colors: AppTheme.pocketColorSweep,
                                    ),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: colorScheme.border),
                                  ),
                                  child: Icon(
                                    Icons.colorize,
                                    color: colorScheme.primaryForeground,
                                    size: 20,
                                  ),
                                ),
                              );
                            }

                            final color =
                                AppTheme.pocketPresetColors[index - 1];
                            String two(int n) =>
                                n.toRadixString(16).padLeft(2, '0');
                            int toByte(double x) => (x * 255.0).round() & 0xff;
                            final hex =
                                '#${two(toByte(color.r))}${two(toByte(color.g))}${two(toByte(color.b))}';
                            final isSelected =
                                selectedColor.value.toLowerCase() ==
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
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: colorScheme.primaryForeground,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
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
                          itemCount: _accountIcons.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final iconName = _accountIcons[index];
                            final isSelected = selectedIcon.value == iconName;
                            final selectedColorValue = parseAccountColor(
                              selectedColor.value,
                              colorScheme.primary,
                            );
                            return GestureDetector(
                              onTap: () => selectedIcon.value = iconName,
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
                                  resolveAccountIcon(iconName),
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
                      Text(
                        'Current Balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: openingController,
                        placeholder: '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Goal Amount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: goalController,
                        placeholder: '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isDefault.value,
                        title: const Text('Set as default'),
                        onChanged: (value) {
                          if (isEditing && initial!.isDefault && !value) {
                            AppToast.info(
                              context,
                              'At least one default account is required.',
                            );
                            return;
                          }
                          isDefault.value = value;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryAdaptiveButton(
                          onPressed: handleSave,
                          child: Text(
                            isEditing
                                ? context.l10n.saveChanges
                                : context.l10n.save,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: PlainAdaptiveButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.l10n.cancel),
                        ),
                      ),
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

const List<String> _accountIcons = [
  // Cash and spending accounts
  'wallet',
  'checking',
  'joint',
  'cash',
  'cash_envelope',
  'card',
  'paypal',

  // Savings and goals
  'savings',
  'reserve',
  'education',
  'medical',
  'allowance',
  'pet',
  'investment',
  'brokerage',
  'gold',
  'retirement',

  // Debt and liabilities
  'debt',
  'loan',
  'mortgage',
  'tax',

  // Other common account buckets
  'emergency',
  'budget',
  'bank',
  'business',
  'insurance',
  'crypto',
  'travel',
  'home',
];

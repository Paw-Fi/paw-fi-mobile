import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_switch.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_icon_options.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';

enum _CategoryScope {
  expense,
  income,
}

class CategoryCustomizationSheet extends HookConsumerWidget {
  const CategoryCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final configAsync = ref.watch(userCategoryConfigProvider);

    final scope = useState(_CategoryScope.expense);
    final queryController = useTextEditingController();
    useListenable(queryController);
    final query = queryController.text.trim().toLowerCase();

    Future<void> showUpsertSheet({
      String? initialName,
      String initialType = 'expense',
      int? initialColorArgb,
      String? initialIconKey,
      required Future<bool> Function(
        String name,
        String type,
        int colorArgb,
        String iconKey,
      ) onSubmit,
      required String title,
    }) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
        builder: (sheetContext) {
          return _CategoryUpsertSheet(
            title: title,
            initialName: initialName,
            initialType: initialType,
            initialColorArgb: initialColorArgb,
            initialIconKey: initialIconKey,
            onSubmit: onSubmit,
          );
        },
      );
    }

    Future<void> confirmDelete({
      required String name,
      required String transactionType,
    }) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.l10n.delete),
            content: Text(
              context.l10n.customCategoryDeleteConfirmation(name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.destructive,
                ),
                child: Text(context.l10n.delete),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        await deleteUserCustomCategory(
          ref: ref,
          name: name,
          transactionType: transactionType,
        );
      }
    }

    Widget buildScopePicker() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSegmentedControl<_CategoryScope>(
            groupValue: scope.value,
            selectedColor: colorScheme.primary,
            unselectedColor: colorScheme.card,
            borderColor: colorScheme.border,
            pressedColor: colorScheme.muted,
            children: {
              _CategoryScope.expense: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  context.l10n.expense,
                  style: TextStyle(
                    color: scope.value == _CategoryScope.expense
                        ? colorScheme.primaryForeground
                        : colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CategoryScope.income: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  context.l10n.income,
                  style: TextStyle(
                    color: scope.value == _CategoryScope.income
                        ? colorScheme.primaryForeground
                        : colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            },
            onValueChanged: (value) {
              scope.value = value;
            },
          ),
        ),
      );
    }

    Widget buildSearchField() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.homeSearchFieldBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.border),
          ),
          child: Row(
            children: [
              Icon(
                PlatformInfo.isIOS ? CupertinoIcons.search : Icons.search,
                color: colorScheme.mutedForeground,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: queryController,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.l10n.search,
                    hintStyle: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 15,
                    ),
                  ),
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => queryController.clear(),
                  child: Icon(
                    PlatformInfo.isIOS
                        ? CupertinoIcons.xmark_circle_fill
                        : Icons.clear,
                    color: colorScheme.mutedForeground,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Material(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: colorScheme.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.category,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.card,
                          border: Border.all(
                            color: colorScheme.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          PlatformInfo.isIOS
                              ? CupertinoIcons.clear
                              : Icons.close,
                          color: colorScheme.onSurface,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              buildScopePicker(),
              const SizedBox(height: 16),
              buildSearchField(),
              const SizedBox(height: 16),

              Expanded(
                child: configAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      context.l10n.customCategoriesLoadFailed(e.toString()),
                      style: TextStyle(color: colorScheme.destructive),
                    ),
                  ),
                  data: (config) {
                    Widget buildCategoryList({required String type}) {
                      final isExpense = type == 'expense';
                      final builtinSet = isExpense
                          ? getExpenseCategories().toSet()
                          : getIncomeCategories().toSet();

                      final groupsToDisplay = <String, List<String>>{};

                      for (final entry in categoryGroups.entries) {
                        final groupKey = entry.key;
                        final cats = entry.value;

                        final validCats = cats.where((c) {
                          if (!builtinSet.contains(c)) return false;

                          final normalized = c.trim().toLowerCase();
                          if (normalized == 'other' ||
                              normalized == 'uncategorized') {
                            return false;
                          }

                          if (query.isNotEmpty) {
                            final localized = getCategoryTranslation(context, c)
                                .toLowerCase();
                            if (!c.toLowerCase().contains(query) &&
                                !localized.contains(query)) {
                              return false;
                            }
                          }
                          return true;
                        }).toList();

                        if (validCats.isNotEmpty) {
                          groupsToDisplay[groupKey] = validCats;
                        }
                      }

                      final customCats = config.customCategories.where((c) {
                        if (isExpense && c.transactionType == 'income') {
                          return false;
                        }
                        if (!isExpense && c.transactionType == 'expense') {
                          return false;
                        }

                        if (query.isNotEmpty &&
                            !c.name.toLowerCase().contains(query)) {
                          return false;
                        }

                        return true;
                      }).toList();

                      if (groupsToDisplay.isEmpty &&
                          customCats.isEmpty &&
                          query.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              context.l10n.noResultsFound,
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                        );
                      }

                      bool isHidden(String name) {
                        final key = name.trim().toLowerCase();
                        if (type == 'income') {
                          return config.hiddenIncomeCategories.contains(key);
                        }
                        return config.hiddenExpenseCategories.contains(key);
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          // Custom Categories Group
                          if (query.isEmpty || customCats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, bottom: 8, top: 8),
                              child: Text(
                                context.l10n.custom.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.mutedForeground,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < customCats.length; i++)
                                    Builder(builder: (context) {
                                      final cat = customCats[i];
                                      final name = cat.name;
                                      final catType = cat.transactionType;
                                      final hiddenNow = isHidden(name);

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Color(cat
                                                      .colorArgb ??
                                                  computeFallbackCategoryColorArgb(
                                                      name)),
                                              child: Icon(
                                                customCategoryIconForKey(
                                                    cat.iconKey ?? 'tag'),
                                                color: colorScheme
                                                    .primaryForeground,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.foreground,
                                                decoration: hiddenNow
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(
                                                PlatformInfo.isIOS
                                                    ? CupertinoIcons.ellipsis
                                                    : Icons.more_vert,
                                                color:
                                                    colorScheme.mutedForeground,
                                              ),
                                              onPressed: () async {
                                                final action =
                                                    await MonekoActionSheet
                                                        .show<String>(
                                                  context: context,
                                                  title: name,
                                                  actions: [
                                                    MonekoActionSheetAction(
                                                      label: hiddenNow
                                                          ? context.l10n
                                                              .unhide
                                                          : context.l10n
                                                              .hide,
                                                      value: 'hide_unhide',
                                                    ),
                                                    MonekoActionSheetAction(
                                                      label: context.l10n
                                                          .edit,
                                                      value: 'edit',
                                                    ),
                                                    MonekoActionSheetAction(
                                                      label: context.l10n
                                                          .delete,
                                                      value: 'delete',
                                                      isDestructive: true,
                                                    ),
                                                  ],
                                                  cancelAction:
                                                      MonekoActionSheetAction(
                                                    label: context.l10n.cancel,
                                                    value: 'cancel',
                                                  ),
                                                );

                                                if (action == 'hide_unhide') {
                                                  await setUserCategoryHidden(
                                                    ref: ref,
                                                    categoryName: name,
                                                    transactionType: type,
                                                    hidden: !hiddenNow,
                                                  );
                                                } else if (action == 'edit') {
                                                  await showUpsertSheet(
                                                    title: context.l10n
                                                        .editCategory,
                                                    initialName: name,
                                                    initialType: catType,
                                                    initialColorArgb:
                                                        cat.colorArgb,
                                                    initialIconKey: cat.iconKey,
                                                    onSubmit: (newName,
                                                        newType,
                                                        colorArgb,
                                                        iconKey) async {
                                                      final renamed =
                                                          await renameUserCustomCategory(
                                                        ref: ref,
                                                        oldName: name,
                                                        oldTransactionType:
                                                            catType,
                                                        newName: newName,
                                                        newTransactionType:
                                                            newType,
                                                      );
                                                      if (!renamed) {
                                                        return false;
                                                      }

                                                      final styled =
                                                          await setUserCustomCategoryStyle(
                                                        ref: ref,
                                                        name: newName,
                                                        transactionType:
                                                            newType,
                                                        colorArgb: colorArgb,
                                                        iconKey: iconKey,
                                                      );
                                                      return styled;
                                                    },
                                                  );
                                                } else if (action == 'delete') {
                                                  await confirmDelete(
                                                    name: name,
                                                    transactionType: catType,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 60),
                                            child: Divider(
                                              height: 1,
                                              color: colorScheme.border,
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.add,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      context.l10n.addCustomCategory,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    onTap: () async {
                                      await showUpsertSheet(
                                        title: context.l10n
                                            .addCustomCategory,
                                        initialType: type,
                                        onSubmit: (name, onSubmitType,
                                            colorArgb, iconKey) async {
                                          return upsertUserCustomCategory(
                                            ref: ref,
                                            name: name,
                                            transactionType: onSubmitType,
                                            colorArgb: colorArgb,
                                            iconKey: iconKey,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Built-in Groups
                          for (final entry in groupsToDisplay.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, bottom: 8, top: 24),
                              child: Text(
                                getCategoryGroupTranslation(context, entry.key)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.mutedForeground,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0;
                                      i < entry.value.length;
                                      i++) ...[
                                    Builder(builder: (context) {
                                      final name = entry.value[i];
                                      final normalized =
                                          name.trim().toLowerCase();
                                      final hiddenNow = isHidden(normalized);

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  getCategoryColor(name),
                                              child: Icon(
                                                getCategoryIcon(name),
                                                color: colorScheme
                                                    .primaryForeground,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              getCategoryTranslation(
                                                  context, name),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.foreground,
                                              ),
                                            ),
                                            trailing: AdaptiveSwitch(
                                              value: !hiddenNow,
                                              onChanged: (value) async {
                                                await setUserCategoryHidden(
                                                  ref: ref,
                                                  categoryName: name,
                                                  transactionType: type,
                                                  hidden: !value,
                                                );
                                              },
                                            ),
                                          ),
                                          if (i < entry.value.length - 1)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 60),
                                              child: Divider(
                                                height: 1,
                                                color: colorScheme.border,
                                              ),
                                            ),
                                        ],
                                      );
                                    }),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    }

                    switch (scope.value) {
                      case _CategoryScope.expense:
                        return buildCategoryList(type: 'expense');
                      case _CategoryScope.income:
                        return buildCategoryList(type: 'income');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryUpsertSheet extends HookWidget {
  const _CategoryUpsertSheet({
    required this.title,
    this.initialName,
    required this.initialType,
    this.initialColorArgb,
    this.initialIconKey,
    required this.onSubmit,
  });

  final String title;
  final String? initialName;
  final String initialType;
  final int? initialColorArgb;
  final String? initialIconKey;
  final Future<bool> Function(
    String name,
    String type,
    int colorArgb,
    String iconKey,
  ) onSubmit;

  String? _validateCategoryName(BuildContext context, String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return context.l10n.customCategoryNameRequired;
    }
    if (normalized.length > 96) {
      return context.l10n.customCategoryNameTooLong;
    }
    if (normalized.contains('`')) {
      return context.l10n.customCategoryNameBackticksNotAllowed;
    }
    final hasControlChars = RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized);
    if (hasControlChars) {
      return context.l10n.customCategoryNameControlCharsNotAllowed;
    }
    if (normalized == 'other') {
      return context.l10n.customCategoryNameReservedOther;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = useTextEditingController(text: initialName ?? '');
    useListenable(nameController);

    final transactionType = useState(initialType);
    const presetColors = AppTheme.pocketPresetColors;

    final selectedColorArgb = useState<int?>(initialColorArgb);

    final defaultIcon =
        (initialIconKey != null && initialIconKey!.trim().isNotEmpty)
            ? initialIconKey!.trim()
            : 'tag';
    final selectedIconKey = useState(defaultIcon);
    final isSaving = useState(false);

    final iconEntries =
        customCategoryIconOptions.entries.toList(growable: false);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.card,
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        PlatformInfo.isIOS ? CupertinoIcons.clear : Icons.close,
                        color: colorScheme.onSurface,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Form Fields Card
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: context.l10n.customCategoryNameLabel,
                              labelStyle: TextStyle(
                                color: colorScheme.mutedForeground,
                              ),
                              border: InputBorder.none,
                            ),
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                        Divider(height: 1, color: colorScheme.border),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                context.l10n.type,
                                style: TextStyle(
                                  color: colorScheme.foreground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              CupertinoSegmentedControl<String>(
                                groupValue: transactionType.value,
                                selectedColor: colorScheme.primary,
                                unselectedColor: colorScheme.card,
                                borderColor: colorScheme.border,
                                pressedColor: colorScheme.muted,
                                children: {
                                  'expense': Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(context.l10n.expense),
                                  ),
                                  'income': Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(context.l10n.income),
                                  ),
                                },
                                onValueChanged: (value) {
                                  transactionType.value = value;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Color Picker
                  Text(
                    context.l10n.color,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: presetColors.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isCustomColorSelected =
                              selectedColorArgb.value != null &&
                                  !presetColors.any((c) =>
                                      c.toARGB32() == selectedColorArgb.value);
                          final selectedColor = selectedColorArgb.value != null
                              ? Color(selectedColorArgb.value!)
                              : Colors.transparent;

                          return GestureDetector(
                            onTap: () {
                              AdaptiveColorPicker.show(
                                context: context,
                                startingColor: isCustomColorSelected
                                    ? selectedColor
                                    : colorScheme.primary,
                                label: context.l10n.selectColor,
                                onColorChanged: (color) {
                                  selectedColorArgb.value = color.toARGB32();
                                },
                              );
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isCustomColorSelected
                                    ? selectedColor
                                    : null,
                                gradient: isCustomColorSelected
                                    ? null
                                    : const SweepGradient(
                                        colors: AppTheme.pocketColorSweep,
                                      ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCustomColorSelected
                                      ? colorScheme.foreground
                                      : colorScheme.border,
                                  width: isCustomColorSelected ? 2 : 1,
                                ),
                              ),
                              child: isCustomColorSelected
                                  ? Icon(
                                      Icons.check,
                                      color: colorScheme.primaryForeground,
                                      size: 24,
                                    )
                                  : Icon(
                                      Icons.colorize,
                                      color: colorScheme.primaryForeground,
                                      size: 24,
                                    ),
                            ),
                          );
                        }

                        final color = presetColors[index - 1];
                        final colorArgb = color.toARGB32();
                        final isSelected = selectedColorArgb.value == colorArgb;

                        return GestureDetector(
                          onTap: () {
                            selectedColorArgb.value = colorArgb;
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: colorScheme.foreground,
                                      width: 2.5,
                                    )
                                  : Border.all(
                                      color: colorScheme.border,
                                    ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: colorScheme.primaryForeground,
                                    size: 24,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon Picker
                  Text(
                    context.l10n.pocketIconLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: iconEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final entry = iconEntries[index];
                        final isSelected = selectedIconKey.value == entry.key;
                        final selectedColor = selectedColorArgb.value != null
                            ? Color(selectedColorArgb.value!)
                            : colorScheme.mutedForeground;

                        return GestureDetector(
                          onTap: () {
                            selectedIconKey.value = entry.key;
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color:
                                  isSelected && selectedColorArgb.value != null
                                      ? selectedColor.withValues(alpha: 0.15)
                                      : isSelected
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.15)
                                          : colorScheme.card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected &&
                                        selectedColorArgb.value != null
                                    ? selectedColor
                                    : isSelected
                                        ? colorScheme.primary
                                        : colorScheme.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              entry.value,
                              color:
                                  isSelected && selectedColorArgb.value != null
                                      ? selectedColor
                                      : isSelected
                                          ? colorScheme.primary
                                          : colorScheme.mutedForeground,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: PrimaryAdaptiveButton(
                onPressed: (nameController.text.trim().isEmpty ||
                        selectedColorArgb.value == null ||
                        isSaving.value)
                    ? null
                    : () async {
                        final validationMessage = _validateCategoryName(
                          context,
                          nameController.text,
                        );
                        if (validationMessage != null) {
                          AppToast.error(context, validationMessage);
                          return;
                        }

                        isSaving.value = true;
                        final ok = await onSubmit(
                          nameController.text.trim(),
                          transactionType.value,
                          selectedColorArgb.value!,
                          selectedIconKey.value,
                        );
                        isSaving.value = false;

                        if (!context.mounted) return;
                        if (ok) {
                          AppToast.success(
                            context,
                            context.l10n.customCategoryUpdated,
                          );
                          Navigator.of(context).pop();
                        } else {
                          AppToast.error(
                            context,
                            context.l10n.customCategoryUpdateFailed,
                          );
                        }
                      },
                child: Text(
                  isSaving.value
                      ? context.l10n.saving
                      : (initialName == null
                          ? context.l10n.customCategoryAddCta
                          : context.l10n.saveChanges),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

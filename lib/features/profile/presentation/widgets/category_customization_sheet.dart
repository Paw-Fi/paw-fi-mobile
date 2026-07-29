import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_icon_options.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';

enum _CategoryScope {
  expense,
  income,
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        child: Icon(
          PlatformInfo.isIOS ? CupertinoIcons.clear : Icons.close,
          color: colorScheme.onSurface,
          size: 16,
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: colorScheme.foreground,
                    ),
              ),
              const _SheetCloseButton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.mutedForeground,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

Widget _indentedDivider(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(left: 56),
    child: Divider(height: 1, color: colorScheme.border.withValues(alpha: 0.5)),
  );
}

class CategoryCustomizationSheet extends HookConsumerWidget {
  const CategoryCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final configAsync = ref.watch(userCategoryConfigProvider);
    final remapsAsync = ref.watch(userCategoryRemapsProvider);

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
        useSafeArea: true,
        backgroundColor: colorScheme.sheetBackground,
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

    Future<void> showRemapSheet({
      String? initialFromCategory,
      String? initialToCategory,
      String initialType = 'expense',
      required List<String> targetCategories,
      required String title,
    }) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: colorScheme.sheetBackground,
        builder: (sheetContext) {
          return _CategoryRemapUpsertSheet(
            title: title,
            initialFromCategory: initialFromCategory,
            initialToCategory: initialToCategory,
            initialType: initialType,
            targetCategories: targetCategories,
            onSubmit: (fromCategory, toCategory, transactionType) async {
              final saved = await saveUserCategoryRemapPreference(
                ref: ref,
                fromCategory: fromCategory,
                toCategory: toCategory,
                transactionType: transactionType,
              );
              if (!saved) return false;

              final previousSource = initialFromCategory?.trim().toLowerCase();
              final nextSource = fromCategory.trim().toLowerCase();
              if (previousSource != null &&
                  previousSource.isNotEmpty &&
                  previousSource != nextSource) {
                return deleteUserCategoryRemapPreference(
                  ref: ref,
                  fromCategory: previousSource,
                  transactionType: initialType,
                );
              }

              return true;
            },
          );
        },
      );
    }

    Future<void> confirmDelete({
      required String name,
      required String transactionType,
    }) async {
      final confirmed = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.delete,
        description: context.l10n.customCategoryDeleteConfirmation(name),
        confirmLabel: context.l10n.delete,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );

      if (confirmed?.confirmed == true) {
        await deleteUserCustomCategory(
          ref: ref,
          name: name,
          transactionType: transactionType,
        );
      }
    }

    Widget buildScopePicker() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MonekoSegmentedControl(
          labels: [context.l10n.expense, context.l10n.income],
          selectedIndex: scope.value == _CategoryScope.expense ? 0 : 1,
          onValueChanged: (index) {
            scope.value =
                index == 0 ? _CategoryScope.expense : _CategoryScope.income;
          },
          height: 40,
        ),
      );
    }

    Widget buildSearchField() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.sheetElementBackground,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: colorScheme.border.withValues(alpha: 0.3)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: context.l10n.category),
        buildScopePicker(),
        const SizedBox(height: 16),
        buildSearchField(),
        const SizedBox(height: 8),
        Expanded(
          child: configAsync.when(
            loading: () => const AsyncDataSkeleton(
              rowCount: 5,
              padding: EdgeInsets.zero,
            ),
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
                final targetCategories = (isExpense
                        ? config.visibleExpenseCategories
                        : config.visibleIncomeCategories)
                    .where((category) =>
                        category.trim().toLowerCase() != 'other')
                    .toList(growable: false);
          
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
          
                final remaps = (remapsAsync.valueOrNull ??
                        const <UserCategoryRemapPreference>[])
                    .where((remap) {
                  if (remap.transactionType != type) return false;
                  if (query.isEmpty) return true;
                  final fromLabel =
                      getCategoryTranslation(context, remap.fromCategory)
                          .toLowerCase();
                  final toLabel =
                      getCategoryTranslation(context, remap.toCategory)
                          .toLowerCase();
                  return remap.fromCategory.contains(query) ||
                      remap.toCategory.contains(query) ||
                      fromLabel.contains(query) ||
                      toLabel.contains(query);
                }).toList(growable: false);
          
                if (groupsToDisplay.isEmpty &&
                    customCats.isEmpty &&
                    remaps.isEmpty &&
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
          
                Widget buildRemapSection() {
                  if (query.isNotEmpty && remaps.isEmpty) {
                    return const SizedBox.shrink();
                  }
          
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(context.l10n.aiMappings),
                      _SectionCard(
                        children: [
                          for (int i = 0; i < remaps.length; i++)
                            Builder(builder: (context) {
                              final remap = remaps[i];
                              final fromLabel = getCategoryTranslation(
                                context,
                                remap.fromCategory,
                              );
                              final toLabel = getCategoryTranslation(
                                context,
                                remap.toCategory,
                              );
          
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.route_outlined,
                                        color: colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      fromLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                             Icon(
                                          PlatformInfo.isIOS
                                             ? CupertinoIcons.arrow_turn_down_right
      : Icons.subdirectory_arrow_right_rounded,
                                          size: 12,
                                          color:
                                              colorScheme.mutedForeground,
                                        ),
                                         const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            toLabel,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colorScheme
                                                  .mutedForeground,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                   
                                      ],
                                    ),
                                    trailing: GestureDetector(
                                      onTap: () async {
                                        final l10n = context.l10n;
                                        final action =
                                            await MonekoActionSheet.show<
                                                String>(
                                          context: context,
                                          title: context.l10n.remapTitle(fromLabel, toLabel),
                                          actions: [
                                            MonekoActionSheetAction(
                                              label: l10n.edit,
                                              value: 'edit',
                                            ),
                                            MonekoActionSheetAction(
                                              label: l10n.delete,
                                              value: 'delete',
                                              isDestructive: true,
                                            ),
                                          ],
                                          cancelAction:
                                              MonekoActionSheetAction(
                                            label: l10n.cancel,
                                            value: 'cancel',
                                          ),
                                        );
          
                                        if (action == 'edit') {
                                          await showRemapSheet(
                                            title: context.l10n.editMapping,
                                            initialFromCategory:
                                                remap.fromCategory,
                                            initialToCategory:
                                                remap.toCategory,
                                            initialType:
                                                remap.transactionType,
                                            targetCategories:
                                                targetCategories,
                                          );
                                        } else if (action == 'delete') {
                                          await deleteUserCategoryRemapPreference(
                                            ref: ref,
                                            fromCategory:
                                                remap.fromCategory,
                                            transactionType:
                                                remap.transactionType,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          PlatformInfo.isIOS
                                              ? CupertinoIcons.ellipsis
                                              : Icons.more_vert,
                                          color:
                                              colorScheme.mutedForeground,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (i < remaps.length - 1)
                                    _indentedDivider(context),
                                ],
                              );
                            }),
                          if (query.isEmpty)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                context.l10n.addMapping,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.primary,
                                  fontSize: 15,
                                ),
                              ),
                              onTap: () async {
                                await showRemapSheet(
                                  title: context.l10n.addMapping,
                                  initialType: type,
                                  targetCategories: targetCategories,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  );
                }
          
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    buildRemapSection(),
          
                    // Custom Categories Group
                    if (query.isEmpty || customCats.isNotEmpty) ...[
                      _SectionLabel(context.l10n.custom),
                      _SectionCard(
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
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Color(cat.colorArgb ??
                                            computeFallbackCategoryColorArgb(
                                                name)),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        customCategoryIconForKey(
                                            cat.iconKey ?? 'tag'),
                                        color:
                                            colorScheme.primaryForeground,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                        color: colorScheme.foreground,
                                        decoration: hiddenNow
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    trailing: GestureDetector(
                                      onTap: () async {
                                        final l10n = context.l10n;
                                        final action =
                                            await MonekoActionSheet.show<
                                                String>(
                                          context: context,
                                          title: name,
                                          actions: [
                                            MonekoActionSheetAction(
                                              label: hiddenNow
                                                  ? l10n.unhide
                                                  : l10n.hide,
                                              value: 'hide_unhide',
                                            ),
                                            MonekoActionSheetAction(
                                              label: l10n.edit,
                                              value: 'edit',
                                            ),
                                            MonekoActionSheetAction(
                                              label: l10n.delete,
                                              value: 'delete',
                                              isDestructive: true,
                                            ),
                                          ],
                                          cancelAction:
                                              MonekoActionSheetAction(
                                            label: l10n.cancel,
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
                                            title: l10n.editCategory,
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
                                                transactionType: newType,
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
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          PlatformInfo.isIOS
                                              ? CupertinoIcons.ellipsis
                                              : Icons.more_vert,
                                          color:
                                              colorScheme.mutedForeground,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (i < customCats.length - 1)
                                    _indentedDivider(context),
                                ],
                              );
                            }),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.add,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              context.l10n.addCustomCategory,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: colorScheme.primary,
                              ),
                            ),
                            onTap: () async {
                              await showUpsertSheet(
                                title: context.l10n.addCustomCategory,
                                initialType: type,
                                onSubmit: (name, onSubmitType, colorArgb,
                                    iconKey) async {
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
                    ],
          
                    // Built-in Groups
                    for (final entry in groupsToDisplay.entries) ...[
                      _SectionLabel(getCategoryGroupTranslation(
                          context, entry.key)),
                      _SectionCard(
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
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: getCategoryColor(
                                            name, context),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        getCategoryIcon(name),
                                        color:
                                            colorScheme.primaryForeground,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      getCategoryTranslation(
                                          context, name),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
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
                                    _indentedDivider(context),
                                ],
                              );
                            }),
                          ]
                        ],
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
    );
  }
}

class _CategoryRemapUpsertSheet extends HookWidget {
  const _CategoryRemapUpsertSheet({
    required this.title,
    this.initialFromCategory,
    this.initialToCategory,
    required this.initialType,
    required this.targetCategories,
    required this.onSubmit,
  });

  final String title;
  final String? initialFromCategory;
  final String? initialToCategory;
  final String initialType;
  final List<String> targetCategories;
  final Future<bool> Function(
    String fromCategory,
    String toCategory,
    String transactionType,
  ) onSubmit;

  String? _validateSource(BuildContext context, String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized.isEmpty) return context.l10n.customCategoryNameRequired;
    if (normalized.length > 96) return context.l10n.customCategoryNameTooLong;
    if (normalized.contains('`')) {
      return context.l10n.customCategoryNameBackticksNotAllowed;
    }
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized)) {
      return context.l10n.customCategoryNameControlCharsNotAllowed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceController = useTextEditingController(
      text: initialFromCategory ?? '',
    );
    useListenable(sourceController);

    final transactionType = initialType;
    final normalizedTargets = targetCategories
        .map((category) => category.trim().toLowerCase())
        .where((category) => category.isNotEmpty && category != 'other')
        .toSet()
        .toList()
      ..sort();
    final fallbackTarget = normalizedTargets.isNotEmpty
        ? normalizedTargets.first
        : (initialToCategory ?? '');
    final selectedTarget = useState(
      initialToCategory != null &&
              normalizedTargets
                  .contains(initialToCategory!.trim().toLowerCase())
          ? initialToCategory!.trim().toLowerCase()
          : fallbackTarget,
    );
    final isSaving = useState(false);

    final canSave = sourceController.text.trim().isNotEmpty &&
        selectedTarget.value.trim().isNotEmpty &&
        !isSaving.value;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: title),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: TextField(
                          controller: sourceController,
                          decoration: InputDecoration(
                            labelText:
                                '${context.l10n.source} ${context.l10n.category}',
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
                      _indentedDivider(context),
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
                            Text(
                              transactionType == 'income'
                                  ? context.l10n.income
                                  : context.l10n.expense,
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _indentedDivider(context),
                      MonekoDisclosureRow(
                        label:
                            '${context.l10n.target} ${context.l10n.category}',
                        value: selectedTarget.value.isEmpty
                            ? context.l10n.selectCategory
                            : getCategoryTranslation(
                                context,
                                selectedTarget.value,
                              ),
                        isLast: true,
                        isValuePlaceholder: selectedTarget.value.isEmpty,
                        onTap: () async {
                          final result = await showCategoryPicker(
                            context: context,
                            currentCategory: selectedTarget.value,
                            isIncome: transactionType == 'income',
                            allCategories: normalizedTargets,
                          );
                          if (result != null) {
                            selectedTarget.value = result;
                          }
                        },
                      ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: PrimaryAdaptiveButton(
                onPressed: !canSave
                    ? null
                    : () async {
                        final validationMessage = _validateSource(
                          context,
                          sourceController.text,
                        );
                        if (validationMessage != null) {
                          AppToast.error(context, validationMessage);
                          return;
                        }

                        final source = sourceController.text.trim();
                        final target = selectedTarget.value.trim();
                        if (source.toLowerCase() == target.toLowerCase()) {
                          AppToast.error(
                            context,
                            context.l10n.customCategoryUpdateFailed,
                          );
                          return;
                        }

                        isSaving.value = true;
                        final ok = await onSubmit(
                          source,
                          target,
                          transactionType,
                        );
                        isSaving.value = false;

                        if (!context.mounted) return;
                        if (ok) {
                          AppToast.success(
                            context,
                            context.l10n.preferenceUpdatedSuccessfully,
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
                  isSaving.value ? context.l10n.saving : context.l10n.save,
                ),
              ),
            ),
          ],
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
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: title),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
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
                      _indentedDivider(context),
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
                            SizedBox(
                              height: 36,
                              child: MonekoSegmentedControl(
                                labels: [
                                  context.l10n.expense,
                                  context.l10n.income,
                                ],
                                selectedIndex:
                                    transactionType.value == 'expense' ? 0 : 1,
                                onValueChanged: (index) {
                                  transactionType.value =
                                      index == 0 ? 'expense' : 'income';
                                },
                                height: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionLabel(context.l10n.color),
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
                              : colorScheme.surface.withValues(alpha: 0.0);

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
                                      size: 22,
                                    )
                                  : Icon(
                                      Icons.colorize,
                                      color: colorScheme.primaryForeground,
                                      size: 22,
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
                                    size: 22,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SectionLabel(context.l10n.pocketIconLabel),
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
                                          : colorScheme.sheetElementBackground,
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
                              size: 22,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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

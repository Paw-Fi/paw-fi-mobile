import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/import/presentation/widgets/import_shared_widgets.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

/// The second wizard step: column-to-field mapping.
class MapColumnsStep extends ConsumerWidget {
  const MapColumnsStep({super.key, required this.state});

  final ImportWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = state.table;
    final mapping = state.mapping;
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    if (table == null || mapping == null) {
      return Center(child: Text(context.l10n.importNoTable));
    }

    final headers = table.headers;
    final isSplit = mapping.hasSplitDebitCredit;

    // Required fields change based on split debit/credit mode.
    final requiredFields = isSplit
        ? [ImportField.date, ImportField.debit, ImportField.credit]
        : [ImportField.date, ImportField.amount];

    final optionalFields = [
      if (!isSplit) ...[],
      ImportField.category,
      ImportField.description,
      ImportField.currency,
      ImportField.type,
      ImportField.reference,
      ImportField.balance,
    ];

    Future<void> pickColumn(ImportField field) async {
      final selectedIndex = mapping.fieldToColumnIndex[field];
      final actions = <MonekoActionSheetAction<int>>[
        MonekoActionSheetAction<int>(
          label: context.l10n.none,
          value: -1,
          icon: Icons.clear_rounded,
        ),
        ...List.generate(headers.length, (index) {
          return MonekoActionSheetAction<int>(
            label: headers[index],
            value: index,
          );
        }),
      ];

      final picked = await MonekoActionSheet.show<int>(
        context: context,
        title: _labelForField(context, field, false),
        message: selectedIndex == null
            ? context.l10n.selectColumn
            : 'Selected: ${headers[selectedIndex]}',
        actions: actions,
        cancelAction: MonekoActionSheetAction<int>(
          label: context.l10n.cancel,
          value: -2,
        ),
      );

      if (picked == null || picked == -2) return;
      if (picked == -1) {
        notifier.updateMapping(field, null);
      } else {
        notifier.updateMapping(field, picked);
      }
    }

    Widget buildFieldTile(ImportField field, {required bool required}) {
      final selectedIndex = mapping.fieldToColumnIndex[field];
      final value = selectedIndex != null &&
              selectedIndex >= 0 &&
              selectedIndex < headers.length
          ? headers[selectedIndex]
          : context.l10n.selectColumn;

      return StandardTile(
        leadingIcon: required ? Icons.star_rounded : Icons.tune_rounded,
        title: _labelForField(context, field, required),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selectedIndex == null
                      ? scheme.mutedForeground
                      : scheme.foreground.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.mutedForeground.withValues(alpha: 0.6),
            ),
          ],
        ),
        onTap: () => pickColumn(field),
      );
    }

    final isReady = requiredFields
        .every((field) => mapping.fieldToColumnIndex.containsKey(field));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstructionCard(
          icon: Icons.table_chart_rounded,
          title: context.l10n.importMapTitle,
          description: context.l10n.importMapHint,
        ),
        // Format badge
        if (table.formatHint != CsvFormatHint.unknown &&
            table.formatHint != CsvFormatHint.generic) ...[
          const SizedBox(height: 12),
          FormatHintBadge(hint: table.formatHint),
        ],
        // Sheet selector for multi-sheet Excel files
        if (state.hasMultipleSheets) ...[
          const SizedBox(height: 12),
          SheetSelector(state: state),
        ],
        const SizedBox(height: 24),
        // Split debit/credit toggle
        GroupedSectionCard(
          title: context.l10n.importColumnFormat.toUpperCase(),
          children: [
            StandardTile(
              leadingIcon: Icons.swap_horiz_rounded,
              title: context.l10n.importSplitDebitCredit,
              subtitle: context.l10n.importSplitDebitCreditHint,
              trailing: AdaptiveSwitch(
                value: isSplit,
                onChanged: (value) => notifier.toggleSplitDebitCredit(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GroupedSectionCard(
          title: context.l10n.required.toUpperCase(),
          children: [
            ...requiredFields.map((f) => buildFieldTile(f, required: true)),
          ],
        ),
        const SizedBox(height: 24),
        GroupedSectionCard(
          title: context.l10n.optional.toUpperCase(),
          children: [
            ...optionalFields.map((f) => buildFieldTile(f, required: false)),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedAdaptiveButton(
                onPressed: () => notifier.setStep(ImportStep.selectFile),
                child: Text(context.l10n.back),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryAdaptiveButton(
                onPressed:
                    isReady ? () => notifier.setStep(ImportStep.preview) : null,
                child: Text(context.l10n.next),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  String _labelForField(
    BuildContext context,
    ImportField field,
    bool required,
  ) {
    final suffix = required ? ' *' : '';
    switch (field) {
      case ImportField.date:
        return '${context.l10n.date}$suffix';
      case ImportField.amount:
        return '${context.l10n.amount}$suffix';
      case ImportField.debit:
        return '${context.l10n.importFieldDebit}$suffix';
      case ImportField.credit:
        return '${context.l10n.importFieldCredit}$suffix';
      case ImportField.category:
        return context.l10n.category;
      case ImportField.description:
        return context.l10n.description;
      case ImportField.currency:
        return context.l10n.currency;
      case ImportField.type:
        return context.l10n.type;
      case ImportField.balance:
        return context.l10n.importFieldBalance;
      case ImportField.reference:
        return context.l10n.importFieldReference;
    }
  }
}

/// A small badge that shows the detected bank/format name.
class FormatHintBadge extends StatelessWidget {
  const FormatHintBadge({super.key, required this.hint});

  final CsvFormatHint hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
              const SizedBox(width: 5),
              Text(
                hint.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tab-style sheet selector shown when an Excel file has multiple sheets.
class SheetSelector extends ConsumerWidget {
  const SheetSelector({super.key, required this.state});

  final ImportWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final sheets = state.availableSheets;
    final selectedIndex = state.selectedSheetIndex;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sheets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => notifier.selectSheet(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : scheme.border.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                sheets[index].sheetName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? scheme.onPrimary : scheme.mutedForeground,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

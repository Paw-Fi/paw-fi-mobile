import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

String _truncateMenuLabel(String label, {int maxLength = 20}) {
  final trimmed = label.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength - 1)}…';
}

String _emailLocalPart(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;
  return trimmed.substring(0, atIndex);
}

String _userLabel(AppUser user, {required bool shortenEmail}) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  return shortenEmail ? _emailLocalPart(user.email) : user.email.trim();
}

class ImportWizardPage extends ConsumerStatefulWidget {
  const ImportWizardPage({super.key});

  @override
  ConsumerState<ImportWizardPage> createState() => _ImportWizardPageState();
}

class _ImportWizardPageState extends ConsumerState<ImportWizardPage> {
  bool _isBlockingDialogVisible = false;
  bool _isBlockingDialogSyncScheduled = false;
  BlockingProcessingController? _blockingDialogController;

  void _dismissBlockingDialogIfVisible() {
    if (!_isBlockingDialogVisible) return;
    var popSucceeded = false;
    try {
      Navigator.of(context, rootNavigator: true).pop();
      popSucceeded = true;
    } catch (_) {}
    if (popSucceeded) {
      _isBlockingDialogVisible = false;
      _blockingDialogController = null;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dismissBlockingDialogIfVisible();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen<ImportWizardState>(importWizardProvider, (previous, next) {
      _syncBlockingDialog(previous: previous, next: next);

      final importJustCompleted =
          previous?.isImporting == true && next.isImporting == false;
      if (importJustCompleted) {
        _handleImportCompleted(next);
      }

      final parseJustFailed =
          previous?.isParsing == true && next.isParsing == false;
      if (parseJustFailed && next.errorMessage != null && context.mounted) {
        _dismissBlockingDialogIfVisible();
        AppToast.error(context, next.errorMessage!);
      }
    });

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: context.l10n.importData),
      body: SafeArea(
        child: Material(
          child: Container(
            color: scheme.appBackground,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, getTopPadding(context) - 65, 16, 24),
                  child: _ImportTimeline(currentStep: state.step),
                ),
                Expanded(
                  child: _buildStep(context, state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, ImportWizardState state) {
    switch (state.step) {
      case ImportStep.selectFile:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SelectFileStep(state: state),
        );
      case ImportStep.mapColumns:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MapColumnsStep(state: state),
        );
      case ImportStep.preview:
        return _PreviewStep(state: state);
    }
  }

  void _syncBlockingDialog({
    required ImportWizardState? previous,
    required ImportWizardState next,
  }) {
    final shouldBlock = next.isParsing || next.isImporting;
    final shouldReconcileVisibility = shouldBlock != _isBlockingDialogVisible;
    final parsingMessageChanged =
        previous?.parsingStatusMessage != next.parsingStatusMessage;
    final shouldRefreshSubMessage =
        shouldBlock && _isBlockingDialogVisible && parsingMessageChanged;

    if (!shouldReconcileVisibility && !shouldRefreshSubMessage) return;

    if (_isBlockingDialogSyncScheduled) return;
    _isBlockingDialogSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isBlockingDialogSyncScheduled = false;
      if (!mounted) return;

      final latest = ref.read(importWizardProvider);
      final shouldBlockNow = latest.isParsing || latest.isImporting;
      if (shouldBlockNow && !_isBlockingDialogVisible) {
        final message = latest.isImporting
            ? context.l10n.importing
            : context.l10n.analyzingExpense;
        _blockingDialogController = showEnhancedBlockingDialog(
          context: context,
          message: message,
          subMessage: latest.isParsing ? latest.parsingStatusMessage : null,
          showElapsedTime: true,
          enableCancelAfterSeconds: 45,
        );
        _isBlockingDialogVisible = true;
        return;
      }

      if (shouldBlockNow && _isBlockingDialogVisible) {
        final message = latest.isImporting
            ? context.l10n.importing
            : context.l10n.analyzingExpense;
        _blockingDialogController?.updateMessage(message);
        if (latest.isParsing) {
          _blockingDialogController
              ?.updateSubMessage(latest.parsingStatusMessage);
        } else {
          _blockingDialogController?.updateSubMessage(null);
        }
      }

      if (!shouldBlockNow && _isBlockingDialogVisible) {
        _dismissBlockingDialogIfVisible();
      }
    });
  }

  void _handleImportCompleted(ImportWizardState next) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _dismissBlockingDialogIfVisible();

      final authState = ref.read(authProvider);
      final userId = authState.uid;
      if (userId.isNotEmpty) {
        final targetHouseholdId = next.targetHouseholdId;
        if (targetHouseholdId == null || targetHouseholdId.isEmpty) {
          ref.read(analyticsProvider.notifier).refresh(userId);
        } else {
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(targetHouseholdId);
          ref.invalidate(userHouseholdsProvider(userId));
          ref.invalidate(householdExpensesProvider);
          ref.invalidate(cachedHouseholdExpensesProvider);
          ref.invalidate(householdSplitsProvider);
          ref.invalidate(cachedHouseholdSplitsProvider);
          ref.invalidate(householdBudgetsProvider);
          ref.invalidate(householdMembersProvider);
        }

        ref.invalidate(pocketsProvider);
        ref.invalidate(currencyTransactionCountsProvider);
      }

      if (next.importedCount > 0) {
        AppToast.success(
          context,
          '${context.l10n.imported}: ${next.importedCount}',
        );
        ref.read(importWizardProvider.notifier).resetAfterImport();
        Navigator.of(context).pop(true);
      } else {
        AppToast.error(
          context,
          '${context.l10n.failed}: ${next.failedCount}',
        );
      }
    });
  }
}

class _ImportTimeline extends StatelessWidget {
  const _ImportTimeline({required this.currentStep});

  final ImportStep currentStep;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ImportStep.selectFile,
      ImportStep.mapColumns,
      ImportStep.preview,
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _TimelineStep(
              stepIndex: i + 1,
              label: _labelForStep(context, steps[i]),
              isActive: steps[i] == currentStep,
              isCompleted: steps[i].index < currentStep.index,
              isLast: i == steps.length - 1,
            ),
          ),
          if (i < steps.length - 1) const _TimelineConnector(),
        ],
      ],
    );
  }

  String _labelForStep(BuildContext context, ImportStep step) {
    switch (step) {
      case ImportStep.selectFile:
        return context.l10n.importStepSelect;
      case ImportStep.mapColumns:
        return context.l10n.importStepMap;
      case ImportStep.preview:
        return context.l10n.importStepPreview;
    }
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.stepIndex,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.isLast,
  });

  final int stepIndex;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final muted = scheme.mutedForeground.withValues(alpha: 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isCompleted ? primary : muted,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: scheme.onPrimary,
                  )
                : Text(
                    '$stepIndex',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? scheme.onPrimary : muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? scheme.foreground : scheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scheme = Theme.of(context).colorScheme;
          return Container(
            height: 2,
            margin: EdgeInsets.only(
                top: 13,
                left: constraints.maxWidth > 0 ? 8 : 0,
                right: constraints.maxWidth > 0 ? 8 : 0),
            color: scheme.primary.withValues(alpha: 0.5),
          );
        },
      ),
    );
  }
}

class _SelectFileStep extends ConsumerWidget {
  const _SelectFileStep({required this.state});

  final ImportWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InstructionCard(
          icon: Icons.upload_file_rounded,
          title: context.l10n.importSelectFileTitle,
          description: context.l10n.importSelectFileHint,
        ),
        const SizedBox(height: 24),
        _GroupedSectionCard(
          title: context.l10n.file.toUpperCase(),
          children: [
            _StandardTile(
              leadingIcon: Icons.description_rounded,
              title: state.fileName ?? context.l10n.noFileSelected,
              subtitle: context.l10n.csvTxtSupported,
              trailing: state.isParsing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: scheme.mutedForeground.withValues(alpha: 0.6),
                    ),
              onTap: state.isParsing ? null : () => notifier.pickFile(),
            ),
          ],
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: state.errorMessage!),
        ],
      ],
    );
  }
}

class _MapColumnsStep extends ConsumerWidget {
  const _MapColumnsStep({required this.state});

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
          label: 'None',
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

      return _StandardTile(
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
        _InstructionCard(
          icon: Icons.table_chart_rounded,
          title: context.l10n.importMapTitle,
          description: context.l10n.importMapHint,
        ),
        // Format badge
        if (table.formatHint != CsvFormatHint.unknown &&
            table.formatHint != CsvFormatHint.generic) ...[
          const SizedBox(height: 12),
          _FormatHintBadge(hint: table.formatHint),
        ],
        // Sheet selector for multi-sheet Excel files
        if (state.hasMultipleSheets) ...[
          const SizedBox(height: 12),
          _SheetSelector(state: state),
        ],
        const SizedBox(height: 24),
        // Split debit/credit toggle
        _GroupedSectionCard(
          title: context.l10n.importColumnFormat.toUpperCase(),
          children: [
            _StandardTile(
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
        _GroupedSectionCard(
          title: context.l10n.required.toUpperCase(),
          children: [
            ...requiredFields.map((f) => buildFieldTile(f, required: true)),
          ],
        ),
        const SizedBox(height: 24),
        _GroupedSectionCard(
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
class _FormatHintBadge extends StatelessWidget {
  const _FormatHintBadge({required this.hint});

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
class _SheetSelector extends ConsumerWidget {
  const _SheetSelector({required this.state});

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

class _PreviewStep extends ConsumerWidget {
  const _PreviewStep({required this.state});

  final ImportWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final importableRows = state.parsedRows
        .where(
            (row) => row.isValid && (!state.skipDuplicates || !row.isDuplicate))
        .length;
    final canImport = importableRows > 0 && !state.isImporting;

    // Filter rows based on "Skip Duplicates" toggle for display?
    // User requested "Show ALL TRANSACTIONS".
    // We will show all, but mark duplicates visually.
    final rowsToDisplay = state.parsedRows;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount:
                rowsToDisplay.length + 3, // Summary + Options + Header + Rows
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildOverviewCard(context, ref),
                );
              }
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildOptionsCard(context, ref, scheme),
                );
              }
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.transactions.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: scheme.mutedForeground,
                    ),
                  ),
                );
              }

              final row = rowsToDisplay[index - 3];
              final isFirst = index == 3;
              final isLast = index == rowsToDisplay.length + 2;

              return _TransactionPreviewTile(
                row: row,
                isFirst: isFirst,
                isLast: isLast,
                onTap: state.isImporting
                    ? null
                    : () => _openEditRowSheet(context, ref, row),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.border)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedAdaptiveButton(
                    onPressed: () => notifier.setStep(ImportStep.mapColumns),
                    child: Text(context.l10n.back),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: canImport ? () => notifier.importRows() : null,
                    child: Text(
                      state.isImporting
                          ? context.l10n.importing
                          : '${context.l10n.importConfirm} ($importableRows)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return _GroupedSectionCard(
      title: context.l10n.summary.toUpperCase(),
      children: [
        _buildAccountSelectorRow(context, ref, scheme),
        _MetricRow(
          leftLabel: context.l10n.rows,
          leftValue: '${state.totalRows}',
          rightLabel: context.l10n.valid,
          rightValue: '${state.validRows}',
        ),
        _MetricRow(
          leftLabel: context.l10n.errors,
          leftValue: '${state.errorRows}',
          rightLabel: context.l10n.duplicates,
          rightValue: '${state.duplicateRows}',
        ),
      ],
    );
  }

  Widget _buildAccountSelectorRow(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
  ) {
    final notifier = ref.read(importWizardProvider.notifier);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final households = householdsAsync.valueOrNull ?? const [];
    final selectedHouseholdId = state.targetHouseholdId;

    Household? selectedHousehold;
    if (selectedHouseholdId != null) {
      for (final household in households) {
        if (household.id == selectedHouseholdId) {
          selectedHousehold = household;
          break;
        }
      }
    }

    final selectedLabel = selectedHouseholdId == null
        ? _userLabel(user, shortenEmail: false)
        : (selectedHousehold?.name ?? context.l10n.forUs);
    final pillLabel = _truncateMenuLabel(selectedLabel, maxLength: 18);
    final personalLabel =
        _truncateMenuLabel(_userLabel(user, shortenEmail: true));

    final items = <AdaptivePopupMenuItem>[
      AdaptivePopupMenuItem(
        label: personalLabel,
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'person.crop.circle.fill'
            : Icons.account_circle,
        value: 'personal',
      ),
      ...households.map(
        (household) => AdaptivePopupMenuItem(
          label: _truncateMenuLabel(household.name),
          icon: household.isPortfolio
              ? (PlatformInfo.isIOS26OrHigher()
                  ? 'person.crop.circle.fill'
                  : Icons.person)
              : (PlatformInfo.isIOS26OrHigher()
                  ? 'person.2.fill'
                  : Icons.group),
          value: 'household:${household.id}',
        ),
      ),
    ];

    final selector = AdaptivePopupMenuButton.widget(
      items: items,
      onSelected: (index, item) {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);

        if (item.value == 'personal') {
          notifier.setTargetAccount(householdId: null, isPortfolio: false);
          return;
        }

        if (item.value is String &&
            (item.value as String).startsWith('household:')) {
          final householdId = (item.value as String).split(':').last;
          Household? picked;
          for (final household in households) {
            if (household.id == householdId) {
              picked = household;
              break;
            }
          }
          notifier.setTargetAccount(
            householdId: householdId,
            isPortfolio: picked?.isPortfolio ?? false,
          );
        }
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: scheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 150,
              ),
              child: Text(
                pillLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: scheme.mutedForeground,
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.importInto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.foreground,
              ),
            ),
          ),
          selector,
        ],
      ),
    );
  }

  Widget _buildOptionsCard(
      BuildContext context, WidgetRef ref, ColorScheme scheme) {
    final notifier = ref.read(importWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupedSectionCard(
          title: context.l10n.options.toUpperCase(),
          children: [
            _StandardTile(
              leadingIcon: Icons.copy_rounded,
              title: context.l10n.skipDuplicates,
              trailing: AdaptiveSwitch(
                value: state.skipDuplicates,
                onChanged: (value) => notifier.setSkipDuplicates(value),
              ),
            ),
          ],
        ),
        if (state.isImporting) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
        ],
        if (state.importedCount > 0 || state.failedCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${context.l10n.imported}: ${state.importedCount} · ${context.l10n.failed}: ${state.failedCount}',
            style: TextStyle(color: scheme.mutedForeground),
          ),
        ],
      ],
    );
  }

  Future<void> _openEditRowSheet(
    BuildContext context,
    WidgetRef ref,
    ImportParsedRow row,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(importWizardProvider.notifier);
    final result = await MonekoBottomSheet.show<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.sheetBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                color: scheme.sheetBorder.withValues(alpha: 0.4),
              ),
            ),
            child: _EditRowSheet(row: row),
          ),
        );
      },
    );

    if (result == 'delete') {
      notifier.deleteParsedRow(row.index);
    } else if (result is ImportParsedRow) {
      notifier.updateParsedRow(result);
    }
  }
}

class _TransactionPreviewTile extends StatelessWidget {
  const _TransactionPreviewTile({
    required this.row,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final ImportParsedRow row;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isError = row.errors.isNotEmpty;
    final isDuplicate = row.isDuplicate;

    final amount = (row.amountCents ?? 0) / 100.0;
    final isIncome = (row.type ?? '').toLowerCase() == 'income';

    return Container(
      decoration: BoxDecoration(
        color: scheme.homeCardSurface,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        border: Border.all(
          color: scheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: scheme.homeCardShadow,
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: TransactionListTile(
              category: row.category ?? 'uncategorized',
              title: row.description?.isNotEmpty == true
                  ? row.description!
                  : (row.category ?? 'Uncategorized'),
              date: row.date,
              amount: amount,
              currency: row.currency ?? 'USD',
              isIncome: isIncome,
              onTap: onTap,
              dense: true,
              trailingWidget: isError
                  ? _StatusBadge(
                      label: 'Invalid',
                      color: scheme.errorAccent,
                      backgroundColor: scheme.errorSurface,
                    )
                  : isDuplicate
                      ? _StatusBadge(
                          label: 'Duplicate',
                          color: scheme.warning,
                          backgroundColor: scheme.warningSurface,
                        )
                      : null,
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: scheme.border.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRowSheet extends StatefulWidget {
  const _EditRowSheet({required this.row});

  final ImportParsedRow row;

  @override
  State<_EditRowSheet> createState() => _EditRowSheetState();
}

class _EditRowSheetState extends State<_EditRowSheet> {
  late DateTime? _date;
  late String _amountText;
  late String _categoryText;
  late String _descriptionText;
  late final DateFormat _dateFormat;

  @override
  void initState() {
    super.initState();
    _dateFormat = DateFormat('yyyy-MM-dd');
    _date = widget.row.date;
    _amountText = widget.row.amountCents != null
        ? (widget.row.amountCents!.abs() / 100.0).toStringAsFixed(2)
        : '';
    _categoryText = widget.row.category ?? '';
    _descriptionText = widget.row.description ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.sheetBorder.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.importEditRowTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  icon: Icon(Icons.delete_rounded, color: scheme.error),
                  tooltip: 'Delete Transaction',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GroupedSectionCard(
              title: context.l10n.details.toUpperCase(),
              children: [
                _StandardTile(
                  leadingIcon: Icons.calendar_month_rounded,
                  title: context.l10n.date,
                  trailing: _ValueChevron(
                    value:
                        _date != null ? _dateFormat.format(_date!) : 'Select',
                  ),
                  onTap: () => _pickDate(context),
                ),
                _StandardTile(
                  leadingIcon: Icons.payments_rounded,
                  title: context.l10n.amount,
                  trailing: _ValueChevron(
                    value: _amountText.isEmpty ? 'Enter' : _amountText,
                    isPlaceholder: _amountText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.amount,
                    placeholder: context.l10n.importEditAmountHint,
                    initialValue: _amountText,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSaved: (value) => setState(() => _amountText = value),
                  ),
                ),
                _StandardTile(
                  leadingIcon: Icons.category_rounded,
                  title: context.l10n.category,
                  trailing: _ValueChevron(
                    value:
                        _categoryText.isEmpty ? 'Uncategorized' : _categoryText,
                    isPlaceholder: _categoryText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.category,
                    placeholder: context.l10n.importEditCategoryHint,
                    initialValue: _categoryText,
                    keyboardType: TextInputType.text,
                    onSaved: (value) => setState(() => _categoryText = value),
                  ),
                ),
                _StandardTile(
                  leadingIcon: Icons.notes_rounded,
                  title: context.l10n.description,
                  trailing: _ValueChevron(
                    value: _descriptionText.isEmpty ? 'None' : _descriptionText,
                    isPlaceholder: _descriptionText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.description,
                    placeholder: context.l10n.importEditDescriptionHint,
                    initialValue: _descriptionText,
                    keyboardType: TextInputType.text,
                    onSaved: (value) =>
                        setState(() => _descriptionText = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedAdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: () => _handleSave(context),
                    child: Text(context.l10n.importEditSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = _date ?? DateTime.now();
    final picked = await showTransactionDatePicker(
      context: context,
      currentDate: current,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String placeholder,
    required String initialValue,
    required TextInputType keyboardType,
    required ValueChanged<String> onSaved,
  }) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: title,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: initialValue,
        placeholder: placeholder,
        keyboardType: keyboardType,
      ),
      confirmLabel: context.l10n.ok,
      cancelLabel: context.l10n.cancel,
    );

    final text = result?.text;
    if (result?.confirmed == true && text != null) {
      onSaved(text);
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    final parsedAmount = parseAmountCents(_amountText);

    final errors = <String>[];
    if (_date == null) {
      errors.add(context.l10n.importErrorInvalidDate);
    }
    if (parsedAmount == null) {
      errors.add(context.l10n.importErrorInvalidAmount);
    }

    if (errors.isNotEmpty) {
      await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.importEditInvalidTitle,
        description: errors.join('\n'),
        confirmLabel: context.l10n.ok,
        cancelLabel: context.l10n.cancel,
      );
      return;
    }

    final categoryValue = _categoryText.trim();
    final descriptionValue = _descriptionText.trim();

    Navigator.of(context).pop(
      widget.row.copyWith(
        date: _date,
        amountCents: parsedAmount?.abs(),
        category: categoryValue.isEmpty ? 'uncategorized' : categoryValue,
        description: descriptionValue.isEmpty ? null : descriptionValue,
      ),
    );
  }
}

class _GroupedSectionCard extends StatelessWidget {
  const _GroupedSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: scheme.mutedForeground,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: _withDividers(context, children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> tiles) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: scheme.border.withValues(alpha: 0.35),
            ),
          ),
        );
      }
    }
    return out;
  }
}

class _StandardTile extends StatelessWidget {
  const _StandardTile({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: scheme.foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueChevron extends StatelessWidget {
  const _ValueChevron({required this.value, this.isPlaceholder = false});

  final String value;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              color: isPlaceholder
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
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.errorBorder.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: TextStyle(color: scheme.errorAccent),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.mutedForeground,
                  ),
                ),
                Text(
                  leftValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: scheme.border.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rightLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.mutedForeground,
                  ),
                ),
                Text(
                  rightValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

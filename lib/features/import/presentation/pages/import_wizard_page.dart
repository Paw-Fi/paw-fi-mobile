import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/import/presentation/widgets/import_map_columns_step.dart';
import 'package:moneko/features/import/presentation/widgets/import_preview_step.dart';
import 'package:moneko/features/import/presentation/widgets/import_select_file_step.dart';
import 'package:moneko/features/import/presentation/widgets/import_timeline.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class ImportWizardPage extends ConsumerStatefulWidget {
  const ImportWizardPage({
    super.key,
    this.lockPersonalTarget = false,
    this.sourceApp,
  });

  final bool lockPersonalTarget;
  final ImportSourceApp? sourceApp;

  @override
  ConsumerState<ImportWizardPage> createState() => _ImportWizardPageState();
}

class _ImportWizardPageState extends ConsumerState<ImportWizardPage> {
  bool _isBlockingDialogVisible = false;
  bool _isBlockingDialogSyncScheduled = false;
  bool _isCompletionDialogVisible = false;
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
    if (widget.lockPersonalTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(importWizardProvider.notifier).setTargetAccount(
              householdId: null,
              isPortfolio: false,
            );
      });
    }
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

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
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
                  child: ImportTimeline(currentStep: state.step),
                ),
                Expanded(
                  child: _buildStep(context, state),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildStep(BuildContext context, ImportWizardState state) {
    switch (state.step) {
      case ImportStep.selectFile:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectFileStep(
            state: state,
            lockPersonalTarget: widget.lockPersonalTarget,
          ),
        );
      case ImportStep.mapColumns:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MapColumnsStep(state: state),
        );
      case ImportStep.preview:
        return PreviewStep(
          state: state,
          lockPersonalTarget: widget.lockPersonalTarget,
        );
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
          enableCancelAfterSeconds: 0,
          onCancel: null,
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
    if (_isCompletionDialogVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _dismissBlockingDialogIfVisible();

      if (!mounted) return;

      final succeeded = next.importedCount;
      final failed = next.failedCount;
      final skipped =
          (next.totalRows - succeeded - failed).clamp(0, next.totalRows);

      _isCompletionDialogVisible = true;
      try {
        await AdaptiveAlertDialog.show(
          context: context,
          title: context.l10n.importCompleted,
          message: [
            '${context.l10n.imported}: $succeeded',
            '${context.l10n.failed}: $failed',
            '${context.l10n.duplicates}: $skipped',
            if (next.errorMessage != null &&
                next.errorMessage!.trim().isNotEmpty)
              next.errorMessage!.trim(),
          ].join('\n'),
          actions: [
            AlertAction(
              title: context.l10n.gotIt,
              style: AlertActionStyle.primary,
              onPressed: () {},
            ),
          ],
        );
      } finally {
        _isCompletionDialogVisible = false;
      }

      _refreshDataAfterImport(next);

      ref.read(importWizardProvider.notifier).resetAfterImport();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  void _refreshDataAfterImport(ImportWizardState next) {
    final authState = ref.read(authProvider);
    final userId = authState.uid;
    if (userId.isEmpty) return;

    final targetHouseholdId = next.targetHouseholdId;
    if (targetHouseholdId == null || targetHouseholdId.isEmpty) {
      unawaited(
        ref
            .read(analyticsProvider.notifier)
            .loadData(userId, forceReload: true),
      );
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
      ref.invalidate(appInitializationV2Provider);
    }

    ref.invalidate(pocketsProvider);
    ref.invalidate(currencyTransactionCountsProvider);
  }
}

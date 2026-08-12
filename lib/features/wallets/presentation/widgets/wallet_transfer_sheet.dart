import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final RegExp _walletTransferExpenseIdPattern =
    RegExp(r'^transfer:([^:]+):(in|out)$');

String? extractWalletTransferIdFromExpenseId(String expenseId) =>
    _walletTransferExpenseIdPattern.firstMatch(expenseId)?.group(1);

bool isWalletTransferExpenseEntry(ExpenseEntry expense) =>
    extractWalletTransferIdFromExpenseId(expense.id) != null;

class _AnimatedAmountText extends StatelessWidget {
  final double value;
  final String symbol;
  final TextStyle style;

  const _AnimatedAmountText({
    required this.value,
    required this.symbol,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(val)))}',
          style: style,
        );
      },
    );
  }
}

class WalletTransferResult {
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String currency;
  final DateTime date;
  final String? note;

  const WalletTransferResult({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.currency,
    required this.date,
    this.note,
  });
}

typedef WalletTransferSubmit = Future<void> Function(
  WalletTransferResult result,
);
typedef WalletTransferDelete = Future<void> Function();

Future<WalletTransferResult?> showWalletTransferSheet(
  BuildContext context, {
  required List<WalletEntity> wallets,
  String? defaultFromWalletId,
  WalletTransfer? initialTransfer,
  WalletTransferSubmit? onSubmit,
  WalletTransferDelete? onDelete,
}) {
  if (wallets.length < 2) {
    return Future.value(null);
  }

  return showModalBottomSheet<WalletTransferResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    // An edit may have unsaved fields. Keep dismissal inside the sheet so it
    // can ask for confirmation instead of silently dropping those fields.
    enableDrag: initialTransfer == null,
    isDismissible: initialTransfer == null,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _WalletTransferSheet(
      wallets: wallets,
      defaultFromWalletId: defaultFromWalletId,
      initialTransfer: initialTransfer,
      onSubmit: onSubmit,
      onDelete: onDelete,
    ),
  );
}

/// Opens the normal transfer editor for a synthetic transfer feed row.
///
/// The transfer is resolved before the editor opens, so a tap never detours
/// through a read-only details sheet. The callback is invoked only after the
/// SQLite-first update has been accepted, allowing the visible feed row to be
/// replaced immediately by its caller.
Future<bool> showWalletTransferEditorForExpense(
  BuildContext context, {
  required ExpenseEntry transferExpense,
  required List<WalletEntity> wallets,
  ValueChanged<WalletTransfer>? onUpdated,
  ValueChanged<WalletTransfer>? onDeleted,
}) async {
  final transfer = await loadWalletTransferForExpense(
    context,
    transferExpense.id,
  );
  if (transfer == null ||
      wallets.length < 2 ||
      !wallets.any((wallet) => wallet.id == transfer.fromAccountId) ||
      !wallets.any((wallet) => wallet.id == transfer.toAccountId)) {
    if (context.mounted) {
      AppToast.error(context, context.l10n.failedToLoad);
    }
    return false;
  }
  if (!context.mounted) return false;

  var updated = false;
  await showWalletTransferSheet(
    context,
    wallets: wallets,
    initialTransfer: transfer,
    onSubmit: (result) async {
      final updatedTransfer = WalletTransfer(
        id: transfer.id,
        fromAccountId: result.fromAccountId,
        toAccountId: result.toAccountId,
        amountCents: result.amountCents,
        currency: result.currency,
        date: result.date,
        note: result.note,
      );
      await ProviderScope.containerOf(context, listen: false)
          .read(walletActionsProvider)
          .updateTransfer(
            existingTransfer: transfer,
            fromAccountId: result.fromAccountId,
            toAccountId: result.toAccountId,
            amountCents: result.amountCents,
            currency: result.currency,
            date: result.date,
            note: result.note,
          );
      updated = true;
      onUpdated?.call(updatedTransfer);
      if (context.mounted) {
        AppToast.success(context, context.l10n.transferUpdatedSuccessfully);
      }
    },
    onDelete: () async {
      await ProviderScope.containerOf(context, listen: false)
          .read(walletActionsProvider)
          .deleteTransfer(transfer);
      updated = true;
      onDeleted?.call(transfer);
      if (context.mounted) {
        AppToast.success(context, context.l10n.transferDeletedSuccessfully);
      }
    },
  );
  return updated;
}

class _WalletTransferSheet extends HookConsumerWidget {
  const _WalletTransferSheet({
    required this.wallets,
    this.defaultFromWalletId,
    this.initialTransfer,
    this.onSubmit,
    this.onDelete,
  });

  final List<WalletEntity> wallets;
  final String? defaultFromWalletId;
  final WalletTransfer? initialTransfer;
  final WalletTransferSubmit? onSubmit;
  final WalletTransferDelete? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize from wallet - use defaultFromWalletId if provided, otherwise first wallet
    final fromIdState = useState<String>(
      initialTransfer?.fromAccountId ?? defaultFromWalletId ?? wallets.first.id,
    );
    final initialFromWallet = wallets.firstWhere(
      (w) => w.id == fromIdState.value,
      orElse: () => wallets.first,
    );

    // Initialize to wallet - first non-from wallet
    final initialToWallet = wallets.firstWhere(
      (w) =>
          w.id != fromIdState.value && w.currency == initialFromWallet.currency,
      orElse: () => wallets.length > 1 ? wallets[1] : wallets.first,
    );
    final toIdState = useState<String>(
      initialTransfer?.toAccountId ?? initialToWallet.id,
    );

    final amountText = useState<String>(
      initialTransfer == null
          ? ''
          : formatAmount(centsToAmount(initialTransfer!.amountCents)),
    );
    final noteController = useTextEditingController(
      text: initialTransfer?.note?.trim() ?? '',
    );
    useListenable(noteController);
    final selectedDate = useState<DateTime>(
      initialTransfer?.date ?? DateTime.now(),
    );
    final isSaving = useState<bool>(false);
    final editingTransfer = initialTransfer;
    final isEditing = editingTransfer != null;
    final allowCloseWithUnsavedChanges = useState<bool>(false);
    final hasUnsavedChanges = isEditing &&
        (fromIdState.value != editingTransfer.fromAccountId ||
            toIdState.value != editingTransfer.toAccountId ||
            (tryParseMoneyToCents(amountText.value) ?? 0).toInt() !=
                editingTransfer.amountCents ||
            !_isSameCalendarDay(selectedDate.value, editingTransfer.date) ||
            _normalizedNote(noteController.text) !=
                _normalizedNote(editingTransfer.note));

    Future<void> requestClose() async {
      if (!hasUnsavedChanges) {
        Navigator.of(context).pop();
        return;
      }
      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.unsavedChanges,
        description: context.l10n.leaveWithoutSavingChanges,
        confirmLabel: context.l10n.leave,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );
      if (confirmation?.confirmed == true && context.mounted) {
        allowCloseWithUnsavedChanges.value = true;
        Navigator.of(context).pop();
      }
    }

    // Get current wallet names for display
    final fromWallet = wallets.firstWhere(
      (w) => w.id == fromIdState.value,
      orElse: () => wallets.first,
    );
    final toWallet = wallets.firstWhere(
      (w) => w.id == toIdState.value,
      orElse: () => wallets.first,
    );
    final currencyCode = fromWallet.currency;
    final symbol = resolveCurrencySymbol(currencyCode);

    // Parse amount from text
    double getAmountValue() {
      return (tryParseMoneyToCents(amountText.value) ?? 0) / 100.0;
    }

    Future<void> handleEditAmount() async {
      final fromColor = parseWalletColor(fromWallet.color, colorScheme.primary);
      final toColor = parseWalletColor(toWallet.color, colorScheme.primary);

      final header = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              resolveWalletIcon(fromWallet.icon),
              size: 14,
              color: fromColor,
            ),
            const SizedBox(width: 6),
            Text(
              fromWallet.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 12,
              color: colorScheme.mutedForeground.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Icon(
              resolveWalletIcon(toWallet.icon),
              size: 14,
              color: toColor,
            ),
            const SizedBox(width: 6),
            Text(
              toWallet.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
      );

      final result = await showCalculatorKeypadSheet(
        context: context,
        initialValue: amountText.value,
        prefix: symbol,
        header: header,
      );
      if (result != null) {
        amountText.value = result;
      }
    }

    Future<void> handleEditDate() async {
      final now = DateTime.now();
      final lastDate =
          selectedDate.value.isAfter(now) ? selectedDate.value : now;
      final firstDate = selectedDate.value.isBefore(DateTime(2020))
          ? selectedDate.value
          : DateTime(2020);
      final result = await showDatePicker(
        context: context,
        initialDate: selectedDate.value,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (result != null) {
        selectedDate.value = result;
      }
    }

    void handleSwapDirection() {
      final temp = fromIdState.value;
      fromIdState.value = toIdState.value;
      toIdState.value = temp;
    }

    Future<void> handleSave() async {
      // Validation
      if (fromIdState.value == toIdState.value) {
        AppToast.error(context, context.l10n.cannotTransferSameWallet);
        return;
      }
      if (fromWallet.currency != toWallet.currency) {
        AppToast.error(
            context, 'Transfers require wallets with the same currency');
        return;
      }

      final amountCents = (tryParseMoneyToCents(amountText.value) ?? 0).toInt();
      if (amountCents <= 0) {
        AppToast.error(context, context.l10n.pleaseEnterValidAmount);
        return;
      }

      final result = WalletTransferResult(
        fromAccountId: fromIdState.value,
        toAccountId: toIdState.value,
        amountCents: amountCents,
        currency: fromWallet.currency,
        date: selectedDate.value,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
      final submit = onSubmit;
      if (submit == null) {
        allowCloseWithUnsavedChanges.value = true;
        Navigator.of(context).pop(result);
        return;
      }

      isSaving.value = true;
      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.paywallProcessing,
      );
      try {
        await WidgetsBinding.instance.endOfFrame;
        await submit(result);
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        allowCloseWithUnsavedChanges.value = true;
        Navigator.of(context).pop(result);
      } catch (error) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        isSaving.value = false;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    Future<void> handleDelete() async {
      final delete = onDelete;
      if (delete == null || isSaving.value) return;
      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.delete,
        description: context.l10n.areYouSureYouWantToDeleteThisTransaction,
        confirmLabel: context.l10n.delete,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );
      if (confirmation?.confirmed != true || !context.mounted) return;
      isSaving.value = true;
      try {
        await delete();
        if (!context.mounted) return;
        allowCloseWithUnsavedChanges.value = true;
        Navigator.of(context).pop();
      } catch (error) {
        if (context.mounted) {
          isSaving.value = false;
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> handleSelectFromWallet() async {
      final selected = await _showWalletSelectionSheet(
        context,
        ref: ref,
        wallets: wallets,
        currentId: fromIdState.value,
        title: context.l10n.fromWallet,
      );
      if (selected != null && selected != fromIdState.value) {
        fromIdState.value = selected;
        final nextFromWallet = wallets.firstWhere(
          (w) => w.id == selected,
          orElse: () => fromWallet,
        );
        final selectedToWallet = wallets.firstWhere(
          (w) => w.id == toIdState.value,
          orElse: () => toWallet,
        );
        if (toIdState.value == selected ||
            selectedToWallet.currency != nextFromWallet.currency) {
          final otherWallet = wallets.firstWhere(
            (w) => w.id != selected && w.currency == nextFromWallet.currency,
            orElse: () => wallets.first,
          );
          toIdState.value = otherWallet.id;
        }
      }
    }

    Future<void> handleSelectToWallet() async {
      final selected = await _showWalletSelectionSheet(
        context,
        ref: ref,
        wallets: wallets
            .where((wallet) => wallet.currency == fromWallet.currency)
            .toList(growable: false),
        currentId: toIdState.value,
        title: context.l10n.toWallet,
      );
      if (selected != null && selected != toIdState.value) {
        toIdState.value = selected;
      }
    }

    return PopScope(
      canPop: !isSaving.value &&
          (!hasUnsavedChanges || allowCloseWithUnsavedChanges.value),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isSaving.value) {
          requestClose();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                      IconButton(
                        onPressed: isSaving.value ? null : requestClose,
                        icon: Icon(Icons.close,
                            color: colorScheme.mutedForeground),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colorScheme.muted.withValues(alpha: 0.2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.transfer,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.foreground,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: isSaving.value ? null : handleSave,
                        icon: isSaving.value
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(Icons.check, color: colorScheme.primary),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.12),
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
                        // Amount Hero Section - matches unified_transaction_sheet styling
                        GestureDetector(
                          onTap: isSaving.value ? null : handleEditAmount,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(getAmountValue())))}',
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    letterSpacing: 0,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.tapToEditAmount,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // From Wallet Section
                        Text(
                          context.l10n.from,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MonekoInput(
                          child: InkWell(
                            onTap: isSaving.value
                                ? null
                                : () => handleSelectFromWallet(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 14.0),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: parseWalletColor(fromWallet.color,
                                              colorScheme.primary)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Icon(
                                        resolveWalletIcon(fromWallet.icon),
                                        key: ValueKey(fromWallet.icon),
                                        color: parseWalletColor(
                                            fromWallet.color,
                                            colorScheme.primary),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      layoutBuilder:
                                          (currentChild, previousChildren) =>
                                              Stack(
                                        alignment: Alignment.centerLeft,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
                                        ],
                                      ),
                                      child: Text(
                                        fromWallet.name,
                                        key: ValueKey(fromWallet.name),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _AnimatedAmountText(
                                    value:
                                        fromWallet.currentBalanceCents / 100.0,
                                    symbol: symbol,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: colorScheme.mutedForeground
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Swap Direction Button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: isSaving.value
                                      ? null
                                      : handleSwapDirection,
                                  icon: Icon(
                                    Icons.swap_vert,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  tooltip: context.l10n.swapDirection,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // To Wallet Section
                        Text(
                          context.l10n.to,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MonekoInput(
                          child: InkWell(
                            onTap: isSaving.value
                                ? null
                                : () => handleSelectToWallet(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 14.0),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: parseWalletColor(toWallet.color,
                                              colorScheme.primary)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Icon(
                                        resolveWalletIcon(toWallet.icon),
                                        key: ValueKey(toWallet.icon),
                                        color: parseWalletColor(toWallet.color,
                                            colorScheme.primary),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      layoutBuilder:
                                          (currentChild, previousChildren) =>
                                              Stack(
                                        alignment: Alignment.centerLeft,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null)
                                            currentChild,
                                        ],
                                      ),
                                      child: Text(
                                        toWallet.name,
                                        key: ValueKey(toWallet.name),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _AnimatedAmountText(
                                    value: toWallet.currentBalanceCents / 100.0,
                                    symbol: symbol,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: colorScheme.mutedForeground
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          context.l10n.date,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MonekoInput(
                          child: InkWell(
                            onTap: isSaving.value ? null : handleEditDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 14.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat.yMMMd(
                                        Localizations.localeOf(context)
                                            .toString(),
                                      ).format(selectedDate.value),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: colorScheme.mutedForeground
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Note Field
                        Text(
                          context.l10n.noteOptional,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: noteController,
                          placeholder: context.l10n.addNoteAboutTransfer,
                          maxLines: 2,
                        ),

                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryAdaptiveButton(
                            onPressed: isSaving.value ? null : handleSave,
                            child: isSaving.value
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(isEditing
                                    ? context.l10n.saveChanges
                                    : context.l10n.transfer),
                          ),
                        ),
                        if (isEditing && onDelete != null) ...[
                          const SizedBox(height: 24),
                          DestructiveAdaptiveButton(
                            onPressed: isSaving.value ? null : handleDelete,
                            child: Text(context.l10n.delete),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showWalletSelectionSheet(
    BuildContext context, {
    required WidgetRef ref,
    required List<WalletEntity> wallets,
    required String currentId,
    required String title,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      enableDrag: true,
      useSafeArea: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalSheetHandle(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back,
                            color: colorScheme.mutedForeground),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colorScheme.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final symbol = resolveCurrencySymbol(wallet.currency);
                      final isSelected = wallet.id == currentId;
                      final walletColor =
                          parseWalletColor(wallet.color, colorScheme.primary);

                      return ListTile(
                        onTap: () => Navigator.of(context).pop(wallet.id),
                        selected: isSelected,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: walletColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            resolveWalletIcon(wallet.icon),
                            color: walletColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          wallet.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        subtitle: Text(
                          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(wallet.currentBalanceCents / 100.0)))}',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: colorScheme.primary)
                            : null,
                      );
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<WalletTransfer?> loadWalletTransferForExpense(
  BuildContext context,
  String transferExpenseId,
) async {
  final transferId = extractWalletTransferIdFromExpenseId(transferExpenseId);
  if (transferId == null) return null;

  try {
    final row = await Supabase.instance.client
        .from('account_transfers')
        .select(
            'id, from_account_id, to_account_id, amount_cents, currency, date, note')
        .eq('id', transferId)
        .maybeSingle();
    if (row is Map<String, dynamic>) return WalletTransfer.fromJson(row);
  } catch (_) {
    // A locally queued transfer may not have a canonical server row yet.
  }
  if (!context.mounted) return null;

  final database = await ProviderScope.containerOf(context, listen: false)
      .read(localDatabaseProvider.future);
  final outgoing = await database.getTransactionByIdOrClientRecordId(
    'transfer:$transferId:out',
  );
  final incoming = await database.getTransactionByIdOrClientRecordId(
    'transfer:$transferId:in',
  );
  if (outgoing?.walletId == null || incoming?.walletId == null) return null;
  return WalletTransfer(
    id: transferId,
    fromAccountId: outgoing!.walletId!,
    toAccountId: incoming!.walletId!,
    amountCents: outgoing.amountCents,
    currency: outgoing.currency ?? incoming.currency ?? 'USD',
    date: outgoing.date,
    note: _normalizedNote(outgoing.rawText),
  );
}

bool _isSameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String? _normalizedNote(String? value) {
  final note = value?.trim();
  if (note == null || note.isEmpty) return null;
  final normalized = note.toLowerCase();
  return normalized == 'transfer in' || normalized == 'transfer out'
      ? null
      : note;
}

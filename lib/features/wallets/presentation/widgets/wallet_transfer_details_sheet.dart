import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final RegExp _walletTransferExpenseIdPattern =
    RegExp(r'^transfer:([^:]+):(in|out)$');

String? extractWalletTransferIdFromExpenseId(String expenseId) {
  final match = _walletTransferExpenseIdPattern.firstMatch(expenseId);
  return match?.group(1);
}

bool isWalletTransferExpenseEntry(ExpenseEntry expense) =>
    extractWalletTransferIdFromExpenseId(expense.id) != null;

Future<bool?> showWalletTransferDetailsSheet(
  BuildContext context, {
  required ExpenseEntry transferExpense,
  required List<WalletEntity> wallets,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _WalletTransferDetailsSheet(
      transferExpense: transferExpense,
      wallets: wallets,
    ),
  );
}

class _WalletTransferDetailsSheet extends HookConsumerWidget {
  const _WalletTransferDetailsSheet({
    required this.transferExpense,
    required this.wallets,
  });

  final ExpenseEntry transferExpense;
  final List<WalletEntity> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.watch(walletActionsProvider);
    final locale = Localizations.localeOf(context).toString();
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final direction = _WalletTransferDirection.fromExpense(transferExpense);
    final transferFuture = useMemoized(
      () => _loadTransferDetails(transferExpense.id),
      [transferExpense.id],
    );
    final transferSnapshot = useFuture(transferFuture);
    final transfer = transferSnapshot.data;
    final isMutating = useState<bool>(false);
    final currencyCode =
        transfer?.currency ?? transferExpense.currency ?? selectedCurrencyCode;
    final symbol = resolveCurrencySymbol(currencyCode);
    final fromWallet = transfer == null
        ? direction == _WalletTransferDirection.outgoing
            ? _walletById(wallets, transferExpense.walletId)
            : null
        : _walletById(wallets, transfer.fromAccountId);
    final toWallet = transfer == null
        ? direction == _WalletTransferDirection.incoming
            ? _walletById(wallets, transferExpense.walletId)
            : null
        : _walletById(wallets, transfer.toAccountId);
    final note = transfer?.note?.trim().isNotEmpty == true
        ? transfer!.note!.trim()
        : _resolvedTransferNote(transferExpense.rawText);
    final amountValue =
        (transfer?.amountCents ?? transferExpense.amountCents) / 100.0;
    final amountPrefix = direction == _WalletTransferDirection.incoming
        ? '+$symbol'
        : '-$symbol';
    final amountColor = direction == _WalletTransferDirection.incoming
        ? colorScheme.success
        : colorScheme.foreground;
    final date = transfer?.date ?? transferExpense.date;
    final formattedDate = DateFormat.yMMMd(locale).format(date);
    final canEditTransfer = transfer != null &&
        wallets.length >= 2 &&
        _walletById(wallets, transfer.fromAccountId) != null &&
        _walletById(wallets, transfer.toAccountId) != null;

    Future<void> handleEditTransfer() async {
      final loadedTransfer = transfer;
      if (loadedTransfer == null || !canEditTransfer || isMutating.value) {
        return;
      }
      final result = await showWalletTransferSheet(
        context,
        wallets: wallets,
        initialTransfer: loadedTransfer,
      );
      if (result == null || !context.mounted) {
        return;
      }
      isMutating.value = true;
      try {
        await actions.updateTransfer(
          existingTransfer: loadedTransfer,
          fromAccountId: result.fromAccountId,
          toAccountId: result.toAccountId,
          amountCents: result.amountCents,
          currency: currencyCode,
          date: result.date,
          note: result.note,
        );
        if (!context.mounted) {
          return;
        }
        AppToast.success(context, context.l10n.saveChanges);
        Navigator.of(context).pop(true);
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      } finally {
        if (context.mounted) {
          isMutating.value = false;
        }
      }
    }

    Future<void> handleDeleteTransfer() async {
      if (transfer == null || isMutating.value) {
        return;
      }
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.delete,
        description: context.l10n.areYouSureYouWantToDeleteThisTransaction,
        confirmLabel: context.l10n.delete,
        cancelLabel: context.l10n.cancel,
      );
      if (confirm?.confirmed != true || !context.mounted) {
        return;
      }
      isMutating.value = true;
      try {
        await actions.deleteTransfer(transfer);
        if (!context.mounted) {
          return;
        }
        AppToast.success(context, context.l10n.delete);
        Navigator.of(context).pop(true);
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      } finally {
        if (context.mounted) {
          isMutating.value = false;
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
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
                    icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.muted.withValues(alpha: 0.2),
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
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Text(
                            '$amountPrefix${formatLocalizedNumber(context, double.parse(formatAmount(amountValue)))}',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w600,
                              color: amountColor,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TransferWalletCard(
                      label: context.l10n.fromWallet,
                      wallet: fromWallet,
                      fallbackLabel: context.l10n.wallet,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    _TransferWalletCard(
                      label: context.l10n.toWallet,
                      wallet: toWallet,
                      fallbackLabel: context.l10n.wallet,
                    ),
                    if (transferSnapshot.connectionState ==
                        ConnectionState.waiting)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    if (note != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.noteOptional,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonekoInput(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (transfer != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryAdaptiveButton(
                          onPressed: isMutating.value || !canEditTransfer
                              ? null
                              : handleEditTransfer,
                          child: Text(context.l10n.edit),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed:
                              isMutating.value ? null : handleDeleteTransfer,
                          child: Text(
                            context.l10n.delete,
                            style: TextStyle(color: colorScheme.destructive),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryAdaptiveButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.done),
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

enum _WalletTransferDirection {
  incoming,
  outgoing;

  factory _WalletTransferDirection.fromExpense(ExpenseEntry expense) {
    return (expense.type ?? 'expense').toLowerCase() == 'income'
        ? _WalletTransferDirection.incoming
        : _WalletTransferDirection.outgoing;
  }
}

class _TransferWalletCard extends StatelessWidget {
  const _TransferWalletCard({
    required this.label,
    required this.wallet,
    required this.fallbackLabel,
  });

  final String label;
  final WalletEntity? wallet;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final walletColor = parseWalletColor(wallet?.color, colorScheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        MonekoInput(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: walletColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    resolveWalletIcon(wallet?.icon),
                    color: walletColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    wallet?.name ?? fallbackLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.foreground,
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
}

Future<WalletTransfer?> _loadTransferDetails(String transferExpenseId) async {
  final transferId = extractWalletTransferIdFromExpenseId(transferExpenseId);
  if (transferId == null) {
    return null;
  }

  try {
    final row = await Supabase.instance.client
        .from('account_transfers')
        .select(
          'id, from_account_id, to_account_id, amount_cents, currency, date, note',
        )
        .eq('id', transferId)
        .maybeSingle();

    if (row is! Map<String, dynamic>) {
      return null;
    }

    return WalletTransfer.fromJson(row);
  } catch (_) {
    return null;
  }
}

WalletEntity? _walletById(List<WalletEntity> wallets, String? walletId) {
  if (walletId == null || walletId.isEmpty) {
    return null;
  }

  for (final wallet in wallets) {
    if (wallet.id == walletId) {
      return wallet;
    }
  }

  return null;
}

String? _resolvedTransferNote(String? rawText) {
  final value = rawText?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final normalized = value.toLowerCase();
  if (normalized == 'transfer in' || normalized == 'transfer out') {
    return null;
  }

  return value;
}

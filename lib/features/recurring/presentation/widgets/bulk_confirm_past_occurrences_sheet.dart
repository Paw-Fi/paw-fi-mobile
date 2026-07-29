import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';

/// Opens the bulk confirmation dialog for remaining past unconfirmed cycles.
Future<bool?> showBulkConfirmPastOccurrencesSheet({
  required BuildContext context,
  required RecurringTransaction recurringTransaction,
  required List<DateTime> occurrences,
  String? initialAccountId,
}) {
  return MonekoBottomSheet.show<bool>(
    context: context,
    title: context.l10n.confirmRemainingCycles,
    isScrollControlled: true,
    onClose: () => Navigator.of(context).pop(false),
    builder: (_) => _BulkConfirmPastOccurrencesForm(
      recurringTransaction: recurringTransaction,
      occurrences: occurrences,
      initialAccountId: initialAccountId,
    ),
  );
}

class _BulkConfirmPastOccurrencesForm extends ConsumerStatefulWidget {
  const _BulkConfirmPastOccurrencesForm({
    required this.recurringTransaction,
    required this.occurrences,
    this.initialAccountId,
  });

  final RecurringTransaction recurringTransaction;
  final List<DateTime> occurrences;
  final String? initialAccountId;

  @override
  ConsumerState<_BulkConfirmPastOccurrencesForm> createState() =>
      _BulkConfirmPastOccurrencesFormState();
}

class _BulkConfirmPastOccurrencesFormState
    extends ConsumerState<_BulkConfirmPastOccurrencesForm> {
  String? _accountId;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accountId =
        widget.initialAccountId ?? widget.recurringTransaction.accountId;
  }

  Future<void> _submitBulk() async {
    final userId = ref.read(authProvider).uid;
    if (userId.isEmpty) {
      setState(() => _error = 'Sign in to confirm payments.');
      return;
    }
    final walletsAsync = ref.read(walletsByCurrencyProvider(
      WalletsCurrencyQuery(
        householdId: widget.recurringTransaction.householdId,
        currency: widget.recurringTransaction.currency,
      ),
    ));
    final loadedWallets = walletsAsync.valueOrNull;
    if (loadedWallets == null) {
      setState(() => _error = walletsAsync.hasError
          ? 'Unable to load wallets.'
          : 'Wallets are still loading.');
      return;
    }
    final activeWallets = loadedWallets
        .where((wallet) => !wallet.isArchived)
        .toList(growable: false);
    if (activeWallets.isEmpty) {
      _accountId = null;
    } else if (_accountId != null &&
        !activeWallets.any((wallet) => wallet.id == _accountId)) {
      setState(() => _error = 'Choose a wallet for confirmation.');
      return;
    }
    if (activeWallets.isNotEmpty &&
        (_accountId == null || _accountId!.isEmpty)) {
      setState(() => _error = 'Choose a wallet for confirmation.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    int successCount = 0;
    final amountCents = (widget.recurringTransaction.amount * 100).round();
    final controller = ref.read(recurringOccurrenceConfirmationProvider);

    for (final occurrence in widget.occurrences) {
      final command = RecurringOccurrenceConfirmationCommand(
        userId: userId,
        recurringTransaction: widget.recurringTransaction,
        scheduledOccurrenceDate: occurrence,
        paidDate: occurrence,
        amountCents: amountCents,
        accountId: _accountId,
        merchant: widget.recurringTransaction.merchant ?? '',
        description: widget.recurringTransaction.description ?? '',
        updateFutureAmount: false,
      );

      final result = await controller.confirm(command);
      if (result.isQueued) {
        successCount++;
      }
    }

    if (!mounted) return;

    if (successCount == 0) {
      setState(() {
        _isSubmitting = false;
        _error = 'Unable to confirm remaining past payments.';
      });
      return;
    }

    Navigator.of(context).pop(true);
    AppToast.success(
      context,
      'Successfully confirmed $successCount past payments.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transaction = widget.recurringTransaction;
    final occurrences = widget.occurrences;

    final walletsAsync = ref.watch(walletsByCurrencyProvider(
      WalletsCurrencyQuery(
        householdId: transaction.householdId,
        currency: transaction.currency,
      ),
    ));
    final loadedWallets = walletsAsync.valueOrNull;
    final wallets = (loadedWallets ?? const <WalletEntity>[])
        .where((wallet) => !wallet.isArchived)
        .toList(growable: false);

    if (!wallets.any((wallet) => wallet.id == _accountId)) {
      _accountId = wallets.isEmpty ? null : wallets.first.id;
    }

    var walletName = loadedWallets == null
        ? (walletsAsync.hasError ? 'Wallets unavailable' : 'Loading wallets...')
        : wallets.isEmpty
            ? context.l10n.noWallet
            : 'Choose wallet';
    for (final wallet in wallets) {
      if (wallet.id == _accountId) {
        walletName = wallet.name;
        break;
      }
    }

    final isIncome = transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? colorScheme.success : colorScheme.foreground;
    final singleAmount = double.parse(formatAmount(transaction.amount));
    final totalAmount = singleAmount * occurrences.length;
    final currencySymbol = resolveCurrencySymbol(transaction.currency);

    final formattedSingleAmount =
        '$sign$currencySymbol${formatLocalizedNumber(context, singleAmount)}';
    final formattedTotalAmount =
        '$sign$currencySymbol${formatLocalizedNumber(context, totalAmount)}';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.confirmRemainingSubtitle(occurrences.length),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Account Selection Tile
          MonekoInput(
            child: MonekoDisclosureRow(
              label: 'Deposit/Withdraw Wallet',
              value: walletName,
              isFirst: true,
              isLast: true,
              onTap: _isSubmitting || wallets.isEmpty
                  ? null
                  : () async {
                      if (wallets.length <= 1) return;
                      // Allow selecting wallet from available wallets
                    },
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card & List of Past Cycles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.sheetElementBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.surfaceBorder,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.unconfirmedPastCycles,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    Text(
                      formattedTotalAmount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 8),

                // Adaptive Container: Max Height Scroll for Long Lists (> 4 items)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: occurrences.length > 4 ? 200 : double.infinity,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: occurrences.length > 4
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: occurrences.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final occurrence = occurrences[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 14,
                                  color: colorScheme.mutedForeground,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatLocalizedDate(context, occurrence),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              formattedSingleAmount,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: amountColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: colorScheme.destructive,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Primary CTA: Confirm All
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitBulk,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                    ),
                  )
                : Text(
                    context.l10n.confirmAllPayments(occurrences.length),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Secondary CTA: Skip
          TextButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(
              context.l10n.skipForNow,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

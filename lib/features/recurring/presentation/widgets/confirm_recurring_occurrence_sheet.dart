import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/utils/recurring_occurrence_schedule.dart';
import 'package:moneko/features/recurring/presentation/widgets/bulk_confirm_past_occurrences_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';

/// Opens the single confirmation flow used by every recurring occurrence CTA.
Future<void> showConfirmRecurringOccurrenceSheet({
  required BuildContext context,
  required RecurringTransaction recurringTransaction,
  required DateTime scheduledOccurrenceDate,
  RecurringOccurrenceTimelineItem? existingOccurrence,
}) {
  final isEditing = existingOccurrence?.isConfirmed == true;
  return MonekoBottomSheet.show<void>(
    context: context,
    title: isEditing ? 'Edit payment' : context.l10n.confirmPayment,
    isScrollControlled: true,
    onClose: () => Navigator.of(context).pop(),
    builder: (_) => _ConfirmRecurringOccurrenceForm(
      recurringTransaction: recurringTransaction,
      scheduledOccurrenceDate: scheduledOccurrenceDate,
      existingOccurrence: existingOccurrence,
    ),
  );
}

class _ConfirmRecurringOccurrenceForm extends ConsumerStatefulWidget {
  const _ConfirmRecurringOccurrenceForm({
    required this.recurringTransaction,
    required this.scheduledOccurrenceDate,
    this.existingOccurrence,
  });

  final RecurringTransaction recurringTransaction;
  final DateTime scheduledOccurrenceDate;
  final RecurringOccurrenceTimelineItem? existingOccurrence;

  @override
  ConsumerState<_ConfirmRecurringOccurrenceForm> createState() =>
      _ConfirmRecurringOccurrenceFormState();
}

class _ConfirmRecurringOccurrenceFormState
    extends ConsumerState<_ConfirmRecurringOccurrenceForm> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late DateTime _paidDate;
  String? _accountId;
  bool _updateFutureAmount = false;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existingOccurrence?.isConfirmed == true;
  bool get _isSettlementLocked =>
      widget.existingOccurrence?.isSettlementLocked == true;
  String get _merchant =>
      widget.existingOccurrence?.actualTransaction?.merchant ??
      widget.recurringTransaction.merchant ??
      '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingOccurrence;
    _amountController = TextEditingController(
        text: existing?.amountCents != null
            ? (existing!.amountCents! / 100).toStringAsFixed(2)
            : widget.recurringTransaction.amount.toStringAsFixed(2));
    _notesController = TextEditingController(
      text: existing?.actualTransaction?.rawText ??
          widget.recurringTransaction.description ??
          '',
    );
    final today = effectiveToday(
      preferredTimezone: ref.read(analyticsProvider).contact?.preferredTimezone,
    );
    _paidDate = existing?.paidDate ??
        (widget.scheduledOccurrenceDate.isAfter(today)
            ? today
            : widget.scheduledOccurrenceDate);
    _accountId = existing?.actualTransaction?.walletId ??
        widget.recurringTransaction.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final normalized = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) return null;
    return (amount * 100).round();
  }

  Future<void> _submit() async {
    final amountCents = _amountCents;
    final userId = ref.read(authProvider).uid;
    final today = effectiveToday(
      preferredTimezone: ref.read(analyticsProvider).contact?.preferredTimezone,
    );
    if (!_isSettlementLocked && amountCents == null) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (!_isEditing &&
        !canConfirmOccurrenceAt(
          widget.recurringTransaction,
          widget.scheduledOccurrenceDate,
          effectiveNow(
            preferredTimezone:
                ref.read(analyticsProvider).contact?.preferredTimezone,
          ),
        )) {
      setState(() =>
          _error = 'This occurrence is not available for confirmation yet.');
      return;
    }
    if (!_isSettlementLocked && (_accountId == null || _accountId!.isEmpty)) {
      setState(() => _error = 'Choose a wallet in this currency.');
      return;
    }
    if (!_isSettlementLocked && _paidDate.isAfter(today)) {
      setState(() => _error = 'The paid date cannot be later than today.');
      return;
    }
    if (userId.isEmpty) {
      setState(() => _error = 'Sign in to confirm this payment.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = _isEditing
        ? await ref.read(recurringOccurrenceUpdateProvider).update(
              RecurringOccurrenceUpdateCommand(
                userId: userId,
                recurringTransaction: widget.recurringTransaction,
                occurrence: widget.existingOccurrence!,
                paidDate: _paidDate,
                amountCents: amountCents,
                accountId: _accountId,
                merchant: _merchant,
                description: _notesController.text,
                updateFutureAmount: _updateFutureAmount,
              ),
            )
        : await ref
            .read(recurringOccurrenceConfirmationProvider)
            .confirm(RecurringOccurrenceConfirmationCommand(
              userId: userId,
              recurringTransaction: widget.recurringTransaction,
              scheduledOccurrenceDate: widget.scheduledOccurrenceDate,
              paidDate: _paidDate,
              amountCents: amountCents!,
              accountId: _accountId!,
              merchant: _merchant,
              description: _notesController.text,
              updateFutureAmount: _updateFutureAmount,
            ));
    if (!mounted) return;
    if (!result.isQueued) {
      setState(() {
        _isSubmitting = false;
        _error = result.error ??
            (_isEditing
                ? 'Unable to update payment.'
                : 'Unable to confirm payment.');
      });
      return;
    }
    List<DateTime> remainingPastOccurrences = const [];
    if (!_isEditing) {
      final preferredTimezone =
          ref.read(analyticsProvider).contact?.preferredTimezone;
      final userNow = effectiveNow(preferredTimezone: preferredTimezone);
      final userToday = DateTime(userNow.year, userNow.month, userNow.day);

      final generated =
          getOccurrencesList(widget.recurringTransaction, userNow);
      final confirmedDateStr =
          formatDateOnlyYmd(widget.scheduledOccurrenceDate);

      final candidatePastOccurrences = generated.where((occ) {
        final occDate = DateTime(occ.year, occ.month, occ.day);
        return !occDate.isAfter(userToday) &&
            formatDateOnlyYmd(occ) != confirmedDateStr;
      }).toList();

      if (candidatePastOccurrences.isNotEmpty) {
        final timeline = ref
                .read(recurringOccurrenceTimelineProvider(
                  RecurringOccurrenceTimelineQuery(
                    userId: userId,
                    householdId: widget.recurringTransaction.householdId,
                    recurringId: widget.recurringTransaction.id,
                    startDate: candidatePastOccurrences.first,
                    endDate: candidatePastOccurrences.last,
                  ),
                ))
                .valueOrNull ??
            const <RecurringOccurrenceTimelineItem>[];

        final confirmedDates = <String>{
          for (final item in timeline)
            if (item.isConfirmed)
              formatDateOnlyYmd(item.scheduledOccurrenceDate),
        };

        remainingPastOccurrences = candidatePastOccurrences
            .where((occ) => !confirmedDates.contains(formatDateOnlyYmd(occ)))
            .toList();
      }
    }

    Navigator.of(context).pop();

    if (!_isEditing && remainingPastOccurrences.isNotEmpty) {
      showBulkConfirmPastOccurrencesSheet(
        context: context,
        recurringTransaction: widget.recurringTransaction,
        occurrences: remainingPastOccurrences,
        initialAccountId: _accountId,
      );
    } else {
      AppToast.success(
        context,
        _isEditing ? 'Payment update saved.' : 'Payment confirmation saved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transaction = widget.recurringTransaction;
    final walletsAsync = ref.watch(walletsByCurrencyProvider(
      WalletsCurrencyQuery(
        householdId: transaction.householdId,
        currency: transaction.currency,
      ),
    ));
    final wallets = (walletsAsync.valueOrNull ?? const <WalletEntity>[])
        .where((wallet) => !wallet.isArchived)
        .toList(growable: false);
    if (!wallets.any((wallet) => wallet.id == _accountId)) {
      _accountId = wallets.isEmpty ? null : wallets.first.id;
    }
    final amountChanged = !_isSettlementLocked &&
        _amountCents != null &&
        _amountCents != (transaction.amount * 100).round();
    final receivedLabel = transaction.type == 'income' ? 'received' : 'paid';
    var walletName = 'Choose wallet';
    for (final wallet in wallets) {
      if (wallet.id == _accountId) {
        walletName = wallet.name;
        break;
      }
    }

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
          MonekoInput(
            child: _ReadOnlyRow(
              label: 'Scheduled date',
              value:
                  formatLocalizedDate(context, widget.scheduledOccurrenceDate),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isSettlementLocked)
            MonekoInput(
              child: Column(
                children: [
                  MonekoDisclosureRow(
                    label: 'Date $receivedLabel',
                    value: formatLocalizedDate(context, _paidDate),
                    isFirst: true,
                    onTap: _isSubmitting
                        ? () {}
                        : () async {
                            final selected = await showTransactionDatePicker(
                              context: context,
                              currentDate: _paidDate,
                              lastDate: effectiveToday(
                                preferredTimezone: ref
                                    .read(analyticsProvider)
                                    .contact
                                    ?.preferredTimezone,
                              ),
                            );
                            if (selected != null && mounted) {
                              setState(() => _paidDate = selected);
                            }
                          },
                  ),
                  const Divider(height: 1),
                  MonekoDisclosureRow(
                    label: 'Actual amount',
                    value:
                        '${resolveCurrencySymbol(transaction.currency)}${_amountController.text}',
                    onTap: _isSubmitting
                        ? () {}
                        : () async {
                            final amount = await showCalculatorKeypadSheet(
                              context: context,
                              initialValue: _amountController.text,
                              prefix:
                                  resolveCurrencySymbol(transaction.currency),
                            );
                            if (amount != null && mounted) {
                              setState(() {
                                _amountController.text = amount;
                                _error = null;
                              });
                            }
                          },
                  ),
                  const Divider(height: 1),
                  MonekoDisclosureRow(
                    label: 'Wallet',
                    value: walletName,
                    isLast: true,
                    isValuePlaceholder: _accountId == null,
                    onTap: _isSubmitting || wallets.isEmpty
                        ? () {}
                        : () async {
                            final selected =
                                await showTransactionSelectionSheet<
                                    WalletEntity>(
                              context: context,
                              items: wallets,
                              getLabel: (wallet) => wallet.name,
                              initial: wallets.firstWhere(
                                  (wallet) => wallet.id == _accountId),
                            );
                            if (selected != null && mounted) {
                              setState(() => _accountId = selected.id);
                            }
                          },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          MonekoInput(
            child: InkWell(
              onTap: _isSubmitting
                  ? null
                  : () async {
                      final result = await MonekoAlertDialog.show(
                        context: context,
                        title: context.l10n.notes,
                        description: null,
                        confirmLabel: context.l10n.save,
                        cancelLabel: context.l10n.cancel,
                        inputConfig: MonekoAlertDialogInputConfig(
                          initialValue: _notesController.text.trim(),
                          placeholder: context.l10n.addANote,
                          isRequired: false,
                          keyboardType: TextInputType.multiline,
                        ),
                      );
                      if (mounted &&
                          result?.confirmed == true &&
                          result?.text != null) {
                        setState(
                            () => _notesController.text = result!.text!.trim());
                      }
                    },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.notes,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _notesController.text.trim().isEmpty
                            ? context.l10n.addANote
                            : _notesController.text.trim(),
                        textAlign: TextAlign.end,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: _notesController.text.trim().isEmpty
                              ? colorScheme.onSurface.withValues(alpha: 0.4)
                              : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSettlementLocked) ...[
            const SizedBox(height: 12),
            Text(
              'This payment has settlement activity. Only notes can be edited.',
              style: TextStyle(color: colorScheme.mutedForeground),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: amountChanged
                ? CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _updateFutureAmount,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(
                            () => _updateFutureAmount = value ?? false),
                    title: const Text('Update future default amount'),
                  )
                : const SizedBox.shrink(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: ValueKey(_error),
                      style: TextStyle(color: colorScheme.destructive),
                    ),
                  ),
          ),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSubmitting
                ? (_isEditing ? 'Saving...' : 'Confirming...')
                : (_isEditing ? 'Save changes' : context.l10n.confirmPayment)),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

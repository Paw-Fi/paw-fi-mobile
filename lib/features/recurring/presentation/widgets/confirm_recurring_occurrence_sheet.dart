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
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
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
import 'package:skeletonizer/skeletonizer.dart';

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
    title: isEditing ? context.l10n.editPayment : context.l10n.confirmPayment,
    isScrollControlled: true,
    onClose: () => Navigator.of(context).pop(),
    builder: (_) => _ConfirmRecurringOccurrenceForm(
      recurringTransaction: recurringTransaction,
      scheduledOccurrenceDate: scheduledOccurrenceDate,
      existingOccurrence: existingOccurrence,
    ),
  );
}

Future<void> showLazyRecurringOccurrenceSheet({
  required BuildContext context,
  required RecurringTransaction recurringTransaction,
  required RecurringOccurrenceTimelineItem occurrence,
}) {
  final occurrenceId = occurrence.occurrenceId;
  if (!occurrence.isConfirmed || occurrenceId == null) {
    return showConfirmRecurringOccurrenceSheet(
      context: context,
      recurringTransaction: recurringTransaction,
      scheduledOccurrenceDate: occurrence.scheduledOccurrenceDate,
      existingOccurrence: occurrence,
    );
  }
  return MonekoBottomSheet.show<void>(
    context: context,
    title: context.l10n.editPayment,
    isScrollControlled: true,
    onClose: () => Navigator.of(context).pop(),
    builder: (_) => _LazyRecurringOccurrenceEditor(
      recurringTransaction: recurringTransaction,
      occurrenceId: occurrenceId,
    ),
  );
}

class _LazyRecurringOccurrenceEditor extends ConsumerWidget {
  const _LazyRecurringOccurrenceEditor({
    required this.recurringTransaction,
    required this.occurrenceId,
  });

  final RecurringTransaction recurringTransaction;
  final String occurrenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).uid;
    final query = RecurringOccurrenceDetailQuery(
      userId: userId,
      occurrenceId: occurrenceId,
    );
    final detail = ref.watch(recurringOccurrenceDetailProvider(query));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: detail.when(
        data: (value) {
          final transaction = value.transaction;
          return _ConfirmRecurringOccurrenceForm(
            key: const ValueKey('recurring-occurrence-detail'),
            recurringTransaction: recurringTransaction,
            scheduledOccurrenceDate: value.occurrence.scheduledOccurrenceDate,
            existingOccurrence: RecurringOccurrenceTimelineItem(
              occurrenceId: value.occurrence.id,
              scheduledOccurrenceDate: value.occurrence.scheduledOccurrenceDate,
              status: value.occurrence.status,
              actualTransaction: transaction == null
                  ? null
                  : ExpenseEntry.fromJson(transaction),
              paidDate: value.occurrence.paidDate,
              amountCents: value.occurrence.amountCents,
              currency: value.occurrence.currency,
              confirmedAt: value.occurrence.confirmedAt,
              confirmationSource: value.occurrence.confirmationSource,
              isSettlementLocked: value.isSettlementLocked,
              wasSkippedBeforeConfirmation:
                  value.occurrence.wasSkippedBeforeConfirmation,
            ),
          );
        },
        loading: () => const _RecurringOccurrenceEditorSkeleton(
          key: ValueKey('recurring-occurrence-detail-loading'),
        ),
        error: (_, __) => Center(
          key: const ValueKey('recurring-occurrence-detail-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: OutlinedButton(
              onPressed: () => ref.invalidate(
                recurringOccurrenceDetailProvider(query),
              ),
              child: Text(context.l10n.retry),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurringOccurrenceEditorSkeleton extends StatelessWidget {
  const _RecurringOccurrenceEditorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Bone(height: 52),
            SizedBox(height: 12),
            Bone(height: 52),
            SizedBox(height: 12),
            Bone(height: 52),
            SizedBox(height: 20),
            Bone(height: 48),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRecurringOccurrenceForm extends ConsumerStatefulWidget {
  const _ConfirmRecurringOccurrenceForm({
    super.key,
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
    _accountId = existing?.actualTransaction != null
        ? existing!.actualTransaction!.walletId
        : widget.recurringTransaction.accountId;
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
      setState(() => _error = context.l10n.recurringOccurrenceEnterAmount);
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
      setState(() => _error = context.l10n.recurringOccurrenceNotAvailable);
      return;
    }
    if (!_isSettlementLocked) {
      final walletsAsync = ref.read(walletsByCurrencyProvider(
        WalletsCurrencyQuery(
          householdId: widget.recurringTransaction.householdId,
          currency: widget.recurringTransaction.currency,
        ),
      ));
      final loadedWallets = walletsAsync.valueOrNull;
      if (loadedWallets == null) {
        setState(() => _error = walletsAsync.hasError
            ? context.l10n.recurringOccurrenceUnableToLoadWallets
            : context.l10n.recurringOccurrenceWalletsLoading);
        return;
      }
      final activeWallets = loadedWallets
          .where((wallet) => !wallet.isArchived)
          .toList(growable: false);
      if (activeWallets.isEmpty) {
        _accountId = null;
      } else if (_accountId != null &&
          !activeWallets.any((wallet) => wallet.id == _accountId)) {
        setState(() =>
            _error = context.l10n.recurringOccurrenceChooseWalletInCurrency);
        return;
      }
      if (!_isEditing &&
          activeWallets.isNotEmpty &&
          (_accountId == null || _accountId!.isEmpty)) {
        setState(() =>
            _error = context.l10n.recurringOccurrenceChooseWalletInCurrency);
        return;
      }
    }
    if (!_isSettlementLocked && _paidDate.isAfter(today)) {
      setState(
          () => _error = context.l10n.recurringOccurrencePaidDateAfterToday);
      return;
    }
    if (userId.isEmpty) {
      setState(() => _error = context.l10n.recurringOccurrenceSignInToConfirm);
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
              accountId: _accountId,
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
                ? context.l10n.recurringOccurrenceUnableToUpdate
                : context.l10n.recurringOccurrenceUnableToConfirm);
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
        _isEditing
            ? context.l10n.recurringOccurrenceUpdateSaved
            : context.l10n.recurringOccurrenceConfirmationSaved,
      );
    }
  }

  Future<void> _unconfirm() async {
    final userId = ref.read(authProvider).uid;
    final occurrence = widget.existingOccurrence;
    if (userId.isEmpty || occurrence == null) return;
    final confirmation = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.recurringOccurrenceUnconfirmQuestion,
      description: context.l10n.recurringOccurrenceUnconfirmDescription,
      confirmLabel: context.l10n.recurringOccurrenceUnconfirm,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );
    if (!mounted || confirmation?.confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await ref
        .read(recurringOccurrenceUnconfirmProvider)
        .unconfirm(RecurringOccurrenceUnconfirmCommand(
          userId: userId,
          recurringTransaction: widget.recurringTransaction,
          occurrence: occurrence,
        ));
    if (!mounted) return;
    if (!result.isQueued) {
      setState(() {
        _isSubmitting = false;
        _error =
            result.error ?? context.l10n.recurringOccurrenceUnableToUnconfirm;
      });
      return;
    }
    Navigator.of(context).pop();
    AppToast.success(context, context.l10n.recurringOccurrenceUnconfirmed);
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
    final loadedWallets = walletsAsync.valueOrNull;
    final wallets = (loadedWallets ?? const <WalletEntity>[])
        .where((wallet) => !wallet.isArchived)
        .toList(growable: false);
    final existingWalletId =
        widget.existingOccurrence?.actualTransaction?.walletId;
    if (!wallets.any((wallet) => wallet.id == _accountId) &&
        (!_isEditing || existingWalletId != null)) {
      _accountId = wallets.isEmpty ? null : wallets.first.id;
    }
    final amountChanged = !_isSettlementLocked &&
        _amountCents != null &&
        _amountCents != (transaction.amount * 100).round();
    final dateLabel = transaction.type == 'income'
        ? context.l10n.recurringOccurrenceDateReceived
        : context.l10n.recurringOccurrenceDatePaid;
    var walletName = loadedWallets == null
        ? (walletsAsync.hasError
            ? context.l10n.recurringOccurrenceWalletsUnavailable
            : context.l10n.recurringOccurrenceLoadingWallets)
        : wallets.isEmpty
            ? context.l10n.noWallet
            : _isEditing && existingWalletId == null && _accountId == null
                ? context.l10n.noWallet
                : context.l10n.recurringOccurrenceChooseWallet;
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
          GestureDetector(
            onTap: _isSubmitting || _isSettlementLocked
                ? null
                : () async {
                    final amount = await showCalculatorKeypadSheet(
                      context: context,
                      initialValue: _amountController.text,
                      prefix: resolveCurrencySymbol(transaction.currency),
                    );
                    if (amount != null && mounted) {
                      setState(() {
                        _amountController.text = amount;
                        _error = null;
                      });
                    }
                  },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    '${resolveCurrencySymbol(transaction.currency)}${_amountController.text}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      letterSpacing: 0,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSettlementLocked
                        ? context.l10n.recurringOccurrenceActualAmount
                        : context.l10n.tapToEditAmount,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MonekoInput(
            child: _ReadOnlyRow(
              label: context.l10n.recurringOccurrenceScheduledDate,
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
                    label: dateLabel,
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
                    label: context.l10n.wallet,
                    value: walletName,
                    isLast: true,
                    isValuePlaceholder: _accountId == null,
                    onTap: _isSubmitting || wallets.isEmpty
                        ? null
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
              context.l10n.recurringOccurrenceSettlementLocked,
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
                    title: Text(
                        context.l10n.recurringOccurrenceUpdateFutureAmount),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(
            height: 18,
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
                ? (_isEditing
                    ? context.l10n.saving
                    : context.l10n.recurringOccurrenceConfirming)
                : (_isEditing
                    ? context.l10n.saveChanges
                    : context.l10n.confirmPayment)),
          ),
          if (_isEditing && !_isSettlementLocked) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _unconfirm,
              child: Text(context.l10n.recurringOccurrenceUnconfirmPayment),
            ),
          ],
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

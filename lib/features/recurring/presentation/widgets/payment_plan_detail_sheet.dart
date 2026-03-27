import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/recurring/domain/models/payment_plan.dart';
import 'package:moneko/features/recurring/presentation/providers/payment_plan_providers.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';

Future<void> showPaymentPlanDetailSheet(
  BuildContext context, {
  required ScheduledListItemDto item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: Theme.of(context).colorScheme.sheetBorder),
    ),
    builder: (_) => PaymentPlanDetailSheet(item: item),
  );
}

class PaymentPlanDetailSheet extends ConsumerStatefulWidget {
  const PaymentPlanDetailSheet({
    super.key,
    required this.item,
  });

  final ScheduledListItemDto item;

  @override
  ConsumerState<PaymentPlanDetailSheet> createState() =>
      _PaymentPlanDetailSheetState();
}

class _PaymentPlanDetailSheetState
    extends ConsumerState<PaymentPlanDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(paymentPlanDetailProvider(widget.item.id));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: detailAsync.when(
          data: (detail) => _buildContent(context, colorScheme, detail),
          loading: () => SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          ),
          error: (error, _) => SizedBox(
            height: 320,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load plan details',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                const SizedBox(height: 16),
                AdaptiveButton(
                  onPressed: () => ref.invalidate(
                    paymentPlanDetailProvider(widget.item.id),
                  ),
                  label: context.l10n.retry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    PaymentPlanDetailDto detail,
  ) {
    final nextPending = _findNextPendingOccurrence(detail.occurrences);
    final plan = detail.plan;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.muted,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.item.title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.item.paymentPlanType == PaymentPlanType.installment
              ? 'Installment plan'
              : context.l10n.recurring,
          style: TextStyle(
            color: colorScheme.mutedForeground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        _SummaryCard(detail: detail),
        const SizedBox(height: 20),
        if (widget.item.paymentPlanType == PaymentPlanType.installment)
          _ActionSection(
            onMarkPaid: nextPending == null
                ? null
                : () => _markOccurrencePaid(nextPending, detail),
            onPartialPay: nextPending == null
                ? null
                : () => _recordPartialPayment(nextPending, detail),
            onSkip: nextPending == null ? null : () => _skipInstallment(detail),
            onPayoff: (plan.remainingBalanceCents ?? 0) <= 0
                ? null
                : () => _payoffPlan(detail),
            onCancel: () => _cancelPlan(detail),
          ),
        if (widget.item.paymentPlanType == PaymentPlanType.installment)
          const SizedBox(height: 20),
        Text(
          'Schedule',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: detail.occurrences.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final occurrence = detail.occurrences[index];
              return _OccurrenceTile(occurrence: occurrence);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _skipInstallment(PaymentPlanDetailDto detail) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: 'Skip next installment',
      description: 'This will defer the next unpaid installment to the end.',
      confirmLabel: context.l10n.confirm,
      cancelLabel: context.l10n.cancel,
      inputConfig: const MonekoAlertDialogInputConfig(
        placeholder: 'Optional reason',
      ),
    );
    if (result == null || !result.confirmed) return;
    if (!mounted) return;

    await _runMutation(
      loadingMessage: 'Skipping installment...',
      mutation: () =>
          ref.read(paymentPlanMutationProvider.notifier).skipInstallment(
                userId: ref.read(authProvider).uid,
                planId: detail.plan.id,
                reason: result.text?.trim().isEmpty == true
                    ? null
                    : result.text?.trim(),
                householdId: widget.item.householdId,
              ),
      successMessage: 'Installment deferred',
    );
  }

  Future<void> _markOccurrencePaid(
    PaymentPlanOccurrenceDto occurrence,
    PaymentPlanDetailDto detail,
  ) async {
    await _runMutation(
      loadingMessage: 'Recording payment...',
      mutation: () => ref.read(paymentPlanMutationProvider.notifier).markPaid(
            userId: ref.read(authProvider).uid,
            planId: detail.plan.id,
            occurrenceId: occurrence.id,
            amountCents: occurrence.remainingAmountCents,
            paymentDate: _todayString(),
            householdId: widget.item.householdId,
          ),
      successMessage: 'Payment recorded',
    );
  }

  Future<void> _recordPartialPayment(
    PaymentPlanOccurrenceDto occurrence,
    PaymentPlanDetailDto detail,
  ) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: 'Record partial payment',
      description: 'Enter an amount less than the remaining balance.',
      confirmLabel: context.l10n.confirm,
      cancelLabel: context.l10n.cancel,
      inputConfig: const MonekoAlertDialogInputConfig(
        placeholder: 'Amount',
        isRequired: true,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
      secondaryInputConfig: const MonekoAlertDialogInputConfig(
        placeholder: 'Optional note',
      ),
    );
    if (result == null || !result.confirmed) return;
    if (!mounted) return;

    final amount = double.tryParse((result.text ?? '').trim());
    if (amount == null || amount <= 0) {
      AppToast.error(context, 'Please enter a valid amount');
      return;
    }

    final amountCents = (amount * 100).round();
    if (amountCents >= occurrence.remainingAmountCents) {
      AppToast.error(
          context, 'Partial payment must be less than remaining balance');
      return;
    }

    await _runMutation(
      loadingMessage: 'Recording partial payment...',
      mutation: () =>
          ref.read(paymentPlanMutationProvider.notifier).markPartiallyPaid(
                userId: ref.read(authProvider).uid,
                planId: detail.plan.id,
                occurrenceId: occurrence.id,
                amountCents: amountCents,
                paymentDate: _todayString(),
                notes: result.secondaryText?.trim().isEmpty == true
                    ? null
                    : result.secondaryText?.trim(),
                householdId: widget.item.householdId,
              ),
      successMessage: 'Partial payment recorded',
    );
  }

  Future<void> _payoffPlan(PaymentPlanDetailDto detail) async {
    final remaining = detail.plan.remainingBalanceCents ?? 0;
    final result = await MonekoAlertDialog.show(
      context: context,
      title: 'Pay off remaining balance',
      description:
          'This will settle the remaining balance of ${(remaining / 100).toStringAsFixed(2)} ${detail.plan.currency}.',
      confirmLabel: context.l10n.confirm,
      cancelLabel: context.l10n.cancel,
      inputConfig: const MonekoAlertDialogInputConfig(
        placeholder: 'Optional note',
      ),
    );
    if (result == null || !result.confirmed) return;
    if (!mounted) return;

    await _runMutation(
      loadingMessage: 'Paying off remaining balance...',
      mutation: () =>
          ref.read(paymentPlanMutationProvider.notifier).earlyPayoff(
                userId: ref.read(authProvider).uid,
                planId: detail.plan.id,
                amountCents: remaining,
                paymentDate: _todayString(),
                notes: result.text?.trim().isEmpty == true
                    ? null
                    : result.text?.trim(),
                householdId: widget.item.householdId,
              ),
      successMessage: 'Remaining balance settled',
    );
  }

  Future<void> _cancelPlan(PaymentPlanDetailDto detail) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: 'Cancel payment plan',
      description:
          'Future unpaid installments will be cancelled, but history stays visible.',
      confirmLabel: context.l10n.cancel,
      cancelLabel: context.l10n.no,
      inputConfig: const MonekoAlertDialogInputConfig(
        placeholder: 'Optional reason',
      ),
      isDestructive: true,
    );
    if (result == null || !result.confirmed) return;
    if (!mounted) return;

    await _runMutation(
      loadingMessage: 'Cancelling payment plan...',
      mutation: () => ref.read(paymentPlanMutationProvider.notifier).cancelPlan(
            userId: ref.read(authProvider).uid,
            planId: detail.plan.id,
            reason: result.text?.trim().isEmpty == true
                ? null
                : result.text?.trim(),
            householdId: widget.item.householdId,
          ),
      successMessage: 'Payment plan cancelled',
    );
  }

  Future<void> _runMutation({
    required Future<Map<String, dynamic>?> Function() mutation,
    required String loadingMessage,
    required String successMessage,
  }) async {
    final userId = ref.read(authProvider).uid;
    if (userId.isEmpty) {
      AppToast.error(context, context.l10n.userNotAuthenticated);
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    var dialogOpen = false;

    showBlockingProcessingDialog(
      context: toastContext,
      message: loadingMessage,
    );
    dialogOpen = true;

    void closeDialog() {
      if (!dialogOpen) return;
      if (rootNavigator.canPop()) rootNavigator.pop();
      dialogOpen = false;
    }

    try {
      final response = await mutation();
      closeDialog();
      if (response == null) {
        final error = ref.read(paymentPlanMutationProvider).error;
        if (!toastContext.mounted) return;
        AppToast.error(toastContext, error ?? 'Action failed');
        return;
      }

      if (!toastContext.mounted) return;
      AppToast.success(toastContext, successMessage);
    } catch (error) {
      closeDialog();
      if (!toastContext.mounted) return;
      AppToast.error(toastContext, error.toString());
    } finally {
      closeDialog();
    }
  }

  PaymentPlanOccurrenceDto? _findNextPendingOccurrence(
    List<PaymentPlanOccurrenceDto> occurrences,
  ) {
    final pending = occurrences
        .where(
          (occurrence) =>
              occurrence.status == PaymentOccurrenceStatus.scheduled ||
              occurrence.status == PaymentOccurrenceStatus.overdue ||
              occurrence.status == PaymentOccurrenceStatus.partiallyPaid,
        )
        .toList(growable: false)
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return pending.isEmpty ? null : pending.first;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});

  final PaymentPlanDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plan = detail.plan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.paymentPlanType == PaymentPlanType.installment) ...[
            _SummaryRow(
              label: 'Remaining balance',
              value:
                  '${((plan.remainingBalanceCents ?? 0) / 100).toStringAsFixed(2)} ${plan.currency}',
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Installments',
              value:
                  '${plan.paidInstallmentsCount ?? 0}/${plan.installmentCount ?? detail.occurrences.length}',
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Status',
              value: plan.planStatus.name,
            ),
          ] else ...[
            _SummaryRow(label: 'Status', value: plan.planStatus.name),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Frequency',
              value: plan.recurrenceRule.frequency,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.mutedForeground,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    this.onMarkPaid,
    this.onPartialPay,
    this.onSkip,
    this.onPayoff,
    this.onCancel,
  });

  final VoidCallback? onMarkPaid;
  final VoidCallback? onPartialPay;
  final VoidCallback? onSkip;
  final VoidCallback? onPayoff;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionButton(label: 'Mark paid', onPressed: onMarkPaid),
        _ActionButton(label: 'Partial payment', onPressed: onPartialPay),
        _ActionButton(label: 'Skip next', onPressed: onSkip),
        _ActionButton(label: 'Pay off remaining', onPressed: onPayoff),
        _ActionButton(
            label: 'Cancel plan', onPressed: onCancel, destructive: true),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: destructive
          ? DestructiveAdaptiveButton(
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedAdaptiveButton(
              onPressed: onPressed,
              child: Text(label, textAlign: TextAlign.center),
            ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence});

  final PaymentPlanOccurrenceDto occurrence;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installment ${occurrence.occurrenceNumber}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatLocalizedDate(context, occurrence.scheduledDate),
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (occurrence.dueAmountCents / 100).toStringAsFixed(2),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                occurrence.status.name,
                style: TextStyle(
                  color: _statusColor(colorScheme, occurrence.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ColorScheme colorScheme, PaymentOccurrenceStatus status) {
    switch (status) {
      case PaymentOccurrenceStatus.paid:
      case PaymentOccurrenceStatus.settledEarly:
        return colorScheme.success;
      case PaymentOccurrenceStatus.skipped:
      case PaymentOccurrenceStatus.cancelled:
        return colorScheme.mutedForeground;
      case PaymentOccurrenceStatus.overdue:
        return colorScheme.destructive;
      case PaymentOccurrenceStatus.partiallyPaid:
        return colorScheme.primary;
      case PaymentOccurrenceStatus.scheduled:
        return colorScheme.onSurfaceVariant;
    }
  }
}

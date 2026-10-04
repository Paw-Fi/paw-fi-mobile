import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class PocketsPlanReviewBanner extends HookWidget {
  const PocketsPlanReviewBanner({
    super.key,
    required this.reviews,
    required this.prepare,
    required this.resolve,
  });

  final List<LocalMutationOutboxData> reviews;
  final Future<PocketsState> Function(LocalMutationOutboxData) prepare;
  final Future<void> Function(LocalMutationOutboxData, bool reapply) resolve;

  @override
  Widget build(BuildContext context) {
    final busy = useState<String?>(null);
    final colors = Theme.of(context).colorScheme;

    Future<void> review(LocalMutationOutboxData row, bool discard) async {
      busy.value = row.clientMutationId;
      try {
        final payload = jsonDecode(row.payloadJson) as Map;
        final currency = payload['currency'] as String;
        String money(num value) =>
            '$currency ${formatLocalizedNumber(context, value)}';
        final pendingBudget = (payload['totalBudgetCents'] as num) / 100;
        final pendingPockets = (payload['pockets'] as List).cast<Map>();
        final current = discard ? null : await prepare(row);
        if (!context.mounted) return;
        final result = await MonekoAlertDialog.show(
          context: context,
          title: context.l10n.pocketPlanNeedsReview,
          description: [
            discard
                ? context.l10n.pocketPlanDiscardDescription
                : context.l10n.pocketPlanReviewDescription,
            '',
            if (current != null) ...[
              '${context.l10n.pocketPlanCurrent}: ${money(current.savedTotalBudget)}',
              for (final pocket in current.saved)
                '${pocket.name}: ${money(pocket.baseBudget)}',
              '',
            ],
            '${context.l10n.pocketPlanSaved}: ${money(pendingBudget)}',
            for (final pocket in pendingPockets)
              '${pocket['name']}: ${money((pocket['budgetAmountCents'] as num) / 100)}',
          ].join('\n'),
          confirmLabel: discard
              ? context.l10n.pocketPlanDiscard
              : context.l10n.pocketPlanReapply,
          isDestructive: discard,
        );
        if (result?.confirmed != true || !context.mounted) return;
        await resolve(row, !discard);
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      } finally {
        if (context.mounted) busy.value = null;
      }
    }

    return AnimatedSize(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: reviews.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.pocketPlanNeedsReview,
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final row in reviews)
                      Wrap(
                        spacing: 12,
                        children: [
                          AdaptiveButton.child(
                            onPressed: busy.value != null
                                ? null
                                : () => review(row, false),
                            child: Text(
                                '${context.l10n.needsReview} ${(jsonDecode(row.payloadJson) as Map)['currency']}'),
                          ),
                          AdaptiveButton.child(
                            onPressed: busy.value != null
                                ? null
                                : () => review(row, true),
                            child: Text(context.l10n.pocketPlanDiscard),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

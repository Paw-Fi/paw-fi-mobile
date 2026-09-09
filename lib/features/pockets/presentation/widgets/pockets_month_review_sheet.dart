import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_month_review.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/subtle_adaptive_button.dart';

class PocketsMonthReviewSheet extends HookConsumerWidget {
  const PocketsMonthReviewSheet({
    super.key,
    required this.scopeParams,
    this.reviewCurrency,
  });

  final PocketsScopeParams scopeParams;
  final String? reviewCurrency;

  static Future<void> show({
    required BuildContext context,
    required PocketsScopeParams scopeParams,
    String? reviewCurrency,
  }) =>
      MonekoBottomSheet.show<void>(
        context: context,
        title: context.l10n.pocketsMonthReviewTitle,
        isScrollControlled: true,
        onClose: () => Navigator.of(context).pop(),
        builder: (_) => PocketsMonthReviewSheet(
          scopeParams: scopeParams,
          reviewCurrency: reviewCurrency,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final review =
        state.monthReviewsByCurrency[reviewCurrency?.toUpperCase()] ??
            state.monthReview;
    if (review == null ||
        (!review.isOutstanding && !review.isPendingConfirmation)) {
      return const SizedBox.shrink();
    }
    final initialDraft = state.monthReviewDraftAllocationsCentsByReviewKey[
            pocketsMonthReviewDraftKey(review)] ??
        {
          for (final suggestion in review.suggestions)
            suggestion.lineageId: suggestion.amountCents,
        };
    final draft = useState<Map<String, int>>(initialDraft);
    final isSubmitting = useState(false);
    final aiReview = useState<PocketsMonthAiReview?>(null);
    final isGeneratingAi = useState(false);
    final validation = validatePocketsMonthReviewDraft(
      review: review,
      allocationsCentsByEnvelopeId: draft.value,
    );
    final remainingCents = review.draftBudgetCents - validation.allocatedCents;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = review.currency.isEmpty ? state.currency : review.currency;
    final previousCycleAmounts = _lastCycleAmounts(review);

    Future<void> persistDraft() =>
        ref.read(pocketsProvider(scopeParams).notifier).saveMonthReviewDraft(
              draft.value,
              currency: review.currency,
            );

    Future<void> generateAiReview() async {
      if (isGeneratingAi.value) return;
      isGeneratingAi.value = true;
      final subscription = ref.read(subscriptionNotifierProvider);
      final isConfirmedFree = subscription.hasValue &&
          !hasPremiumFeatureAccess(subscription.valueOrNull);
      if (isConfirmedFree) {
        isGeneratingAi.value = false;
        await PlusLockedSheet.show(
          context,
          highlightedFeature: PlusFeature.aiMonthlyBudgetReview,
        );
        return;
      }
      try {
        aiReview.value = await ref.refresh(
          pocketsMonthAiReviewProvider(
            PocketsMonthAiReviewRequest(
              scopeParams: scopeParams,
              currency: currency,
            ),
          ).future,
        );
      } catch (error) {
        if (context.mounted) {
          if (ErrorHandler.isPlusFeatureLimitError(error)) {
            await PlusLockedSheet.show(
              context,
              highlightedFeature: PlusFeature.aiMonthlyBudgetReview,
            );
            return;
          }
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      } finally {
        if (context.mounted) isGeneratingAi.value = false;
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.pocketsMonthReviewHeading(
                  _financialCycleLabel(
                    context,
                    state.periodMonth,
                    state.financialMonthStartDay,
                  ),
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.pocketsMonthReviewDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
              ),
              if (review.hasHouseholdConflict) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.pocketsMonthReviewHouseholdConflict,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.warning,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              _ReviewSummary(
                currency: currency,
                monthlyBudgetCents: review.monthlyBudgetCents,
                allocatedCents: validation.allocatedCents,
                remainingCents: remainingCents,
                carryCents: review.carryCents,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: review.isPendingConfirmation
                        ? null
                        : () => draft.value = {
                              for (final suggestion in review.suggestions)
                                suggestion.lineageId: suggestion.amountCents,
                            },
                    child: Text(context.l10n.pocketsMonthReviewUseSuggested),
                  ),
                  if (previousCycleAmounts.isNotEmpty)
                    TextButton(
                      onPressed: review.isPendingConfirmation
                          ? null
                          : () => draft.value = {
                                for (final suggestion in review.suggestions)
                                  suggestion.lineageId: previousCycleAmounts[
                                          suggestion.lineageId] ??
                                      suggestion.amountCents,
                              },
                      child: Text(context.l10n.pocketsMonthReviewUseLastCycle),
                    ),
                  TextButton(
                    onPressed: review.isPendingConfirmation
                        ? null
                        : () => draft.value = {
                              for (final suggestion in review.suggestions)
                                suggestion.lineageId: 0,
                            },
                    child: Text(context.l10n.pocketsMonthReviewClearAmounts),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SubtleAdaptiveButton(
                label: isGeneratingAi.value
                    ? context.l10n.pocketsMonthReviewGeneratingAi
                    : context.l10n.pocketsMonthReviewGenerateAi,
                onPressed: isGeneratingAi.value ? null : generateAiReview,
              ),
              if (aiReview.value?.review != null) ...[
                const SizedBox(height: 12),
                _AiReviewCard(review: aiReview.value!.review!),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: review.suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final suggestion = review.suggestions[index];
                    final explanation =
                        aiReview.value?.review?.pocketExplanations.firstWhere(
                      (item) => item.lineageId == suggestion.lineageId,
                      orElse: () => const PocketsMonthAiPocketExplanation(
                        lineageId: '',
                        text: '',
                        factIds: [],
                      ),
                    );
                    return PocketsMonthReviewSuggestionField(
                      key: ValueKey(suggestion.lineageId),
                      suggestion: suggestion,
                      currency: currency,
                      valueCents: draft.value[suggestion.lineageId] ?? 0,
                      aiExplanation: explanation?.text.isEmpty == true
                          ? null
                          : explanation?.text,
                      onChanged: (value) {
                        draft.value = {
                          ...draft.value,
                          suggestion.lineageId: value,
                        };
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: context.l10n.pocketsMonthReviewSaveDraftSemantics,
                child: SubtleAdaptiveButton(
                  label: context.l10n.pocketsMonthReviewSaveDraft,
                  onPressed: review.isPendingConfirmation
                      ? null
                      : () async {
                          try {
                            await persistDraft();
                            if (context.mounted) {
                              AppToast.success(
                                context,
                                context.l10n.pocketsMonthReviewDraftSaved,
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              AppToast.error(
                                context,
                                ErrorHandler.getUserFriendlyMessage(error),
                              );
                            }
                          }
                        },
                ),
              ),
              if (remainingCents > 0) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.pocketsMonthReviewUnassignedDescription(
                    formatCurrency(remainingCents / 100, currency),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: context.l10n.pocketsMonthReviewConfirmSemantics,
                child: PrimaryAdaptiveButton(
                  onPressed: review.isOutstanding &&
                          review.canEdit &&
                          validation.isValid &&
                          !isSubmitting.value
                      ? () async {
                          isSubmitting.value = true;
                          try {
                            await persistDraft();
                            await ref
                                .read(pocketsProvider(scopeParams).notifier)
                                .confirmMonthReviewSetup(
                                  draft.value,
                                  currency: review.currency,
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (error) {
                            if (context.mounted) {
                              AppToast.error(
                                context,
                                ErrorHandler.getUserFriendlyMessage(error),
                              );
                            }
                          } finally {
                            if (context.mounted) isSubmitting.value = false;
                          }
                        }
                      : null,
                  child: Text(review.isPendingConfirmation || isSubmitting.value
                      ? context.l10n.pocketsMonthReviewConfirming
                      : context.l10n.pocketsMonthReviewConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.currency,
    required this.monthlyBudgetCents,
    required this.allocatedCents,
    required this.remainingCents,
    required this.carryCents,
  });

  final String currency;
  final int monthlyBudgetCents;
  final int allocatedCents;
  final int remainingCents;
  final int carryCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.sheetBorder),
      ),
      child: Column(
        children: [
          _AmountRow(
            label: context.l10n.pocketsMonthReviewMonthlyBudget,
            amountCents: monthlyBudgetCents,
            currency: currency,
          ),
          const SizedBox(height: 8),
          _AmountRow(
              label: context.l10n.pocketsMonthReviewAddedToPockets,
              amountCents: allocatedCents,
              currency: currency),
          const SizedBox(height: 8),
          _AmountRow(
              label: context.l10n.pocketsMonthReviewRemaining,
              amountCents: remainingCents,
              currency: currency),
          const SizedBox(height: 8),
          _AmountRow(
              label: context.l10n.pocketsMonthReviewCarry,
              amountCents: carryCents,
              currency: currency),
          const SizedBox(height: 10),
          Text(
            context.l10n.pocketsMonthReviewCarryDescription,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _AiReviewCard extends StatelessWidget {
  const _AiReviewCard({required this.review});

  final PocketsMonthAiReviewContent review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.infoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review.headline.text,
              style: TextStyle(color: scheme.foreground)),
          if (review.celebration.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.celebration.text,
                style: TextStyle(color: scheme.foreground)),
          ],
          if (review.previousCycleSummary.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.previousCycleSummary.text,
                style: TextStyle(color: scheme.foreground)),
          ],
          ...review.attentionItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(item.text, style: TextStyle(color: scheme.foreground)),
            ),
          ),
          ...review.recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(item.text, style: TextStyle(color: scheme.foreground)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amountCents,
    required this.currency,
  });

  final String label;
  final int amountCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
            child:
                Text(label, style: TextStyle(color: scheme.mutedForeground))),
        Text(
          formatCurrency(amountCents / 100, currency),
          style:
              TextStyle(color: scheme.foreground, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class PocketsMonthReviewSuggestionField extends StatelessWidget {
  const PocketsMonthReviewSuggestionField({
    super.key,
    required this.suggestion,
    required this.currency,
    required this.valueCents,
    required this.onChanged,
    this.aiExplanation,
  });

  final PocketsMonthReviewSuggestion suggestion;
  final String currency;
  final int valueCents;
  final ValueChanged<int> onChanged;
  final String? aiExplanation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = suggestion.label.isEmpty
        ? context.l10n.pocketsMonthReviewPocket
        : suggestion.label;
    final availableCents = valueCents + suggestion.incomingCarryCents;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.sheetBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackEditor = constraints.maxWidth < 380 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final details = _SuggestionDetails(
            suggestion: suggestion,
            currency: currency,
            label: label,
            availableCents: availableCents,
          );
          final editor = _AllocationEditor(
            label: label,
            currency: currency,
            lineageId: suggestion.lineageId,
            valueCents: valueCents,
            onChanged: onChanged,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackEditor) ...[
                details,
                const SizedBox(height: 12),
                editor,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    SizedBox(width: 112, child: editor),
                  ],
                ),
              AnimatedSwitcher(
                duration: animationDuration,
                child: aiExplanation?.isNotEmpty == true
                    ? Padding(
                        key: ValueKey(aiExplanation),
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          aiExplanation!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.mutedForeground,
                                  ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('no-ai-explanation'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SuggestionDetails extends StatelessWidget {
  const _SuggestionDetails({
    required this.suggestion,
    required this.currency,
    required this.label,
    required this.availableCents,
  });

  final PocketsMonthReviewSuggestion suggestion;
  final String currency;
  final String label;
  final int availableCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        _ReviewFact(
          label: context.l10n.pocketsMonthReviewSuggestedAmount,
          value: formatCurrency(suggestion.amountCents / 100, currency),
        ),
        _ReviewFact(
          label: context.l10n.pocketsMonthReviewCarriedFromLastCycle,
          value: formatCurrency(suggestion.incomingCarryCents / 100, currency),
        ),
        _ReviewFact(
          label: context.l10n.pocketsMonthReviewAvailable,
          value: formatCurrency(availableCents / 100, currency),
        ),
        const SizedBox(height: 4),
        Text(
          _suggestionReason(context, suggestion.fundingPolicy),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.mutedForeground),
        ),
      ],
    );
  }
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text(
        context.l10n.pocketsMonthReviewAmountFact(label, value),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
      );
}

class _AllocationEditor extends StatelessWidget {
  const _AllocationEditor({
    required this.label,
    required this.currency,
    required this.lineageId,
    required this.valueCents,
    required this.onChanged,
  });

  final String label;
  final String currency;
  final String lineageId;
  final int valueCents;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.pocketsMonthReviewAllocationSemantics(label),
        textField: true,
        child: TextFormField(
          key: ValueKey('$lineageId-$valueCents'),
          initialValue: (valueCents / 100).toStringAsFixed(2),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          decoration: InputDecoration(
            labelText: context.l10n.pocketsMonthReviewAddedThisCycle,
            prefixText: '${resolveCurrencySymbol(currency)} ',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value.replaceAll(',', '.')) ?? 0;
            if (!amount.isFinite || amount < 0) {
              onChanged(0);
              return;
            }
            final cents = amount * 100;
            onChanged(
                cents > 9007199254740991 ? 9007199254740991 : cents.round());
          },
        ),
      );
}

String _financialCycleLabel(
  BuildContext context,
  DateTime periodMonth,
  int financialMonthStartDay,
) {
  final cycle = financialCycleForMonth(
    periodMonth,
    startDay: financialMonthStartDay,
  );
  return '${formatLocalizedDate(context, cycle.start, includeYear: true)} - '
      '${formatLocalizedDate(context, cycle.end, includeYear: true)}';
}

String _suggestionReason(BuildContext context, String fundingPolicy) =>
    switch (fundingPolicy) {
      'refill_to' => context.l10n.pocketsMonthReviewRefillReason,
      'add_every_cycle' => context.l10n.pocketsMonthReviewRepeatReason,
      'decide_each_cycle' => context.l10n.pocketsMonthReviewLastCycleReason,
      _ => context.l10n.pocketsMonthReviewSuggestionReason,
    };

Map<String, int> _lastCycleAmounts(PocketsMonthReview review) {
  const allocationKeys = [
    'last_cycle_allocations',
    'previous_allocations',
    'last_confirmed_allocations',
  ];
  for (final key in allocationKeys) {
    final allocations = review.facts[key];
    if (allocations is! List) continue;
    final amounts = <String, int>{};
    for (final allocation in allocations.whereType<Map>()) {
      final lineageId = allocation['lineage_id']?.toString() ?? '';
      final amount = allocation['amount_cents'];
      if (lineageId.isNotEmpty && amount is num) {
        amounts[lineageId] = amount.round();
      }
    }
    if (amounts.isNotEmpty) return amounts;
  }
  return const {};
}

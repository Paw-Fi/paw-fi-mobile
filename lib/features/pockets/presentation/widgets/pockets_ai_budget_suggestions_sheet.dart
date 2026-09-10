import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_ai_budget_suggestions.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class PocketsAiBudgetSuggestionsBanner extends ConsumerWidget {
  const PocketsAiBudgetSuggestionsBanner({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.pocketsAiSuggestionsTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.pocketsAiSuggestionsSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.mutedForeground,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryAdaptiveButton(
              onPressed: () async {
                final hasAccess = await PlusLockedSheet.ensureAccess(
                  context,
                  ref,
                  feature: PlusFeature.aiMonthlyBudgetSuggestions,
                );
                if (!hasAccess || !context.mounted) return;
                await PocketsAiBudgetSuggestionsSheet.show(
                  context: context,
                  scopeParams: scopeParams,
                  currency: currency,
                );
              },
              prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
              child: Text(context.l10n.pocketsAiSuggestionsAction),
            ),
          ),
        ],
      ),
    );
  }
}

class PocketsAiBudgetSuggestionsSheet extends HookConsumerWidget {
  const PocketsAiBudgetSuggestionsSheet({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  static Future<void> show({
    required BuildContext context,
    required PocketsScopeParams scopeParams,
    required String currency,
  }) =>
      MonekoBottomSheet.show<void>(
        context: context,
        title: context.l10n.pocketsAiSuggestionsTitle,
        isScrollControlled: true,
        onClose: () => Navigator.of(context).pop(),
        builder: (_) => PocketsAiBudgetSuggestionsSheet(
          scopeParams: scopeParams,
          currency: currency,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = useMemoized(
      () => PocketsAiBudgetSuggestionsRequest(
        scopeParams: scopeParams,
        currency: currency,
      ),
      [scopeParams, currency],
    );
    final result = ref.watch(pocketsAiBudgetSuggestionsProvider(request));
    final pockets = ref.watch(pocketsProvider(scopeParams)).editing;
    final pocketNames = {for (final pocket in pockets) pocket.id: pocket.name};
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: result.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (error, _) => _SuggestionError(
            onRetry: () =>
                ref.invalidate(pocketsAiBudgetSuggestionsProvider(request)),
          ),
          data: (suggestions) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestions.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
              ),
              if (suggestions.isFallback) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.pocketsAiSuggestionsFallback,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = suggestions.suggestions[index];
                    final amount = item.amountCents / 100;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pocketNames[item.envelopeId] ??
                                      context.l10n
                                          .pocketsAiSuggestionsUnknownPocket,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: colorScheme.foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Text(
                                '${resolveCurrencySymbol(currency)}${formatLocalizedNumber(context, amount)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.reason,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.mutedForeground,
                                    ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.pocketsAiSuggestionsManualNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionError extends StatelessWidget {
  const _SuggestionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, color: colorScheme.mutedForeground),
          const SizedBox(height: 12),
          Text(
            context.l10n.pocketsAiSuggestionsUnavailable,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.mutedForeground,
                ),
          ),
          const SizedBox(height: 14),
          PrimaryAdaptiveButton(
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}

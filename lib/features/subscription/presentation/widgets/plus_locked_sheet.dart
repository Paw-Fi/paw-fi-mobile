import 'dart:ui';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/paywall_plan_selection.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/widgets/unified_plan_card.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

String formatPlusYearlyMonthlyEquivalent(double yearlyPrice) {
  final monthlyPrice = yearlyPrice / 12;
  return r'$' + monthlyPrice.toStringAsFixed(2);
}

const _plusLockedInAppAiExpenseLogging = 'In-app AI expense logging';
const _plusLockedHealthDetails = 'Health report details';
const _plusLockedAiScenarios = 'AI scenarios';
const _plusLockedWallets = 'Wallets';

class PlusLockedSheet extends HookConsumerWidget {
  const PlusLockedSheet({super.key});

  static const bool _forceUseStripeCheckout = false;

  static Future<void> show(BuildContext context) {
    return MonekoBottomSheet.show(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.sheetBackground,
      builder: (context) => const PlusLockedSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final subscription = ref.watch(subscriptionNotifierProvider).valueOrNull;
    final subscriptionDetailsAsync = ref.watch(subscriptionManagementProvider);
    final productsAsync = ref.watch(subscriptionProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final content = _LockedSheetContent.resolve(context, subscription);
    final currentSubscription = subscriptionDetailsAsync.valueOrNull?.subscription;
    final currentPlanId = currentSubscription?.plan ?? 'free';
    final currentInterval = currentSubscription?.billingInterval;
    final currentStatus = currentSubscription?.status?.toLowerCase();
    final selectedPlanId = useState<String?>(null);
    final isCheckoutProcessing = useState(false);

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final useIap = isIos && !_forceUseStripeCheckout;
    final plans = buildPlusPlanOptions(
      context: context,
      useIap: useIap,
      productsAsync: productsAsync,
      iapStateAsync: iapStateAsync,
    );
    final visiblePlans =
        plans.where((plan) => plan.serverPlanId == 'plus').toList();
    final isStoreReady = !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);

    useEffect(() {
      if (visiblePlans.isEmpty) {
        selectedPlanId.value = null;
        return null;
      }

      final nextSelection = selectPaywallPlanId(
        currentPlanId: currentPlanId,
        currentInterval: currentInterval,
        plans: visiblePlans,
        currentSelection: selectedPlanId.value,
        preferredPlanId: 'plus',
        preferredBillingInterval: 'yearly',
      );
      if (nextSelection != selectedPlanId.value) {
        selectedPlanId.value = nextSelection;
      }
      return null;
    }, [
      currentPlanId,
      currentInterval,
      visiblePlans.length,
    ]);

    PlanOption? activePlanOption;
    for (final option in visiblePlans) {
      if (option.id == selectedPlanId.value) {
        activePlanOption = option;
        break;
      }
    }

    final effectiveActivePlanOption =
        activePlanOption ?? (visiblePlans.isNotEmpty ? visiblePlans.first : null);

    bool isCurrentPlan(PlanOption option) {
      final shouldBlockSamePlan =
          (currentSubscription?.isSubscribed ?? false) && currentStatus == 'active';
      if (!shouldBlockSamePlan) {
        return false;
      }
      return subscriptionMatchesPlanOption(currentSubscription, option);
    }

    Future<void> onCheckoutPressed() async {
      final selectedOption = effectiveActivePlanOption;
      if (selectedOption == null || isCheckoutProcessing.value) {
        return;
      }

      if (isCurrentPlan(selectedOption)) {
        AppToast.info(context, context.l10n.alreadyOnThisPlan);
        return;
      }

      isCheckoutProcessing.value = true;
      try {
        if (useIap) {
          final iapState = iapStateAsync.valueOrNull;
          if (iapState == null || !iapState.storeAvailable) {
            throw Exception(context.l10n.paywallErrorStoreUnavailableShort);
          }

          final catalog = selectedOption.catalogProduct;
          if (catalog == null) {
            throw Exception(context.l10n.paywallErrorMissingProductMapping);
          }

          await ref.read(iapControllerProvider.notifier).buy(catalog);

          final isActivated = await waitForMobileStripeSubscriptionActivation(
            refreshSubscription: () async {
              await ref.read(subscriptionManagementProvider.notifier).refresh();
            },
            hasActiveSubscription: () {
              final latestSubscription = ref
                  .read(subscriptionManagementProvider)
                  .valueOrNull
                  ?.subscription;
              return subscriptionMatchesPlanOption(latestSubscription, selectedOption);
            },
          );

          if (!context.mounted) return;
          if (!isActivated) {
            throw Exception(context.l10n.paywallErrorNotActivated);
          }
        } else {
          await startStripeCheckoutForOption(
            context: context,
            option: selectedOption,
            supabaseClient: supabase,
            noSessionError: context.l10n.paywallErrorNoSession,
            startCheckoutError: context.l10n.paywallErrorStartCheckout,
            noCheckoutUrlError: context.l10n.paywallErrorNoCheckoutUrl,
            paymentCanceledMessage: context.l10n.paymentCanceled,
            paymentFailedMessage: context.l10n.paymentFailed,
            notActivatedMessage: context.l10n.paywallErrorNotActivated,
            refreshSubscription: () async {
              await ref.read(subscriptionManagementProvider.notifier).refresh();
            },
            hasActiveSubscription: () {
              final latestSubscription = ref
                  .read(subscriptionManagementProvider)
                  .valueOrNull
                  ?.subscription;
              return subscriptionMatchesPlanOption(latestSubscription, selectedOption);
            },
          );
        }

        if (!context.mounted) return;
        AppToast.success(context, context.l10n.paymentSuccessfulCheckingSubscription);
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        final raw = error.toString();
        final isCanceled = raw.toLowerCase().contains('cancel');
        if (isCanceled) {
          AppToast.info(context, context.l10n.paymentCanceled);
          return;
        }
        AppToast.error(context, raw);
      } finally {
        isCheckoutProcessing.value = false;
      }
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(content.mode),
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(
          children: [
            // Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 240),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SheetHero(content: content),
                    const SizedBox(height: 32),
                    _PremiumFeaturesList(features: content.features),
                  ],
                ),
              ),
            ),

            // Floating Bottom Card (Half cutted card)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 8),
                    decoration: BoxDecoration(
                      color: colorScheme.sheetBackground.withValues(alpha: 0.8),
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (content.note != null) ...[
                          _SheetNote(text: content.note!),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.sheetElementBackground,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.border.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            
                              if (visiblePlans.isEmpty)
                                Text(
                                  context.l10n.paywallErrorLoadOptions,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else ...[
                                UnifiedPlanCard(
                                  plans: visiblePlans,
                                  selectedPlanId: selectedPlanId.value ?? '',
                                  onPlanSelected: (id) => selectedPlanId.value = id,
                                  isCurrentPlan: isCurrentPlan,
                                  isNewUser: currentSubscription == null,
                                ),
                                const SizedBox(height: 12),
                                if (effectiveActivePlanOption != null)
                                  PaywallCheckoutActionButton(
                                    option: effectiveActivePlanOption,
                                    isProcessing: isCheckoutProcessing.value,
                                    isStoreReady: isStoreReady,
                                    canConfirmAutoRenew: true,
                                    isCurrentPlan: isCurrentPlan(effectiveActivePlanOption),
                                    trialMode: false,
                                    includePrice: true,
                                    centerText: true,
                                    onPressed: onCheckoutPressed,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.mutedForeground,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            context.l10n.plusLockedMaybeLaterCta,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LockedSheetMode { freeToPlus, trialToPlus }

class _LockedSheetContent {
  const _LockedSheetContent({
    required this.mode,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.features,
    required this.ctaLabel,
    this.note,
  });

  final _LockedSheetMode mode;
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color Function(ColorScheme) iconBackground;
  final Color Function(ColorScheme) iconForeground;
  final List<_PremiumFeature> features;
  final String ctaLabel;
  final String? note;

  static _LockedSheetContent resolve(
      BuildContext context, Subscription? subscription) {
    if (isTrialingPlan(subscription)) {
      return _trialPlus(context);
    }
    return _freePlus(context);
  }

  static _LockedSheetContent _freePlus(BuildContext context) {
    return _LockedSheetContent(
      mode: _LockedSheetMode.freeToPlus,
      eyebrow: context.l10n.plus,
      title: context.l10n.plusPlan,
      description: context.l10n.plusLockedDescription,
      icon: Icons.auto_awesome_rounded,
      iconBackground: (scheme) => scheme.primary.withValues(alpha: 0.12),
      iconForeground: (scheme) => scheme.primary,
      features: _plusOnlyFeatures(context),
      ctaLabel: context.l10n.subscribeForPricePeriod(
        context.l10n.plusPlan,
        '',
      ),
    );
  }

  static _LockedSheetContent _trialPlus(BuildContext context) {
    return _LockedSheetContent(
      mode: _LockedSheetMode.trialToPlus,
      eyebrow: context.l10n.plusLockedTrialEyebrow,
      title: context.l10n.plusPlan,
      description: context.l10n.plusLockedTrialDescription,
      icon: Icons.auto_awesome_rounded,
      iconBackground: (scheme) => scheme.warningSurface,
      iconForeground: (scheme) => scheme.warning,
      features: _plusOnlyFeatures(context),
      ctaLabel: context.l10n.subscribeForPricePeriod(
        context.l10n.plusPlan,
        '',
      ),
      note: context.l10n.plusLockedTrialReviewPlansNote,
    );
  }

  static List<_PremiumFeature> _plusOnlyFeatures(BuildContext context) {
    return [
      _PremiumFeature(
        icon: Icons.auto_awesome_rounded,
        title: _plusLockedInAppAiExpenseLogging,
        value: context.l10n.unlimited,
      ),
      const _PremiumFeature(
        icon: Icons.monitor_heart_rounded,
        title: _plusLockedHealthDetails,
      ),
      const _PremiumFeature(
        icon: Icons.insights_rounded,
        title: _plusLockedAiScenarios,
      ),
      _PremiumFeature(
        icon: Icons.chat_bubble_rounded,
        title: context.l10n.plusLockedMessagingAppCapture,
      ),
      _PremiumFeature(
        icon: Icons.receipt_long_rounded,
        title: context.l10n.plusLockedEmailReceiptImport,
      ),
      _PremiumFeature(
        icon: Icons.group_rounded,
        title: context.l10n.plusLockedSharedBudgets,
        value: context.l10n.unlimited,
      ),
      _PremiumFeature(
        icon: Icons.account_balance_wallet_rounded,
        title: _plusLockedWallets,
        value: context.l10n.unlimited,
      ),
      _PremiumFeature(
        icon: Icons.account_balance_rounded,
        title: context.l10n.plusLockedBankSync,
      ),
      _PremiumFeature(
        icon: Icons.public_rounded,
        title: context.l10n.multipleCurrencies,
      ),
      _PremiumFeature(
        icon: Icons.currency_exchange_rounded,
        title: context.l10n.currencyConverter,
      ),
      _PremiumFeature(
        icon: Icons.trending_up_rounded,
        title: context.l10n.plusLockedLiveExchangeRates,
      ),
      _PremiumFeature(
        icon: Icons.lock_rounded,
        title: context.l10n.appLock,
      ),
      _PremiumFeature(
        icon: Icons.support_agent_rounded,
        title: context.l10n.customerSupport,
        value: context.l10n.plusLockedPrioritySupport,
      ),
    ];
  }
}

class _PremiumFeature {
  const _PremiumFeature({
    required this.icon,
    required this.title,
    this.value,
  });

  final IconData icon;
  final String title;
  final String? value;
}

class _SheetHero extends StatelessWidget {
  const _SheetHero({required this.content});

  final _LockedSheetContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.mode == _LockedSheetMode.trialToPlus) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.warningSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content.eyebrow.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: colorScheme.warning,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          content.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colorScheme.foreground,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content.description,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colorScheme.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.infoSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colorScheme.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumFeaturesList extends StatelessWidget {
  const _PremiumFeaturesList({required this.features});

  final List<_PremiumFeature> features;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.85, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.sheetElementBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border(
            top: BorderSide(color: colorScheme.border.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.border.withValues(alpha: 0.5)),
            right: BorderSide(color: colorScheme.border.withValues(alpha: 0.5)),
          ),
        ),
        padding: const EdgeInsets.only(top: 4, bottom: 0),
        child: Column(
          children: features.map((feature) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    feature.icon,
                    size: 16,
                    color: colorScheme.foreground,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                            letterSpacing: -0.2,
                          ),
                        ),
                      
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                child: _PlanComparisonTable(
                                  content: _freeVsPlusComparison(
                                    context,
                                    plusBadge:
                                        context.l10n.plusLockedRecommendedBadge,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: Icon(Icons.close,
                                      color: colorScheme.mutedForeground),
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: IconButton.styleFrom(
                                    backgroundColor: colorScheme.surface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 22,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PlanComparisonContent {
  const _PlanComparisonContent({
    required this.featureHeader,
    required this.columns,
    required this.rows,
    required this.highlightedColumn,
  });

  final String featureHeader;
  final List<_PlanColumn> columns;
  final List<_ComparisonRowData> rows;
  final int highlightedColumn;
}

class _PlanColumn {
  const _PlanColumn({required this.title, this.badge});

  final String title;
  final String? badge;
}

class _ComparisonRowData {
  const _ComparisonRowData({
    required this.feature,
    required this.values,
  });

  final String feature;
  final List<_ComparisonValue> values;
}

class _ComparisonValue {
  const _ComparisonValue._({
    this.label,
    required this.included,
  });

  factory _ComparisonValue.included() => const _ComparisonValue._(
        included: true,
      );

  factory _ComparisonValue.text(String label) => _ComparisonValue._(
        label: label,
        included: null,
      );

  final String? label;
  final bool? included;
}

class _PlanComparisonTable extends StatelessWidget {
  const _PlanComparisonTable({required this.content});

  final _PlanComparisonContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.sheetElementBackground,
          border: Border.all(color: colorScheme.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            _PlanComparisonHeader(content: content),
            for (var index = 0; index < content.rows.length; index++)
              _PlanComparisonRow(
                data: content.rows[index],
                highlightedColumn: content.highlightedColumn,
                isLast: index == content.rows.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanComparisonHeader extends StatelessWidget {
  const _PlanComparisonHeader({required this.content});

  final _PlanComparisonContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.border.withValues(alpha: 0.7)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Text(
                  content.featureHeader,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
            for (var index = 0; index < content.columns.length; index++)
              Expanded(
                flex: 3,
                child: _PlanHeaderCell(
                  column: content.columns[index],
                  highlighted: index == content.highlightedColumn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanHeaderCell extends StatelessWidget {
  const _PlanHeaderCell({
    required this.column,
    required this.highlighted,
  });

  final _PlanColumn column;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = highlighted
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surface.withValues(alpha: 0.0);

    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            column.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlighted ? colorScheme.primary : colorScheme.foreground,
            ),
          ),
          if (column.badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: highlighted
                    ? colorScheme.primary
                    : colorScheme.muted.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                column.badge!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: highlighted
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanComparisonRow extends StatelessWidget {
  const _PlanComparisonRow({
    required this.data,
    required this.highlightedColumn,
    required this.isLast,
  });

  final _ComparisonRowData data;
  final int highlightedColumn;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                child: Text(
                  data.feature,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            for (var index = 0; index < data.values.length; index++)
              Expanded(
                flex: 3,
                child: _ComparisonValueCell(
                  value: data.values[index],
                  highlighted: index == highlightedColumn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonValueCell extends StatelessWidget {
  const _ComparisonValueCell({
    required this.value,
    required this.highlighted,
  });

  final _ComparisonValue value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = highlighted
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surface.withValues(alpha: 0.0);

    final child = switch (value.included) {
      true => Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: highlighted ? colorScheme.primary : colorScheme.success,
        ),
      false => Icon(
          Icons.cancel_rounded,
          size: 19,
          color: colorScheme.mutedForeground.withValues(alpha: 0.55),
        ),
      null => Text(
          value.label ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color:
                highlighted ? colorScheme.primary : colorScheme.mutedForeground,
          ),
        ),
    };

    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      alignment: Alignment.center,
      child: child,
    );
  }
}

_PlanComparisonContent _freeVsPlusComparison(
  BuildContext context, {
  String? featureHeader,
  String? plusBadge,
}) {
  return _PlanComparisonContent(
    featureHeader: featureHeader ?? context.l10n.plusLockedFeatureHeader,
    columns: [
      _PlanColumn(title: context.l10n.free),
      _PlanColumn(title: context.l10n.plus, badge: plusBadge),
    ],
    highlightedColumn: 1,
    rows: [
      _ComparisonRowData(
        feature: context.l10n.plusLockedAiExpenseCapture,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.plusLockedMessagingAppCapture,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.plusLockedEmailReceiptImport,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.plusLockedSharedBudgets,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.plusLockedBankSync,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.multipleCurrencies,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.currencyConverter,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.plusLockedLiveExchangeRates,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.appLock,
        values: [
          const _ComparisonValue._(included: false),
          _ComparisonValue.included()
        ],
      ),
      _ComparisonRowData(
        feature: context.l10n.customerSupport,
        values: [
          _ComparisonValue.text(context.l10n.plusLockedStandardSupport),
          _ComparisonValue.text(context.l10n.plusLockedPrioritySupport),
        ],
      ),
    ],
  );
}

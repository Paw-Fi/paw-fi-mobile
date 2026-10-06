import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/mobile_stripe_checkout.dart';
import 'package:moneko/features/subscription/presentation/providers/iap_controller_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_products_provider.dart';
import 'package:moneko/features/subscription/presentation/subscription_checkout_shared.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';

String formatPlusYearlyMonthlyEquivalent(double yearlyPrice) {
  final monthlyPrice = yearlyPrice / 12;
  return r'$' + monthlyPrice.toStringAsFixed(2);
}

PlanOption? resolvePlusIntroYearlyPlan(List<PlanOption> plans) {
  for (final option in plans) {
    if (option.serverPlanId == 'plus' && option.billingInterval == 'yearly') {
      return option;
    }
  }
  return null;
}

enum PlusFeature {
  healthDetails,
  aiScenarios,
  aiMonthlyBudgetSuggestions,
  messagingAppCapture,
  emailReceiptImport,
  spaceCreation,
  walletCreation,
  bankSync,
  multipleCurrencies,
  currencyConverter,
  liveExchangeRates,
  appLock,
  customerSupport,
}

Future<void> showFreeVsPlusComparisonDialog(
  BuildContext context, {
  PlusFeature? highlightedFeature,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: _PlanComparisonTable(
              content: _freeVsPlusComparison(
                context,
                highlightedFeature: highlightedFeature,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: context.l10n.close,
              icon: Icon(Icons.close, color: colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PlusLockedSheet extends HookConsumerWidget {
  const PlusLockedSheet({super.key, this.highlightedFeature});

  final PlusFeature? highlightedFeature;

  static const bool _forceUseStripeCheckout = false;

  static Future<void> show(
    BuildContext context, {
    PlusFeature? highlightedFeature,
  }) {
    return context.push<void>(Uri(
      path: '/plus-locked',
      queryParameters: {
        if (highlightedFeature != null) 'feature': highlightedFeature.name,
      },
    ).toString());
  }

  static Future<bool> ensureAccess(
    BuildContext context,
    WidgetRef ref, {
    required PlusFeature feature,
  }) async {
    final subscriptionAsync = ref.read(subscriptionNotifierProvider);
    try {
      final subscription = subscriptionAsync.hasValue
          ? subscriptionAsync.valueOrNull
          : await ref.read(subscriptionNotifierProvider.future);
      if (hasPremiumFeatureAccess(subscription)) {
        return true;
      }
    } catch (_) {
      // Unknown entitlement state must not be treated as confirmed free.
      // Server-side entitlement checks remain the final authority.
      return true;
    }

    if (!context.mounted) return false;
    await show(context, highlightedFeature: feature);
    if (!context.mounted) return false;
    try {
      return hasPremiumFeatureAccess(
        await ref.read(subscriptionNotifierProvider.future),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final subscriptionDetailsAsync = ref.watch(subscriptionManagementProvider);
    final productsAsync = ref.watch(subscriptionProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final currentSubscription =
        subscriptionDetailsAsync.valueOrNull?.subscription;
    final currentStatus = currentSubscription?.status?.toLowerCase();
    final isCheckoutProcessing = useState(false);

    final useIap = shouldUseAppStoreCheckout(
      forceStripeCheckout: _forceUseStripeCheckout,
    );
    final plans = buildPlusPlanOptions(
      context: context,
      useIap: useIap,
      productsAsync: productsAsync,
      iapStateAsync: iapStateAsync,
    );
    final yearlyOption = resolvePlusIntroYearlyPlan(plans);
    final isStoreReady =
        !useIap || (iapStateAsync.valueOrNull?.storeAvailable ?? false);
    final isProcessing = isCheckoutProcessing.value;
    bool isCurrentPlan(PlanOption option) {
      final shouldBlockSamePlan =
          (currentSubscription?.isSubscribed ?? false) &&
              currentStatus == 'active';
      if (!shouldBlockSamePlan) {
        return false;
      }
      return subscriptionMatchesPlanOption(currentSubscription, option);
    }

    Future<void> onCheckoutPressed() async {
      final selectedOption = yearlyOption;
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

          await ref.read(iapControllerProvider.notifier).buy(
                catalog,
                useMonthlyCommitment: selectedOption.isCommitment,
              );

          final isActivated = await waitForIapPurchaseCompletion(
            productId: catalog.storeProductId,
            readState: () => ref.read(iapControllerProvider).valueOrNull,
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
              await ref.read(subscriptionNotifierProvider.notifier).refresh();
            },
            hasActiveSubscription: () {
              final latestSubscription = ref
                  .read(subscriptionManagementProvider)
                  .valueOrNull
                  ?.subscription;
              return subscriptionMatchesPlanOption(
                  latestSubscription, selectedOption);
            },
          );
        }

        if (!context.mounted) return;
        AppToast.success(
            context, context.l10n.paymentSuccessfulCheckingSubscription);
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        final raw = error.toString();
        final isCanceled = error is PaymentCanceledException ||
            raw.toLowerCase().contains('cancel');
        if (error is IapPurchasePendingException) {
          AppToast.info(context, context.l10n.paywallProcessing);
          return;
        }
        if (isCanceled) {
          AppToast.info(context, context.l10n.paymentCanceled);
          return;
        }
        AppToast.error(context, raw);
      } finally {
        isCheckoutProcessing.value = false;
      }
    }

    final priceLoading = useIap &&
        ((!productsAsync.hasValue && productsAsync.isLoading) ||
            (!iapStateAsync.hasValue && iapStateAsync.isLoading));
    final canCheckout = yearlyOption != null &&
        isStoreReady &&
        !isProcessing &&
        !isCurrentPlan(yearlyOption);
    final foreground = colorScheme.plusIntroForeground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: colorScheme.surface.withValues(alpha: 0),
        systemNavigationBarColor: colorScheme.plusIntroBottom,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.plusIntroTop,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.plusIntroTop, colorScheme.plusIntroBottom],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  key: const ValueKey('plus-intro-scroll'),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _PlusIntroHero(),
                                const SizedBox(height: 24),
                                _PremiumFeaturesList(
                                    highlightedFeature: highlightedFeature),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 36),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      child: yearlyOption != null &&
                                              !priceLoading
                                          ? Text(
                                              context.l10n.monthlyMonth(
                                                yearlyOption.priceDisplay,
                                              ),
                                              key: const ValueKey(
                                                  'plus-intro-price'),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: foreground),
                                            )
                                          : priceLoading
                                              ? Container(
                                                  key: const ValueKey(
                                                      'plus-intro-price-loading'),
                                                  width: 220,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                      color:
                                                          foreground.withValues(
                                                              alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7)),
                                                )
                                              : Text(
                                                  context.l10n
                                                      .paywallErrorStoreUnavailableShort,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: foreground),
                                                ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: colorScheme.copyWith(
                                      primary: colorScheme.plusIntroButton,
                                      onPrimary:
                                          colorScheme.plusIntroButtonForeground,
                                    ),
                                  ),
                                  child: PrimaryAdaptiveButton(
                                    key: const ValueKey('plus-intro-continue'),
                                    onPressed:
                                        canCheckout ? onCheckoutPressed : null,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      child: isProcessing
                                          ? Row(
                                              key: const ValueKey('processing'),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CupertinoActivityIndicator(
                                                    color: colorScheme
                                                        .plusIntroButtonForeground,
                                                    radius: 8,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                    child: Text(context.l10n
                                                        .paywallProcessing)),
                                              ],
                                            )
                                          : Row(
                                              key: const ValueKey('continue'),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                    child: Text(context
                                                        .l10n.continueButton)),
                                                const SizedBox(width: 8),
                                                SvgPicture.asset(
                                                    'lib/assets/images/paywall/intro/stars.svg',
                                                    width: 19,
                                                    height: 15),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  key: const ValueKey('plus-intro-all-plans'),
                                  onPressed: () => context.push(
                                      '/plan-selection?mode=resubscribe&plan=plus&interval=yearly'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: foreground,
                                      disabledForegroundColor:
                                          foreground.withValues(alpha: 0.5),
                                      minimumSize: const Size(48, 48)),
                                  child: Text(context.l10n.seeAllPlans,
                                      style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          decorationColor: foreground,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          const _PlusIntroReviews(),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 12,
                  child: IconButton(
                    tooltip: context.l10n.close,
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close_rounded, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlusFeatureGuard extends ConsumerStatefulWidget {
  const PlusFeatureGuard({
    super.key,
    required this.feature,
    required this.child,
  });

  final PlusFeature feature;
  final Widget child;

  @override
  ConsumerState<PlusFeatureGuard> createState() => _PlusFeatureGuardState();
}

class _PlusFeatureGuardState extends ConsumerState<PlusFeatureGuard> {
  bool? _hasAccess;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final hasAccess = await PlusLockedSheet.ensureAccess(
      context,
      ref,
      feature: widget.feature,
    );
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _hasAccess = hasAccess;
    });
    if (!hasAccess) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess == true) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: SafeArea(
        child: Center(
          child: _isChecking || _hasAccess == null
              ? const CircularProgressIndicator.adaptive()
              : TextButton(
                  onPressed: _checkAccess,
                  child: Text(context.l10n.viewPlans),
                ),
        ),
      ),
    );
  }
}

const _introAssetPath = 'lib/assets/images/paywall/intro/';

class _PlusIntroHero extends StatelessWidget {
  const _PlusIntroHero();

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.plusIntroForeground;
    return Column(children: [
      Image.asset('${_introAssetPath}paywall-plane.png',
          width: 145, height: 121, excludeFromSemantics: true),
      const SizedBox(height: 16),
      Text(context.l10n.unlockMonekoPlus,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: foreground,
              letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text(context.l10n.paywallBenefit0,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: foreground)),
    ]);
  }
}

class _PremiumFeature {
  const _PremiumFeature(this.title, this.asset, [this.keys = const []]);
  final String title;
  final String asset;
  final List<PlusFeature> keys;
}

class _PremiumFeaturesList extends StatelessWidget {
  const _PremiumFeaturesList({this.highlightedFeature});
  final PlusFeature? highlightedFeature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final features = [
      _PremiumFeature(context.l10n.unlimitedAiExpenseCapture, 'paywall-chart'),
      _PremiumFeature(context.l10n.unlimitedSpacesWallets, 'paywall-wallets',
          [PlusFeature.spaceCreation, PlusFeature.walletCreation]),
      _PremiumFeature(context.l10n.whatsAppTelegramTracking, 'paywall-wa',
          [PlusFeature.messagingAppCapture]),
      _PremiumFeature(context.l10n.plusLockedEmailReceiptImport,
          'paywall-receipt', [PlusFeature.emailReceiptImport]),
      _PremiumFeature(context.l10n.bankSyncUsCanada, 'paywall-bank',
          [PlusFeature.bankSync]),
      _PremiumFeature(context.l10n.multiCurrencyLiveRates, 'paywall-currency', [
        PlusFeature.multipleCurrencies,
        PlusFeature.currencyConverter,
        PlusFeature.liveExchangeRates
      ]),
      _PremiumFeature(
          context.l10n.appLock, 'paywall-lock', [PlusFeature.appLock]),
      _PremiumFeature(context.l10n.prioritySupport, 'paywall-support',
          [PlusFeature.customerSupport]),
    ];
    // Retain a visible highlighted benefit for gates outside the core eight.
    switch (highlightedFeature) {
      case PlusFeature.healthDetails:
        features.insert(
            0,
            _PremiumFeature(context.l10n.plusLockedHealthDetails,
                'paywall-chart', [PlusFeature.healthDetails]));
      case PlusFeature.aiScenarios:
        features.insert(
            0,
            _PremiumFeature(context.l10n.plusLockedAiScenarios, 'paywall-chart',
                [PlusFeature.aiScenarios]));
      case PlusFeature.aiMonthlyBudgetSuggestions:
        features.insert(
            0,
            _PremiumFeature(context.l10n.plusLockedAiMonthlyBudgetSuggestions,
                'paywall-chart', [PlusFeature.aiMonthlyBudgetSuggestions]));
      default:
        break;
    }
    final index = features
        .indexWhere((feature) => feature.keys.contains(highlightedFeature));
    if (index > 0) features.insert(0, features.removeAt(index));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.plusIntroSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: scheme.plusIntroForeground.withValues(alpha: 0.3)),
      ),
      child: Column(
          children: features.map((feature) {
        final highlighted = feature.keys.contains(highlightedFeature);
        return Container(
          key: ValueKey(
              'plus-intro-feature-${feature.asset}-${feature.keys.join('-')}'),
          color: highlighted
              ? scheme.plusIntroForeground.withValues(alpha: 0.14)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Image.asset('$_introAssetPath${feature.asset}.png',
                width: 28, height: 28, excludeFromSemantics: true),
            const SizedBox(width: 10),
            Expanded(
                child: Text(feature.title,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight:
                            highlighted ? FontWeight.w800 : FontWeight.w600,
                        color: scheme.plusIntroForeground))),
            const SizedBox(width: 8),
            Icon(Icons.check_rounded,
                size: 20, color: scheme.plusIntroForeground),
          ]),
        );
      }).toList()),
    );
  }
}

class _PlusIntroReviews extends StatelessWidget {
  const _PlusIntroReviews();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
          child: SvgPicture.asset('${_introAssetPath}bg-cloud.svg',
              fit: BoxFit.fill)),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
        child: Column(children: [
          Image.asset('${_introAssetPath}plus-review-couple.png',
              height: 210, fit: BoxFit.contain, excludeFromSemantics: true),
          const SizedBox(height: 20),
          const PaywallReviewsSection(plusIntro: true),
        ]),
      ),
    ]);
  }
}

class _PlanComparisonContent {
  const _PlanComparisonContent({
    required this.featureHeader,
    required this.columns,
    required this.rows,
    required this.highlightedColumn,
    this.highlightedRowIndex = -1,
  });

  final String featureHeader;
  final List<_PlanColumn> columns;
  final List<_ComparisonRowData> rows;
  final int highlightedColumn;
  final int highlightedRowIndex;
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
    this.featureKey,
  });

  final String feature;
  final List<_ComparisonValue> values;
  final PlusFeature? featureKey;
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

    return MonekoTextScale(
      mode: MonekoTextScaling.compact,
      child: Padding(
        padding: const EdgeInsets.only(top: 54),
        child: ClipRRect(
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
                    isHighlighted: index == content.highlightedRowIndex,
                  ),
              ],
            ),
          ),
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
    this.isHighlighted = false,
  });

  final _ComparisonRowData data;
  final int highlightedColumn;
  final bool isLast;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color:
            isHighlighted ? colorScheme.primary.withValues(alpha: 0.06) : null,
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
                    fontWeight:
                        isHighlighted ? FontWeight.w800 : FontWeight.w600,
                    color: isHighlighted
                        ? colorScheme.primary
                        : colorScheme.foreground,
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
          color: colorScheme.primary,
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
  PlusFeature? highlightedFeature,
}) {
  final rows = [
    _ComparisonRowData(
      feature: context.l10n.plusLockedAiExpenseCapture,
      values: [_ComparisonValue.included(), _ComparisonValue.included()],
    ),
    _ComparisonRowData(
      feature: context.l10n.plusLockedSharedBudgets,
      values: [
        _ComparisonValue.text('2'),
        _ComparisonValue.text(context.l10n.unlimited),
      ],
      featureKey: PlusFeature.spaceCreation,
    ),
    _ComparisonRowData(
      feature: context.l10n.walletCreation,
      values: [
        _ComparisonValue.text('2'),
        _ComparisonValue.text(context.l10n.unlimited),
      ],
      featureKey: PlusFeature.walletCreation,
    ),
    _ComparisonRowData(
      feature: context.l10n.plusLockedMessagingAppCapture,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.messagingAppCapture,
    ),
    _ComparisonRowData(
      feature: context.l10n.plusLockedEmailReceiptImport,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.emailReceiptImport,
    ),
    _ComparisonRowData(
      feature: context.l10n.plusLockedBankSync,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.bankSync,
    ),
    _ComparisonRowData(
      feature: context.l10n.multipleCurrencies,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.multipleCurrencies,
    ),
    _ComparisonRowData(
      feature: context.l10n.currencyConverter,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.currencyConverter,
    ),
    _ComparisonRowData(
      feature: context.l10n.plusLockedLiveExchangeRates,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.liveExchangeRates,
    ),
    _ComparisonRowData(
      feature: context.l10n.appLock,
      values: [
        const _ComparisonValue._(included: false),
        _ComparisonValue.included()
      ],
      featureKey: PlusFeature.appLock,
    ),
    _ComparisonRowData(
      feature: context.l10n.customerSupport,
      values: [
        _ComparisonValue.text(context.l10n.plusLockedStandardSupport),
        _ComparisonValue.text(context.l10n.plusLockedPrioritySupport),
      ],
      featureKey: PlusFeature.customerSupport,
    ),
  ];

  var highlightedRowIndex = -1;
  if (highlightedFeature != null) {
    final index = rows.indexWhere((r) => r.featureKey == highlightedFeature);
    if (index >= 0) {
      final row = rows.removeAt(index);
      rows.insert(0, row);
      highlightedRowIndex = 0;
    }
  }

  return _PlanComparisonContent(
    featureHeader: featureHeader ?? context.l10n.plusLockedFeatureHeader,
    columns: [
      _PlanColumn(title: context.l10n.free),
      _PlanColumn(title: context.l10n.plus, badge: plusBadge),
    ],
    highlightedColumn: 1,
    rows: rows,
    highlightedRowIndex: highlightedRowIndex,
  );
}

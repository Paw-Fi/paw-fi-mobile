import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';

/// Scrollable plan presentation with fixed hero and rating artwork sizes.
class PlanSelectionLayout extends StatelessWidget {
  const PlanSelectionLayout({
    super.key,
    required this.header,
    required this.plans,
    required this.comparison,
    required this.actions,
    required this.footer,
  });

  final Widget header;
  final Widget plans;
  final Widget comparison;
  final Widget? actions;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.planSelectionBackground,
      child: Stack(
        children: [
          Positioned.fill(
            top: 148,
            child: ExcludeSemantics(
              child: SvgPicture.asset(scheme.planSelectionBackgroundAsset,
                  fit: BoxFit.fill),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('plan-selection-viewport'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.sizeOf(context).width < 360
                                  ? 16
                                  : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header,
                              SizedBox(
                                key: const ValueKey('plan-selection-hero'),
                                height: 220,
                                child: ExcludeSemantics(
                                    child: Image.asset(
                                        scheme.planSelectionHeroAsset,
                                        fit: BoxFit.contain)),
                              ),
                              const SizedBox(height: 16),
                              Text(context.l10n.moneySmarterWithMonekoPlus,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface)),
                              const SizedBox(height: 12),
                              plans,
                              comparison,
                              const SizedBox(height: 12),
                              const SizedBox(
                                key: ValueKey('plan-selection-rating'),
                                height: 90,
                                child: Center(
                                    child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: PaywallAppRatingBadge(
                                      planSelection: true),
                                )),
                              ),
                              const SizedBox(height: 16),
                              footer,
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.bottomCenter,
                  child: actions == null
                      ? const SizedBox.shrink()
                      : Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: 480,
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.6),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: DecoratedBox(
                                key: const ValueKey(
                                    'plan-selection-floating-actions'),
                                decoration: BoxDecoration(
                                  color: scheme.sheetBackground,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: scheme.sheetBorder),
                                  boxShadow: [
                                    BoxShadow(
                                        color: scheme.shadow
                                            .withValues(alpha: 0.12),
                                        blurRadius: 18,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: actions!),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

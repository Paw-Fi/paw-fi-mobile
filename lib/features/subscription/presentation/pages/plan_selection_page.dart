import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
// import 'package:moneko/features/subscription/data/models/subscription_details.dart'; // Removed unused import
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart'; // Colors are here
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

// --- DATA ---
// Minimalist structure, focus on key differentiator
class PlanOption {
  final String id;
  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final String tagline;
  final bool popular;
  final bool isLifetime;

  const PlanOption({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.tagline,
    this.popular = false,
    this.isLifetime = false,
  });
}

const List<PlanOption> _kPlans = [
  PlanOption(
    id: 'free',
    name: 'Starter',
    monthlyPrice: 0,
    yearlyPrice: 0,
    tagline: 'Basic budgeting & manual tracking.',
  ),
  PlanOption(
    id: 'plus',
    name: 'Plus',
    monthlyPrice: 7.99,
    yearlyPrice: 49.0, // ~4.08/mo
    tagline: 'Unlimited AI, Sync, & Smart Insights.',
    popular: true,
  ),
  PlanOption(
    id: 'lifetime',
    name: 'Lifetime',
    monthlyPrice: 149.0,
    yearlyPrice: 149.0,
    tagline: 'One-time payment. Forever Access.',
    isLifetime: true,
  ),
];

// --- PAGE ---
class PlanSelectionPage extends HookConsumerWidget {
  const PlanSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);
    final isLoading = useState(false);
    final colorScheme = Theme.of(context).colorScheme;

    // View State
    final billingInterval = useState<String>('yearly');
    final selectedPlanId = useState<String?>(null);

    // Effect: Set initial selection based on current subscription
    useEffect(() {
      if (subscriptionAsync.value != null) {
        final current = subscriptionAsync.value!.subscription?.plan ?? 'free';
        // Only override if user hasn't manually selected yet (or first load)
        if (selectedPlanId.value == null) {
          selectedPlanId.value = current;
          // Also try to set interval if possible (not yet in model, defaulting to yearly is fine)
        }
      }
      return null;
    }, [subscriptionAsync.value]);

    // Helpers
    int getPlanLevel(String id) {
      if (id == 'lifetime') return 3;
      if (id == 'plus') return 2;
      return 1; // free
    }

    final currentSub = subscriptionAsync.value;
    final currentPlanId = currentSub?.subscription?.plan ?? 'free';

    // DIRECT RETURN FOR LIFETIME USERS
    if (currentPlanId == 'lifetime') {
      return const _LifetimeView();
    }

    // Derived values for the currently SELECTABLE plan
    final activePlanOption = _kPlans.firstWhere(
      (p) => p.id == (selectedPlanId.value ?? 'plus'),
      orElse: () => _kPlans[1], // Default to Plus
    );

    // Action Logic
    Future<void> onMainAction() async {
      if (activePlanOption.id == currentPlanId) {
        // Same plan selected.
        // Check if interval is different (only for Plus)
        if (activePlanOption.id == 'plus') {
          // Logic to check if we are swapping interval?
          // Since we don't have current interval from backend easily, we assume
          // this button is only clickable if sensible.
          // For now, let's allow "Update Interval" flow if it's Plus.
          final result = await MonekoAlertDialog.show(
            context: context,
            title: 'Update Billing Cycle',
            description:
                'Switch your Plus plan to ${billingInterval.value} billing?',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
          );
          if (result?.confirmed == true) {
            // ... logic
            isLoading.value = true;
            try {
              await ref
                  .read(subscriptionManagementProvider.notifier)
                  .changePlan(
                    plan: 'plus',
                    billingInterval: billingInterval.value,
                  );
              if (context.mounted) AppToast.success(context, 'Plan updated');
            } catch (e) {
              if (context.mounted) AppToast.error(context, e.toString());
            } finally {
              isLoading.value = false;
            }
          }
        }
        return;
      }

      final currentLevel = getPlanLevel(currentPlanId);
      final newLevel = getPlanLevel(activePlanOption.id);

      // Downgrade / Cancel
      if (newLevel < currentLevel) {
        // e.g. Plus -> Free
        final result = await MonekoAlertDialog.show(
          context: context,
          title: 'Cancel Subscription', // Minimal text
          description:
              'Downgrade to Starter? You will lose premium features at the end of the period.',
          confirmLabel: 'Confirm',
          cancelLabel: 'Keep Plan',
          isDestructive: true,
        );
        if (result?.confirmed == true) {
          isLoading.value = true;
          try {
            await ref
                .read(subscriptionManagementProvider.notifier)
                .cancelSubscription();
            if (context.mounted)
              AppToast.success(context, 'Subscription cancelled');
          } catch (e) {
            if (context.mounted) AppToast.error(context, e.toString());
          } finally {
            isLoading.value = false;
          }
        }
        return;
      }

      // Upgrade (Free -> Plus, Plus -> Lifetime)
      if (newLevel > currentLevel) {
        final isLifetime = activePlanOption.isLifetime;
        final price = isLifetime
            ? activePlanOption.monthlyPrice
            : (billingInterval.value == 'monthly'
                ? activePlanOption.monthlyPrice
                : activePlanOption.yearlyPrice);

        final period = isLifetime
            ? 'one-time'
            : (billingInterval.value == 'monthly' ? '/mo' : '/yr');

        final result = await MonekoAlertDialog.show(
          context: context,
          title: 'Confirm Upgrade',
          description:
              'Upgrade to ${activePlanOption.name} for \$${price.toStringAsFixed(2)}$period?',
          confirmLabel: 'Pay & Upgrade',
          cancelLabel: 'Cancel',
        );

        if (result?.confirmed == true) {
          isLoading.value = true;
          try {
            await ref.read(subscriptionManagementProvider.notifier).changePlan(
                  plan: activePlanOption.id,
                  billingInterval: isLifetime ? null : billingInterval.value,
                );
            if (context.mounted)
              AppToast.success(context, 'Welcome to ${activePlanOption.name}!');
          } catch (e) {
            if (context.mounted)
              AppToast.error(
                  context, e.toString()); // Simplify error handling for brevity
          } finally {
            isLoading.value = false;
          }
        }
      }
    }

    // Button Text Logic
    String getButtonText() {
      if (isLoading.value) return 'Processing...';
      if (activePlanOption.id == currentPlanId) {
        if (activePlanOption.id == 'plus') return 'Update Billing Cycle';
        return 'Current Plan';
      }
      if (getPlanLevel(activePlanOption.id) < getPlanLevel(currentPlanId))
        return 'Downgrade to ${activePlanOption.name}';
      return 'Upgrade to ${activePlanOption.name}';
    }

    bool isButtonEnabled() {
      if (isLoading.value) return false;
      if (activePlanOption.id == 'free' && currentPlanId == 'free')
        return false; // Already free
      if (activePlanOption.id == 'lifetime' && currentPlanId == 'lifetime')
        return false;

      // Ensure user can't "upgrade" to same plan unless it's Plus (interval switch)
      // Ideally we check if interval is actually different, but for now we allow the button to trigger the check
      return true;
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Membership'), // Shorter title
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // 1. Billing Toggle (Top Center)
              // Only meaningful if not viewing Lifetime solely?
              // Actually, standard UI shows this at top.
              Center(
                child: _MinimalToggle(
                  value: billingInterval.value,
                  onChanged: (v) => billingInterval.value = v,
                ),
              ),

              const Spacer(), // Push content to center roughly or use flex

              // 2. Plan List (The Core)
              // Minimal rows.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _kPlans.map((plan) {
                    final isSelected = selectedPlanId.value == plan.id;
                    return _MinimalPlanRow(
                      plan: plan,
                      isSelected: isSelected,
                      billing: billingInterval.value,
                      onTap: () => selectedPlanId.value = plan.id,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // 3. Simple Summary of Selection
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1.0,
                child: Column(
                  children: [
                    Text(
                      activePlanOption.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // TODO: Show feature modal
                        showModalBottomSheet(
                            context: context,
                            builder: (_) =>
                                _FeatureSheet(plan: activePlanOption));
                      },
                      child: Text(
                        'See features',
                        style: TextStyle(
                          color: colorScheme.primary, // Using primary for link
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // 4. Sticky Bottom Action
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    PrimaryAdaptiveButton(
                      onPressed: isButtonEnabled() ? onMainAction : null,
                      child: Text(getButtonText()),
                    ),
                    const SizedBox(height: 12),
                    if (activePlanOption.monthlyPrice > 0)
                      Text(
                        'Recurring billing. Cancel anytime.',
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _LifetimeView extends StatelessWidget {
  const _LifetimeView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Membership'),
      body: Material(
        color: scheme.appBackground,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Icon(Icons.verified_rounded,
                    size: 64, color: scheme.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Lifetime Member',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for your support!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You have successfully unlocked all features forever. Your early belief in our mission means the world to us.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.mutedForeground,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged; // 'monthly' | 'yearly'

  const _MinimalToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface, // Subtle bg
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
              text: 'Monthly',
              isActive: value == 'monthly',
              onTap: () => onChanged('monthly')),
          _ToggleItem(
              text: 'Yearly (-25%)',
              isActive: value == 'yearly',
              onTap: () => onChanged('yearly')),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleItem(
      {required this.text, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary
              : Colors.transparent, // Active = Primary fill
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? scheme.onPrimary : scheme.mutedForeground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MinimalPlanRow extends StatelessWidget {
  final PlanOption plan;
  final bool isSelected;
  final String billing;
  final VoidCallback onTap;

  const _MinimalPlanRow({
    required this.plan,
    required this.isSelected,
    required this.billing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Calculate Price Display
    String priceStr;
    if (plan.monthlyPrice == 0) {
      priceStr = 'Free';
    } else if (plan.isLifetime) {
      priceStr = '\$${plan.monthlyPrice.toStringAsFixed(0)}';
    } else {
      // If billing is yearly, show monthly equivalent or total?
      // User prompt said "user cant view all .. at once".
      // Let's show monthly equivalent for yearly toggle to make it look cheaper (standard UX)
      final p =
          billing == 'monthly' ? plan.monthlyPrice : (plan.yearlyPrice / 12);
      priceStr = '\$${p.toStringAsFixed(2)}/mo';
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          // No borders, just fill change
          color: isSelected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          // Maybe very subtle border for unselected? No, user said "less border".
          // We rely on the Text Color & Layout to define rows.
        ),
        child: Row(
          children: [
            // 1. Selector Circle (Radio-like)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: 2,
                ),
                color: isSelected ? scheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child:
                          Icon(Icons.check, size: 12, color: scheme.onPrimary))
                  : null,
            ),
            const SizedBox(width: 16),

            // 2. Name
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface, // Always visible
              ),
            ),
            if (plan.popular) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('PRO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple)),
              ),
            ],

            const Spacer(),

            // 3. Price
            Text(
              priceStr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? scheme.onSurface : scheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureSheet extends StatelessWidget {
  final PlanOption plan;
  const _FeatureSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Hardcoded feature lists for display
    // In real app, these might come from the PlanOption object
    List<String> getFeatures() {
      if (plan.id == 'free')
        return ['Manual Tracking', 'Basic Charts', '1 Goal'];
      if (plan.id == 'plus')
        return [
          'Everything in Free',
          'Unlimited AI Coach',
          'Bank Sync',
          'Unlimited Goals',
          'Export CSV'
        ];
      return [
        'Everything in Plus',
        'Lifetime Access',
        'Founder Badge',
        'Priority Support'
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(plan.tagline, style: TextStyle(color: scheme.mutedForeground)),
          const SizedBox(height: 24),
          ...getFeatures().map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 18, color: scheme.primary),
                    const SizedBox(width: 12),
                    Text(f, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          PrimaryAdaptiveButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

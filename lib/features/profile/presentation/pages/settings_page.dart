import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDarkMode = currentTheme == shadcnui.ThemeMode.dark;
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final contact = analyticsState.contact;
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);

    final selectedCurrency = useState<String?>(contact?.preferredCurrency?.toUpperCase());
    final isSaving = useState(false);

    useEffect(() {
      selectedCurrency.value = contact?.preferredCurrency?.toUpperCase();
      return null;
    }, [contact?.preferredCurrency]);

    final currencies = getAvailableCurrencyOptions();

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: shadcnui.IconButton(
          variance: shadcnui.ButtonVariance.ghost,
          icon: Icon(Icons.arrow_back, color: colorScheme.foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  shadcnui.Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(value ? shadcnui.ThemeMode.dark : shadcnui.ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
            const shadcnui.Gap(24),
            Text(
              'Membership',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            _MembershipCard(
              colorScheme: colorScheme,
              subscriptionAsync: subscriptionAsync,
            ),
            const shadcnui.Gap(24),
            Text(
              'Currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Text(
                      'Currency',
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: _CurrencyDropdown(
                      colorScheme: colorScheme,
                      options: currencies,
                      selected: selectedCurrency.value,
                      isSaving: isSaving.value,
                      onChanged: (code) async {
                            if (code == null) return;
                            final normalized = code.toUpperCase();
                            if (normalized == selectedCurrency.value) return;

                            if (!isSupportedCurrencyCode(normalized)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unsupported currency code: $normalized'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                              return;
                            }

                            if (authState.uid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please sign in to update your currency.'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                              return;
                            }

                            isSaving.value = true;
                            try {
                              final response = await supabase.functions.invoke(
                                'update-preferred-currency',
                                body: {
                                  'userId': authState.uid,
                                  'currency': normalized,
                                },
                              );

                              final status = response.status;
                              if (status >= 400) {
                                throw Exception('Request failed ($status)');
                              }

                              final payload = response.data as Map<String, dynamic>?;
                              if (payload == null || payload['ok'] != true) {
                                final message = payload?['error'] as String? ?? 'Unable to update currency';
                                throw Exception(message);
                              }

                              selectedCurrency.value = normalized;
                              ref.read(analyticsProvider.notifier).updatePreferredCurrency(normalized);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Currency updated to $normalized'),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            } catch (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update currency: $error'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                            } finally {
                              isSaving.value = false;
                            }
                          },
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.colorScheme,
    required this.options,
    required this.selected,
    required this.isSaving,
    required this.onChanged,
  });

  final shadcnui.ColorScheme colorScheme;
  final Map<String, String> options;
  final String? selected;
  final bool isSaving;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = selected?.toUpperCase();
    final current = normalizedSelected != null && options.containsKey(normalizedSelected)
        ? normalizedSelected
        : options.keys.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.5), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          icon: isSaving
              ? SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                )
              : Icon(Icons.keyboard_arrow_down, size: 16, color: colorScheme.mutedForeground),
          isDense: true,
          isExpanded: true,
          dropdownColor: colorScheme.card,
          style: TextStyle(color: colorScheme.foreground, fontSize: 13, fontWeight: FontWeight.w500),
          items: options.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.value}  ${entry.key}'),
                ),
              )
              .toList(),
          onChanged: isSaving ? null : onChanged,
        ),
      ),
    );
  }
}

class _MembershipCard extends ConsumerWidget {
  const _MembershipCard({
    required this.colorScheme,
    required this.subscriptionAsync,
  });

  final shadcnui.ColorScheme colorScheme;
  final AsyncValue<SubscriptionDetails?> subscriptionAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: subscriptionAsync.when(
        loading: () => Row(
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 20,
              color: colorScheme.mutedForeground,
            ),
            const shadcnui.Gap(16),
            Expanded(
              child: Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
          ],
        ),
        error: (error, _) => Row(
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 20,
              color: colorScheme.destructive,
            ),
            const shadcnui.Gap(16),
            Expanded(
              child: Text(
                'Failed to load membership',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            shadcnui.IconButton(
              variance: shadcnui.ButtonVariance.ghost,
              icon: Icon(Icons.refresh, size: 16, color: colorScheme.mutedForeground),
              onPressed: () {
                ref.read(subscriptionManagementProvider.notifier).refresh();
              },
            ),
          ],
        ),
        data: (subscriptionDetails) {
          final plan = subscriptionDetails?.planDisplayName ?? 'Free';
          final status = subscriptionDetails?.statusDisplayName ?? 'Free plan';
          final isActive = subscriptionDetails?.hasActiveSubscription ?? false;
          final renewalInfo = subscriptionDetails?.renewalInfo;
          final isTrialing = subscriptionDetails?.isTrialing ?? false;
          final isCanceled = subscriptionDetails?.isCanceled ?? false;
          final isPastDue = subscriptionDetails?.isPastDue ?? false;
          final isLifetime = subscriptionDetails?.isLifetime ?? false;

          // Determine icon and color based on subscription state
          IconData icon;
          Color iconColor;
          
          if (isPastDue) {
            icon = Icons.warning_outlined;
            iconColor = AppTheme.danger;
          } else if (isCanceled) {
            icon = Icons.card_membership_outlined;
            iconColor = colorScheme.mutedForeground;
          } else if (isTrialing) {
            icon = Icons.schedule_outlined;
            iconColor = AppTheme.warning;
          } else if (isActive) {
            icon = isLifetime ? Icons.stars : Icons.card_membership;
            iconColor = AppTheme.success;
          } else {
            icon = Icons.card_membership_outlined;
            iconColor = colorScheme.mutedForeground;
          }

          return Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: iconColor,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const shadcnui.Gap(2),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            color: isPastDue 
                                ? AppTheme.danger 
                                : isTrialing 
                                    ? AppTheme.warning 
                                    : colorScheme.mutedForeground,
                            fontWeight: isPastDue || isTrialing ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  shadcnui.IconButton(
                    variance: shadcnui.ButtonVariance.ghost,
                    icon: Icon(Icons.open_in_new, size: 16, color: colorScheme.mutedForeground),
                    onPressed: () async {
                      final url = Uri.parse('https://moneko.io/dashboard/user-settings/membership');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Could not open membership page'),
                            backgroundColor: colorScheme.destructive,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              // Show renewal/expiry information
              if (renewalInfo != null) ...[
                const shadcnui.Gap(8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRenewalInfoBackgroundColor(subscriptionDetails, colorScheme),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getRenewalInfoBorderColor(subscriptionDetails, colorScheme),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRenewalInfoIcon(subscriptionDetails),
                        size: 14,
                        color: _getRenewalInfoTextColor(subscriptionDetails, colorScheme),
                      ),
                      const shadcnui.Gap(6),
                      Text(
                        renewalInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getRenewalInfoTextColor(subscriptionDetails, colorScheme),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _getRenewalInfoBackgroundColor(SubscriptionDetails? details, shadcnui.ColorScheme colorScheme) {
    if (details == null) return colorScheme.muted.withValues(alpha: 0.1);

    if (details.isTrialing) {
      return AppTheme.warning.withValues(alpha: 0.1);
    } else if (details.isCanceled || details.isPastDue) {
      return AppTheme.danger.withValues(alpha: 0.1);
    } else if (details.isActive) {
      return AppTheme.success.withValues(alpha: 0.1);
    }

    return colorScheme.muted.withValues(alpha: 0.1);
  }

  Color _getRenewalInfoBorderColor(SubscriptionDetails? details, shadcnui.ColorScheme colorScheme) {
    if (details == null) return colorScheme.border;

    if (details.isTrialing) {
      return AppTheme.warning.withValues(alpha: 0.3);
    } else if (details.isCanceled || details.isPastDue) {
      return AppTheme.danger.withValues(alpha: 0.3);
    } else if (details.isActive) {
      return AppTheme.success.withValues(alpha: 0.3);
    }

    return colorScheme.border;
  }

  Color _getRenewalInfoTextColor(SubscriptionDetails? details, shadcnui.ColorScheme colorScheme) {
    if (details == null) return colorScheme.mutedForeground;

    if (details.isTrialing) {
      return AppTheme.warning;
    } else if (details.isCanceled || details.isPastDue) {
      return AppTheme.danger;
    } else if (details.isActive) {
      return AppTheme.success;
    }

    return colorScheme.mutedForeground;
  }

  IconData _getRenewalInfoIcon(SubscriptionDetails? details) {
    if (details == null) return Icons.info_outlined;

    if (details.isTrialing) {
      return Icons.schedule_outlined;
    } else if (details.isCanceled) {
      return Icons.event_busy_outlined;
    } else if (details.isPastDue) {
      return Icons.warning_outlined;
    } else if (details.isActive) {
      return Icons.event_outlined;
    }

    return Icons.info_outlined;
  }
}

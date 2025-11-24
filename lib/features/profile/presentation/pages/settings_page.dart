import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/destructive-adaptive-button.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_binding_card.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDarkMode = currentTheme == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final contact = analyticsState.contact;
    final subscriptionAsync = ref.watch(subscriptionManagementProvider);

    final selectedCurrency =
        useState<String?>(contact?.preferredCurrency?.toUpperCase());
    final nameReloadKey = useState(0);

    useEffect(() {
      selectedCurrency.value = contact?.preferredCurrency?.toUpperCase();
      return null;
    }, [contact?.preferredCurrency]);

    Future<void> handleNotificationToggle() async {
      try {
        final status = await Permission.notification.status;

        if (status.isDenied || status.isPermanentlyDenied) {
          await AppSettings.openAppSettings(
            type: AppSettingsType.notification,
            asAnotherTask: true,
          );

          if (context.mounted) {
            AppToast.info(context, context.l10n.enableNotificationsInSettings);
          }
        } else if (status.isGranted) {
          try {
            await ref.read(deviceRegistrationServiceProvider).initialize();
          } catch (e) {
            debugPrint('Error initializing notifications: $e');
          }
        } else {
          final newStatus = await Permission.notification.request();
          if (newStatus.isGranted) {
            try {
              await ref.read(deviceRegistrationServiceProvider).initialize();
            } catch (e) {
              debugPrint('Error initializing notifications: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error handling notification toggle: $e');
      }
    }

    final selectedLocale = ref.watch(localeProvider);
    const supportedLocales = AppLocalizations.supportedLocales;
    final dropdownValue = _coerceToSupported(selectedLocale, supportedLocales);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.settings,
      ),
      floatingActionButton: kDebugMode
          ? AdaptiveFloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Bottom Sheet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: scheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Press to show a global AppToast above this sheet.',
                              style: TextStyle(color: scheme.mutedForeground),
                            ),
                            const SizedBox(height: 16),
                            AdaptiveButton(
                              onPressed: () {
                                AppToast.success(
                                  context,
                                  'Hello from bottom sheet!',
                                );
                              },
                              label: 'Show Toast',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Icon(Icons.bug_report),
            )
          : null,
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                Center(
                  child: FutureBuilder<Map<String, dynamic>?>(
                    key: ValueKey('avatar-${nameReloadKey.value}'),
                    future: Supabase.instance.client
                        .from('users')
                        .select('full_name, avatar_url')
                        .eq('id', authState.uid)
                        .maybeSingle(),
                    builder: (context, snapshot) {
                      final dbName = snapshot.data != null
                          ? snapshot.data!['full_name'] as String?
                          : null;
                      final dbAvatarUrl = snapshot.data != null
                          ? snapshot.data!['avatar_url'] as String?
                          : null;

                      final displayName = (dbName?.trim().isNotEmpty == true)
                          ? dbName!.trim()
                          : (authState.displayName?.trim().isNotEmpty == true
                              ? authState.displayName!.trim()
                              : 'User');
                      final initials = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : (authState.email.isNotEmpty
                              ? authState.email.substring(0, 1).toUpperCase()
                              : 'U');

                      String? validatedAvatarUrl;
                      if (dbAvatarUrl != null &&
                          dbAvatarUrl.isNotEmpty &&
                          dbAvatarUrl != 'SKIPPED' &&
                          (dbAvatarUrl.startsWith('http://') ||
                              dbAvatarUrl.startsWith('https://'))) {
                        validatedAvatarUrl = dbAvatarUrl;
                      }

                      final avatarUrl = validatedAvatarUrl ??
                          (authState.photoUrl != null &&
                                  authState.photoUrl!.isNotEmpty
                              ? authState.photoUrl
                              : null);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/avatar'),
                            child: Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: avatarUrl != null
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF7458FF),
                                          Color(0xFF836DFF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarUrl != null
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _InitialsAvatar(initials: initials),
                                      )
                                    : _InitialsAvatar(initials: initials),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Material(
                              color: colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => context.push('/avatar'),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.appBackground,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: colorScheme.primaryForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Section
                _SectionHeader(title: context.l10n.fullName),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey('name-${nameReloadKey.value}'),
                  future: Supabase.instance.client
                      .from('users')
                      .select('full_name')
                      .eq('id', authState.uid)
                      .maybeSingle(),
                  builder: (context, snapshot) {
                    final dbName = snapshot.data != null
                        ? snapshot.data!['full_name'] as String?
                        : null;
                    final currentName = (dbName?.trim().isNotEmpty == true)
                        ? dbName!.trim()
                        : (authState.displayName?.trim().isNotEmpty == true
                            ? authState.displayName!.trim()
                            : '');

                    return AdaptiveListTile(
                      leading: Icon(
                        Icons.person_outline,
                        size: 20,
                        color: colorScheme.mutedForeground,
                      ),
                      title: Text(
                        currentName.isEmpty
                            ? context.l10n.fullName
                            : currentName,
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.mutedForeground,
                      ),
                      onTap: () => _showEditNameSheet(
                        context: context,
                        ref: ref,
                        initialName: currentName,
                        onUpdated: () {
                          nameReloadKey.value++;
                          ref.invalidate(userProfileProvider(authState.uid));
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Language Section
                _SectionHeader(title: context.l10n.language),
                const SizedBox(height: 12),
                AdaptiveCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 20,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Locale?>(
                            isExpanded: true,
                            value: dropdownValue,
                            items: [
                              DropdownMenuItem<Locale?>(
                                value: null,
                                child: Text(
                                  context.l10n.systemDefault,
                                  style: TextStyle(
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ),
                              ...supportedLocales.map(
                                (locale) => DropdownMenuItem<Locale?>(
                                  value: locale,
                                  child: Text(
                                    _displayLocaleName(locale),
                                    style: TextStyle(
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value == null) {
                                await ref
                                    .read(localeProvider.notifier)
                                    .setSystem();
                              } else {
                                await ref
                                    .read(localeProvider.notifier)
                                    .setLocale(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Appearance Section
                _SectionHeader(title: context.l10n.appearance),
                const SizedBox(height: 12),
                AdaptiveListTile(
                  leading: Icon(
                    Icons.dark_mode_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  title: Text(
                    context.l10n.darkMode,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: AdaptiveSwitch(
                    value: isDarkMode,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Notifications Section
                _SectionHeader(title: context.l10n.notifications),
                const SizedBox(height: 12),
                AdaptiveListTile(
                  leading: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  title: Text(
                    context.l10n.pushNotifications,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.receiveAlertsAndUpdates,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: colorScheme.mutedForeground,
                  ),
                  onTap: () => handleNotificationToggle(),
                ),
                const SizedBox(height: 24),

                // WhatsApp Binding
                buildWhatsAppBindingCard(context, ref),
                const SizedBox(height: 24),

                // Membership Section
                _SectionHeader(title: context.l10n.membership),
                const SizedBox(height: 12),
                _MembershipCard(
                  colorScheme: colorScheme,
                  subscriptionAsync: subscriptionAsync,
                ),
                const SizedBox(height: 32),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: DestructiveAdaptiveButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(deviceRegistrationServiceProvider)
                            .unregisterDevice();
                      } catch (_) {}

                      debugPrint(
                        '🧹 Clearing all user-specific Riverpod state before logout',
                      );

                      // Analytics and expenses
                      ref.invalidate(analyticsProvider);

                      // Households
                      ref.invalidate(userHouseholdsProvider);
                      ref.invalidate(householdExpensesProvider);
                      ref.invalidate(householdSplitsProvider);
                      ref.invalidate(householdBudgetsProvider);
                      ref.invalidate(householdSummaryProvider);
                      ref.invalidate(householdMembersProvider);
                      ref.invalidate(selectedHouseholdProvider);

                      // View mode and filters
                      ref.invalidate(viewModeProvider);
                      ref.invalidate(homeFilterProvider);

                      // Income
                      ref.invalidate(incomeSummaryProvider);
                      ref.invalidate(incomeListProvider);

                      // Goals
                      ref.invalidate(goalsListProvider);
                      ref.invalidate(goalSummaryProvider);

                      // Subscription
                      ref.invalidate(subscriptionManagementProvider);

                      // User profile
                      ref.invalidate(userProfileProvider);

                      // Pockets (budget envelopes)
                      ref.invalidate(pocketsProvider);

                      // Recurring transactions
                      ref.invalidate(recurringTransactionsProvider);
                      ref.invalidate(recurringTransactionSaveProvider);
                      ref.invalidate(selectedRecurringTabProvider);

                      debugPrint('✅ All user-specific state cleared');

                      // Sign out from auth last (this will trigger navigation to login)
                      await ref.read(authProvider.notifier).signOut();
                    },
                    child: Text(context.l10n.signOut),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.mutedForeground,
        letterSpacing: 0.5,
      ),
    );
  }
}

Future<void> _showEditNameSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String initialName,
  required VoidCallback onUpdated,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final controller = TextEditingController(text: initialName);
  final authState = ref.read(authProvider);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      AppLocalizations.of(ctx)!.fullName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 20),

                // Text Field
                AdaptiveTextField(
                  controller: controller,
                  placeholder: AppLocalizations.of(ctx)!.fullName,
                  autofocus: true,
                  onSubmitted: (_) async => await _saveName(
                    ctx,
                    ref,
                    controller,
                    authState.uid,
                    setState,
                    onUpdated,
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: AdaptiveButton(
                        style: AdaptiveButtonStyle.plain,
                        onPressed: () => Navigator.of(ctx).pop(),
                        label: AppLocalizations.of(ctx)!.cancel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdaptiveButton(
                        onPressed: () async {
                          await _saveName(
                            ctx,
                            ref,
                            controller,
                            authState.uid,
                            setState,
                            onUpdated,
                          );
                        },
                        label: AppLocalizations.of(ctx)!.save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _saveName(
  BuildContext ctx,
  WidgetRef ref,
  TextEditingController controller,
  String userId,
  void Function(void Function()) setState,
  VoidCallback onUpdated,
) async {
  final newName = controller.text.trim();
  if (newName.isEmpty || newName.length < 2) {
    setState(() {});
    AppToast.info(ctx, 'Please enter a valid name');
    return;
  }

  try {
    setState(() {});
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {
        'full_name': newName,
        'name': newName,
      }),
    );

    await Supabase.instance.client.from('users').update({
      'full_name': newName,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', userId);

    onUpdated();

    if (!ctx.mounted) return;
    Navigator.of(ctx).pop();
    AppToast.success(ctx, 'Profile updated');
  } catch (e) {
    if (ctx.mounted) {
      AppToast.error(ctx, 'Failed to update: $e');
    }
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
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

  final ColorScheme colorScheme;
  final AsyncValue<SubscriptionDetails?> subscriptionAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: subscriptionAsync.when(
        loading: () => Row(
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 20,
              color: colorScheme.mutedForeground,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.l10n.loading,
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
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.l10n.failedToLoadMembership,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh,
                size: 16,
                color: colorScheme.mutedForeground,
              ),
              onPressed: () {
                ref.read(subscriptionManagementProvider.notifier).refresh();
              },
            ),
          ],
        ),
        data: (subscriptionDetails) {
          final plan = _getLocalizedPlanName(subscriptionDetails, context);
          final status = _getLocalizedStatusName(subscriptionDetails, context);
          final renewalInfo =
              _getLocalizedRenewalInfo(subscriptionDetails, context);
          final isActive = subscriptionDetails?.hasActiveSubscription ?? false;
          final isTrialing = subscriptionDetails?.isTrialing ?? false;
          final isCanceled = subscriptionDetails?.isCanceled ?? false;
          final isPastDue = subscriptionDetails?.isPastDue ?? false;
          final isLifetime = subscriptionDetails?.isLifetime ?? false;

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
                  const SizedBox(width: 16),
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
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            color: isPastDue
                                ? AppTheme.danger
                                : isTrialing
                                    ? AppTheme.warning
                                    : colorScheme.mutedForeground,
                            fontWeight: isPastDue || isTrialing
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse(
                        'https://moneko.io/dashboard/user-settings/membership',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          AppToast.error(
                            context,
                            context.l10n.couldNotOpenMembershipPage,
                          );
                        }
                      }
                    },
                    child: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              if (renewalInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getRenewalInfoBackgroundColor(
                      subscriptionDetails,
                      colorScheme,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRenewalInfoIcon(subscriptionDetails),
                        size: 14,
                        color: _getRenewalInfoTextColor(
                          subscriptionDetails,
                          colorScheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        renewalInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getRenewalInfoTextColor(
                            subscriptionDetails,
                            colorScheme,
                          ),
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

  String _getLocalizedPlanName(
      SubscriptionDetails? details, BuildContext context) {
    if (details == null || details.subscription?.plan == null) {
      return context.l10n.freePlan;
    }

    switch (details.subscription!.plan!.toLowerCase()) {
      case 'lifetime':
        return context.l10n.lifetimePlan;
      case 'plus':
        return context.l10n.plusPlan;
      case 'monthly':
        return context.l10n.plusMonthlyPlan;
      case 'yearly':
        return context.l10n.plusYearlyPlan;
      default:
        return details.subscription!.plan!.toUpperCase();
    }
  }

  String _getLocalizedStatusName(
      SubscriptionDetails? details, BuildContext context) {
    if (details == null || details.subscription?.plan == null) {
      return context.l10n.freePlanStatus;
    }

    if (details.subscription!.plan!.toLowerCase() == 'free') {
      return context.l10n.freePlanStatus;
    }

    switch (details.subscription!.status?.toLowerCase()) {
      case 'active':
        return details.isLifetime
            ? context.l10n.activeLifetimeStatus
            : context.l10n.activeStatus;
      case 'canceled':
        return context.l10n.canceledStatus;
      case 'past_due':
        return context.l10n.pastDueStatus;
      case 'trialing':
        return context.l10n.trialStatus;
      default:
        return details.subscription!.status ?? context.l10n.freePlanStatus;
    }
  }

  String? _getLocalizedRenewalInfo(
      SubscriptionDetails? details, BuildContext context) {
    if (details == null || details.subscription == null || details.isLifetime) {
      return null;
    }

    final subscription = details.subscription!;
    final status = subscription.status?.toLowerCase();

    if (status == 'trialing' && subscription.currentPeriodEnd != null) {
      final trialEnd = subscription.currentPeriodEnd!;
      final now = DateTime.now();
      final daysLeft = trialEnd.difference(now).inDays;

      if (daysLeft > 0) {
        return context.l10n.trialEndsInDays(daysLeft);
      } else {
        return context.l10n.trialEnded;
      }
    }

    if (status == 'active' &&
        details.daysUntilNextPayment != null &&
        details.daysUntilNextPayment! > 0) {
      return context.l10n.renewsInDays(details.daysUntilNextPayment!);
    }

    if (status == 'canceled' && subscription.currentPeriodEnd != null) {
      final endDate = subscription.currentPeriodEnd!;
      final now = DateTime.now();
      final daysLeft = endDate.difference(now).inDays;

      if (daysLeft > 0) {
        return context.l10n.accessEndsInDays(daysLeft);
      } else {
        return context.l10n.subscriptionEnded;
      }
    }

    return null;
  }

  Color _getRenewalInfoBackgroundColor(
      SubscriptionDetails? details, ColorScheme colorScheme) {
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

  Color _getRenewalInfoTextColor(
      SubscriptionDetails? details, ColorScheme colorScheme) {
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

String _displayLocaleName(Locale locale) {
  final lc = locale.languageCode.toLowerCase();
  final cc = (locale.countryCode ?? '').toUpperCase();

  if (lc == 'de') return 'Deutsch';
  if (lc == 'en') return 'English';
  if (lc == 'es') return 'Español';
  if (lc == 'fr') return 'Français';
  if (lc == 'ja' || lc == 'jp') return '日本語';
  if (lc == 'ko' || lc == 'kr') return '한국어';
  if (lc == 'nl') return 'Nederlands';
  if (lc == 'ur' || lc == 'pk') return 'اردو';
  if (lc == 'ru') return 'Русский';
  if (lc == 'uk' || lc == 'ua') return 'Українська';
  if (lc == 'it') return 'Italiano';
  if (lc == 'vi') return 'Tiếng Việt';

  if (lc == 'zh' || lc == 'cn') {
    if (cc == 'CN' || cc.isEmpty) return '简体中文';
    if (cc == 'TW' || cc == 'HK' || cc == 'MO') return '繁體中文';
    return '中文';
  }

  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

Locale? _coerceToSupported(Locale? selected, List<Locale> supported) {
  if (selected == null) return null;
  for (final l in supported) {
    if (l.languageCode.toLowerCase() == selected.languageCode.toLowerCase() &&
        (l.countryCode ?? '').toUpperCase() ==
            (selected.countryCode ?? '').toUpperCase()) {
      return l;
    }
  }
  for (final l in supported) {
    if (l.languageCode.toLowerCase() == selected.languageCode.toLowerCase()) {
      return l;
    }
  }
  return null;
}

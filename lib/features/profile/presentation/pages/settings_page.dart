import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';

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
    final nameReloadKey = useState(0);

    useEffect(() {
      selectedCurrency.value = contact?.preferredCurrency?.toUpperCase();
      return null;
    }, [contact?.preferredCurrency]);


    Future<void> handleNotificationToggle() async {
      try {
        // User wants to enable notifications
        final status = await Permission.notification.status;
        
        if (status.isDenied || status.isPermanentlyDenied) {
          // Permission was denied, open Moneko's notification settings page specifically
          await AppSettings.openAppSettings(
            type: AppSettingsType.notification,
            asAnotherTask: true,
          );
          
          // Show info dialog
          if (context.mounted) {
            shadcnui.showToast(
              context: context,
              builder: (context, overlay) => shadcnui.Alert(
                leading: const Icon(Icons.info_outline),
                title: shadcnui.Text(context.l10n.enableNotificationsInSettings),
              ),
            );
          }
        } else if (status.isGranted) {
          // Already granted, re-initialize device registration
          try {
            await ref.read(deviceRegistrationServiceProvider).initialize();
          } catch (e) {
            debugPrint('Error initializing notifications: $e');
          }
        } else {
          // Request permission
          final newStatus = await Permission.notification.request();
          if (newStatus.isGranted) {
            // Initialize device registration
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

    final currencies = getAvailableCurrencyOptions();
    final selectedLocale = ref.watch(localeProvider);
    final supportedLocales = AppLocalizations.supportedLocales;
    final dropdownValue = _coerceToSupported(selectedLocale, supportedLocales);

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
          context.l10n.settings,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Avatar with edit (pencil) overlay
            Center(
              child: FutureBuilder<Map<String, dynamic>?>(
                key: ValueKey('avatar-${nameReloadKey.value}'),
                future: Supabase.instance.client
                    .from('users')
                    .select('full_name, avatar_url')
                    .eq('id', authState.uid)
                    .maybeSingle(),
                builder: (context, snapshot) {
                  final dbName = snapshot.data != null ? snapshot.data!['full_name'] as String? : null;
                  final dbAvatarUrl = snapshot.data != null ? snapshot.data!['avatar_url'] as String? : null;

                  final displayName = (dbName?.trim().isNotEmpty == true)
                      ? dbName!.trim()
                      : (authState.displayName?.trim().isNotEmpty == true ? authState.displayName!.trim() : 'User');
                  final initials = displayName.isNotEmpty
                      ? displayName.substring(0, 1).toUpperCase()
                      : (authState.email.isNotEmpty ? authState.email.substring(0, 1).toUpperCase() : 'U');
                  final avatarUrl = (dbAvatarUrl != null && dbAvatarUrl.isNotEmpty)
                      ? dbAvatarUrl
                      : (authState.photoUrl != null && authState.photoUrl!.isNotEmpty ? authState.photoUrl : null);

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
                                    colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.25),
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
                                    errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials),
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
                                border: Border.all(color: colorScheme.background, width: 3),
                              ),
                              child: Icon(Icons.edit, size: 18, color: colorScheme.primaryForeground),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const shadcnui.Gap(24),
            // Full name (tap to edit)
            Text(
              context.l10n.fullName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            FutureBuilder<Map<String, dynamic>?>(
              key: ValueKey('name-${nameReloadKey.value}'),
              future: Supabase.instance.client
                  .from('users')
                  .select('full_name')
                  .eq('id', authState.uid)
                  .maybeSingle(),
              builder: (context, snapshot) {
                final dbName = snapshot.data != null ? snapshot.data!['full_name'] as String? : null;
                final currentName = (dbName?.trim().isNotEmpty == true)
                    ? dbName!.trim()
                    : (authState.displayName?.trim().isNotEmpty == true ? authState.displayName!.trim() : '');

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.border, width: 1),
                  ),
                  child: InkWell(
                    onTap: () => _showEditNameSheet(
                      context: context,
                      ref: ref,
                      initialName: currentName,
                      onUpdated: () {
                        // Force refetch and invalidate user profile provider for consumers
                        nameReloadKey.value++;
                        ref.invalidate(userProfileProvider(authState.uid));
                      },
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 20,
                          color: colorScheme.mutedForeground,
                        ),
                        const shadcnui.Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          
                              Text(
                                currentName.isNotEmpty ? currentName : '—',
                                 style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: colorScheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const shadcnui.Gap(24),
            // Language
            Text(
              context.l10n.language,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical:4),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.language_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Text(
                      context.l10n.language,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Locale?>(
                      value: dropdownValue,
                      alignment: Alignment.centerRight,
                      dropdownColor: colorScheme.card,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.mutedForeground),
                      items: [
                        DropdownMenuItem<Locale?>(
                          value: null,
                          child: Text(
                            context.l10n.systemDefault,
                            style: TextStyle(color: colorScheme.foreground),
                          ),
                        ),
                        ...AppLocalizations.supportedLocales.map((locale) {
                          return DropdownMenuItem<Locale?>(
                            value: locale,
                            child: Text(
                              _displayLocaleName(locale),
                              style: TextStyle(color: colorScheme.foreground),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) async {
                        final previous = ref.read(localeProvider);
                        final auth = ref.read(authProvider);
                        try {
                          if (value == null) {
                            await ref.read(localeProvider.notifier).setSystem();
                          } else {
                            final lc = value.languageCode.toLowerCase();
                            final cc = (value.countryCode ?? '').toUpperCase();
                            final normalized = lc == 'cn'
                                ? const Locale('zh')
                                : (lc == 'zh' && cc.isEmpty)
                                    ? const Locale('zh')
                                    : value;
                            await ref.read(localeProvider.notifier).setLocale(normalized);
                          }

                          // Persist preference to backend (same flow as currency)
                          if (auth.uid.isNotEmpty) {
                            final selected = ref.read(localeProvider);
                            final langCode = selected == null
                                ? null
                                : selected.languageCode.toLowerCase();

                            try {
                              final resp = await Supabase.instance.client.functions.invoke(
                                'update-preferred-language',
                                body: {
                                  'userId': auth.uid,
                                  'language': langCode,
                                },
                              );
                              if (resp.status >= 400) {
                                throw Exception('Request failed (${resp.status})');
                              }
                              final payload = resp.data as Map<String, dynamic>?;
                              if (payload == null || payload['ok'] != true) {
                                throw Exception(payload?['error'] ?? 'Unable to update language');
                              }
                            } catch (e) {
                              // Rollback locale on failure
                              if (previous == null) {
                                await ref.read(localeProvider.notifier).setSystem();
                              } else {
                                await ref.read(localeProvider.notifier).setLocale(previous);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to sync language preference: $e'),
                                    action: SnackBarAction(
                                      label: 'Retry',
                                      onPressed: () async {
                                        try {
                                          final sel = ref.read(localeProvider);
                                          final code = sel == null ? null : sel.languageCode.toLowerCase();
                                          final retry = await Supabase.instance.client.functions.invoke(
                                            'update-preferred-language',
                                            body: {
                                              'userId': auth.uid,
                                              'language': code,
                                            },
                                          );
                                          if (retry.status >= 400) throw Exception('Retry failed');
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: const Text('Language updated successfully')),
                                            );
                                          }
                                        } catch (_) {}
                                      },
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
            ),
            const shadcnui.Gap(24),
            Text(
              context.l10n.appearance,
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
                      context.l10n.darkMode,
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
              context.l10n.notifications,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            InkWell(
              onTap: () => handleNotificationToggle(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.border, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 20,
                      color: colorScheme.mutedForeground,
                    ),
                    const shadcnui.Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.pushNotifications,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const shadcnui.Gap(2),
                          Text(
                            context.l10n.receiveAlertsAndUpdates,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.card_membership_outlined,
                      size: 20,
                      color: colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            const shadcnui.Gap(24),
            Text(
              context.l10n.membership,
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
            const shadcnui.Gap(32),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: shadcnui.DestructiveButton(
                onPressed: () async {
                  // Best-effort: unregister device and clear local token before auth is cleared
                  try {
                    await ref.read(deviceRegistrationServiceProvider).unregisterDevice();
                  } catch (_) {}
                  await ref.read(authProvider.notifier).signOut();
                },
                child: Text(context.l10n.signOut),
              ),
            ),
          ],
        ),
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
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  final controller = TextEditingController(text: initialName);
  final authState = ref.read(authProvider);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      bool isSaving = false;
      String? errorText;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(ctx)!.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(ctx)!.fullName,
                    errorText: errorText,
                    filled: true,
                    fillColor: colorScheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async => await _saveName(ctx, ref, controller, authState.uid, setState, onUpdated),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: shadcnui.OutlineButton(
                        onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                        child: Text(AppLocalizations.of(ctx)!.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: shadcnui.PrimaryButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                await _saveName(ctx, ref, controller, authState.uid, setState, onUpdated);
                              },
                        child: isSaving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colorScheme.primaryForeground)),
                              )
                            : Text(AppLocalizations.of(ctx)!.save),
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
  final colorScheme = shadcnui.Theme.of(ctx).colorScheme;
  final newName = controller.text.trim();
  if (newName.isEmpty || newName.length < 2) {
    setState(() {}); // keep UI responsive; validation shown via snackbar below
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Please enter a valid name')), // concise default copy
    );
    return;
  }

  try {
    setState(() {});
    // Update Supabase Auth metadata (both keys for cross-platform consistency)
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {
        'full_name': newName,
        'name': newName,
      }),
    );

    // Update public users table
    await Supabase.instance.client
        .from('users')
        .update({'full_name': newName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);

    // Invalidate Riverpod-derived profile data and notify
    onUpdated();

    Navigator.of(ctx).pop();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Profile updated'),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Failed to update: $e')),
    );
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
            const shadcnui.Gap(16),
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
          // Get localized display names
          final plan = _getLocalizedPlanName(subscriptionDetails, context);
          final status = _getLocalizedStatusName(subscriptionDetails, context);
          final renewalInfo = _getLocalizedRenewalInfo(subscriptionDetails, context);
          final isActive = subscriptionDetails?.hasActiveSubscription ?? false;
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
                            content: Text(context.l10n.couldNotOpenMembershipPage),
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

  String _getLocalizedPlanName(SubscriptionDetails? details, BuildContext context) {
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

  String _getLocalizedStatusName(SubscriptionDetails? details, BuildContext context) {
    if (details == null || details.subscription?.plan == null) {
      return context.l10n.freePlanStatus;
    }

    if (details.subscription!.plan!.toLowerCase() == 'free') {
      return context.l10n.freePlanStatus;
    }

    switch (details.subscription!.status?.toLowerCase()) {
      case 'active':
        return details.isLifetime ? context.l10n.activeLifetimeStatus : context.l10n.activeStatus;
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

  String? _getLocalizedRenewalInfo(SubscriptionDetails? details, BuildContext context) {
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

    if (status == 'active' && details.daysUntilNextPayment != null && details.daysUntilNextPayment! > 0) {
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

String _displayLocaleName(Locale locale) {
  final lc = locale.languageCode.toLowerCase();
  final cc = (locale.countryCode ?? '').toUpperCase();

  // German
  if (lc == 'de') return 'Deutsch';
  
  // English
  if (lc == 'en') return 'English';
  
  // Spanish
  if (lc == 'es') return 'Español';
  
  // French
  if (lc == 'fr') return 'Français';
  
  // Japanese
  if (lc == 'ja' || lc == 'jp') return '日本語';
  
  // Korean
  if (lc == 'ko' || lc == 'kr') return '한국어';
  
  // Dutch
  if (lc == 'nl') return 'Nederlands';
  
  // Urdu (Pakistan)
  if (lc == 'ur' || lc == 'pk') return 'اردو';
  
  // Russian
  if (lc == 'ru') return 'Русский';
  
  // Ukrainian
  if (lc == 'uk' || lc == 'ua') return 'Українська';

  // Pakistani
  if ( lc == 'pks') return 'پکستانی';

  // Italian
  if (lc == 'it') return 'Italiano';

  // Chinese (handle various tags and legacy 'cn')
  if (lc == 'zh' || lc == 'cn') {
    // Simplified for CN or script Hans (if present via other configs)
    if (cc == 'CN' || cc.isEmpty) return '简体中文';
    if (cc == 'TW' || cc == 'HK' || cc == 'MO') return '繁體中文';
    return '中文';
  }

  // Fallback: show native name if easy mapping is known; otherwise show BCP-47-ish label
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

Locale? _coerceToSupported(Locale? selected, List<Locale> supported) {
  if (selected == null) return null;
  // exact match
  for (final l in supported) {
    if (l.languageCode.toLowerCase() == selected.languageCode.toLowerCase() &&
        (l.countryCode ?? '').toUpperCase() == (selected.countryCode ?? '').toUpperCase()) {
      return l;
    }
  }
  // language-only match
  for (final l in supported) {
    if (l.languageCode.toLowerCase() == selected.languageCode.toLowerCase()) {
      return l;
    }
  }
  return null;
}

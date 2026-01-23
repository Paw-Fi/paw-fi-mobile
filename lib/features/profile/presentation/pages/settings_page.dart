import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_tutorial_modal.dart';
// import 'package:moneko/features/subscription/data/models/subscription_details.dart'; // Removed unused import
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
// import 'package:moneko/features/profile/presentation/widgets/whatsapp_binding_card.dart'; // Removed unused import
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/moneko_list_picker.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

bool _isAvatarCropInProgress = false;

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
    final selectedTimezone = useState<String?>(contact?.preferredTimezone);
    final nameReloadKey = useState(0);
    final deviceTimezone = _currentDeviceTimezone();
    final deviceOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    useEffect(() {
      selectedCurrency.value = contact?.preferredCurrency?.toUpperCase();
      selectedTimezone.value = contact?.preferredTimezone;
      return null;
    }, [contact?.preferredCurrency, contact?.preferredTimezone]);

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

    Future<void> handleManualNotificationFix() async {
      try {
        try {
          await ref.read(deviceRegistrationServiceProvider).unregisterDevice();
        } catch (e) {
          debugPrint('Error during manual notification unregister: $e');
        }

        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (e) {
          debugPrint('Error re-initializing notifications manually: $e');
        }

        if (context.mounted) {
          AppToast.success(
            context,
            context.l10n.notificationsRefreshedSuccessfully,
          );
        }
      } catch (e) {
        debugPrint('Error handling manual notification fix: $e');
      }
    }

    Future<void> handleClearAppBadge() async {
      try {
        final isSupported = await AppBadgePlus.isSupported();
        if (!isSupported) {
          if (context.mounted) {
            AppToast.info(
              context,
              context.l10n.appIconBadgeNotSupported,
            );
          }
          return;
        }

        AppBadgePlus.updateBadge(0);
        if (context.mounted) {
          AppToast.success(context, context.l10n.appIconBadgeCleared);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.appIconBadgeClearFailed);
        }
      }
    }

    final selectedLocale = ref.watch(localeProvider);
    const supportedLocales = AppLocalizations.supportedLocales;
    final dropdownValue = _coerceToSupported(selectedLocale, supportedLocales);
    final timezoneValue = selectedTimezone.value ?? 'UTC';
    final timezoneDisplay = _formatTimezoneLabel(
      _resolveTimezoneOption(
        timezone: timezoneValue,
        fallbackOffsetMinutes: deviceOffsetMinutes,
        preferFallback: timezoneValue == deviceTimezone,
      ),
    );
    final timezoneOptions = _buildTimezoneOptionsList(
      deviceTimezone: deviceTimezone,
      currentTimezone: selectedTimezone.value,
      deviceOffsetMinutes: deviceOffsetMinutes,
    );
    final packageInfo =
        useFuture(useMemoized(() => PackageInfo.fromPlatform()));
    final currentTimezoneOption = timezoneOptions.firstWhere(
      (option) => option.value == timezoneValue,
      orElse: () => timezoneOptions.first,
    );

    Future<void> handleTimezoneChange(String timezone) async {
      final previous = selectedTimezone.value;
      selectedTimezone.value = timezone;
      try {
        await Supabase.instance.client.functions.invoke(
          'update-preferred-timezone',
          body: {
            'userId': authState.uid,
            'timezone': timezone,
          },
        );
        ref.invalidate(analyticsProvider);
        if (context.mounted) {
          AppToast.success(context, context.l10n.timezoneUpdated);
        }
      } catch (e) {
        selectedTimezone.value = previous;
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.timezoneUpdateFailed(e.toString()),
          );
        }
      }
    }

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
                            material.Text(
                              'Debug Menu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: scheme.foreground,
                              ),
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
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Premium Profile Header
                _ProfileHeader(
                  authState: authState,
                  nameReloadKey: nameReloadKey.value,
                  onAvatarTap: () => _showAvatarSourceSheet(
                    context,
                    ref,
                    () {
                      nameReloadKey.value++;
                      if (authState.uid.isNotEmpty) {
                        ref.invalidate(userProfileProvider(authState.uid));
                      }
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Account Settings Group
                _SettingsGroup(
                  title: context.l10n.account,
                  children: [
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

                        return _SettingsTile(
                          icon: Icons.person_rounded,
                          label: context.l10n.fullName,
                          value: currentName.isEmpty
                              ? context.l10n.tapToSet
                              : currentName,
                          onTap: () => _showEditNameSheet(
                            context: context,
                            ref: ref,
                            initialName: currentName,
                            onUpdated: () {
                              nameReloadKey.value++;
                              ref.invalidate(
                                  userProfileProvider(authState.uid));
                            },
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.email_rounded,
                      label: context.l10n.email,
                      value: authState.email,
                      showChevron: false,
                    ),
                  ],
                ),

                // Preferences Group
                _SettingsGroup(
                  title: context.l10n.preferences,
                  children: [
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      label: context.l10n.language,
                      valueWidget: DropdownButtonHideUnderline(
                        child: DropdownButton<Locale?>(
                          isDense: true,
                          alignment: Alignment.centerRight,
                          icon: Row(
                            children: [
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                          dropdownColor: isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          value: dropdownValue,
                          items: [
                            DropdownMenuItem<Locale?>(
                              value: null,
                              child: Text(
                                context.l10n.systemDefault,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                            ...supportedLocales.map(
                              (locale) => DropdownMenuItem<Locale?>(
                                value: locale,
                                child: Text(
                                  _displayLocaleName(locale),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.mutedForeground,
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
                    _SettingsTile(
                      icon: Icons.public_rounded,
                      label: context.l10n.timezone,
                      value: timezoneDisplay,
                      onTap: () async {
                        final selection =
                            await MonekoListPicker.show<_TimezoneOption>(
                          context: context,
                          items: timezoneOptions,
                          initial: currentTimezoneOption,
                          title: context.l10n.chooseTimezone,
                          labelBuilder: (option) =>
                              _formatTimezoneLabel(option) +
                              (option.value == deviceTimezone
                                  ? ' (${context.l10n.deviceLabel})'
                                  : ''),
                        );
                        if (selection != null &&
                            selection.value != selectedTimezone.value) {
                          await handleTimezoneChange(selection.value);
                        }
                      },
                    ),
                    _SettingsTile(
                      icon: isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: context.l10n.darkMode,
                      trailing: AdaptiveSwitch(
                        value: isDarkMode,
                        onChanged: (value) {
                          ref.read(themeModeProvider.notifier).setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                    ),
                  ],
                ),

                // Integrations
                _SettingsGroup(title: context.l10n.integrations, children: [
                  _SettingsTile(
                    icon: Icons.account_balance_rounded,
                    label: context.l10n.syncBankAccountsTitle,
                    value: context.l10n.comingSoon,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              const PlaidSyncWalkthroughPage(),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    customIcon: SvgPicture.string(
                      _whatsappRealSvg,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: context.l10n.whatsAppConnected,
                    value:
                        ref.watch(whatsAppBindingProvider).asData?.value == true
                            ? context.l10n.activeStatus
                            : context.l10n.tapToSet,
                    onTap: () async {
                      final isBound =
                          ref.read(whatsAppBindingProvider).valueOrNull ??
                              false;
                      if (isBound) {
                        final url = Uri.parse('https://wa.link/zxwtld');
                        try {
                          bool launched = await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                          if (!launched)
                            launched = await launchUrl(url,
                                mode: LaunchMode.inAppBrowserView);
                          if (!launched)
                            await launchUrl(url, mode: LaunchMode.inAppWebView);
                        } catch (_) {
                          if (context.mounted)
                            AppToast.error(
                                context, 'Could not launch WhatsApp');
                        }
                      } else {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => const WhatsAppTutorialModal(),
                        );
                        if (result == true) {
                          ref.invalidate(whatsAppBindingProvider);
                        }
                      }
                    },
                  ),
                ]),

                // Notifications Group
                _SettingsGroup(
                  title: context.l10n.notifications,
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_active_rounded,
                      label: context.l10n.pushNotifications,
                      onTap: () => handleNotificationToggle(),
                    ),
                    _SettingsTile(
                      icon: Icons.build_circle_rounded,
                      label: context.l10n.fixNotificationIssuesTitle,
                      onTap: () => handleManualNotificationFix(),
                    ),
                    _SettingsTile(
                      icon: Icons.remove_circle_outline_rounded,
                      label: context.l10n.clearAppIconBadgeTitle,
                      onTap: () => handleClearAppBadge(),
                    ),
                  ],
                ),

                // Subscription
                // Manage Membership
                _SettingsGroup(
                  title: context.l10n.membership,
                  children: [
                    _SettingsTile(
                      icon: Icons.star_outline_rounded,
                      label: context.l10n.membership,
                      value: subscriptionAsync.when(
                        data: (d) => d?.hasActiveSubscription == true
                            ? 'Premium'
                            : 'Free',
                        loading: () => '...',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () async {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const PlanSelectionPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Sign Out
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DestructiveAdaptiveButton(
                    onPressed: () async {
                      showBlockingProcessingDialog(
                        context: context,
                        message: context.l10n.signingOut,
                      );

                      try {
                        try {
                          await ref
                              .read(deviceRegistrationServiceProvider)
                              .unregisterDevice();
                        } catch (_) {}

                        debugPrint(
                          '🧹 Clearing all user-specific Riverpod state before logout',
                        );

                        await ref
                            .read(selectedHouseholdProvider.notifier)
                            .clearSelection();

                        if (authState.uid.isNotEmpty) {
                          ref.invalidate(userHouseholdsProvider(authState.uid));
                        }

                        // Centralized clean-up for app initialization + primary pages
                        ref
                            .read(appInitializationV2Provider.notifier)
                            .clearCacheAndReset();

                        ref.invalidate(incomeSummaryProvider);
                        ref.invalidate(incomeListProvider);
                        ref.invalidate(goalsListProvider);
                        ref.invalidate(goalSummaryProvider);
                        ref.invalidate(subscriptionManagementProvider);
                        ref.invalidate(userProfileProvider);

                        debugPrint('✅ All user-specific state cleared');

                        await ref.read(authProvider.notifier).signOut();
                      } finally {
                        if (context.mounted) {
                          // Handled by router/auth state change
                        }
                      }
                    },
                    child: material.Text(context.l10n.signOut,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: material.Text(
                    packageInfo.hasData
                        ? 'Version ${packageInfo.data!.version}'
                        : '',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAvatarSourceSheet(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onUpdated,
) async {
  final result = await MonekoActionSheet.show<String>(
    context: context,
    title: context.l10n.changeAvatar,
    actions: [
      MonekoActionSheetAction<String>(
        label: context.l10n.takePhoto,
        value: 'camera',
      ),
      MonekoActionSheetAction<String>(
        label: context.l10n.chooseFromGallery,
        value: 'gallery',
      ),
    ],
    cancelAction: MonekoActionSheetAction<String>(
      label: context.l10n.cancel,
      value: 'cancel',
    ),
  );

  ImageSource? source;
  if (result == 'camera') {
    source = ImageSource.camera;
  } else if (result == 'gallery') {
    source = ImageSource.gallery;
  }

  if (source == null) {
    return;
  }

  if (!context.mounted) return;

  final file = await _pickAndCropAvatarImage(context, source);
  if (file == null || !context.mounted) {
    return;
  }

  if (context.mounted) {
    await _uploadAndSaveAvatar(context, ref, file, onUpdated);
  }
}

Future<File?> _pickAndCropAvatarImage(
  BuildContext context,
  ImageSource source,
) async {
  try {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (image == null) return null;

    final file = File(image.path);
    final fileSize = await file.length();

    if (!StorageConfig.isValidFileSize(fileSize)) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.imageTooLarge} (${StorageConfig.getFileSizeString(fileSize)}). '
          '${context.l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
        );
      }
      return null;
    }

    if (!StorageConfig.isAllowedFormat(image.path)) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.unsupportedFileFormat,
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    if (_isAvatarCropInProgress) {
      return null;
    }

    _isAvatarCropInProgress = true;
    final CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        maxWidth: 800,
        maxHeight: 800,
        compressFormat: ImageCompressFormat.png,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: context.l10n.cropCoverImage,
            toolbarColor: Theme.of(context).colorScheme.appBackground,
            toolbarWidgetColor: Theme.of(context).colorScheme.foreground,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: context.l10n.cropCoverImage,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } finally {
      _isAvatarCropInProgress = false;
    }

    if (croppedFile == null) {
      return null;
    }

    return File(croppedFile.path);
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        context.l10n.failedToProcessImage(e.toString()),
      );
    }
    return null;
  }
}

Future<void> _uploadAndSaveAvatar(
  BuildContext context,
  WidgetRef ref,
  File imageFile,
  VoidCallback onUpdated,
) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  showBlockingProcessingDialog(
    context: context,
    message: context.l10n.updatingAvatar,
  );

  try {
    final bytes = await imageFile.readAsBytes();

    if (!StorageConfig.isValidFileSize(bytes.length)) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.imageTooLarge} (${StorageConfig.getFileSizeString(bytes.length)}). '
          '${context.l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
        );
      }
      return;
    }

    final path = '${user.id}/avatar.png';

    await client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
            cacheControl: '3600',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);
    final cacheBustedUrl =
        '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await client.from('users').update({
      'avatar_url': cacheBustedUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    onUpdated();

    ref.invalidate(userProfileProvider(user.id));

    if (context.mounted) {
      AppToast.success(context, context.l10n.avatarUpdated);
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        context.l10n.failedToSaveAvatar,
      );
    }
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.authState,
    required this.nameReloadKey,
    required this.onAvatarTap,
  });

  final AppUser authState;
  final int nameReloadKey;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Center(
          child: FutureBuilder<Map<String, dynamic>?>(
            key: ValueKey('avatar-$nameReloadKey'),
            future: Supabase.instance.client
                .from('users')
                .select('full_name, avatar_url')
                .eq('id', authState.uid)
                .maybeSingle(),
            builder: (context, snapshot) {
              final dbName = snapshot.data?['full_name'] as String?;
              final dbAvatarUrl = snapshot.data?['avatar_url'] as String?;

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
                  (authState.photoUrl?.isNotEmpty == true
                      ? authState.photoUrl
                      : null);

              return GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? const Color(0xFF1C1C1E)
                              : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF1C1C1E)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: colorScheme.onPrimary,
                        ),
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
          authState.displayName ?? 'User',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          authState.email,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    this.icon,
    this.customIcon,
    required this.label,
    this.value,
    this.valueWidget,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: customIcon ??
                    Icon(
                      icon,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: label == "Email" ? 1 : 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              if (valueWidget != null) valueWidget!,
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.withOpacity(0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _currentDeviceTimezone() {
  try {
    final now = DateTime.now();
    final name = now.timeZoneName;
    if (name.contains('/')) return name;

    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  } catch (_) {
    return 'UTC';
  }
}

int? _parseOffsetMinutes(String timezone) {
  if (timezone == 'UTC' || timezone == 'GMT') return 0;

  final match =
      RegExp(r'^(?:UTC|GMT)?([+-])(\d{2}):(\d{2})$').firstMatch(timezone);
  if (match == null) return null;

  final sign = match.group(1) == '-' ? -1 : 1;
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  return sign * (hours * 60 + minutes);
}

String _formatOffsetMinutes(int offsetMinutes) {
  final sign = offsetMinutes >= 0 ? '+' : '-';
  final absMinutes = offsetMinutes.abs();
  final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

class _TimezoneOption {
  const _TimezoneOption({
    required this.value,
    required this.offsetMinutes,
    this.label,
  });

  final String value;
  final int offsetMinutes;
  final String? label;
}

const List<_TimezoneOption> _timezoneOptions = [
  _TimezoneOption(value: 'America/Los_Angeles', offsetMinutes: -480),
  _TimezoneOption(value: 'UTC-08:00', offsetMinutes: -480),
  _TimezoneOption(value: 'America/Denver', offsetMinutes: -420),
  _TimezoneOption(value: 'America/Chicago', offsetMinutes: -360),
  _TimezoneOption(value: 'America/Mexico_City', offsetMinutes: -360),
  _TimezoneOption(value: 'UTC-06:00', offsetMinutes: -360),
  _TimezoneOption(value: 'America/New_York', offsetMinutes: -300),
  _TimezoneOption(value: 'America/Toronto', offsetMinutes: -300),
  _TimezoneOption(value: 'UTC-05:00', offsetMinutes: -300),
  _TimezoneOption(value: 'America/Sao_Paulo', offsetMinutes: -180),
  _TimezoneOption(value: 'UTC-03:00', offsetMinutes: -180),
  _TimezoneOption(value: 'UTC', offsetMinutes: 0),
  _TimezoneOption(value: 'Europe/London', offsetMinutes: 0),
  _TimezoneOption(value: 'UTC+01:00', offsetMinutes: 60),
  _TimezoneOption(value: 'Europe/Berlin', offsetMinutes: 60),
  _TimezoneOption(value: 'Europe/Paris', offsetMinutes: 60),
  _TimezoneOption(value: 'Europe/Madrid', offsetMinutes: 60),
  _TimezoneOption(value: 'UTC+02:00', offsetMinutes: 120),
  _TimezoneOption(value: 'Europe/Moscow', offsetMinutes: 180),
  _TimezoneOption(value: 'UTC+03:00', offsetMinutes: 180),
  _TimezoneOption(value: 'Asia/Dubai', offsetMinutes: 240),
  _TimezoneOption(value: 'UTC+05:30', offsetMinutes: 330),
  _TimezoneOption(value: 'Asia/Jakarta', offsetMinutes: 420),
  _TimezoneOption(value: 'Asia/Bangkok', offsetMinutes: 420),
  _TimezoneOption(value: 'UTC+07:00', offsetMinutes: 420),
  _TimezoneOption(value: 'Asia/Singapore', offsetMinutes: 480),
  _TimezoneOption(value: 'Asia/Hong_Kong', offsetMinutes: 480),
  _TimezoneOption(value: 'Asia/Shanghai', offsetMinutes: 480),
  _TimezoneOption(value: 'Asia/Kuala_Lumpur', offsetMinutes: 480),
  _TimezoneOption(value: 'UTC+08:00', offsetMinutes: 480),
  _TimezoneOption(value: 'Asia/Tokyo', offsetMinutes: 540),
  _TimezoneOption(value: 'UTC+09:00', offsetMinutes: 540),
  _TimezoneOption(value: 'Australia/Sydney', offsetMinutes: 600),
  _TimezoneOption(value: 'Australia/Melbourne', offsetMinutes: 600),
  _TimezoneOption(value: 'UTC+10:00', offsetMinutes: 600),
  _TimezoneOption(value: 'Pacific/Auckland', offsetMinutes: 720),
];

final Map<String, _TimezoneOption> _timezoneOptionsMap = {
  for (final option in _timezoneOptions) option.value: option,
};

String _formatTimezoneLabel(_TimezoneOption option) {
  final baseLabel = option.label ?? option.value;
  return '(GMT ${_formatOffsetMinutes(option.offsetMinutes)}) $baseLabel';
}

_TimezoneOption _resolveTimezoneOption({
  required String timezone,
  required int fallbackOffsetMinutes,
  bool preferFallback = false,
}) {
  final known = _timezoneOptionsMap[timezone];
  final parsedOffset = _parseOffsetMinutes(timezone);
  final offsetMinutes = parsedOffset ??
      (preferFallback ? fallbackOffsetMinutes : null) ??
      known?.offsetMinutes ??
      fallbackOffsetMinutes;
  return _TimezoneOption(
    value: timezone,
    offsetMinutes: offsetMinutes,
    label: known?.label,
  );
}

List<_TimezoneOption> _buildTimezoneOptionsList({
  required String deviceTimezone,
  required String? currentTimezone,
  required int deviceOffsetMinutes,
}) {
  final options = <String, _TimezoneOption>{
    for (final option in _timezoneOptions) option.value: option,
  };

  void addIfMissing(
    String? timezone, {
    bool preferFallback = false,
    bool force = false,
  }) {
    if (timezone == null || timezone.isEmpty) return;
    if (force || !options.containsKey(timezone)) {
      options[timezone] = _resolveTimezoneOption(
        timezone: timezone,
        fallbackOffsetMinutes: deviceOffsetMinutes,
        preferFallback: preferFallback,
      );
    }
  }

  addIfMissing(deviceTimezone, preferFallback: true, force: true);
  addIfMissing(currentTimezone);

  final sorted = options.values.toList()
    ..sort((a, b) {
      final offsetComparison = a.offsetMinutes.compareTo(b.offsetMinutes);
      if (offsetComparison != 0) return offsetComparison;
      return (a.label ?? a.value).compareTo(b.label ?? b.value);
    });

  return sorted;
}

Future<void> _showEditNameSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String initialName,
  required VoidCallback onUpdated,
}) async {
  final authState = ref.read(authProvider);
  final l10n = AppLocalizations.of(context)!;

  final result = await MonekoAlertDialog.show(
    context: context,
    title: l10n.fullName,
    description: null,
    confirmLabel: l10n.save,
    cancelLabel: l10n.cancel,
    inputConfig: MonekoAlertDialogInputConfig(
      initialValue: initialName,
      placeholder: l10n.fullName,
      isRequired: true,
      keyboardType: TextInputType.text,
      // Basic validation, more detailed checks remain in _saveName
      validationPattern: RegExp(r'^.{2,}$'),
      validationMessage: l10n.pleaseEnterAValidName,
    ),
  );

  if (result == null || !result.confirmed || result.text == null) {
    return;
  }

  if (!context.mounted) return;

  final controller = TextEditingController(text: result.text!);
  await _saveName(
    context,
    ref,
    controller,
    authState.uid,
    onUpdated,
  );
}

Future<void> _saveName(
  BuildContext ctx,
  WidgetRef ref,
  TextEditingController controller,
  String userId,
  VoidCallback onUpdated,
) async {
  final newName = controller.text.trim();
  if (newName.isEmpty || newName.length < 2) {
    AppToast.info(ctx, AppLocalizations.of(ctx)!.pleaseEnterAValidName);
    return;
  }

  try {
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
    final navigator = Navigator.of(ctx);
    if (navigator.canPop()) {
      navigator.pop();
    }
    AppToast.success(ctx, AppLocalizations.of(ctx)!.profileUpdated);
  } catch (e) {
    if (ctx.mounted) {
      AppToast.error(
        ctx,
        AppLocalizations.of(ctx)!.failedToUpdate(e.toString()),
      );
    }
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.monekoPrimary, AppTheme.monekoSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: colorScheme.primaryForeground,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// End of _MembershipCard class
// _MembershipCard class is removed as requested by the user.

// Actual WhatsApp Path:
const String _whatsappRealSvg =
    '''<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>WhatsApp</title><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.008-.57-.008-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>''';

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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/destructive_adaptive_button.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_binding_card.dart';
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
          await ref
              .read(deviceRegistrationServiceProvider)
              .unregisterDevice();
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
            'Notifications refreshed successfully',
          );
        }
      } catch (e) {
        debugPrint('Error handling manual notification fix: $e');
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
    final timezoneSubtitle = selectedTimezone.value == null
        ? 'Defaults to your device time'
        : 'Used for dates and reminders';
    final timezoneOptions = _buildTimezoneOptionsList(
      deviceTimezone: deviceTimezone,
      currentTimezone: selectedTimezone.value,
      deviceOffsetMinutes: deviceOffsetMinutes,
    );
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
          AppToast.success(context, 'Timezone updated');
        }
      } catch (e) {
        selectedTimezone.value = previous;
        if (context.mounted) {
          AppToast.error(context, 'Failed to update timezone: $e');
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
                            onTap: () => _showAvatarSourceSheet(
                              context,
                              ref,
                              () {
                                nameReloadKey.value++;
                                if (authState.uid.isNotEmpty) {
                                  ref.invalidate(
                                    userProfileProvider(authState.uid),
                                  );
                                }
                              },
                            ),
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
                                onTap: () =>  _showAvatarSourceSheet(
                              context,
                              ref,
                              () {
                                nameReloadKey.value++;
                                if (authState.uid.isNotEmpty) {
                                  ref.invalidate(
                                    userProfileProvider(authState.uid),
                                  );
                                }
                              },
                            ),
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

                // Timezone Section
                const _SectionHeader(title: 'Timezone'),
                const SizedBox(height: 12),
                AdaptiveListTile(
                  leading: Icon(
                    Icons.schedule_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  title: Text(
                    timezoneDisplay,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    timezoneSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  trailing: Icon(
                    Icons.unfold_more,
                    size: 18,
                    color: colorScheme.mutedForeground,
                  ),
                  onTap: () async {
                    final selection = await MonekoListPicker.show<_TimezoneOption>(
                      context: context,
                      items: timezoneOptions,
                      initial: currentTimezoneOption,
                      title: 'Choose timezone',
                      labelBuilder: (option) => _formatTimezoneLabel(option) +
                          (option.value == deviceTimezone ? ' (Device)' : ''),
                    );
                    if (selection != null &&
                        selection.value != selectedTimezone.value) {
                      await handleTimezoneChange(selection.value);
                    }
                  },
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
                const SizedBox(height: 12),
                AdaptiveListTile(
                  leading: Icon(
                    Icons.refresh_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  title: Text(
                    'Fix notification issues',
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Re-register this device if notifications are not working.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  trailing: Icon(
                    Icons.refresh,
                    size: 16,
                    color: colorScheme.mutedForeground,
                  ),
                  onTap: () => handleManualNotificationFix(),
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
                      showBlockingProcessingDialog(
                        context: context,
                        message: 'Signing out...',
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

                        debugPrint('✅ All user-specific state cleared');

                        // Sign out from auth last (this will trigger navigation to login)
                        await ref.read(authProvider.notifier).signOut();
                      } finally {
                        if (context.mounted) {
                      
                        }
                      }
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

Future<void> _showAvatarSourceSheet(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onUpdated,
) async {
  final result = await MonekoActionSheet.show<String>(
    context: context,
    title: 'Change avatar',
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

  final file = await _pickAndCropAvatarImage(context, source);
  if (file == null) {
    return;
  }

  await _uploadAndSaveAvatar(context, ref, file, onUpdated);
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

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      maxWidth: 800,
      maxHeight: 800,
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.l10n.cropCoverImage,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
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

    if (croppedFile == null) {
      return null;
    }

    return File(croppedFile.path);
  } catch (e) {
    if (context.mounted) {
      AppToast.error(context, 'Failed to process image: $e');
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
    message: 'Updating avatar...',
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
      AppToast.success(context, 'Avatar updated');
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.failedToSaveAvatar}: $e',
      );
    }
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
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

String _currentDeviceTimezone() {
  try {
    final now = DateTime.now();
    final name = now.timeZoneName;
    if (name.contains('/')) return name;

    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes =
        (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
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
      final offsetComparison =
          a.offsetMinutes.compareTo(b.offsetMinutes);
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
      validationMessage: 'Please enter a valid name',
    ),
  );

  if (result == null || !result.confirmed || result.text == null) {
    return;
  }

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
    AppToast.info(ctx, 'Please enter a valid name');
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

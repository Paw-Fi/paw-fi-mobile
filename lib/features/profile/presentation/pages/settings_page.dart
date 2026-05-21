import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
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
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/telegram_tutorial_modal.dart';
import 'package:moneko/features/profile/presentation/widgets/category_customization_sheet.dart';
// import 'package:moneko/features/subscription/data/models/subscription_details.dart'; // Removed unused import
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/overview_dashboard_page.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
// import 'package:moneko/features/profile/presentation/widgets/whatsapp_binding_card.dart'; // Removed unused import
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:moneko/shared/widgets/moneko_list_picker.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_preview_page.dart';
import 'package:moneko/features/home/presentation/state/ai_hold_quick_action_preference.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/services/preferred_language_sync_service.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/services/support_ticket_service.dart';
import 'package:moneko/features/profile/presentation/pages/email_import_settings_page.dart';
import 'package:moneko/features/profile/presentation/pages/ios_wallet_capture_page.dart';
import 'package:moneko/features/profile/presentation/pages/android_notification_capture_page.dart';
import 'package:moneko/features/wallets/presentation/pages/archived_wallets_page.dart';

import 'package:crypto/crypto.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

bool _isAvatarCropInProgress = false;
bool _isAvatarUploadInProgress = false;

String _holdQuickActionLabel(BuildContext context, AiHoldQuickAction? action) {
  return switch (action) {
    AiHoldQuickAction.camera => context.l10n.takePhotoWithCamera,
    AiHoldQuickAction.photoLibrary => context.l10n.choosePhotoFromLibrary,
    AiHoldQuickAction.recordAudio => context.l10n.recordWithAudio,
    AiHoldQuickAction.textInputDrawer => context.l10n.showTextInputDrawer,
    AiHoldQuickAction.manualEntry => context.l10n.manualInputQuickActionLabel,
    null => context.l10n.notSet,
  };
}

const Set<String> _restrictedRegionCountryCodes = {
  'ID', // Indonesia
  'CU', // Cuba
  'IR', // Iran
  'KP', // North Korea
  'SY', // Syria
};

Map<String, String> _restrictedRegionCountryNames(BuildContext context) {
  return {
    'ID': context.l10n.indonesia,
    'CU': context.l10n.cuba,
    'IR': context.l10n.iran,
    'KP': context.l10n.northKorea,
    'SY': context.l10n.syria,
  };
}

bool _isDeviceInRestrictedRegion({String? countryCode}) {
  final code = countryCode ?? _resolveDeviceCountryCode();
  if (code == null) {
    return false;
  }
  return _restrictedRegionCountryCodes.contains(code);
}

String? _restrictedRegionDisplayName(
    String? countryCode, BuildContext context) {
  if (countryCode == null || countryCode.isEmpty) return null;
  return _restrictedRegionCountryNames(context)[countryCode] ?? countryCode;
}

String? _resolveDeviceCountryCode() {
  try {
    final primary = ui.PlatformDispatcher.instance.locale;
    final code = primary.countryCode;
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      final localeCode = locale.countryCode;
      if (localeCode != null && localeCode.isNotEmpty) {
        return localeCode.toUpperCase();
      }
    }
  } catch (_) {
    // Ignore and fall back to Platform.localeName
  }

  try {
    final segments = Platform.localeName.split('_');
    if (segments.length > 1) {
      final inferred = segments.last.trim();
      if (inferred.isNotEmpty) {
        return inferred.toUpperCase();
      }
    }
  } catch (_) {
    // Ignore failures and return null.
  }

  return null;
}

Future<bool> _showWhatsAppRestrictedRegionDialog({
  required BuildContext context,
  required String countryName,
}) async {
  final result = await MonekoAlertDialog.show(
    context: context,
    title: context.l10n.whatsAppAccessLimitedTitle,
    description: context.l10n.whatsAppAccessLimitedDescription(
      countryName,
    ),
    confirmLabel: context.l10n.acknowledge,
    cancelLabel: context.l10n.continueAnyway,
  );
  return result?.confirmed ?? false;
}

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
    final prefs = ref.read(sharedPreferencesProvider);
    final holdQuickAction =
        useState<AiHoldQuickAction?>(readAiHoldQuickActionPreference(prefs));
    final isAccountDeletionInProgress = useState(false);
    final isDataResetInProgress = useState(false);
    final siriStatusReloadKey = useState(0);
    final hasAcknowledgedRestrictedRegion = useState(false);
    final deviceCountryCode = _resolveDeviceCountryCode();
    final isDeviceInRestrictedRegion =
        _isDeviceInRestrictedRegion(countryCode: deviceCountryCode);
    final restrictedCountryName =
        _restrictedRegionDisplayName(deviceCountryCode, context);
    final siriShortcutStatus = useFuture(
      useMemoized(
        () => SiriShortcutAuthService.instance.getStatus(),
        [authState.uid, siriStatusReloadKey.value],
      ),
    );
    final nameReloadKey = useState(0);
    final deviceTimezoneFuture = useFuture(
      useMemoized(resolveCanonicalDeviceTimezone),
    );
    final deviceTimezone =
        deviceTimezoneFuture.data ?? currentDeviceTimezoneOffsetLabel();
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

    Future<void> syncSiriShortcutAuthContextNow() async {
      final session = Supabase.instance.client.auth.currentSession;
      try {
        await SiriShortcutAuthService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: session?.accessToken,
          refreshToken: session?.refreshToken,
          userId: session?.user.id,
          expiresAt: session?.expiresAt,
        );
        siriStatusReloadKey.value++;
        // Also sync Android notification capture credentials
        if (Platform.isAndroid) {
          try {
            await NotificationCaptureService.instance.syncAuthContext(
              supabaseUrl: Constants.supabaseUrl,
              supabaseAnonKey: Constants.supabaseAnon,
              accessToken: session?.accessToken ?? '',
              refreshToken: session?.refreshToken ?? '',
              userId: session?.user.id ?? '',
              expiresAt: session?.expiresAt ?? 0,
            );
          } catch (_) {
            // Silently ignore — Android sync is best-effort here
          }
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(
              context, '${context.l10n.siriShortcutsSyncFailed}: $error');
        }
      }
    }

    Future<void> handleSiriIntegrationDebugTest() async {
      try {
        await syncSiriShortcutAuthContextNow();
        final status = await SiriShortcutAuthService.instance.getStatus();
        if (!context.mounted) return;

        final isReady = status['isReady'] == true;
        if (isReady) {
          AppToast.success(context, 'Siri integration test passed');
        } else {
          AppToast.info(context, 'Siri integration test failed');
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, 'Siri integration test failed: $error');
        }
      }
    }

    Future<void> handleSiriShortcutSetup() async {
      await syncSiriShortcutAuthContextNow();
      if (!context.mounted) return;

      final result = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.siriShortcuts,
        description: context.l10n.siriShortcutsDescription,
        confirmLabel: context.l10n.siriShortcutsOpenShortcuts,
        cancelLabel: context.l10n.cancel,
      );

      if (result?.confirmed != true || !context.mounted) {
        return;
      }

      try {
        final launched = await launchUrl(
          Uri.parse('shortcuts://'),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          AppToast.error(context, context.l10n.siriShortcutsOpenFailed);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.siriShortcutsOpenFailed);
        }
      }
    }

    String resolveSiriShortcutStatusText() {
      final status = siriShortcutStatus.data;
      if (status == null) {
        return siriShortcutStatus.hasError
            ? context.l10n.siriShortcutsSetupRequired
            : context.l10n.siriShortcutsChecking;
      }

      final isReady = status['isReady'] == true;
      final hasCredentials = status['hasCredentials'] == true;
      final hasSupabaseConfig = status['hasSupabaseConfig'] == true;

      if (isReady) return context.l10n.siriShortcutsReady;
      if (hasSupabaseConfig && hasCredentials) {
        return context.l10n.siriShortcutsReady;
      }
      if (hasSupabaseConfig || hasCredentials) {
        return context.l10n.siriShortcutsNeedsRefresh;
      }
      return context.l10n.siriShortcutsSetupRequired;
    }

    Future<void> launchIntegrationUrl(
      Uri url, {
      required String errorMessage,
    }) async {
      try {
        var launched =
            await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!launched) {
          launched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        }
        if (!launched) {
          launched = await launchUrl(url, mode: LaunchMode.inAppWebView);
        }
        if (!launched && context.mounted) {
          AppToast.error(context, errorMessage);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, errorMessage);
        }
      }
    }

    final selectedLocale = ref.watch(localeProvider);
    const supportedLocales = AppLocalizations.supportedLocales;
    final dropdownValue = _coerceToSupported(selectedLocale, supportedLocales);
    final canonicalSelectedTimezone =
        canonicalTimezoneValue(selectedTimezone.value);
    final isLegacyTimezone =
        _isLegacyTimezoneValue(selectedTimezone.value ?? '');
    final timezoneValue = isLegacyTimezone
        ? _deviceTimezoneSentinel
        : (canonicalSelectedTimezone ?? _deviceTimezoneSentinel);
    final timezoneDisplay = isLegacyTimezone
        ? '(GMT ${_formatOffsetMinutes(deviceOffsetMinutes)}) ${context.l10n.deviceLabel} ${context.l10n.legacySettingDetected}'
        : (timezoneValue == _deviceTimezoneSentinel
            ? '${_formatTimezoneLabel(_resolveTimezoneOption(timezone: deviceTimezone, fallbackOffsetMinutes: deviceOffsetMinutes, preferFallback: true))} ${context.l10n.currentTimezone}'
            : _formatTimezoneLabel(
                _resolveTimezoneOption(
                  timezone: timezoneValue,
                  fallbackOffsetMinutes: deviceOffsetMinutes,
                  preferFallback: false,
                ),
              ));
    final timezoneOptions = _buildTimezoneOptionsList(
      deviceTimezone: deviceTimezone,
      currentTimezone: canonicalSelectedTimezone,
      deviceOffsetMinutes: deviceOffsetMinutes,
      context: context,
      hideMatchingDeviceOffsetOption: timezoneValue == _deviceTimezoneSentinel,
    );
    final packageInfo =
        useFuture(useMemoized(() => PackageInfo.fromPlatform()));
    final integrationStatusReloadKey = useState(0);
    final walletCaptureEnabledFuture = useMemoized(
        () => _getWalletCaptureEnabled(ref),
        [authState.uid, integrationStatusReloadKey.value]);
    final emailImportEnabledFuture = useMemoized(
        () => _getEmailImportEnabled(ref),
        [authState.uid, integrationStatusReloadKey.value]);
    final currentTimezoneOption = timezoneOptions.firstWhere(
      (option) => option.value == timezoneValue,
      orElse: () => timezoneOptions.first,
    );

    Future<bool> guardRestrictedRegion() async {
      if (!isDeviceInRestrictedRegion) return true;
      if (hasAcknowledgedRestrictedRegion.value) return true;
      final acknowledged = await _showWhatsAppRestrictedRegionDialog(
        context: context,
        countryName: restrictedCountryName ?? context.l10n.yourCountry,
      );
      if (acknowledged) {
        hasAcknowledgedRestrictedRegion.value = true;
      }
      return !acknowledged;
    }

    Future<void> handleTimezoneChange(String timezone) async {
      final previous = selectedTimezone.value;
      final isDeviceMode = timezone == _deviceTimezoneSentinel;
      final timezoneToPersist = isDeviceMode
          ? canonicalTimezoneValue(deviceTimezone)
          : canonicalTimezoneValue(timezone);
      selectedTimezone.value = timezoneToPersist;
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'update-preferred-timezone',
          body: {
            'userId': authState.uid,
            'timezone': timezoneToPersist,
          },
        );
        final data = response.data;
        final isSuccessful = response.status < 400 &&
            data is Map<String, dynamic> &&
            (data['ok'] == true || data['success'] == true);
        if (!isSuccessful) {
          throw Exception('Failed to update timezone');
        }
        // Update the contact in-place so the useEffect doesn't reset
        // selectedTimezone to null during the transient empty state that
        // ref.invalidate would cause.
        ref
            .read(analyticsProvider.notifier)
            .updatePreferredTimezone(timezoneToPersist);
        // Background-refresh to sync the full dataset from the server.
        ref.read(analyticsProvider.notifier).refresh(authState.uid);
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

    Future<void> handleDeleteAccount() async {
      if (ref.read(previewModeProvider).isActive) {
        if (context.mounted) {
          AppToast.info(
            context,
            context.l10n.previewAccountDeletionDisabled,
          );
        }
        return;
      }

      final l10n = context.l10n;

      if (isAccountDeletionInProgress.value) {
        return;
      }

      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: l10n.settingsDeleteAccountTitle,
        description: l10n.settingsDeleteAccountDescription,
        confirmLabel: l10n.settingsDeleteAccountButton,
        cancelLabel: l10n.cancel,
        isDestructive: true,
        inputConfig: MonekoAlertDialogInputConfig(
          placeholder: context.l10n.delete,
          isRequired: true,
          validationPattern: RegExp(r'^DELETE$'),
          validationMessage: l10n.settingsDeleteAccountConfirmValidation,
        ),
      );

      if (confirmation == null || !confirmation.confirmed || !context.mounted) {
        return;
      }

      if ((confirmation.text ?? '').trim() != context.l10n.delete) {
        if (context.mounted) {
          AppToast.info(context, l10n.settingsDeleteAccountConfirmValidation);
        }
        return;
      }

      isAccountDeletionInProgress.value = true;

      NavigatorState? rootNavigator;
      var dialogShown = false;
      try {
        rootNavigator = Navigator.of(context, rootNavigator: true);
      } catch (e) {
        debugPrint('Unable to capture root navigator for deletion flow: $e');
      }

      try {
        if (context.mounted) {
          await Future<void>.delayed(Duration.zero);
          if (!context.mounted) {
            return;
          }
          showBlockingProcessingDialog(
            context: context,
            message: l10n.settingsDeleteAccountInProgress,
          );
          dialogShown = true;
        }

        final deleteResult = await Supabase.instance.client.rpc(
          'delete_user_account',
        );

        final wasDeleted = switch (deleteResult) {
          Map _ => deleteResult['success'] == true,
          bool _ => deleteResult,
          null => true,
          _ => false,
        };
        if (!wasDeleted) {
          final errorMessage = deleteResult is Map
              ? (deleteResult['message']?.toString() ??
                  deleteResult['error']?.toString() ??
                  l10n.failedToDelete)
              : l10n.failedToDelete;
          if (context.mounted) {
            AppToast.error(context, errorMessage);
          }
          return;
        }

        try {
          await ref.read(deviceRegistrationServiceProvider).unregisterDevice();
        } catch (_) {}

        try {
          await ref.read(selectedHouseholdProvider.notifier).clearSelection();
        } catch (_) {}

        if (authState.uid.isNotEmpty) {
          ref.invalidate(userHouseholdsProvider(authState.uid));
          ref.invalidate(userProfileProvider(authState.uid));
        }

        ref.read(appInitializationV2Provider.notifier).clearCacheAndReset();
        ref.invalidate(incomeSummaryProvider);
        ref.invalidate(incomeListProvider);
        ref.invalidate(goalsListProvider);
        ref.invalidate(goalSummaryProvider);
        ref.invalidate(subscriptionManagementProvider);

        try {
          if (ref.read(previewModeProvider).isActive) {
            if (context.mounted) {
              AppToast.info(
                context,
                context.l10n.previewSignOutDisabledInDemoMode,
              );
            }
            return;
          }
          await ref.read(authProvider.notifier).signOut();
        } catch (_) {}

        if (dialogShown &&
            rootNavigator != null &&
            rootNavigator.mounted &&
            rootNavigator.canPop()) {
          try {
            rootNavigator.pop();
            dialogShown = false;
          } catch (_) {}
        }

        if (context.mounted) {
          AppToast.success(context, l10n.settingsDeleteAccountSuccess);
        }
      } catch (e, st) {
        debugPrint('Account deletion failed: $e\n$st');
        if (context.mounted) {
          AppToast.error(context, '${l10n.failedToDelete}: $e');
        }
      } finally {
        if (dialogShown &&
            rootNavigator != null &&
            rootNavigator.mounted &&
            rootNavigator.canPop()) {
          try {
            rootNavigator.pop();
          } catch (e) {
            debugPrint('Failed to dismiss delete account dialog: $e');
          }
        }
        if (context.mounted) {
          isAccountDeletionInProgress.value = false;
        }
      }
    }

    Future<void> handleResetFinancialData() async {
      if (ref.read(previewModeProvider).isActive) {
        if (context.mounted) {
          AppToast.info(
            context,
            context.l10n.previewResetFinancialDataDisabledInDemoMode,
          );
        }
        return;
      }

      if (isDataResetInProgress.value) {
        return;
      }

      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.resetDataCannotBeUndone,
        description: context.l10n.resetDataConfirmationMessage,
        confirmLabel: context.l10n.resetData,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
        inputConfig: MonekoAlertDialogInputConfig(
          placeholder: context.l10n.reset,
          isRequired: true,
          validationPattern: RegExp(r'^RESET$'),
          validationMessage: context.l10n.typeResetToConfirm,
        ),
      );

      if (confirmation == null || !confirmation.confirmed || !context.mounted) {
        return;
      }

      if ((confirmation.text ?? '').trim() != "RESET") {
        if (context.mounted) {
          AppToast.info(context, context.l10n.typeResetToConfirm);
        }
        return;
      }

      isDataResetInProgress.value = true;

      NavigatorState? rootNavigator;
      var dialogShown = false;
      try {
        rootNavigator = Navigator.of(context, rootNavigator: true);
      } catch (_) {}

      try {
        if (context.mounted) {
          await Future<void>.delayed(Duration.zero);
          if (!context.mounted) {
            return;
          }
          showBlockingProcessingDialog(
            context: context,
            message: context.l10n.resettingFinancialData,
          );
          dialogShown = true;
        }

        final result = await Supabase.instance.client.rpc(
          'reset_user_financial_data',
        );

        final wasReset = switch (result) {
          Map _ => result['success'] == true,
          bool _ => result,
          _ => false,
        };

        if (!wasReset) {
          final errorMessage = result is Map
              ? (result['message']?.toString() ??
                  result['error']?.toString() ??
                  context.l10n.failedToResetFinancialData)
              : context.l10n.failedToResetFinancialData;
          if (context.mounted) {
            AppToast.error(context, errorMessage);
          }
          return;
        }

        ref.read(appInitializationV2Provider.notifier).clearCacheAndReset();
        ref.invalidate(analyticsProvider);
        ref.invalidate(incomeSummaryProvider);
        ref.invalidate(incomeListProvider);
        ref.invalidate(goalsListProvider);
        ref.invalidate(goalSummaryProvider);
        ref.invalidate(subscriptionManagementProvider);
        ref.invalidate(recurringTransactionsProvider);
        ref.invalidate(pocketsProvider);
        ref.invalidate(scopedWalletsProvider);
        ref.invalidate(walletsPageStateProvider);
        ref.invalidate(bankConnectionsProvider);
        ref.invalidate(monthlyFinancialReportProvider);

        ref.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
        ref.read(dashboardRefreshSignalProvider.notifier).state += 1;

        try {
          final database = await ref.read(localDatabaseProvider.future);
          await database.clearAllLocalData();
          await database.deleteJsonCacheByPrefix(
            namespace: 'monthly_report',
            cacheKeyPrefix: 'monthly-report:v3:${authState.uid}:',
          );
        } catch (_) {}

        // Intentionally do not clear SharedPreferences here.
        // Router onboarding/auth gates rely on persisted flags, and clearing
        // them would route authenticated users back into onboarding.

        if (authState.uid.isNotEmpty) {
          ref.read(analyticsProvider.notifier).refresh(authState.uid);
        }

        if (dialogShown &&
            rootNavigator != null &&
            rootNavigator.mounted &&
            rootNavigator.canPop()) {
          try {
            rootNavigator.pop();
            dialogShown = false;
          } catch (_) {}
        }

        if (context.mounted) {
          await MonekoAlertDialog.show(
            context: context,
            title: context.l10n.resetSuccessful,
            description: context.l10n.yourDataHasBeenClearedPleaseRestart,
            confirmLabel: context.l10n.restartNow,
            showCancelButton: false,
          );
          if (context.mounted) {
            await SystemNavigator.pop();
            await Future<void>.delayed(const Duration(milliseconds: 120));
            exit(0);
          }
        }
      } catch (e, st) {
        debugPrint('Reset financial data failed: $e\n$st');
        if (context.mounted) {
          AppToast.error(
              context, context.l10n.failedToResetFinancialDataWithError(e));
        }
      } finally {
        if (dialogShown &&
            rootNavigator != null &&
            rootNavigator.mounted &&
            rootNavigator.canPop()) {
          try {
            rootNavigator.pop();
          } catch (_) {}
        }
        if (context.mounted) {
          isDataResetInProgress.value = false;
        }
      }
    }

    Future<void> handleHoldQuickActionChange() async {
      final cancelLabel = context.l10n.cancel;
      final result = await MonekoActionSheet.show<String>(
        context: context,
        title: context.l10n.pressAndHoldQuickAction,
        actions: [
          MonekoActionSheetAction<String>(
            label: context.l10n.takePhotoWithCamera,
            value: 'camera',
          ),
          MonekoActionSheetAction<String>(
            label: context.l10n.choosePhotoFromLibrary,
            value: 'photoLibrary',
          ),
          MonekoActionSheetAction<String>(
            label: context.l10n.recordWithAudio,
            value: 'recordAudio',
          ),
          MonekoActionSheetAction<String>(
            label: context.l10n.showTextInputDrawer,
            value: 'textInputDrawer',
          ),
          MonekoActionSheetAction<String>(
            label: context.l10n.manualInputQuickActionLabel,
            value: 'manualEntry',
          ),
        ],
        cancelAction: MonekoActionSheetAction<String>(
          label: cancelLabel,
          value: cancelLabel,
        ),
      );

      if (result == null || result == cancelLabel) {
        return;
      }

      final nextAction = switch (result) {
        'camera' => AiHoldQuickAction.camera,
        'photoLibrary' => AiHoldQuickAction.photoLibrary,
        'recordAudio' => AiHoldQuickAction.recordAudio,
        'textInputDrawer' => AiHoldQuickAction.textInputDrawer,
        'manualEntry' => AiHoldQuickAction.manualEntry,
        'unset' => null,
        _ => holdQuickAction.value,
      };

      if (nextAction == holdQuickAction.value) {
        return;
      }

      await writeAiHoldQuickActionPreference(prefs, nextAction);
      holdQuickAction.value = nextAction;

      if (!context.mounted) return;
      AppToast.success(
        context,
        context.l10n.quickActionUpdated(
          _holdQuickActionLabel(context, nextAction),
        ),
      );
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.settings,
      ),
      floatingActionButton: kDebugMode
          ? AdaptiveFloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return Material(
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom:
                                16 + MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              material.Text(
                                'Debug Menu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.foreground,
                                ),
                              ),
                            ],
                          ),
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
                  onAvatarTap: () async {
                    try {
                      await _showAvatarSourceSheet(
                        context,
                        () {
                          nameReloadKey.value++;
                          if (authState.uid.isNotEmpty) {
                            ref.invalidate(userProfileProvider(authState.uid));
                          }
                        },
                      );
                    } catch (e, st) {
                      debugPrint(
                        context.l10n.unexpectedAvatarUpdateError(e),
                      );
                      if (context.mounted) {
                        AppToast.error(
                            context, context.l10n.failedToSaveAvatar);
                      }
                    }
                  },
                ),

                const SizedBox(height: 32),

                // Account Settings Group
                _SettingsGroup(
                  title: context.l10n.account,
                  children: [
                    _SettingsTile(
                      icon: Icons.pie_chart,
                      label: context.l10n.accountOverview,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const OverviewDashboardPage(),
                          ),
                        );
                      },
                    ),
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
                                  fontSize: 13,
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
                            final localeNotifier =
                                ref.read(localeProvider.notifier);
                            if (value == null) {
                              await localeNotifier.setSystem();
                            } else {
                              await localeNotifier.setLocale(value);
                            }

                            if (authState.uid.isNotEmpty) {
                              await ref
                                  .read(preferredLanguageSyncServiceProvider)
                                  .syncForUserSafely(
                                    userId: authState.uid,
                                    locale: value == null
                                        ? await resolveEffectiveAppLocale()
                                        : normalizeAppLocale(value),
                                    force: true,
                                  );
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
                          labelBuilder: (option) {
                            if (option.value == _deviceTimezoneSentinel) {
                              final deviceOption = _resolveTimezoneOption(
                                timezone: deviceTimezone,
                                fallbackOffsetMinutes: deviceOffsetMinutes,
                                preferFallback: true,
                              );
                              return '${_formatTimezoneLabel(deviceOption)} (${context.l10n.currentTimezone})';
                            }
                            return _formatTimezoneLabel(option);
                          },
                        );
                        final normalizedSelection =
                            selection?.value == _deviceTimezoneSentinel
                                ? null
                                : canonicalTimezoneValue(selection?.value);
                        if (selection != null &&
                            normalizedSelection != selectedTimezone.value) {
                          await handleTimezoneChange(selection.value);
                        }
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.currency_exchange_rounded,
                      label: context.l10n.currency,
                      value: context.l10n.tapToSet,
                      onTap: () {
                        context.push('/currency-rates');
                      },
                    ),
                    _SettingsTile(
                      icon: isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: context.l10n.darkMode,
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: AdaptiveSwitch(
                          value: isDarkMode,
                          onChanged: (value) {
                            ref.read(themeModeProvider.notifier).setThemeMode(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                          },
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.category_rounded,
                      label: context.l10n.categories,
                      value: context.l10n.settingsCustomCategoriesAction,
                      onTap: () async {
                        await MonekoBottomSheet.show(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: colorScheme.sheetBackground,
                          builder: (sheetContext) {
                            return const CategoryCustomizationSheet();
                          },
                        );
                      },
                    ),
                  ],
                ),

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

                // Integrations
                _SettingsGroup(title: context.l10n.integrations, children: [
                  if (Platform.isIOS)
                    _SettingsTile(
                      icon: Icons.mic_rounded,
                      label: context.l10n.siriShortcuts,
                      value: resolveSiriShortcutStatusText(),
                      onTap: handleSiriShortcutSetup,
                    ),
                  if (Platform.isIOS)
                    _SettingsTile(
                      icon: Icons.widgets_rounded,
                      label: context.l10n.homeScreenWidgets,
                      onTap: () => launchIntegrationUrl(
                        Uri.parse(
                            'https://moneko.io/help/ios-home-screen-widgets'),
                        errorMessage: context.l10n.couldNotOpenWidgetsHelp,
                      ),
                    ),
                  if (kDebugMode && Platform.isIOS)
                    _SettingsTile(
                      icon: Icons.bug_report_rounded,
                      label: "Test Siri Integration",
                      onTap: handleSiriIntegrationDebugTest,
                    ),
                  _SettingsTile(
                    icon: Icons.upload_file_rounded,
                    label: context.l10n.importData,
                    onTap: () {
                      context.push('/import');
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.forward_to_inbox_rounded,
                    label: context.l10n.emailFileImportEnableSwitchTitle,
                    valueWidget: FutureBuilder<bool>(
                      future: emailImportEnabledFuture,
                      builder: (context, snapshot) {
                        final isEnabled = snapshot.data ?? false;
                        return Text(
                          isEnabled
                              ? context.l10n.activeStatus
                              : context.l10n.tapToSet,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const EmailImportSettingsPage(),
                            ),
                          )
                          .then((_) => integrationStatusReloadKey.value++);
                    },
                  ),
                  _SettingsTile(
                    customIcon: SvgPicture.string(
                      _telegramSvg,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    label:
                        ref.watch(telegramBindingProvider).asData?.value == true
                            ? context.l10n.telegramConnected
                            : context.l10n.connectTelegram,
                    value:
                        ref.watch(telegramBindingProvider).asData?.value == true
                            ? context.l10n.activeStatus
                            : context.l10n.tapToSet,
                    onTap: () async {
                      final isBound =
                          ref.read(telegramBindingProvider).valueOrNull ??
                              false;
                      if (isBound) {
                        await launchIntegrationUrl(
                          Uri.parse('https://t.me/moneko_ai_bot'),
                          errorMessage: context.l10n.couldNotLaunchTelegram,
                        );
                      } else {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => const TelegramTutorialModal(),
                        );
                        if (result == true) {
                          ref.invalidate(telegramBindingProvider);
                        }
                      }
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
                      final tileContext = context;
                      final canProceed = await guardRestrictedRegion();
                      if (!canProceed) {
                        return;
                      }
                      if (!tileContext.mounted) {
                        return;
                      }
                      final isBound =
                          ref.read(whatsAppBindingProvider).valueOrNull ??
                              false;
                      if (isBound) {
                        await launchIntegrationUrl(
                          Uri.parse('https://wa.link/zxwtld'),
                          errorMessage: context.l10n.couldNotLaunchWhatsApp,
                        );
                      } else {
                        final result = await showDialog<bool>(
                          context: tileContext,
                          builder: (context) => const WhatsAppTutorialModal(),
                        );
                        if (result == true) {
                          ref.invalidate(whatsAppBindingProvider);
                        }
                      }
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: Platform.isIOS
                        ? context.l10n.applePayIntegration
                        : context.l10n.autoTransactionCapture,
                    value: null,
                    valueWidget: FutureBuilder<bool>(
                      future: walletCaptureEnabledFuture,
                      builder: (context, snapshot) {
                        final isEnabled = snapshot.data ?? false;
                        return Text(
                          isEnabled
                              ? context.l10n.activeStatus
                              : context.l10n.tapToSet,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                    onTap: () {
                      if (Platform.isIOS) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    const IosWalletCapturePage(),
                              ),
                            )
                            .then((_) => integrationStatusReloadKey.value++);
                      } else if (Platform.isAndroid) {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    const AndroidNotificationCapturePage(),
                              ),
                            )
                            .then((_) => integrationStatusReloadKey.value++);
                      }
                    },
                  ),
                  // _SettingsTile(
                  //   icon: Icons.account_balance_rounded,
                  //   label: context.l10n.syncBankAccountsTitle,
                  //   value: context.l10n.comingSoon,
                  //   onTap: () {
                  //     Navigator.of(context).push(
                  //       MaterialPageRoute<void>(
                  //         builder: (context) =>
                  //             const PlaidSyncWalkthroughPage(),
                  //       ),
                  //     );
                  //   },
                  // ),
                ]),

                // Wallet
                _SettingsGroup(
                  title: context.l10n.wallet,
                  children: [
                    _SettingsTile(
                      icon: Icons.archive_outlined,
                      label: context.l10n.archivedWallets,
                      value: context.l10n.tapToManage,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const ArchivedWalletsPage(),
                          ),
                        );
                      },
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
                        data: (d) {
                          final status = d?.subscription?.status?.toLowerCase();
                          if (status == 'trialing') {
                            return context.l10n.trialStatus;
                          }
                          return d?.hasActiveSubscription == true
                              ? context.l10n.plusPlan
                              : context.l10n.free;
                        },
                        loading: () => '...',
                        error: (_, __) => context.l10n.error('unknown'),
                      ),
                      onTap: () async {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PlanSelectionPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // App Experience
                _SettingsGroup(
                  title: context.l10n.appExperience,
                  children: [
                    _SettingsTile(
                      icon: Icons.touch_app_rounded,
                      label: context.l10n.pressAndHoldQuickAction,
                      value: _holdQuickActionLabel(
                        context,
                        holdQuickAction.value,
                      ),
                      onTap: handleHoldQuickActionChange,
                    ),
                    _SettingsTile(
                      icon: Icons.play_circle_rounded,
                      label: context.l10n.restartOnboarding,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                const OnboardingPreviewPage(fromSettings: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Support
                _SettingsGroup(
                  title: context.l10n.support,
                  children: [
                    _SettingsTile(
                      icon: Icons.help_rounded,
                      label: context.l10n.helpCenter,
                      onTap: () => launchIntegrationUrl(
                        Uri.parse('https://moneko.io/help'),
                        errorMessage: context.l10n.couldNotOpenHelpCenter,
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.bug_report_rounded,
                      label: context.l10n.reportABug,
                      onTap: () => _showReportBugSheet(context),
                    ),
                    _SettingsTile(
                      icon: Icons.chat_bubble_rounded,
                      label: context.l10n.submitNewFeatureRequest,
                      onTap: () => _showSubmitFeedbackSheet(context),
                    ),
                  ],
                ),

                _SettingsGroup(
                  title: context.l10n.dangerZone,
                  children: [
                    _SettingsTile(
                      icon: Icons.restart_alt_rounded,
                      iconColor: colorScheme.destructive,
                      label: context.l10n.resetData,
                      labelColor: colorScheme.destructive,
                      value: isDataResetInProgress.value
                          ? context.l10n.resetting
                          : null,
                      onTap: isDataResetInProgress.value
                          ? null
                          : () => handleResetFinancialData(),
                    ),
                    _SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: colorScheme.destructive,
                      label: context.l10n.settingsDeleteAccountButton,
                      labelColor: colorScheme.destructive,
                      value: isAccountDeletionInProgress.value
                          ? context.l10n.settingsDeleteAccountInProgress
                          : null,
                      onTap: isAccountDeletionInProgress.value
                          ? null
                          : () => handleDeleteAccount(),
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

                        if (ref.read(previewModeProvider).isActive) {
                          if (context.mounted) {
                            AppToast.info(
                              context,
                              context.l10n.previewSignOutDisabled,
                            );
                          }
                        } else {
                          await ref.read(authProvider.notifier).signOut();
                        }
                      } finally {
                        if (context.mounted) {
                          // Handled by router/auth state change
                        }
                      }
                    },
                    child: material.Text(context.l10n.signOut,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: material.Text(
                    packageInfo.hasData
                        ? context.l10n.version(packageInfo.data!.version)
                        : '',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  /// Checks if wallet capture is enabled by querying Supabase for the wallet_capture_enabled flag
  Future<bool> _getWalletCaptureEnabled(WidgetRef ref) async {
    try {
      final authState = ref.read(authProvider);
      if (authState.uid.isEmpty) return false;

      final response = await Supabase.instance.client
          .from('user_contacts')
          .select('wallet_capture_enabled')
          .eq('user_id', authState.uid)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return (response?['wallet_capture_enabled'] as bool?) ?? false;
    } catch (e) {
      debugPrint('Error checking wallet capture enabled status: $e');
      return false;
    }
  }

  Future<bool> _getEmailImportEnabled(WidgetRef ref) async {
    try {
      final authState = ref.read(authProvider);
      if (authState.uid.isEmpty) return false;

      final response = await Supabase.instance.client
          .from('user_contacts')
          .select('email_import_enabled')
          .eq('user_id', authState.uid)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return (response?['email_import_enabled'] as bool?) ?? false;
    } catch (e) {
      debugPrint('Error checking email import enabled status: $e');
      return false;
    }
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.file,
    required this.onRemove,
  });

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            file,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.foreground.withValues(alpha: 0.85),
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
            ),
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: colorScheme.sheetBackground,
            ),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

Future<void> _showAvatarSourceSheet(
  BuildContext context,
  VoidCallback onUpdated,
) async {
  try {
    if (_isAvatarUploadInProgress) {
      if (context.mounted) {
        AppToast.info(context, context.l10n.updatingAvatar);
      }
      return;
    }

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
      await _uploadAndSaveAvatar(context, file, onUpdated);
    }
  } catch (e, st) {
    debugPrint('Avatar flow failed: $e\n$st');
    if (context.mounted) {
      AppToast.error(context, context.l10n.failedToSaveAvatar);
    }
  }
}

Future<void> _showReportBugSheet(BuildContext context) async {
  await _showSupportSheet(
    context: context,
    mode: _SupportSheetMode.reportBug,
  );
}

Future<void> _showSubmitFeedbackSheet(BuildContext context) async {
  await _showSupportSheet(
    context: context,
    mode: _SupportSheetMode.feedback,
  );
}

Future<void> _showSupportSheet({
  required BuildContext context,
  required _SupportSheetMode mode,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  await MonekoBottomSheet.show(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.sheetBackground,
    builder: (sheetContext) {
      return _SupportSheet(mode: mode);
    },
  );
}

const _maxTicketAttachments = 5;
const _maxAttachmentBytes = 5 * 1024 * 1024;
const _attachmentMinDimension = 1600;

class _SupportSheet extends HookConsumerWidget {
  const _SupportSheet({required this.mode});

  final _SupportSheetMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textController = useTextEditingController();
    final focusNode = useFocusNode();
    final picker = useMemoized(ImagePicker.new);
    final attachments = useState<List<File>>(<File>[]);
    final isSubmitting = useState(false);
    final includeDiagnostics = useState(true);
    useListenable(textController);
    useEffect(() {
      Future.microtask(() => focusNode.requestFocus());
      return null;
    }, const []);
    final currentMessage = textController.text.trim();
    final supportTicketService = ref.read(supportTicketServiceProvider);

    List<File> currentAttachments() => List<File>.from(attachments.value);

    Future<void> handlePick(_AttachmentSource source) async {
      final remainingSlots = _maxTicketAttachments - attachments.value.length;
      if (remainingSlots <= 0) {
        AppToast.info(
          context,
          context.l10n.attachmentLimitMessage(_maxTicketAttachments.toString()),
        );
        return;
      }

      if (source == _AttachmentSource.camera) {
        final selection = await pickImageWithGuard(
          picker: picker,
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 2048,
        );
        if (selection == null) return;
        attachments.value = [
          ...currentAttachments(),
          File(selection.path),
        ];
        return;
      }

      final picked = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 2048,
      );
      if (picked.isEmpty) return;
      final files =
          picked.take(remainingSlots).map((xfile) => File(xfile.path));
      attachments.value = [
        ...currentAttachments(),
        ...files,
      ];
    }

    Future<void> handleAttach() async {
      final selection = await MonekoActionSheet.show<_AttachmentSource>(
        context: context,
        title: context.l10n.attachAScreenshot,
        actions: [
          MonekoActionSheetAction(
            label: context.l10n.takePhoto,
            value: _AttachmentSource.camera,
            icon: Icons.photo_camera_outlined,
          ),
          MonekoActionSheetAction(
            label: context.l10n.chooseFromLibrary,
            value: _AttachmentSource.gallery,
            icon: Icons.photo_library_rounded,
          ),
        ],
        cancelAction: MonekoActionSheetAction(
          label: context.l10n.cancel,
          value: _AttachmentSource.cancel,
        ),
      );
      if (selection == null || selection == _AttachmentSource.cancel) {
        return;
      }
      await handlePick(selection);
    }

    Future<void> handleSubmit() async {
      final message = textController.text.trim();
      if (message.isEmpty) {
        HapticFeedback.mediumImpact();
        AppToast.info(
            context, context.l10n.pleaseDescribeTheIssueBeforeSubmitting);
        return;
      }
      if (message.length < 10) {
        HapticFeedback.mediumImpact();
        AppToast.info(
          context,
          context.l10n.pleaseIncludeAtLeast10Characters,
        );
        return;
      }
      if (isSubmitting.value) return;
      isSubmitting.value = true;
      final attachmentSizeErrorMessage =
          context.l10n.eachScreenshotMustBeSmallerThan5MB;
      try {
        final diagnostics =
            includeDiagnostics.value ? await _collectDeviceDiagnostics() : null;
        final preparedAttachments = await _createSupportAttachments(
          attachments.value,
          attachmentSizeErrorMessage,
        );
        final packageInfo = await PackageInfo.fromPlatform();
        final result = await supportTicketService.submitTicket(
          type: mode.ticketType,
          message: message,
          diagnostics: diagnostics,
          metadata: {
            'mode': mode.name,
            'includeDiagnostics': includeDiagnostics.value,
            'hasAttachments': attachments.value.isNotEmpty,
            'attachmentCount': attachments.value.length,
          },
          attachments: preparedAttachments,
          appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
          platform: _currentPlatformLabel(),
          source: 'settings_support_sheet',
        );

        if (context.mounted) {
          textController.clear();
          attachments.value = const [];
          Navigator.of(context).maybePop();
          final messageText = result.success
              ? mode.getSuccessMessage(context)
              : context.l10n.ticketSubmittedWeWillFollowUpSoon;
          AppToast.success(context, messageText);
        }
      } on SupportTicketException catch (error) {
        debugPrint('Support ticket submission failed: ${error.message}');
        if (context.mounted) {
          AppToast.error(
            context,
            error.message,
          );
        }
      } catch (error, stack) {
        debugPrint('Support submission failed: $error\n$stack');
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.somethingWentWrongWhileSubmittingTicket,
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height - mediaQuery.padding.top - 24;
    final isSubmitDisabled = currentMessage.isEmpty || isSubmitting.value;

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Material(
              color: colorScheme.sheetBackground,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + viewInsets),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.sheetBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          splashRadius: 20,
                          icon: const Icon(Icons.close_rounded),
                          color: colorScheme.foreground,
                          onPressed: isSubmitting.value
                              ? null
                              : () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.getTitle(context),
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.getDescription(context),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          borderRadius: BorderRadius.circular(999),
                          color: colorScheme.primary,
                          disabledColor:
                              colorScheme.primary.withValues(alpha: 0.4),
                          onPressed: isSubmitDisabled ? null : handleSubmit,
                          minimumSize: const Size(0, 0),
                          child: isSubmitting.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  context.l10n.submit,
                                  style: TextStyle(
                                    color: colorScheme.primaryForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        focusNode: focusNode,
                        controller: textController,
                        minLines: 5,
                        maxLines: 7,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.foreground,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: mode.getPlaceholder(context),
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SupportSheetActionCard(
                      onTap: handleAttach,
                      icon: Icons.photo_camera_outlined,
                      title: attachments.value.isEmpty
                          ? context.l10n.attachScreenshots
                          : context.l10n.addAnotherAttachment,
                      subtitle: attachments.value.isEmpty
                          ? context.l10n.addUpToImagesUnder5MBEach(
                              _maxTicketAttachments.toString())
                          : context.l10n.ofAttached(
                              attachments.value.length.toString(),
                              _maxTicketAttachments.toString(),
                            ),
                      trailing: attachments.value.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20),
                              color: colorScheme.mutedForeground,
                              onPressed: () => attachments.value = const [],
                            ),
                    ),
                    if (attachments.value.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final file in attachments.value)
                            _AttachmentPreview(
                              file: file,
                              onRemove: () {
                                attachments.value = currentAttachments()
                                  ..remove(file);
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.deviceInformation,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.l10n.includeAnonymizedDiagnostics,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: includeDiagnostics.value,
                              onChanged: (value) =>
                                  includeDiagnostics.value = value,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportSheetActionCard extends StatelessWidget {
  const _SupportSheetActionCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.foreground.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: colorScheme.foreground),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

enum _SupportSheetMode { reportBug, feedback }

extension _SupportSheetModeX on _SupportSheetMode {
  String getTitle(BuildContext context) {
    return switch (this) {
      _SupportSheetMode.reportBug => context.l10n.reportABugTitle,
      _SupportSheetMode.feedback => context.l10n.submitNewFeatureRequestTitle,
    };
  }

  String getDescription(BuildContext context) {
    return switch (this) {
      _SupportSheetMode.reportBug =>
        context.l10n.tellUsWhatWentWrongDescription,
      _SupportSheetMode.feedback =>
        context.l10n.shareIdeasFeatureRequestsDescription,
    };
  }

  String getPlaceholder(BuildContext context) {
    return switch (this) {
      _SupportSheetMode.reportBug =>
        context.l10n.whatHappenedIncludeStepsPlaceholder,
      _SupportSheetMode.feedback =>
        context.l10n.shareYourThoughtsFeatureIdeasPlaceholder,
    };
  }

  String getSuccessMessage(BuildContext context) {
    return switch (this) {
      _SupportSheetMode.reportBug => context.l10n.thanksBugReportQueue,
      _SupportSheetMode.feedback => context.l10n.thanksFeedbackTicketLogged,
    };
  }

  SupportTicketType get ticketType {
    return switch (this) {
      _SupportSheetMode.reportBug => SupportTicketType.bug,
      _SupportSheetMode.feedback => SupportTicketType.feedback,
    };
  }
}

enum _AttachmentSource { camera, gallery, cancel }

Future<Map<String, dynamic>> _collectDeviceDiagnostics() async {
  final plugin = DeviceInfoPlugin();
  final packageInfo = await PackageInfo.fromPlatform();
  final timezone = await resolveDeviceTimezoneIdentifier();
  final Map<String, dynamic> payload = {
    'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
    'locale': Platform.localeName,
    'timezone': timezone,
  };

  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    payload.addAll({
      'platform': 'android',
      'brand': info.brand,
      'model': info.model,
      'manufacturer': info.manufacturer,
      'osVersion': info.version.release,
      'sdk': info.version.sdkInt,
      'isPhysicalDevice': info.isPhysicalDevice,
    });
  } else if (Platform.isIOS) {
    final info = await plugin.iosInfo;
    payload.addAll({
      'platform': 'ios',
      'device': info.name,
      'model': info.model,
      'systemName': info.systemName,
      'systemVersion': info.systemVersion,
      'isPhysicalDevice': info.isPhysicalDevice,
    });
  } else {
    final info = await plugin.deviceInfo;
    payload.addAll({
      'platform': 'other',
      'data': info.data,
    });
  }

  return payload;
}

Future<List<SupportTicketAttachment>> _createSupportAttachments(
  List<File> files,
  String sizeErrorMessage,
) async {
  if (files.isEmpty) return const [];
  final attachments = <SupportTicketAttachment>[];
  for (final file in files) {
    if (!await file.exists()) {
      continue;
    }
    final optimized = await _compressAttachment(file);
    final bytes = optimized ?? await file.readAsBytes();
    if (bytes.length > _maxAttachmentBytes) {
      throw SupportTicketException(
        sizeErrorMessage,
      );
    }
    final fileName = file.path.split('/').last;
    attachments.add(
      SupportTicketAttachment(
        base64: base64Encode(bytes),
        fileName: fileName,
        contentType: _inferMimeType(fileName),
      ),
    );
  }
  return attachments;
}

Future<Uint8List?> _compressAttachment(File file) async {
  try {
    final format = _compressFormatForExtension(file.path);
    final quality = _compressQualityForExtension(file.path);
    return await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: quality,
      minWidth: _attachmentMinDimension,
      minHeight: _attachmentMinDimension,
      format: format,
      keepExif: true,
    );
  } catch (error, stack) {
    debugPrint('Attachment compression failed: $error\n$stack');
    return null;
  }
}

CompressFormat _compressFormatForExtension(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'png':
      return CompressFormat.png;
    case 'webp':
      return CompressFormat.webp;
    case 'heic':
      return CompressFormat.heic;
    default:
      return CompressFormat.jpeg;
  }
}

int _compressQualityForExtension(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  if (ext == 'png') {
    return 72;
  }
  return 70;
}

String _inferMimeType(String fileName) {
  final extension =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'jpeg':
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}

String _currentPlatformLabel() {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return Platform.operatingSystem;
}

Future<File?> _pickAndCropAvatarImage(
  BuildContext context,
  ImageSource source,
) async {
  try {
    final picker = ImagePicker();
    final XFile? image = await pickImageWithGuard(
      picker: picker,
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

    final outputFile = File(croppedFile.path);
    if (!await outputFile.exists()) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.failedToSaveAvatar);
      }
      return null;
    }

    final outputFileSize = await outputFile.length();
    if (!StorageConfig.isValidFileSize(outputFileSize)) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.imageTooLarge} (${StorageConfig.getFileSizeString(outputFileSize)}). '
          '${context.l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
        );
      }
      return null;
    }

    return outputFile;
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
  File imageFile,
  VoidCallback onUpdated,
) async {
  final l10n = context.l10n;

  if (_isAvatarUploadInProgress) {
    return;
  }

  _isAvatarUploadInProgress = true;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    _isAvatarUploadInProgress = false;
    return;
  }

  NavigatorState? rootNavigator;
  if (context.mounted) {
    try {
      rootNavigator = Navigator.of(context, rootNavigator: true);
    } catch (e, st) {
      debugPrint('Failed to get root navigator: $e\n$st');
    }
  }

  var dialogShown = false;
  var showSuccessToast = false;
  String? errorToastMessage;

  try {
    if (!await imageFile.exists()) {
      errorToastMessage = l10n.failedToSaveAvatar;
      return;
    }

    final fileSize = await imageFile.length();

    if (!StorageConfig.isValidFileSize(fileSize)) {
      errorToastMessage =
          '${l10n.imageTooLarge} (${StorageConfig.getFileSizeString(fileSize)}). '
          '${l10n.maxIs} ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.';
      return;
    }

    if (context.mounted) {
      try {
        await Future<void>.delayed(Duration.zero);
        if (context.mounted) {
          showBlockingProcessingDialog(
            context: context,
            message: l10n.updatingAvatar,
          );
          dialogShown = true;
        }
      } catch (e, st) {
        debugPrint('Failed to show avatar dialog: $e\n$st');
      }
    }

    final path = '${user.id}/avatar.png';

    // Read file bytes for deterministic hash computation
    final imageBytes = await imageFile.readAsBytes();

    await client.storage.from('avatars').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
            cacheControl: '31536000',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);

    // Use deterministic content hash for cache-busting instead of random
    // timestamp. Same avatar content -> same URL -> CDN/device cache hit.
    final contentHash = sha256.convert(imageBytes).toString().substring(0, 8);

    await client.from('users').update({
      'avatar_url': '$publicUrl?v=$contentHash',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    onUpdated();

    showSuccessToast = true;
  } catch (e, st) {
    debugPrint('Failed to upload/save avatar: $e\n$st');
    errorToastMessage = l10n.failedToSaveAvatar;
  } finally {
    _isAvatarUploadInProgress = false;
    if (dialogShown && rootNavigator != null && rootNavigator.mounted) {
      try {
        rootNavigator.pop();
      } catch (e, st) {
        debugPrint('Failed to dismiss avatar dialog: $e\n$st');
      }
    }

    if (context.mounted && errorToastMessage != null) {
      AppToast.error(context, errorToastMessage);
    } else if (context.mounted && showSuccessToast) {
      AppToast.success(context, l10n.avatarUpdated);
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
  final Future<void> Function() onAvatarTap;

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
                      : context.l10n.user);
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
                onTap: () async {
                  await onAvatarTap();
                },
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
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
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
          authState.displayName ?? context.l10n.user,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          authState.email,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
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
              fontSize: 11,
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
                      color: Colors.black.withValues(alpha: 0.05),
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
                      color: Colors.grey.withValues(alpha: 0.2),
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
    this.labelColor,
    this.value,
    this.valueWidget,
    this.trailing,
    this.iconColor,
    this.onTap,
    this.showChevron = true,
  });

  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color? labelColor;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  final Color? iconColor;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: customIcon ??
                    Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? colorScheme.onSurface,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: label == "Email" ? 1 : 4,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: labelColor ?? colorScheme.onSurface,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
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
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

const String _deviceTimezoneSentinel = '__DEVICE__';

const List<_TimezoneOption> _timezoneOptions = [
  _TimezoneOption(value: 'UTC-12:00', offsetMinutes: -720),
  _TimezoneOption(value: 'UTC-11:00', offsetMinutes: -660),
  _TimezoneOption(value: 'UTC-10:00', offsetMinutes: -600),
  _TimezoneOption(value: 'UTC-09:30', offsetMinutes: -570),
  _TimezoneOption(value: 'UTC-09:00', offsetMinutes: -540),
  _TimezoneOption(value: 'UTC-08:00', offsetMinutes: -480),
  _TimezoneOption(value: 'UTC-07:00', offsetMinutes: -420),
  _TimezoneOption(value: 'UTC-06:00', offsetMinutes: -360),
  _TimezoneOption(value: 'UTC-05:00', offsetMinutes: -300),
  _TimezoneOption(value: 'UTC-04:00', offsetMinutes: -240),
  _TimezoneOption(value: 'UTC-03:30', offsetMinutes: -210),
  _TimezoneOption(value: 'UTC-03:00', offsetMinutes: -180),
  _TimezoneOption(value: 'UTC-02:00', offsetMinutes: -120),
  _TimezoneOption(value: 'UTC-01:00', offsetMinutes: -60),
  _TimezoneOption(value: 'UTC', offsetMinutes: 0),
  _TimezoneOption(value: 'UTC+01:00', offsetMinutes: 60),
  _TimezoneOption(value: 'UTC+02:00', offsetMinutes: 120),
  _TimezoneOption(value: 'UTC+03:00', offsetMinutes: 180),
  _TimezoneOption(value: 'UTC+03:30', offsetMinutes: 210),
  _TimezoneOption(value: 'UTC+04:00', offsetMinutes: 240),
  _TimezoneOption(value: 'UTC+04:30', offsetMinutes: 270),
  _TimezoneOption(value: 'UTC+05:00', offsetMinutes: 300),
  _TimezoneOption(value: 'UTC+05:30', offsetMinutes: 330),
  _TimezoneOption(value: 'UTC+05:45', offsetMinutes: 345),
  _TimezoneOption(value: 'UTC+06:00', offsetMinutes: 360),
  _TimezoneOption(value: 'UTC+06:30', offsetMinutes: 390),
  _TimezoneOption(value: 'UTC+07:00', offsetMinutes: 420),
  _TimezoneOption(value: 'UTC+08:00', offsetMinutes: 480),
  _TimezoneOption(value: 'UTC+08:45', offsetMinutes: 525),
  _TimezoneOption(value: 'UTC+09:00', offsetMinutes: 540),
  _TimezoneOption(value: 'UTC+09:30', offsetMinutes: 570),
  _TimezoneOption(value: 'UTC+10:00', offsetMinutes: 600),
  _TimezoneOption(value: 'UTC+10:30', offsetMinutes: 630),
  _TimezoneOption(value: 'UTC+11:00', offsetMinutes: 660),
  _TimezoneOption(value: 'UTC+12:00', offsetMinutes: 720),
  _TimezoneOption(value: 'UTC+12:45', offsetMinutes: 765),
  _TimezoneOption(value: 'UTC+13:00', offsetMinutes: 780),
  _TimezoneOption(value: 'UTC+14:00', offsetMinutes: 840),
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
  final offsetMinutes = known?.offsetMinutes ??
      tryParseTimezoneOffsetMinutes(timezone) ??
      (preferFallback
          ? fallbackOffsetMinutes
          : resolveUserTimezoneOffsetMinutes(
              timezone,
              fallbackOffsetMinutes: fallbackOffsetMinutes,
              at: DateTime.now(),
            ));
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
  required BuildContext context,
  bool hideMatchingDeviceOffsetOption = false,
}) {
  final options = <String, _TimezoneOption>{
    for (final option in _timezoneOptions) option.value: option,
  };
  options[_deviceTimezoneSentinel] = _TimezoneOption(
    value: _deviceTimezoneSentinel,
    offsetMinutes: deviceOffsetMinutes,
    label: context.l10n.deviceTimezone,
  );

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

  if (_isValidFixedOffsetTimezone(currentTimezone)) {
    addIfMissing(currentTimezone);
  }

  if (hideMatchingDeviceOffsetOption) {
    final canonicalDeviceTimezone = canonicalTimezoneValue(deviceTimezone);
    if (canonicalDeviceTimezone != null) {
      options.remove(canonicalDeviceTimezone);
    }
  }

  final sorted = options.values.toList()
    ..sort((a, b) {
      final offsetComparison = a.offsetMinutes.compareTo(b.offsetMinutes);
      if (offsetComparison != 0) return offsetComparison;
      return (a.label ?? a.value).compareTo(b.label ?? b.value);
    });

  return sorted;
}

bool _isValidFixedOffsetTimezone(String? timezone) {
  final trimmed = timezone?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  return tryParseTimezoneOffsetMinutes(trimmed) != null;
}

bool _isLegacyTimezoneValue(String timezone) {
  final trimmed = timezone.trim();
  if (trimmed.isEmpty) return false;
  return !_isValidFixedOffsetTimezone(trimmed);
}

Future<void> _showEditNameSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String initialName,
  required VoidCallback onUpdated,
}) async {
  final authState = ref.read(authProvider);
  final l10n = context.l10n;

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
    AppToast.info(ctx, ctx.l10n.pleaseEnterAValidName);
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

    // Keep denormalized household member names in sync in environments where
    // household_members.user_name exists.
    try {
      await Supabase.instance.client
          .from('household_members')
          .update({'user_name': newName}).eq('user_id', userId);
    } on PostgrestException catch (e) {
      final message = (e.message).toLowerCase();
      final missingUserNameColumn = e.code == '42703' ||
          (e.code == 'PGRST204' && message.contains('user_name'));
      if (!missingUserNameColumn) rethrow;
    }

    onUpdated();

    if (!ctx.mounted) return;
    final navigator = Navigator.of(ctx);
    if (navigator.canPop()) {
      navigator.pop();
    }
    AppToast.success(ctx, ctx.l10n.profileUpdated);
  } catch (e) {
    if (ctx.mounted) {
      AppToast.error(
        ctx,
        ctx.l10n.failedToUpdate(e.toString()),
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
          fontSize: 30,
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

const String _telegramSvg =
    '''<svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><title>Telegram</title><path d="M11.944 0A12 12 0 1 0 24 12 12.002 12.002 0 0 0 11.944 0Zm5.368 7.747-1.968 9.28c-.146.66-.534.822-1.083.512l-2.99-2.206-1.444 1.39c-.159.159-.292.292-.595.292l.213-3.053 5.56-5.022c.242-.213-.054-.332-.376-.12l-6.873 4.33-2.962-.926c-.646-.2-.66-.646.136-.956l11.584-4.468c.535-.2 1.003.12.798.947Z"/></svg>''';

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
  if (lc == 'th') return 'ไทย';
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

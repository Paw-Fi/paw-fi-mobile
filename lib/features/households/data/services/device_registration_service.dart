import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Global container for deep link handling from FCM
class DeepLinkContainer {
  static DeepLinkService? deepLinkService;
  static WidgetRef? ref;
}

/// Service for managing push notification device registration
class DeviceRegistrationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;

  static const String _androidChannelId = 'high_importance_channel';
  static const String _androidChannelName = 'High Importance Notifications';
  static const String _androidChannelDescription =
      'Used for important notifications.';
  static const String _updatesChannelId =
      'household_updates'; // must match server channel_id
  static const String _updatesChannelName = 'Household Updates';

  DeviceRegistrationService(
    this._supabase,
    this._messaging,
    this._localNotifications,
  );

  /// Initialize push notifications
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔔 Device registration service already initialized');
      return;
    }
    debugPrint('🔔 Initializing device registration service...');

    try {
      // Wrap entire initialization in a timeout to prevent hanging
      await _performInitialization().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              '⚠️ Device registration initialization timed out after 10s');
          throw TimeoutException('Device registration timed out');
        },
      );
    } catch (e) {
      debugPrint('❌ Device registration initialization failed: $e');
      // Mark as initialized anyway to prevent blocking app startup
      _initialized = true;
      rethrow;
    }
  }

  /// Perform the actual initialization (extracted for timeout handling)
  Future<void> _performInitialization() async {
    // Android 13+: request notifications permission via permission_handler
    if (Platform.isAndroid) {
      try {
        final status = await Permission.notification.request().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Android notification permission request timed out');
            return PermissionStatus.denied;
          },
        );
        if (status.isDenied) {
          debugPrint(
              '⚠️ Notification permission denied on Android (continuing to obtain FCM token)');
        }
      } catch (e) {
        debugPrint('⚠️ Android notification permission request failed: $e');
      }
    }

    // Request permission (iOS) and general settings
    final settings = await _messaging
        .requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    )
        .timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('⚠️ FCM permission request timed out');
        return const NotificationSettings(
          authorizationStatus: AuthorizationStatus.notDetermined,
          alert: AppleNotificationSetting.notSupported,
          announcement: AppleNotificationSetting.notSupported,
          badge: AppleNotificationSetting.notSupported,
          carPlay: AppleNotificationSetting.notSupported,
          lockScreen: AppleNotificationSetting.notSupported,
          notificationCenter: AppleNotificationSetting.notSupported,
          showPreviews: AppleShowPreviewSetting.notSupported,
          timeSensitive: AppleNotificationSetting.notSupported,
          criticalAlert: AppleNotificationSetting.notSupported,
          sound: AppleNotificationSetting.notSupported,
          providesAppNotificationSettings:
              AppleNotificationSetting.notSupported,
        );
      },
    );

    // iOS/macOS: ensure foreground notifications can be shown while app is open
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (authorized) {
      debugPrint('✅ Push notification permission granted');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // iOS local notification presentation already enabled via FCM options above

      // Listen for token refresh first so we don't miss an early emission
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        registerDevice(newToken);
      });

      // iOS: wait briefly for APNs token to be assigned before requesting FCM token
      if (Platform.isIOS) {
        final apns = await _waitForApnsToken(timeoutMs: 10000);
        debugPrint('🍎 APNs Token: ${apns ?? "<null>"}');
      }

      // Get and register FCM token (gracefully handle APNs-not-ready scenarios)
      try {
        String? token = await _messaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ FCM getToken timed out');
            return null;
          },
        );
        if (token == null && Platform.isIOS) {
          // Retry once after APNs likely ready
          token = await _messaging.getToken().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ FCM getToken retry timed out');
              return null;
            },
          );
        }

        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          await registerDevice(token);
        } else {
          debugPrint('⚠️ FCM token is null; waiting for onTokenRefresh');
        }
      } catch (e) {
        debugPrint('⚠️ getToken failed: $e');
        // Rely on onTokenRefresh later
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message opened
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      _initialized = true;
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('❌ Push notification permission denied');
      _initialized = true; // Mark as initialized even if denied
    } else {
      debugPrint('⚠️ Push notification permission not determined');
      _initialized = true; // Mark as initialized even if not determined
    }
  }

  /// Wait for APNs token to be set (iOS only). Returns null if not ready in time.
  Future<String?> _waitForApnsToken({int timeoutMs = 10000}) async {
    if (!Platform.isIOS) return null;
    final start = DateTime.now().millisecondsSinceEpoch;
    String? apns;
    while (DateTime.now().millisecondsSinceEpoch - start < timeoutMs) {
      try {
        apns = await _messaging.getAPNSToken();
      } catch (_) {}
      if (apns != null && apns.isNotEmpty) return apns;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return apns;
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    // Use monochrome adaptive icon from mipmap for status bar
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher_monochrome');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Ensure the FCM channel used by the server exists
      const updatesChannel = AndroidNotificationChannel(
        _updatesChannelId,
        _updatesChannelName,
        description: 'Household-related updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(updatesChannel);
    }
  }

  /// Register device with backend
  Future<void> registerDevice(String pushToken) async {
    try {
      // Skip frequent re-registration: compare with last cached token and time
      final userId = _supabase.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      final cachePrefix = 'device_reg:${userId ?? "anon"}:';
      final lastToken = prefs.getString('${cachePrefix}token');
      final lastAtIso = prefs.getString('${cachePrefix}registered_at');
      final now = DateTime.now();
      DateTime? lastAt =
          lastAtIso != null ? DateTime.tryParse(lastAtIso) : null;

      // Re-register only if token changed or older than 24h
      if (lastToken == pushToken &&
          lastAt != null &&
          now.difference(lastAt) < const Duration(hours: 24)) {
        debugPrint(
            '⏭️ Skipping device registration (cached, <24h, token unchanged)');
        return;
      }

      debugPrint('📤 Registering device with backend...');

      final response = await _supabase.functions.invoke(
        'households-register-device',
        body: {
          'platform': Platform.isIOS ? 'ios' : 'android',
          'push_token': pushToken,
          'device_model': await _getDeviceModel(),
          'os_version': Platform.operatingSystemVersion,
        },
      );

      if (response.status == 200) {
        debugPrint('✅ Device registered successfully');
        await prefs.setString('${cachePrefix}token', pushToken);
        await prefs.setString(
            '${cachePrefix}registered_at', now.toIso8601String());
      } else {
        debugPrint('❌ Device registration failed: ${response.status}');
      }
    } catch (e) {
      // Treat 409 "Device already registered" as a non-fatal, idempotent success
      if (e is FunctionException && e.status == 409) {
        debugPrint(
            'ℹ️ Device already registered on backend (409), treating as success');

        try {
          final userId = _supabase.auth.currentUser?.id;
          final prefs = await SharedPreferences.getInstance();
          final cachePrefix = 'device_reg:${userId ?? "anon"}:';
          final now = DateTime.now();

          await prefs.setString('${cachePrefix}token', pushToken);
          await prefs.setString(
              '${cachePrefix}registered_at', now.toIso8601String());
        } catch (_) {
          // Ignore cache errors here; registration is already valid on backend
        }

        return;
      }

      debugPrint('❌ Error registering device: $e');
    }
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    debugPrint('📬 Title: ${message.notification?.title}');
    debugPrint('📬 Body: ${message.notification?.body}');
    debugPrint('📬 Data: ${message.data}');

    // Android: show local notification when app is in foreground
    // iOS already shows system banner via foreground presentation options
    if (Platform.isAndroid) {
      _showLocalNotification(message);
    }
  }

  /// Handle background message opened (user tapped notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('🔔 Background message opened: ${message.messageId}');
    debugPrint('🔔 Data: ${message.data}');

    // Handle navigation using deep link if provided
    final deepLink = message.data['deep_link'];
    if (deepLink != null && deepLink.isNotEmpty) {
      debugPrint('🔗 Deep link found: $deepLink');

      // Wait a bit for app to be ready, then trigger deep link directly
      Future.delayed(const Duration(milliseconds: 500), () {
        if (DeepLinkContainer.deepLinkService != null &&
            DeepLinkContainer.ref != null) {
          final uri = Uri.parse(deepLink);
          debugPrint('🚀 Triggering deep link directly: $deepLink');
          DeepLinkContainer.deepLinkService!
              .handleDeepLinkUri(uri, DeepLinkContainer.ref!);
        }
      });
    } else {
      // Fallback to legacy navigation
      final type = message.data['type'];
      final householdId = message.data['household_id'];

      if (type == 'budget_warn' || type == 'budget_alert') {
        // Navigate to household overview
        debugPrint('📊 Navigating to household: $householdId');
        // TODO: Implement navigation to household overview
      } else if (type == 'invite_accepted') {
        // Navigate to household members
        debugPrint('👥 Navigating to household members: $householdId');
        // TODO: Implement navigation to members page
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher_monochrome',
      color: AppTheme.monekoPrimary,
      // Use a guaranteed-present drawable to avoid runtime crashes if a custom
      // logo resource is missing in a given build.
      largeIcon: DrawableResourceAndroidBitmap('ic_stat_notification'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Moneko',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap (for local notifications shown in foreground)
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');

    // The payload contains the deep_link if available
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // The payload is the message.data.toString(), we need to parse it
        // For now, we'll just log it - in production, you'd parse the map
        // and extract the deep_link field
        debugPrint('📦 Payload: ${response.payload}');
        // TODO: Parse payload map and extract deep_link, then call _triggerDeepLink
      } catch (e) {
        debugPrint('⚠️ Failed to parse notification payload: $e');
      }
    }
  }

  /// Check if device is registered with backend (checks cache and token existence)
  Future<bool> isRegistered() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final cachePrefix = 'device_reg:$userId:';
      final cachedToken = prefs.getString('${cachePrefix}token');

      // Check if we have a cached token and it's recent
      if (cachedToken != null && cachedToken.isNotEmpty) {
        final lastAtIso = prefs.getString('${cachePrefix}registered_at');
        if (lastAtIso != null) {
          final lastAt = DateTime.tryParse(lastAtIso);
          if (lastAt != null &&
              DateTime.now().difference(lastAt) < const Duration(days: 7)) {
            debugPrint(
                '✅ Device registration found in cache (token: ${cachedToken.substring(0, 10)}...)');
            return true;
          }
        }
      }

      debugPrint('⚠️ No valid device registration found in cache');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking registration status: $e');
      return false;
    }
  }

  /// Get device model
  Future<String> _getDeviceModel() async {
    if (Platform.isIOS) {
      return 'iOS Device'; // You can use device_info_plus for actual model
    } else if (Platform.isAndroid) {
      return 'Android Device'; // You can use device_info_plus for actual model
    }
    return 'Unknown';
  }

  /// Unregister device (call on logout)
  Future<void> unregisterDevice() async {
    try {
      // If there's no session, just clear local cache and exit silently
      if (_supabase.auth.currentSession == null) {
        debugPrint('⚠️ No active session during unregister; skipping backend call');
      }
      // Get user ID before it's cleared by logout
      final userId = _supabase.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      final cachePrefix = 'device_reg:${userId ?? "anon"}:';

      // Try to get token from cache first (more reliable than FCM during logout)
      String? token = prefs.getString('${cachePrefix}token');

      // Fallback to FCM token if cache is empty
      if (token == null || token.isEmpty) {
        token = await _messaging.getToken();
      }

      if (token != null && token.isNotEmpty) {
        debugPrint('🗑️ Deleting device from backend...');

        // Call Edge Function to DELETE device row (not just mark inactive)
        if (_supabase.auth.currentSession != null) {
          final response = await _supabase.functions.invoke(
            'households-register-device',
            body: {
              'platform': Platform.isIOS ? 'ios' : 'android',
              'push_token': token,
              'delete_device': true,
            },
          );

          if (response.status == 200) {
            debugPrint('✅ Device deleted from backend successfully');
          } else {
            debugPrint('⚠️ Device deletion failed: ${response.status}');
          }
        } else {
          debugPrint('⚠️ Skipping backend delete - session missing');
        }
      } else {
        debugPrint('⚠️ No push token found to delete');
      }

      // Always clear local cache, even if backend deletion fails
      try {
        // Remove cached entries for current (or anon) prefix
        await prefs.remove('${cachePrefix}token');
        await prefs.remove('${cachePrefix}registered_at');

        // Additionally, purge ALL device_reg caches to avoid cross-account residue
        final keys = prefs.getKeys();
        for (final k in keys.where((k) => k.startsWith('device_reg:'))) {
          await prefs.remove(k);
        }
        debugPrint('✅ Local device cache cleared (all prefixes)');
      } catch (e) {
        debugPrint('⚠️ Failed to clear local device cache: $e');
      }

      // Force FCM to drop the current token so next login fetches a fresh one
      try {
        await _messaging.deleteToken();
        debugPrint('🗑️ FCM token deleted locally');
      } catch (e) {
        debugPrint('⚠️ Failed to delete FCM token locally: $e');
      }

      // Ensure service can re-initialize cleanly on next login
      _initialized = false;
    } catch (e) {
      if (e is FunctionException && e.status == 401) {
        debugPrint('⚠️ Unregister skipped: session unauthorized (likely logged out)');
      } else {
        debugPrint('❌ Error unregistering device: $e');
      }

      // Still try to clear cache even if deletion failed
      try {
        final userId = _supabase.auth.currentUser?.id;
        final prefs = await SharedPreferences.getInstance();
        final cachePrefix = 'device_reg:${userId ?? "anon"}:';
        await prefs.remove('${cachePrefix}token');
        await prefs.remove('${cachePrefix}registered_at');
        final keys = prefs.getKeys();
        for (final k in keys.where((k) => k.startsWith('device_reg:'))) {
          await prefs.remove(k);
        }
      } catch (_) {
        // Ignore cache clearing errors
      }
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('🧹 Cleared all local notifications');
    } catch (e) {
      debugPrint('⚠️ Failed to clear local notifications: $e');
    }
  }
}

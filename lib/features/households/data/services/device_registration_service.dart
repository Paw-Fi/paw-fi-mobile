import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing push notification device registration
class DeviceRegistrationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  DeviceRegistrationService(
    this._supabase,
    this._messaging,
    this._localNotifications,
  );

  /// Initialize push notifications
  Future<void> initialize() async {
    debugPrint('🔔 Initializing device registration service...');

    // Android 13+: request notifications permission via permission_handler
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        debugPrint('⚠️ Notification permission denied on Android');
        return;
      }
    }

    // Request permission (iOS) and general settings
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Push notification permission granted');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get and register FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
        await registerDevice(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        registerDevice(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message opened
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('❌ Push notification permission denied');
    } else {
      debugPrint('⚠️ Push notification permission not determined');
    }
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        'household_budgets',
        'Household Budgets',
        description: 'Notifications for household budget alerts and nudges',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Register device with backend
  Future<void> registerDevice(String pushToken) async {
    try {
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
      } else {
        debugPrint('❌ Device registration failed: ${response.status}');
      }
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    debugPrint('📬 Title: ${message.notification?.title}');
    debugPrint('📬 Body: ${message.notification?.body}');
    debugPrint('📬 Data: ${message.data}');

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Handle background message opened (user tapped notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('🔔 Background message opened: ${message.messageId}');
    debugPrint('🔔 Data: ${message.data}');

    // Handle navigation based on notification data
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

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'household_budgets',
      'Household Budgets',
      channelDescription: 'Notifications for household budget alerts and nudges',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
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

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Parse payload and navigate to appropriate screen
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
      final token = await _messaging.getToken();
      if (token != null) {
        // Call Edge Function to mark device as inactive
        await _supabase.functions.invoke(
          'households-register-device',
          body: {
            'push_token': token,
            'is_active': false,
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error unregistering device: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Title: ${message.notification?.title}');
  debugPrint('🔔 Body: ${message.notification?.body}');
  debugPrint('🔔 Data: ${message.data}');
}

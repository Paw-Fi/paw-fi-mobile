import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/core/notifications/notification_intent_parser.dart';
import 'package:moneko/core/theme/app_theme.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

final householdRemoteMutationRefreshSignalProvider =
    StateProvider.family<int, String>((ref, householdId) => 0);

const _householdMutationRefreshEventTypes = {
  'expense_added',
  'expense_edited',
  'expense_deleted',
  'split_settled',
  'settlement_completed',
};

@foundation.visibleForTesting
Future<String?> clearHouseholdMutationCaches(
  Map<String, dynamic> data,
) async {
  final eventType = data['event_type']?.toString();
  final householdId = data['household_id']?.toString().trim();
  if (householdId == null || householdId.isEmpty) return null;
  if (!_householdMutationRefreshEventTypes.contains(eventType)) return null;

  try {
    final prefs = await SharedPreferences.getInstance();
    final prefixes = <String>[
      'households:splits:v1:$householdId:',
      'households:expenses:v1:$householdId:',
      'households:summary:v1:$householdId:',
      'households:settlement-payments:v1:$householdId:',
    ];
    final keys = prefs.getKeys().where(
          (key) => prefixes.any(key.startsWith),
        );
    await Future.wait(keys.map(prefs.remove));
  } catch (_) {}

  return householdId;
}

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

enum DeviceRegistrationResult {
  registered,
  alreadyRegistered,
  deferredUntilPrompted,
  permissionDenied,
  tokenUnavailable,
  backendRejected,
  unauthenticated,
  failed,
}

abstract interface class DeviceRegistrationGateway {
  String? get currentUserId;
  bool get hasActiveSession;
  bool get isIOS;
  bool get isAndroid;
  Stream<String> get onTokenRefresh;

  Future<void> requestAndroidNotificationPermission();
  Future<NotificationSettings> requestMessagingPermission();
  Future<void> configureForegroundPresentation();
  Future<String?> getApnsToken();
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<bool> registerDevice(String pushToken);
  Future<bool> unregisterDevice(String pushToken);
}

class FirebaseDeviceRegistrationGateway implements DeviceRegistrationGateway {
  FirebaseDeviceRegistrationGateway(this._supabase, this._messaging);

  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  bool get hasActiveSession => _supabase.auth.currentSession != null;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> requestAndroidNotificationPermission() async {
    await Permission.notification.request().timeout(
          const Duration(seconds: 5),
          onTimeout: () => PermissionStatus.denied,
        );
  }

  @override
  Future<NotificationSettings> requestMessagingPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  @override
  Future<void> configureForegroundPresentation() {
    return _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<String?> getApnsToken() => _messaging.getAPNSToken();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Future<bool> registerDevice(String pushToken) async {
    try {
      final response = await _supabase.functions.invoke(
        'households-register-device',
        body: {
          'platform': isIOS ? 'ios' : 'android',
          'push_token': pushToken,
          'device_model': isIOS ? 'iOS Device' : 'Android Device',
          'os_version': Platform.operatingSystemVersion,
        },
      );
      return response.status == 200;
    } on FunctionException catch (error) {
      return error.status == 409;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unregisterDevice(String pushToken) async {
    try {
      final response = await _supabase.functions.invoke(
        'households-register-device',
        body: {
          'platform': isIOS ? 'ios' : 'android',
          'push_token': pushToken,
          'delete_device': true,
        },
      );
      return response.status == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Service for managing push notification device registration
class DeviceRegistrationService {
  final Ref _ref;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final DeviceRegistrationGateway _gateway;
  final Duration _apnsTokenWaitTimeout;
  final Duration _interactionHandlersTimeout;
  final NotificationIntentParser _intentParser = NotificationIntentParser();
  late final Future<void> Function() _interactionHandlersInitializer;
  bool _initialized = false;
  String? _initializedUserId;
  bool _interactionHandlersInitialized = false;
  bool _tokenRefreshListenerInitialized = false;
  Future<DeviceRegistrationResult>? _initializationFuture;
  String? _initializationUserId;
  bool _initializationBypassesPromptGate = false;
  int _lifecycleGeneration = 0;
  bool _acceptTokenRefreshes = false;
  Future<void> _tokenRefreshQueue = Future.value();
  Future<void>? _sessionCleanupFuture;

  static const String _androidChannelId = 'high_importance_channel';
  static const String _androidChannelName = 'High Importance Notifications';
  static const String _androidChannelDescription =
      'Used for important notifications.';
  static const String _updatesChannelId =
      'household_updates'; // must match server channel_id
  static const String _updatesChannelName = 'Household Updates';
  static const String _defaultFcmChannelId =
      'moneko_notifications'; // must match AndroidManifest fallback channel
  static const String _defaultFcmChannelName = 'Moneko Notifications';

  DeviceRegistrationService(
    this._ref,
    SupabaseClient supabase,
    this._messaging,
    this._localNotifications, {
    DeviceRegistrationGateway? gateway,
    Future<void> Function()? interactionHandlersInitializer,
    Duration apnsTokenWaitTimeout = const Duration(seconds: 10),
    Duration interactionHandlersTimeout = const Duration(seconds: 5),
  })  : _gateway =
            gateway ?? FirebaseDeviceRegistrationGateway(supabase, _messaging),
        _apnsTokenWaitTimeout = apnsTokenWaitTimeout,
        _interactionHandlersTimeout = interactionHandlersTimeout {
    _interactionHandlersInitializer =
        interactionHandlersInitializer ?? _ensureInteractionHandlersInitialized;
  }

  /// Initialize push notifications
  Future<DeviceRegistrationResult> initialize({
    bool force = false,
    bool bypassPromptGate = false,
  }) {
    final sessionCleanup = _sessionCleanupFuture;
    if (sessionCleanup != null) {
      return sessionCleanup.then(
        (_) => initialize(
          force: force,
          bypassPromptGate: bypassPromptGate,
        ),
      );
    }

    final currentUserId = _gateway.currentUserId;
    if (_initialized &&
        _initializedUserId == currentUserId &&
        currentUserId != null &&
        !force) {
      _debugPrint('🔔 Device registration service already initialized');
      return Future.value(DeviceRegistrationResult.alreadyRegistered);
    }

    final inFlight = _initializationFuture;
    if (inFlight != null) {
      final canShareAttempt = _initializationUserId == currentUserId &&
          (!bypassPromptGate || _initializationBypassesPromptGate);
      if (canShareAttempt) return inFlight;

      return inFlight.then((_) {
        if (_gateway.currentUserId != currentUserId) {
          return DeviceRegistrationResult.unauthenticated;
        }
        return initialize(
          force: force,
          bypassPromptGate: bypassPromptGate,
        );
      });
    }

    final generation = _lifecycleGeneration;
    late final Future<DeviceRegistrationResult> future;
    future = _initialize(
      expectedUserId: currentUserId,
      generation: generation,
      bypassPromptGate: bypassPromptGate,
    ).whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
        _initializationUserId = null;
        _initializationBypassesPromptGate = false;
      }
    });
    _initializationFuture = future;
    _initializationUserId = currentUserId;
    _initializationBypassesPromptGate = bypassPromptGate;
    return future;
  }

  Future<DeviceRegistrationResult> _initialize({
    required String? expectedUserId,
    required int generation,
    required bool bypassPromptGate,
  }) async {
    _debugPrint('🔔 Initializing device registration service...');
    try {
      final userId = expectedUserId;
      if (userId == null || userId.isEmpty || !_gateway.hasActiveSession) {
        return DeviceRegistrationResult.unauthenticated;
      }

      if (!bypassPromptGate) {
        final prefs = await SharedPreferences.getInstance();
        final prompted =
            prefs.getBool('notifications_prompted:$userId') ?? false;
        if (!prompted) {
          _debugPrint(
              '⏭️ Skipping notification permission prompt until onboarding page triggers it');
          return DeviceRegistrationResult.deferredUntilPrompted;
        }
      }
      if (!_isCurrentAttempt(userId, generation)) {
        return DeviceRegistrationResult.unauthenticated;
      }

      final result = await _performInitialization(
        expectedUserId: userId,
        generation: generation,
      );
      if (!_isCurrentAttempt(userId, generation)) {
        return DeviceRegistrationResult.unauthenticated;
      }
      _initialized = result == DeviceRegistrationResult.registered;
      _initializedUserId = _initialized ? userId : null;
      return result;
    } catch (_) {
      _debugPrint('❌ Device registration initialization failed');
      _initialized = false;
      _initializedUserId = null;
      return DeviceRegistrationResult.failed;
    }
  }

  bool _isCurrentAttempt(String userId, int generation) {
    return generation == _lifecycleGeneration &&
        _gateway.hasActiveSession &&
        _gateway.currentUserId == userId;
  }

  /// Perform the actual initialization (extracted for timeout handling)
  Future<DeviceRegistrationResult> _performInitialization({
    required String expectedUserId,
    required int generation,
  }) async {
    await _interactionHandlersInitializer()
        .timeout(_interactionHandlersTimeout);
    if (!_isCurrentAttempt(expectedUserId, generation)) {
      return DeviceRegistrationResult.unauthenticated;
    }

    // Android 13+: request notifications permission via permission_handler
    if (_gateway.isAndroid) {
      try {
        await _gateway.requestAndroidNotificationPermission();
      } catch (_) {
        _debugPrint('⚠️ Android notification permission request failed');
      }
    }

    // Request permission (iOS) and general settings
    final settings = await _gateway.requestMessagingPermission().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _debugPrint('⚠️ FCM permission request timed out');
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
    if (!_isCurrentAttempt(expectedUserId, generation)) {
      return DeviceRegistrationResult.unauthenticated;
    }

    // iOS/macOS: ensure foreground notifications can be shown while app is open
    if (_gateway.isIOS) {
      await _gateway.configureForegroundPresentation().timeout(
            const Duration(seconds: 5),
          );
    }

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (authorized) {
      _debugPrint('✅ Push notification permission granted');
      if (!_isCurrentAttempt(expectedUserId, generation)) {
        return DeviceRegistrationResult.unauthenticated;
      }
      _acceptTokenRefreshes = true;

      // Listen for token refresh first so we don't miss an early emission
      if (!_tokenRefreshListenerInitialized) {
        _gateway.onTokenRefresh.listen((newToken) {
          _debugPrint('🔄 FCM Token refreshed');
          _enqueueTokenRefresh(newToken);
        });
        _tokenRefreshListenerInitialized = true;
      }

      // iOS: wait briefly for APNs token to be assigned before requesting FCM token
      if (_gateway.isIOS) {
        final apns = await _waitForApnsToken();
        _debugPrint(
            '🍎 APNs Token ${apns != null ? "obtained" : "unavailable"}');
        if (apns == null) {
          return DeviceRegistrationResult.tokenUnavailable;
        }
      }

      // Get and register FCM token (gracefully handle APNs-not-ready scenarios)
      String? token;
      try {
        token = await _gateway.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _debugPrint('⚠️ FCM getToken timed out');
            return null;
          },
        );
      } catch (_) {
        _debugPrint('⚠️ getToken failed');
        return DeviceRegistrationResult.tokenUnavailable;
      }

      if (token == null || token.isEmpty) {
        _debugPrint('⚠️ FCM token is null; waiting for onTokenRefresh');
        return DeviceRegistrationResult.tokenUnavailable;
      }
      _debugPrint('📱 FCM Token obtained');
      return registerDevice(
        token,
        expectedUserId: expectedUserId,
        generation: generation,
      );
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _debugPrint('❌ Push notification permission denied');
      return DeviceRegistrationResult.permissionDenied;
    } else {
      _debugPrint('⚠️ Push notification permission not determined');
      return DeviceRegistrationResult.permissionDenied;
    }
  }

  /// Wait for APNs token to be set (iOS only). Returns null if not ready in time.
  Future<String?> _waitForApnsToken() async {
    if (!_gateway.isIOS) return null;
    final stopwatch = Stopwatch()..start();
    while (true) {
      try {
        final apns = await _gateway.getApnsToken();
        if (apns != null && apns.isNotEmpty) return apns;
      } catch (_) {}
      if (stopwatch.elapsed >= _apnsTokenWaitTimeout) return null;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _ensureInteractionHandlersInitialized() async {
    if (_interactionHandlersInitialized) {
      return;
    }

    await _initializeLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message opened
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    _interactionHandlersInitialized = true;

    // Check for initial message (app opened from terminated state)
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
    } catch (_) {
      _debugPrint('⚠️ Failed to read initial FCM notification message');
    }
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

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    final launchPayload = launchResponse?.payload;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _dispatchPayloadString(launchPayload, source: 'local_launch');
    }

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

      const defaultFcmChannel = AndroidNotificationChannel(
        _defaultFcmChannelId,
        _defaultFcmChannelName,
        description: 'Default notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(defaultFcmChannel);
    }
  }

  /// Register device with backend
  Future<DeviceRegistrationResult> registerDevice(
    String pushToken, {
    String? expectedUserId,
    int? generation,
  }) async {
    try {
      final userId = expectedUserId ?? _gateway.currentUserId;
      final attemptGeneration = generation ?? _lifecycleGeneration;
      if (userId == null ||
          userId.isEmpty ||
          !_isCurrentAttempt(userId, attemptGeneration)) {
        return DeviceRegistrationResult.unauthenticated;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachePrefix = 'device_reg:$userId:';
      final previousToken = prefs.getString('${cachePrefix}token');
      final now = DateTime.now();
      if (!_isCurrentAttempt(userId, attemptGeneration)) {
        return DeviceRegistrationResult.unauthenticated;
      }

      _debugPrint('📤 Registering device with backend...');
      final registered = await _gateway.registerDevice(pushToken);
      if (!registered) {
        _debugPrint('❌ Device registration failed');
        return DeviceRegistrationResult.backendRejected;
      }
      if (!_isCurrentAttempt(userId, attemptGeneration)) {
        return DeviceRegistrationResult.unauthenticated;
      }

      _debugPrint('✅ Device registered successfully');
      if (previousToken != null &&
          previousToken.isNotEmpty &&
          previousToken != pushToken) {
        await _gateway.unregisterDevice(previousToken);
        if (!_isCurrentAttempt(userId, attemptGeneration)) {
          return DeviceRegistrationResult.unauthenticated;
        }
      }
      await prefs.setString('${cachePrefix}token', pushToken);
      if (!_isCurrentAttempt(userId, attemptGeneration)) {
        await _clearRegistrationCacheForUser(prefs, userId);
        return DeviceRegistrationResult.unauthenticated;
      }
      await prefs.setString(
          '${cachePrefix}registered_at', now.toIso8601String());
      if (!_isCurrentAttempt(userId, attemptGeneration)) {
        await _clearRegistrationCacheForUser(prefs, userId);
        return DeviceRegistrationResult.unauthenticated;
      }
      return DeviceRegistrationResult.registered;
    } catch (_) {
      _debugPrint('❌ Error registering device');
      return DeviceRegistrationResult.failed;
    }
  }

  void _enqueueTokenRefresh(String pushToken) {
    if (!_acceptTokenRefreshes) return;
    final userId = _gateway.currentUserId;
    final generation = _lifecycleGeneration;
    if (userId == null || !_isCurrentAttempt(userId, generation)) return;

    _tokenRefreshQueue = _tokenRefreshQueue
        .then(
          (_) => _registerRefreshedToken(
            pushToken,
            expectedUserId: userId,
            generation: generation,
          ),
        )
        .catchError((_) {});
  }

  Future<void> _registerRefreshedToken(
    String pushToken, {
    required String expectedUserId,
    required int generation,
  }) async {
    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      await pendingInitialization;
    }
    if (!_isCurrentAttempt(expectedUserId, generation)) return;

    final result = await registerDevice(
      pushToken,
      expectedUserId: expectedUserId,
      generation: generation,
    );
    if (result == DeviceRegistrationResult.registered &&
        _isCurrentAttempt(expectedUserId, generation)) {
      _initialized = true;
      _initializedUserId = expectedUserId;
    }
  }

  Future<DeviceRegistrationResult> repairDeviceRegistration() {
    return initialize(force: true, bypassPromptGate: true);
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    _debugPrint('📬 Foreground message received');
    unawaited(_refreshHouseholdMutationData(message.data));

    // Android: show local notification when app is in foreground
    // iOS already shows system banner via foreground presentation options
    if (Platform.isAndroid) {
      _showLocalNotification(message);
    }
  }

  Future<void> _refreshHouseholdMutationData(Map<String, dynamic> data) async {
    final householdId = await clearHouseholdMutationCaches(data);
    if (householdId == null) return;

    _ref
        .read(
            householdRemoteMutationRefreshSignalProvider(householdId).notifier)
        .state += 1;
  }

  /// Handle background message opened (user tapped notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    _debugPrint('🔔 Background message opened');
    unawaited(_refreshHouseholdMutationData(message.data));

    _dispatchDataMap(message.data, source: 'fcm_tap');
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

    const fallbackAndroidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher_monochrome',
      color: AppTheme.monekoPrimary,
    );

    const fallbackDetails = NotificationDetails(
      android: fallbackAndroidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Moneko',
        message.notification?.body ?? '',
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        await _localNotifications.show(
          message.hashCode,
          message.notification?.title ?? 'Moneko',
          message.notification?.body ?? '',
          fallbackDetails,
          payload: jsonEncode(message.data),
        );
      } else {
        rethrow;
      }
    }
  }

  /// Handle notification tap (for local notifications shown in foreground)
  void _onNotificationTapped(NotificationResponse response) {
    _debugPrint('🔔 Notification tapped');

    if (response.payload != null && response.payload!.isNotEmpty) {
      _dispatchPayloadString(response.payload!, source: 'local_tap');
    }
  }

  void _dispatchPayloadString(String payload, {required String source}) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _dispatchDataMap(decoded, source: source);
      }
    } catch (_) {
      _debugPrint('⚠️ Failed to decode local notification payload');
    }
  }

  void _dispatchDataMap(Map<String, dynamic> data, {required String source}) {
    final intent = _intentParser.fromData(data);
    // ignore: discarded_futures
    _ref
        .read(notificationDispatcherProvider)
        .enqueueIntent(intent, source: source);
  }

  /// Check if device is registered with backend (checks cache and token existence)
  Future<bool> isRegistered() async {
    try {
      final userId = _gateway.currentUserId;
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
            _debugPrint('✅ Device registration found in cache');
            return true;
          }
        }
      }

      _debugPrint('⚠️ No valid device registration found in cache');
      return false;
    } catch (e) {
      _debugPrint('❌ Error checking registration status');
      return false;
    }
  }

  /// Unregister device (call on logout)
  Future<void> unregisterDevice() {
    final userId = _gateway.currentUserId;
    final pendingInitialization = _invalidateLifecycle();
    return _enqueueSessionCleanup(
      () => _unregisterDevice(
        userId: userId,
        pendingInitialization: pendingInitialization,
      ),
    );
  }

  Future<void> _unregisterDevice({
    required String? userId,
    required Future<DeviceRegistrationResult>? pendingInitialization,
  }) async {
    if (pendingInitialization != null) {
      try {
        await pendingInitialization;
      } catch (_) {}
    }
    await _tokenRefreshQueue;

    final prefs = await SharedPreferences.getInstance();
    final cachePrefix = 'device_reg:${userId ?? "anon"}:';
    if (userId != null && _hasDifferentActiveUser(userId)) {
      await _clearRegistrationCacheForUser(prefs, userId);
      return;
    }

    try {
      if (!_gateway.hasActiveSession) {
        _debugPrint(
            '⚠️ No active session during unregister; skipping backend call');
      }

      // Try to get token from cache first (more reliable than FCM during logout)
      String? token = prefs.getString('${cachePrefix}token');

      // Fallback to FCM token if cache is empty
      if (token == null || token.isEmpty) {
        try {
          token = await _gateway.getToken();
        } catch (_) {
          _debugPrint('⚠️ Failed to read FCM token during unregister');
        }
      }

      if (token != null && token.isNotEmpty) {
        _debugPrint('🗑️ Deleting device from backend...');

        // Call Edge Function to DELETE device row (not just mark inactive)
        if (_gateway.hasActiveSession) {
          try {
            final deleted = await _gateway.unregisterDevice(token);
            if (deleted) {
              _debugPrint('✅ Device deleted from backend successfully');
            } else {
              _debugPrint('⚠️ Device deletion failed');
            }
          } catch (_) {
            _debugPrint('⚠️ Device deletion failed');
          }
        } else {
          _debugPrint('⚠️ Skipping backend delete - session missing');
        }
      } else {
        _debugPrint('⚠️ No push token found to delete');
      }
    } catch (_) {
      _debugPrint('❌ Error unregistering device');
    } finally {
      try {
        if (userId == null) {
          await prefs.remove('${cachePrefix}token');
          await prefs.remove('${cachePrefix}registered_at');
        } else {
          await _clearRegistrationCacheForUser(prefs, userId);
        }
      } catch (_) {
        _debugPrint('⚠️ Failed to clear local device cache');
      }

      if (userId == null || !_hasDifferentActiveUser(userId)) {
        try {
          await _gateway.deleteToken();
          _debugPrint('🗑️ FCM token deleted locally');
        } catch (_) {
          _debugPrint('⚠️ Failed to delete FCM token locally');
        }

        await clearAllNotifications();

        _initialized = false;
        _initializedUserId = null;
        _initializationFuture = null;
      }
    }
  }

  Future<void> handleSessionEnded({required String userId}) {
    final pendingInitialization =
        _hasDifferentActiveUser(userId) ? null : _invalidateLifecycle();
    return _enqueueSessionCleanup(
      () => _handleSessionEnded(
        userId: userId,
        pendingInitialization: pendingInitialization,
      ),
    );
  }

  Future<void> _handleSessionEnded({
    required String userId,
    required Future<DeviceRegistrationResult>? pendingInitialization,
  }) async {
    if (_hasDifferentActiveUser(userId)) {
      final prefs = await SharedPreferences.getInstance();
      await _clearRegistrationCacheForUser(prefs, userId);
      return;
    }

    if (pendingInitialization != null) {
      try {
        await pendingInitialization;
      } catch (_) {}
    }
    await _tokenRefreshQueue;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearRegistrationCacheForUser(prefs, userId);
    } catch (_) {
      _debugPrint('⚠️ Failed to clear device cache after session ended');
    }

    if (_hasDifferentActiveUser(userId)) return;

    try {
      await _gateway.deleteToken();
    } catch (_) {
      _debugPrint('⚠️ Failed to delete FCM token after session ended');
    }

    await clearAllNotifications();

    _initialized = false;
    _initializedUserId = null;
    _initializationFuture = null;
  }

  Future<void> _enqueueSessionCleanup(Future<void> Function() action) {
    final previousCleanup = _sessionCleanupFuture ?? Future<void>.value();
    final ready = previousCleanup.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    late final Future<void> cleanup;
    cleanup = ready.then((_) => action()).whenComplete(() {
      if (identical(_sessionCleanupFuture, cleanup)) {
        _sessionCleanupFuture = null;
      }
    });
    _sessionCleanupFuture = cleanup;
    return cleanup;
  }

  Future<DeviceRegistrationResult>? _invalidateLifecycle() {
    _lifecycleGeneration += 1;
    _initialized = false;
    _initializedUserId = null;
    _acceptTokenRefreshes = false;
    return _initializationFuture;
  }

  bool _hasDifferentActiveUser(String endedUserId) {
    final activeUserId = _gateway.currentUserId;
    return _gateway.hasActiveSession &&
        activeUserId != null &&
        activeUserId.isNotEmpty &&
        activeUserId != endedUserId;
  }

  Future<void> _clearRegistrationCacheForUser(
    SharedPreferences prefs,
    String userId,
  ) async {
    await prefs.remove('device_reg:$userId:token');
    await prefs.remove('device_reg:$userId:registered_at');
  }

  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      _debugPrint('🧹 Cleared all local notifications');
    } catch (e) {
      _debugPrint('⚠️ Failed to clear local notifications');
    }
  }
}

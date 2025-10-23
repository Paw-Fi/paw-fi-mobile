import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

initApp() async {
  const env = String.fromEnvironment('ENV');
  final fileName = (env == 'prod' || env == 'production')
      ? '.env.prod'
      : (env == 'dev' || env == 'development')
          ? '.env.development'
          : (kReleaseMode ? '.env.prod' : '.env.development');

  await dotenv.load(fileName: fileName);

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnon,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Use PKCE flow for proper OAuth handling
    ),
  );

  // Initialize device registration service for push notifications
  final deviceRegistrationService = DeviceRegistrationService(
    Supabase.instance.client,
    FirebaseMessaging.instance,
    FlutterLocalNotificationsPlugin(),
  );

  // Initialize push notifications (only if user is authenticated)
  // Service will handle permission requests and device registration
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    if (session != null) {
      // User logged in - initialize device registration
      deviceRegistrationService.initialize();
    } else {
      // User logged out - unregister device
      deviceRegistrationService.unregisterDevice();
    }
  });

  // Check if user is already authenticated on app start
  final currentSession = Supabase.instance.client.auth.currentSession;
  if (currentSession != null) {
    deviceRegistrationService.initialize();
  }
}

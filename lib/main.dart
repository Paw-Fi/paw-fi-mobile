import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/app/app.dart';
import 'package:moneko/core/app/init.dart';
import 'package:moneko/firebase_options.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

/// Top-level background message handler for Firebase Cloud Messaging
/// Must be a top-level function for iOS background execution
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Title: ${message.notification?.title}');
  debugPrint('🔔 Body: ${message.notification?.body}');
  debugPrint('🔔 Data: ${message.data}');

  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Handle the message (e.g., update local database, show notification)
  // Note: Don't do heavy processing here, just handle the notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before everything else
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Supabase and other app dependencies
  await initApp();

  // Initialize SharedPreferences for persistent state
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Provide SharedPreferences instance to selected household provider
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const App(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:moneko/core/app/app.dart';
import 'package:moneko/core/app/init.dart';
import 'package:moneko/firebase_options.dart';

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

  runApp(const ProviderScope(child: App()));
}

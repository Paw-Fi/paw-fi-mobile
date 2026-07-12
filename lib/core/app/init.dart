import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moneko/core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _androidNotificationCaptureChannel =
    MethodChannel('moneko/notification_capture');
const _iosSiriShortcutChannel = MethodChannel('moneko/siri_shortcut_auth');

initApp() async {
  const env = String.fromEnvironment('ENV');
  const fileName = (env == 'prod' || env == 'production')
      ? 'dotenv-prod'
      : (env == 'dev' || env == 'development')
          ? 'dotenv-dev'
          : (kReleaseMode ? 'dotenv-prod' : 'dotenv-dev');

  await dotenv.load(fileName: fileName);

  await _migrateToSingleOwnerAuthSession();

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnon,
    authOptions: const FlutterAuthClientOptions(
      authFlowType:
          AuthFlowType.pkce, // Use PKCE flow for proper OAuth handling
    ),
  );
}

Future<void> _migrateToSingleOwnerAuthSession() async {
  if (kIsWeb) return;

  final preferences = await SharedPreferences.getInstance();
  if (preferences.getBool(Constants.singleOwnerAuthMigrationKey) == true) {
    return;
  }

  try {
    if (Platform.isAndroid) {
      await _androidNotificationCaptureChannel
          .invokeMethod<void>('clearLegacyNativeSession');
    } else if (Platform.isIOS) {
      await _iosSiriShortcutChannel
          .invokeMethod<void>('clearLegacyNativeSession');
    }
  } on MissingPluginException {
    // The fixed native code never reads the legacy token. Continue so a
    // platform-channel failure cannot repeatedly sign out a newly logged-in user.
  } on PlatformException {
    // Best-effort secure-storage cleanup; session ownership is enforced by the
    // fixed native implementations even when old storage cannot be opened.
  }

  final projectRef = Uri.parse(Constants.supabaseUrl).host.split('.').first;
  final sessionKey = 'sb-$projectRef-auth-token';
  final hadPersistedSession = preferences.containsKey(sessionKey);
  await preferences.remove(sessionKey);
  if (hadPersistedSession) {
    await preferences.setBool(
      Constants.singleOwnerReauthenticationRequiredKey,
      true,
    );
  }
  await preferences.setBool(Constants.singleOwnerAuthMigrationKey, true);
}

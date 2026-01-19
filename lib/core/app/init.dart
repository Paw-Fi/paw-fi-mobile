import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moneko/core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

initApp() async {
  const env = String.fromEnvironment('ENV');
  const fileName = (env == 'prod' || env == 'production')
      ? 'dotenv-prod'
      : (env == 'dev' || env == 'development')
          ? 'dotenv-dev'
          : (kReleaseMode ? 'dotenv-prod' : 'dotenv-dev');

  await dotenv.load(fileName: fileName);

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnon,
    authOptions: const FlutterAuthClientOptions(
      authFlowType:
          AuthFlowType.pkce, // Use PKCE flow for proper OAuth handling
    ),
  );
}

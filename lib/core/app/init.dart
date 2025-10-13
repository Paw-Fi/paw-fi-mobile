import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moneko/core/core.dart';
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
  );
}

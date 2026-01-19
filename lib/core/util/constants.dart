import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class Constants {
  // Load values at access time so they reflect dotenv.load() that happens during app init.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnon => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Environment type
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'production');
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}

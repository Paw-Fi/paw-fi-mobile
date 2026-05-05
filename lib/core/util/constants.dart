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

  // Subscription & Referral
  static const int discordVoucherMonths = 12;

  // Subscription pricing (USD)
  static const double subscriptionMonthlyPrice = 4.99;
  static const double subscriptionMonthlyOriginalPrice = 7.99;
  static const double subscriptionYearlyPrice = 34.99;
  static const double subscriptionYearlyOriginalPrice = 59.99;
  static const double subscriptionLifetimePrice = 69.99;

  // Checkout URLs
  static String get checkoutBaseUrl =>
      dotenv.env['PAYMENT_CHECKOUT_URL'] ?? 'moneko.io';
}

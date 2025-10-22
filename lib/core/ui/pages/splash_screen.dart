import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

/// Splash screen with device registration for push notifications
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize device registration for push notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeviceRegistration();
    });
  }

  Future<void> _initializeDeviceRegistration() async {
    try {
      debugPrint('🔔 Initializing device registration for push notifications...');

      // Get the device registration service
      final deviceService = ref.read(deviceRegistrationServiceProvider);

      // Initialize FCM and register device
      await deviceService.initialize();

      debugPrint('✅ Device registration completed successfully');
    } catch (e, stack) {
      // Don't block app startup on device registration failure
      debugPrint('⚠️ Device registration failed (non-critical): $e');
      debugPrint('Stack trace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final brightness = shadcnui.Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo with theme-aware styling
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? colorScheme.card : Colors.white,
                borderRadius: BorderRadius.circular(24),

              ),
              child: Image.asset(
                'lib/assets/images/logo192.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            // Loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

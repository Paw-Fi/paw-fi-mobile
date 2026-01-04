import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Splash screen with device registration for push notifications
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Image.asset(
                'lib/assets/gifs/splashscreen-loading.gif',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    CircularProgressIndicator(color: colorScheme.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

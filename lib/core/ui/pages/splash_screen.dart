import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Splash screen with device registration for push notifications
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // No per-page initialization; all app init is centralized in AppInitialization provider

  @override
  Widget build(BuildContext context) {
    // final colorScheme = shadcnui.Theme.of(context).colorScheme;
    // final brightness = shadcnui.Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.black,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

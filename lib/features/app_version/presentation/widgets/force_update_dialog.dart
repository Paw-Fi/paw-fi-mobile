import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/theme/app_theme.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String minVersion;
  final String? message;
  final String? appStoreUrl;

  const ForceUpdateDialog({
    Key? key,
    required this.currentVersion,
    required this.minVersion,
    this.message,
    this.appStoreUrl,
  }) : super(key: key);

  Future<void> _openStore() async {
    String? storeUrl = appStoreUrl;

    // Default URLs if not provided
    if (storeUrl == null || storeUrl.isEmpty) {
      if (Platform.isIOS) {
        // TestFlight public link (replace with your actual link)
        storeUrl = 'https://testflight.apple.com/join/Q9rNbkN5';
        // OR App Store link:
        // storeUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';
      } else if (Platform.isAndroid) {
        storeUrl = 'https://play.google.com/store/apps/details?id=com.moneko.app';
      }
    }

    if (storeUrl != null) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false, // Prevent dismissing with back button
      child: Dialog(
        backgroundColor: colorScheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Icon(
                Icons.system_update,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                message ??
                    'A new version of Moneko is available. Please update to continue using the app.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.mutedForeground,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

            
              // Update button
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  onPressed: _openStore,
                  label: 'Update now',
                  style: AdaptiveButtonStyle.filled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

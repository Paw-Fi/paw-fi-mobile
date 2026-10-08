import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/version_provider.dart';
import 'force_update_dialog.dart';

/// Wraps the app to show force update dialog when needed
class VersionCheckWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const VersionCheckWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<VersionCheckWrapper> createState() =>
      _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends ConsumerState<VersionCheckWrapper>
    with WidgetsBindingObserver {
  bool _shouldShowDialog = false;
  bool _isCheckingVersion = false;

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to check when app comes to foreground
    WidgetsBinding.instance.addObserver(this);

    // Initial version check after app launches
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkVersion();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check version when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted && !_shouldShowDialog) {
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    // Prevent multiple simultaneous checks
    if (_shouldShowDialog || _isCheckingVersion) {
      return;
    }

    _isCheckingVersion = true;

    try {
      // Check if update is required
      final updateRequired = await ref.read(isUpdateRequiredProvider.future);

      if (updateRequired && mounted) {
        // Get version data
        final versionConfig = await ref.read(versionConfigProvider.future);
        final currentVersion = await ref.read(currentAppVersionProvider.future);

        if (!mounted || versionConfig == null) {
          return;
        }

        // Update state to indicate dialog is showing
        setState(() {
          _shouldShowDialog = true;
        });

        // Wait until current frame work is complete so we don't show dialogs
        // while widgets are being deactivated/rebuilt during route transitions.
        await WidgetsBinding.instance.endOfFrame;

        if (mounted && context.mounted) {
          await showForceUpdateDialog(
            context: context,
            currentVersion: currentVersion,
            message: versionConfig.updateMessage,
            appStoreUrl: Platform.isIOS
                ? versionConfig.iosAppStoreUrl
                : versionConfig.androidPlayStoreUrl,
          );
        }

        // If dialog returns (it shouldn't if it's non-dismissible, but AdaptiveAlertDialog might be),
        // we reset the flag so it can be triggered again on resume/check.
        if (mounted) {
          setState(() {
            _shouldShowDialog = false;
          });
        }
      }
    } catch (e, stack) {
      developer.log('Exception in version check: $e',
          name: 'VersionCheck', error: e, stackTrace: stack);
    } finally {
      _isCheckingVersion = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

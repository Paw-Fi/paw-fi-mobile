import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
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

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to check when app comes to foreground
    WidgetsBinding.instance.addObserver(this);

    // Initial version check after app launches
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        developer.log('Initial check after navigation settled',
            name: 'VersionCheck');
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
      developer.log('App resumed, checking version...', name: 'VersionCheck');
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    // Prevent multiple simultaneous checks
    if (_shouldShowDialog) {
      developer.log('Dialog already showing, skipping...',
          name: 'VersionCheck');
      return;
    }

    try {
      developer.log('Starting version check...', name: 'VersionCheck');

      // Check if update is required
      final updateRequired = await ref.read(isUpdateRequiredProvider.future);

      developer.log('Update required: $updateRequired', name: 'VersionCheck');

      if (updateRequired && mounted) {
        developer.log('Fetching version data...', name: 'VersionCheck');

        // Get version data
        final versionConfig = await ref.read(versionConfigProvider.future);
        final currentVersion = await ref.read(currentAppVersionProvider.future);

        if (!mounted || versionConfig == null) {
          developer.log('Widget unmounted or no config', name: 'VersionCheck');
          return;
        }

        // Update state to indicate dialog is showing
        setState(() {
          _shouldShowDialog = true;
        });

        developer.log('Showing force update dialog imperatively',
            name: 'VersionCheck');

        final dialogContext = rootNavigatorKey.currentContext ?? context;

        if (dialogContext.mounted) {
          await showForceUpdateDialog(
            context: dialogContext,
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
      } else {
        developer.log('No update required', name: 'VersionCheck');
      }
    } catch (e, stack) {
      developer.log('Exception in version check: $e',
          name: 'VersionCheck', error: e, stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

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
  ConsumerState<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends ConsumerState<VersionCheckWrapper> with WidgetsBindingObserver {
  bool _shouldShowDialog = false;
  String? _currentVersion;
  String? _minVersion;
  String? _updateMessage;
  String? _appStoreUrl;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer to check when app comes to foreground
    WidgetsBinding.instance.addObserver(this);
    
    // Initial version check after app launches
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        print('[VersionCheck] Initial check after navigation settled');
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
      print('[VersionCheck] App resumed, checking version...');
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    // Prevent multiple simultaneous checks
    if (_shouldShowDialog) {
      print('[VersionCheck] Dialog already showing, skipping...');
      return;
    }

    try {
      print('[VersionCheck] Starting version check...');
      
      // Check if update is required
      final updateRequired = await ref.read(isUpdateRequiredProvider.future);
      
      print('[VersionCheck] Update required: $updateRequired');
      
      if (updateRequired && mounted) {
        print('[VersionCheck] Fetching version data...');
        
        // Get version data
        final versionConfig = await ref.read(versionConfigProvider.future);
        final currentVersion = await ref.read(currentAppVersionProvider.future);

        if (!mounted || versionConfig == null) {
          print('[VersionCheck] Widget unmounted or no config');
          return;
        }

        // Update state to show dialog in the widget tree
        setState(() {
          _shouldShowDialog = true;
          _currentVersion = currentVersion;
          _minVersion = versionConfig.minVersion;
          _updateMessage = versionConfig.updateMessage;
          _appStoreUrl = versionConfig.iosAppStoreUrl;
        });
        
        print('[VersionCheck] ✅ Dialog state updated - should now be visible!');
      } else {
        print('[VersionCheck] No update required');
      }
    } catch (e, stack) {
      print('[VersionCheck] Exception in version check: $e');
      print('[VersionCheck] Stack trace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowDialog && _currentVersion != null && _minVersion != null) {
      // Render dialog directly in the tree as an overlay
      print('[VersionCheck] 🎨 Rendering dialog overlay in build method');
      return Stack(
        children: [
          widget.child,
          // Full-screen blocking overlay
          Positioned.fill(
            child: Material(
              color: Colors.black54, // Semi-transparent background
              child: Center(
                child: ForceUpdateDialog(
                  currentVersion: _currentVersion!,
                  minVersion: _minVersion!,
                  message: _updateMessage,
                  appStoreUrl: _appStoreUrl,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return widget.child;
  }
}

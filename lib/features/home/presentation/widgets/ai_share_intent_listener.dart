import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

final sharedAiInputHandlerProvider =
    Provider((ref) => handleSharedAiInputFiles);

class AiShareIntentListener extends ConsumerStatefulWidget {
  final Widget child;

  const AiShareIntentListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AiShareIntentListener> createState() =>
      _AiShareIntentListenerState();
}

class _AiShareIntentListenerState extends ConsumerState<AiShareIntentListener> {
  final List<AiSharedInputFile> _pendingFiles = <AiSharedInputFile>[];
  final Set<String> _receivedPaths = <String>{};
  StreamSubscription<List<SharedMediaFile>>? _intentSubscription;
  AppLifecycleListener? _lifecycleListener;
  Timer? _navigatorRetryTimer;
  bool _drainScheduled = false;
  bool _isProcessing = false;
  bool _receiveErrorPending = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    _lifecycleListener = AppLifecycleListener(onResume: _scheduleDrain);
    final sharing = ReceiveSharingIntent.instance;
    _intentSubscription = sharing
        .getMediaStream()
        .listen(_enqueueSharedMedia, onError: (_) => _receiveFailed());

    unawaited(
      sharing
          .getInitialMedia()
          .then<void>((media) {
            if (mounted) _enqueueSharedMedia(media);
          })
          .catchError((_) => _receiveFailed())
          .whenComplete(() async {
            try {
              await sharing.reset();
            } catch (_) {
              _receiveFailed();
            }
          }),
    );
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    _lifecycleListener?.dispose();
    _navigatorRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final appLockState = ref.watch(appLockControllerProvider);
    if ((_pendingFiles.isNotEmpty || _receiveErrorPending) &&
        auth.uid.trim().isNotEmpty &&
        !appLockState.shouldBlockApp) {
      _scheduleDrain();
    }
    return widget.child;
  }

  void _enqueueSharedMedia(List<SharedMediaFile> media) {
    final files = media
        .map((item) {
          if (item.type == SharedMediaType.url) return null;
          final path = _localFilePath(item.path);
          if (path == null || !_receivedPaths.add(path)) return null;
          return AiSharedInputFile(
            path: path,
            name: _fileNameFromPath(path),
            mimeType: item.mimeType,
          );
        })
        .whereType<AiSharedInputFile>()
        .toList(growable: false);
    if (files.isEmpty) return;

    _pendingFiles.addAll(files);
    _scheduleDrain();
  }

  void _receiveFailed() {
    if (!mounted) return;
    _receiveErrorPending = true;
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_drainScheduled || _isProcessing || !mounted) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _drainScheduled = false;
      unawaited(_drainPendingFiles());
    });
    // A share event can arrive after the app has stopped drawing frames.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _drainPendingFiles() async {
    if (!mounted ||
        _isProcessing ||
        (_pendingFiles.isEmpty && !_receiveErrorPending)) {
      return;
    }

    final auth = ref.read(authProvider);
    final appLockState = ref.read(appLockControllerProvider);
    if (auth.uid.trim().isEmpty || appLockState.shouldBlockApp) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;

    // This listener is mounted from MaterialApp.builder, above the router's
    // Overlay. Run AI processing from the root navigator so its progress and
    // completion notifications are visible.
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) {
      _navigatorRetryTimer?.cancel();
      _navigatorRetryTimer = Timer(
        const Duration(milliseconds: 100),
        _scheduleDrain,
      );
      return;
    }

    if (_receiveErrorPending) {
      _receiveErrorPending = false;
      AppToast.error(navigatorContext, navigatorContext.l10n.failedToAnalyze);
    }
    if (_pendingFiles.isEmpty) return;
    _isProcessing = true;
    final batch = List<AiSharedInputFile>.from(_pendingFiles);
    _pendingFiles.clear();
    try {
      await ref.read(sharedAiInputHandlerProvider)(
        navigatorContext,
        ref,
        files: batch,
      );
    } catch (_) {
      if (navigatorContext.mounted) {
        AppToast.error(navigatorContext, navigatorContext.l10n.failedToAnalyze);
      }
    } finally {
      _isProcessing = false;
      if (mounted && (_pendingFiles.isNotEmpty || _receiveErrorPending)) {
        _scheduleDrain();
      }
    }
  }
}

String? _localFilePath(String rawPath) {
  final path = rawPath.trim();
  if (path.startsWith('/')) return path;
  final uri = Uri.tryParse(path);
  if (uri?.scheme != 'file' || uri!.hasQuery || uri.hasFragment) return null;
  try {
    final localPath = uri.toFilePath();
    return localPath.startsWith('/') ? localPath : null;
  } on UnsupportedError {
    return null;
  } on ArgumentError {
    return null;
  }
}

String _fileNameFromPath(String path) {
  final name = path.split('/').last.trim();
  return name.isEmpty ? 'shared-file' : name;
}

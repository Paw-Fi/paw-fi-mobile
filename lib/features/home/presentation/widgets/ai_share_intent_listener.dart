import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

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
  StreamSubscription<List<SharedMediaFile>>? _intentSubscription;
  String? _lastBatchSignature;
  bool _drainScheduled = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    _intentSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_enqueueSharedMedia, onError: (_) {});

    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then((media) {
        _enqueueSharedMedia(media);
        ReceiveSharingIntent.instance.reset();
      }),
    );
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final appLockState = ref.watch(appLockControllerProvider);
    if (_pendingFiles.isNotEmpty &&
        auth.uid.trim().isNotEmpty &&
        !appLockState.shouldBlockApp) {
      _scheduleDrain();
    }
    return widget.child;
  }

  void _enqueueSharedMedia(List<SharedMediaFile> media) {
    final files = media
        .map((item) {
          final path = item.path.trim();
          if (path.isEmpty) return null;
          return AiSharedInputFile(
            path: path,
            name: _fileNameFromPath(path),
            mimeType: item.mimeType,
          );
        })
        .whereType<AiSharedInputFile>()
        .toList(growable: false);
    if (files.isEmpty) return;

    final signature = files.map((file) => file.path).join('|');
    if (signature == _lastBatchSignature) return;
    _lastBatchSignature = signature;
    _pendingFiles.addAll(files);
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_drainScheduled || _isProcessing || !mounted) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      unawaited(_drainPendingFiles());
    });
  }

  Future<void> _drainPendingFiles() async {
    if (!mounted || _isProcessing || _pendingFiles.isEmpty) return;

    final auth = ref.read(authProvider);
    final appLockState = ref.read(appLockControllerProvider);
    if (auth.uid.trim().isEmpty || appLockState.shouldBlockApp) return;

    _isProcessing = true;
    final batch = List<AiSharedInputFile>.from(_pendingFiles);
    _pendingFiles.clear();
    try {
      await handleSharedAiInputFiles(
        context,
        ref,
        files: batch,
      );
    } finally {
      _isProcessing = false;
      if (_pendingFiles.isNotEmpty) {
        _scheduleDrain();
      }
    }
  }
}

String _fileNameFromPath(String path) {
  final name = path.split('/').last.trim();
  return name.isEmpty ? 'shared-file' : name;
}

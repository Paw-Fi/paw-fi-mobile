import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/features/auth/auth.dart';

/// Mounted above authentication routes so logout also revokes widget data.
final homeWidgetSessionSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (kIsWeb) return;
  var active = true;
  ref.onDispose(() => active = false);
  unawaited(WidgetService()
      .synchronizeOwner(userId, isCurrent: () => active)
      .catchError((Object error) {
    debugPrint('Home widget session sync failed: ${error.runtimeType}');
  }));
});

import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/data/repositories/ai_input_capture_repository.dart';
import 'package:path_provider/path_provider.dart';

final aiInputCaptureRepositoryProvider =
    FutureProvider<AiInputCaptureRepository>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return AiInputCaptureRepository(database, directory: () async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/pending_ai_inputs');
  });
});

final pendingAiInputsProvider =
    StreamProvider.autoDispose.family<List<AiInputCapture>, String>(
  (ref, userId) async* {
    final repository = await ref.watch(aiInputCaptureRepositoryProvider.future);
    yield* repository.watchPending(userId);
  },
);

final aiInputResumeSignalProvider = StateProvider<int>((ref) => 0);

/// A native attention tap is an opaque local identity, never save authority.
class AiInputOpenRequest {
  const AiInputOpenRequest(
      {required this.userId,
      required this.captureId,
      required this.executionId});
  final String userId;
  final String captureId;
  final String executionId;

  static AiInputOpenRequest? fromUri(Uri uri) {
    if (uri.scheme != 'moneko' ||
        uri.host != 'ai-analysis' ||
        uri.path.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll.length != 3 ||
        !['userId', 'captureId', 'executionId']
            .every((key) => uri.queryParametersAll[key]?.length == 1)) {
      return null;
    }
    final capture = uri.queryParameters['captureId']!;
    final user = uri.queryParameters['userId']!;
    final execution = uri.queryParameters['executionId']!;
    if (!RegExp(r'^ai_input_[a-f0-9]{32}$').hasMatch(capture) ||
        user.isEmpty ||
        user.length > 128 ||
        execution.length > 256 ||
        !execution.startsWith('$capture:')) {
      return null;
    }
    return AiInputOpenRequest(
        userId: user, captureId: capture, executionId: execution);
  }

  bool matches(AiInputCapture capture) =>
      capture.userId == userId &&
      capture.id == captureId &&
      capture.payload['executionId'] == executionId;
}

final aiInputOpenRequestProvider =
    StateProvider<AiInputOpenRequest?>((ref) => null);

final aiInputResumeControllerProvider =
    Provider<AiInputResumeController>((ref) {
  ref.watch(authProvider.select((user) => user.uid));
  final controller = AiInputResumeController();
  ref.onDispose(controller.dispose);
  return controller;
});

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

final aiInputResumeControllerProvider =
    Provider<AiInputResumeController>((ref) {
  ref.watch(authProvider.select((user) => user.uid));
  final controller = AiInputResumeController();
  ref.onDispose(controller.dispose);
  return controller;
});

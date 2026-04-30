import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/transaction_providers.dart';
import '../../domain/transaction_command.dart';

final transactionCaptureControllerProvider =
    AsyncNotifierProvider<TransactionCaptureController, void>(
  TransactionCaptureController.new,
);

class TransactionCaptureController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String> createLocalTransaction(
    CreateTransactionCommand command,
  ) async {
    state = const AsyncLoading();

    try {
      final transactionId = await ref
          .read(transactionRepositoryProvider)
          .createLocalTransaction(command);
      state = const AsyncData(null);
      return transactionId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

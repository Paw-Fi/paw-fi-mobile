import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/processing_state.dart';
import 'package:moneko/features/home/presentation/state/expense_processing_notifier.dart';

final expenseProcessingProvider =
    StateNotifierProvider<ExpenseProcessingNotifier, ProcessingState>((ref) {
  return ExpenseProcessingNotifier(ref);
});

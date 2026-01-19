import 'package:moneko/features/home/presentation/models/models.dart';

/// Loading state for expense processing
class ProcessingState {
  final bool isProcessing;
  final String? message;
  final double? progress;
  final ExpenseEntry? createdExpense;
  final String?
      localImagePath; // For showing local photo instead of waiting for upload

  ProcessingState({
    this.isProcessing = false,
    this.message,
    this.progress,
    this.createdExpense,
    this.localImagePath,
  });

  ProcessingState copyWith({
    bool? isProcessing,
    String? message,
    double? progress,
    ExpenseEntry? createdExpense,
    String? localImagePath,
    bool clearMessage = false,
    bool clearExpense = false,
  }) {
    return ProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      message: clearMessage ? null : (message ?? this.message),
      progress: progress ?? this.progress,
      createdExpense:
          clearExpense ? null : (createdExpense ?? this.createdExpense),
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}

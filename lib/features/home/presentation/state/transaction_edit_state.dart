import 'package:moneko/features/home/presentation/models/expense_entry.dart';

/// Represents which field is currently being edited
enum EditField {
  amount,
  category,
  description,
  date,
  time,
  currency,
}

/// State for transaction editing with optimistic updates
class TransactionEditState {
  final String? editingExpenseId;
  final EditField? currentField;
  final bool isLoading;
  final String? error;
  final ExpenseEntry? optimisticUpdate; // Temporary updated version shown in UI

  const TransactionEditState({
    this.editingExpenseId,
    this.currentField,
    this.isLoading = false,
    this.error,
    this.optimisticUpdate,
  });

  TransactionEditState copyWith({
    String? editingExpenseId,
    EditField? currentField,
    bool? isLoading,
    String? error,
    ExpenseEntry? optimisticUpdate,
    bool clearError = false,
    bool clearOptimisticUpdate = false,
  }) {
    return TransactionEditState(
      editingExpenseId: editingExpenseId ?? this.editingExpenseId,
      currentField: currentField ?? this.currentField,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      optimisticUpdate: clearOptimisticUpdate
          ? null
          : (optimisticUpdate ?? this.optimisticUpdate),
    );
  }
}

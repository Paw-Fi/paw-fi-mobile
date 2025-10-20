/// Represents a summary of expenses and budgets for a specific currency
class CurrencySummary {
  final String currencyCode; // e.g., USD, EUR, GBP
  final double totalExpenses;
  final double totalBudget;
  final int transactionCount;

  const CurrencySummary({
    required this.currencyCode,
    required this.totalExpenses,
    required this.totalBudget,
    required this.transactionCount,
  });

  /// Net cashflow for this currency (budget - expenses)
  double get netCashflow => totalBudget - totalExpenses;

  /// Whether the net cashflow is positive
  bool get isPositive => netCashflow >= 0;
}

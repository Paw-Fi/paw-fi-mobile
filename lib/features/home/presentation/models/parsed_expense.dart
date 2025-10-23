// Data model for parsed (but not yet saved) expense from AI analysis

class ParsedExpense {
  final double amount;
  final String category;
  final String currency;
  final String currencySymbol;
  final DateTime date;
  final String? description;
  final String? localImagePath; // Local image path for display before upload

  ParsedExpense({
    required this.amount,
    required this.category,
    required this.currency,
    required this.currencySymbol,
    required this.date,
    this.description,
    this.localImagePath,
  });

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    return ParsedExpense(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      currency: json['currency'] as String,
      currencySymbol: json['currencySymbol'] as String? ?? '\$',
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
      localImagePath: json['localImagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'localImagePath': localImagePath,
    };
  }

  // Create a copy with modified fields
  ParsedExpense copyWith({
    double? amount,
    String? category,
    String? currency,
    String? currencySymbol,
    DateTime? date,
    String? description,
    String? localImagePath,
  }) {
    return ParsedExpense(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      date: date ?? this.date,
      description: description ?? this.description,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  // Convert to amount in cents for backend
  int get amountCents => (amount * 100).round();

  // Format for display
  String get formattedAmount => '${currencySymbol}${amount.toStringAsFixed(2)}';
}

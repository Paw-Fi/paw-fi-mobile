// Data model for parsed (but not yet saved) transaction from AI analysis

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';

class ParsedExpense {
  // true = income, false = expense
  final bool isIncome;
  final double amount;
  final String category;
  final String currency;
  final String currencySymbol;
  final DateTime date;
  final String? description;
  final List<String>? breakdown;
  final String? localImagePath; // Local image path for display before upload
  // Household sharing (expense only)
  final String? payerUserId; // Who paid
  final String? payerHint; // Parsed hint when no userId is available

  ParsedExpense({
    this.isIncome = false,
    required this.amount,
    required this.category,
    required this.currency,
    required this.currencySymbol,
    required this.date,
    this.description,
    this.breakdown,
    this.localImagePath,
    this.payerUserId,
    this.payerHint,
  });

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    return ParsedExpense(
      isIncome: (json['type']?.toString().toLowerCase() == 'income') ||
          (json['isIncome'] == true),
      amount: (json['amount'] as num).toDouble(),
      category: normalizeCategory(json['category'] as String),
      currency: json['currency'] as String,
      currencySymbol: json['currencySymbol'] as String? ?? '\$',
      date: DateTime.parse(json['date'] as String),
      description: json['description'] is String
          ? sanitizeUtf16(json['description'] as String)
          : null,
      breakdown: json['breakdown'] != null
          ? (json['breakdown'] as List)
              .map((e) => sanitizeUtf16(e.toString()))
              .toList()
          : null,
      localImagePath: json['localImagePath'] as String?,
      payerUserId: (json['payerUserId'] as String?) ??
          (json['payer_user_id'] as String?),
      payerHint: (json['payerHint'] as String?) ??
          (json['payerName'] as String?) ??
          (json['paidBy'] as String?) ??
          (json['payerEmail'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isIncome': isIncome,
      'amount': amount,
      'category': category,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'breakdown': breakdown,
      'localImagePath': localImagePath,
      'payerUserId': payerUserId,
      'payerHint': payerHint,
    };
  }

  // Create a copy with modified fields
  ParsedExpense copyWith({
    bool? isIncome,
    double? amount,
    String? category,
    String? currency,
    String? currencySymbol,
    DateTime? date,
    String? description,
    List<String>? breakdown,
    String? localImagePath,
    String? payerUserId,
    String? payerHint,
  }) {
    return ParsedExpense(
      isIncome: isIncome ?? this.isIncome,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      date: date ?? this.date,
      description: description ?? this.description,
      breakdown: breakdown ?? this.breakdown,
      localImagePath: localImagePath ?? this.localImagePath,
      payerUserId: payerUserId ?? this.payerUserId,
      payerHint: payerHint ?? this.payerHint,
    );
  }

  // Convert to amount in cents for backend
  int get amountCents => (amount * 100).round();

  // Format for display
  String get formattedAmount => '$currencySymbol${amount.toStringAsFixed(2)}';
}

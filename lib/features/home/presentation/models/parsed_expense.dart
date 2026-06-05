// Data model for parsed (but not yet saved) transaction from AI analysis

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/utils/currency.dart';

const Object _copyWithUnset = Object();

class ParsedExpense {
  // true = income, false = expense
  final bool isIncome;
  final double amount;
  final String category;
  final String currency;
  final String currencySymbol;
  final DateTime date;
  final String? description;
  final String? merchant;
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
    this.merchant,
    this.breakdown,
    this.localImagePath,
    this.payerUserId,
    this.payerHint,
  });

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    final parsedDateOnly = tryParseDateOnlyYmd(rawDate);
    final parsedDateTime = DateTime.tryParse(rawDate ?? '');
    final date = parsedDateOnly ??
        (parsedDateTime != null
            ? DateTime(
                parsedDateTime.year,
                parsedDateTime.month,
                parsedDateTime.day,
              )
            : DateTime.now());

    return ParsedExpense(
      isIncome: (json['type']?.toString().toLowerCase() == 'income') ||
          (json['isIncome'] == true),
      amount: (json['amount'] as num).toDouble(),
      category: normalizeCategory(json['category'] as String),
      currency: json['currency'] as String,
      currencySymbol: json['currencySymbol'] as String? ?? '\$',
      date: date,
      description: json['description'] is String
          ? sanitizeUtf16(json['description'] as String)
          : null,
      merchant: json['merchant'] is String
          ? sanitizeUtf16(json['merchant'] as String)
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
      'date': formatDateOnlyYmd(date),
      'description': description,
      'merchant': merchant,
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
    Object? description = _copyWithUnset,
    Object? merchant = _copyWithUnset,
    Object? breakdown = _copyWithUnset,
    Object? localImagePath = _copyWithUnset,
    Object? payerUserId = _copyWithUnset,
    Object? payerHint = _copyWithUnset,
  }) {
    return ParsedExpense(
      isIncome: isIncome ?? this.isIncome,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      date: date ?? this.date,
      description: identical(description, _copyWithUnset)
          ? this.description
          : description as String?,
      merchant: identical(merchant, _copyWithUnset)
          ? this.merchant
          : merchant as String?,
      breakdown: identical(breakdown, _copyWithUnset)
          ? this.breakdown
          : breakdown as List<String>?,
      localImagePath: identical(localImagePath, _copyWithUnset)
          ? this.localImagePath
          : localImagePath as String?,
      payerUserId: identical(payerUserId, _copyWithUnset)
          ? this.payerUserId
          : payerUserId as String?,
      payerHint: identical(payerHint, _copyWithUnset)
          ? this.payerHint
          : payerHint as String?,
    );
  }

  // Convert to amount in cents for backend
  int get amountCents => (amount * 100).round();

  // Format for display
  String get formattedAmount => '$currencySymbol${formatAmount(amount)}';
}

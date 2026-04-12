import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/utils/user_timezone.dart';

/// Represents a daily budget entry from daily_budgets table
class DailyBudgetEntry {
  final String id;
  final String? contactId;
  final DateTime date;
  final int amountCents;
  final String? currency;

  DailyBudgetEntry({
    required this.id,
    this.contactId,
    required this.date,
    required this.amountCents,
    this.currency,
  });

  double get amount => amountCents / 100.0;

  DailyBudgetEntry copyWith({
    String? id,
    String? contactId,
    DateTime? date,
    int? amountCents,
    String? currency,
  }) {
    return DailyBudgetEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
    );
  }

  factory DailyBudgetEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    final dateOnly = tryParseDateOnlyYmd(rawDate);
    final parsed = DateTime.tryParse(rawDate ?? '');
    return DailyBudgetEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String?,
      date: dateOnly != null
          ? DateTime(dateOnly.year, dateOnly.month, dateOnly.day)
          : (parsed != null
              ? DateTime(parsed.year, parsed.month, parsed.day)
              : DateTime.fromMillisecondsSinceEpoch(0)),
      amountCents: json['amount_cents'] as int,
      currency: canonicalizeCurrencyCode(json['currency'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'date': formatDateOnlyYmd(date),
      'amount_cents': amountCents,
      'currency': currency,
    };
  }
}

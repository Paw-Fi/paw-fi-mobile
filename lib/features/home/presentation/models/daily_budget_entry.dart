/// Represents a daily budget entry from daily_budgets table
class DailyBudgetEntry {
  final String id;
  final String contactId;
  final DateTime date;
  final int amountCents;
  final String? currency;

  DailyBudgetEntry({
    required this.id,
    required this.contactId,
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
    return DailyBudgetEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      date: DateTime.parse(json['date'] as String),
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String?,
    );
  }
}

/// Represents a single spending entry from expenses table
class ExpenseEntry {
  final String id;
  final String? contactId;
  final DateTime date;
  final int amountCents;
  final String? currency;
  final String? category;
  final DateTime createdAt;
  final String? rawText;
  final String? receiptImageUrl;

  ExpenseEntry({
    required this.id,
    this.contactId,
    required this.date,
    required this.amountCents,
    this.currency,
    this.category,
    required this.createdAt,
    this.rawText,
    this.receiptImageUrl,
  });

  double get amount => amountCents / 100.0;

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rawText: json['raw_text'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
    );
  }

  /// Create a copy of this ExpenseEntry with some fields replaced
  ExpenseEntry copyWith({
    String? id,
    String? contactId,
    DateTime? date,
    int? amountCents,
    String? currency,
    String? category,
    DateTime? createdAt,
    String? rawText,
    String? receiptImageUrl,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      rawText: rawText ?? this.rawText,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
    );
  }
}

class AccountTransfer {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String currency;
  final DateTime date;
  final String? note;

  const AccountTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.currency,
    required this.date,
    this.note,
  });

  factory AccountTransfer.fromJson(Map<String, dynamic> json) {
    return AccountTransfer(
      id: json['id'] as String,
      fromAccountId: json['from_account_id'] as String,
      toAccountId: json['to_account_id'] as String,
      amountCents: (json['amount_cents'] as num?)?.round() ?? 0,
      currency: (json['currency'] as String?) ?? 'USD',
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      note: json['note'] as String?,
    );
  }
}

/// Recurring transaction model
/// Represents a recurring income or expense transaction

class RecurringTransaction {
  final String id;
  final DateTime date;
  final String category;
  final String? description;
  final String? source; // For income
  final double amount; // In major units
  final String currency;
  final String ownerType; // 'me', 'partner', 'household'
  final String privacyScope; // 'private', 'balances_only', 'full'
  final String? householdId;
  final RecurrenceRule recurrenceRule;
  final String type; // 'income' or 'expense'
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RecurringTransaction({
    required this.id,
    required this.date,
    required this.category,
    this.description,
    this.source,
    required this.amount,
    required this.currency,
    required this.ownerType,
    required this.privacyScope,
    this.householdId,
    required this.recurrenceRule,
    required this.type,
    required this.attachments,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      description:
          json['description'] as String? ?? json['raw_text'] as String?,
      source: json['source'] as String?,
      amount: (json['amountMajor'] as num?)?.toDouble() ??
          (json['amount_cents'] as num).toDouble() / 100,
      currency: json['currency'] as String,
      ownerType:
          json['ownerType'] as String? ?? json['owner_type'] as String? ?? 'me',
      privacyScope: json['privacyScope'] as String? ??
          json['privacy_scope'] as String? ??
          'full',
      householdId:
          json['householdId'] as String? ?? json['household_id'] as String?,
      recurrenceRule: RecurrenceRule.fromJson(
        json['recurrenceRule'] as Map<String, dynamic>? ??
            json['recurrence_rule'] as Map<String, dynamic>,
      ),
      type: json['type'] as String,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
      'source': source,
      'amountMajor': amount,
      'currency': currency,
      'ownerType': ownerType,
      'privacyScope': privacyScope,
      'householdId': householdId,
      'recurrenceRule': recurrenceRule.toJson(),
      'type': type,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  RecurringTransaction copyWith({
    String? id,
    DateTime? date,
    String? category,
    String? description,
    String? source,
    double? amount,
    String? currency,
    String? ownerType,
    String? privacyScope,
    String? householdId,
    RecurrenceRule? recurrenceRule,
    String? type,
    List<Attachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      ownerType: ownerType ?? this.ownerType,
      privacyScope: privacyScope ?? this.privacyScope,
      householdId: householdId ?? this.householdId,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the next occurrence date from a reference date
  DateTime getNextOccurrence([DateTime? from]) {
    final reference = from ?? DateTime.now();
    final anchor = recurrenceRule.anchorDate;

    // If reference is before anchor, return anchor
    if (reference.isBefore(anchor)) {
      return anchor;
    }

    // If there's an end date and we're past it, return the anchor (no more occurrences)
    if (recurrenceRule.endDate != null &&
        reference.isAfter(recurrenceRule.endDate!)) {
      return anchor;
    }

    // Calculate next occurrence based on frequency
    switch (recurrenceRule.frequency) {
      case 'daily':
        final interval = recurrenceRule.interval ?? 1;
        final daysDiff = reference.difference(anchor).inDays;
        final nextDays = ((daysDiff / interval).ceil() * interval).toInt();
        return anchor.add(Duration(days: nextDays));

      case 'weekly':
        final interval = recurrenceRule.interval ?? 1;
        final weeksDiff = reference.difference(anchor).inDays ~/ 7;
        final nextWeeks = ((weeksDiff / interval).ceil() * interval).toInt();
        return anchor.add(Duration(days: nextWeeks * 7));

      case 'biweekly':
        final weeksDiff = reference.difference(anchor).inDays ~/ 7;
        final nextWeeks = ((weeksDiff / 2).ceil() * 2).toInt();
        return anchor.add(Duration(days: nextWeeks * 7));

      case 'monthly':
        final interval = recurrenceRule.interval ?? 1;
        var nextDate = DateTime(anchor.year, anchor.month, anchor.day);
        while (nextDate.isBefore(reference) ||
            nextDate.isAtSameMomentAs(reference)) {
          final newMonth = nextDate.month + interval;
          final newYear = nextDate.year + (newMonth - 1) ~/ 12;
          final adjustedMonth = ((newMonth - 1) % 12) + 1;
          nextDate = DateTime(newYear, adjustedMonth, anchor.day);
        }
        return nextDate;

      case 'yearly':
        final interval = recurrenceRule.interval ?? 1;
        var nextDate = DateTime(anchor.year, anchor.month, anchor.day);
        while (nextDate.isBefore(reference) ||
            nextDate.isAtSameMomentAs(reference)) {
          nextDate =
              DateTime(nextDate.year + interval, anchor.month, anchor.day);
        }
        return nextDate;

      default:
        return anchor;
    }
  }

  /// Check if the recurring transaction is still active
  bool get isActive {
    if (recurrenceRule.endDate == null) return true;
    return DateTime.now().isBefore(recurrenceRule.endDate!);
  }

  /// Get human-readable frequency text
  String get frequencyText {
    switch (recurrenceRule.frequency) {
      case 'daily':
        return recurrenceRule.interval != null && recurrenceRule.interval! > 1
            ? 'Every ${recurrenceRule.interval} days'
            : 'Daily';
      case 'weekly':
        return recurrenceRule.interval != null && recurrenceRule.interval! > 1
            ? 'Every ${recurrenceRule.interval} weeks'
            : 'Weekly';
      case 'biweekly':
        return 'Every 2 weeks';
      case 'monthly':
        return recurrenceRule.interval != null && recurrenceRule.interval! > 1
            ? 'Every ${recurrenceRule.interval} months'
            : 'Monthly';
      case 'yearly':
        return recurrenceRule.interval != null && recurrenceRule.interval! > 1
            ? 'Every ${recurrenceRule.interval} years'
            : 'Yearly';
      case 'custom':
        return 'Custom';
      default:
        return 'Unknown';
    }
  }
}

/// Recurrence rule for recurring transactions
class RecurrenceRule {
  final String
      frequency; // 'daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom'
  final DateTime anchorDate;
  final DateTime? endDate;
  final int? interval; // For custom frequency (e.g., every 2 weeks)

  RecurrenceRule({
    required this.frequency,
    required this.anchorDate,
    this.endDate,
    this.interval,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: json['frequency'] as String,
      anchorDate: DateTime.parse(json['anchor_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      interval: json['interval'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'anchor_date': anchorDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'interval': interval,
    };
  }

  RecurrenceRule copyWith({
    String? frequency,
    DateTime? anchorDate,
    DateTime? endDate,
    int? interval,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      anchorDate: anchorDate ?? this.anchorDate,
      endDate: endDate ?? this.endDate,
      interval: interval ?? this.interval,
    );
  }
}

/// Attachment model for transaction documentation
class Attachment {
  final String url;
  final String type; // 'image', 'pdf', 'document'
  final String name;
  final int size; // In bytes

  Attachment({
    required this.url,
    required this.type,
    required this.name,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: json['url'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'name': name,
      'size': size,
    };
  }
}

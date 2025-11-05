/// Income entry model
/// Represents a single income transaction with privacy controls and household sharing

class IncomeEntry {
  final String id;
  final DateTime date;
  final String category;
  final String? description;
  final String? source;
  final double amount; // In major units
  final String currency;
  final String ownerType; // 'me', 'partner', 'household'
  final String privacyScope; // 'private', 'balances_only', 'full'
  final String? householdId;
  final bool isAcknowledged;
  final int acknowledgedCount;
  final double? normalizedAmount; // Converted to base currency
  final String? baseCurrency;
  final double? fxRate;
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final String? parentRecurringId;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool privacyRedacted; // True if details are hidden due to privacy scope

  IncomeEntry({
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
    required this.isAcknowledged,
    required this.acknowledgedCount,
    this.normalizedAmount,
    this.baseCurrency,
    this.fxRate,
    required this.isRecurring,
    this.recurrenceRule,
    this.parentRecurringId,
    required this.attachments,
    required this.createdAt,
    this.updatedAt,
    required this.privacyRedacted,
  });

  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    return IncomeEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      description: json['description'] as String?,
      source: json['source'] as String?,
      amount: (json['amountMajor'] as num).toDouble(),
      currency: json['currency'] as String,
      ownerType: json['ownerType'] as String? ?? 'me',
      privacyScope: json['privacyScope'] as String? ?? 'full',
      householdId: json['householdId'] as String?,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      acknowledgedCount: json['acknowledgedCount'] as int? ?? 0,
      normalizedAmount: json['normalizedAmountMajor'] != null
          ? (json['normalizedAmountMajor'] as num).toDouble()
          : null,
      baseCurrency: json['baseCurrency'] as String?,
      fxRate: json['fxRate'] != null ? (json['fxRate'] as num).toDouble() : null,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] != null
          ? RecurrenceRule.fromJson(json['recurrenceRule'] as Map<String, dynamic>)
          : null,
      parentRecurringId: json['parentRecurringId'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      privacyRedacted: json['privacyRedacted'] as bool? ?? false,
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
      'isAcknowledged': isAcknowledged,
      'acknowledgedCount': acknowledgedCount,
      'normalizedAmountMajor': normalizedAmount,
      'baseCurrency': baseCurrency,
      'fxRate': fxRate,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule?.toJson(),
      'parentRecurringId': parentRecurringId,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'privacyRedacted': privacyRedacted,
    };
  }

  IncomeEntry copyWith({
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
    bool? isAcknowledged,
    int? acknowledgedCount,
    double? normalizedAmount,
    String? baseCurrency,
    double? fxRate,
    bool? isRecurring,
    RecurrenceRule? recurrenceRule,
    String? parentRecurringId,
    List<Attachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? privacyRedacted,
  }) {
    return IncomeEntry(
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
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      normalizedAmount: normalizedAmount ?? this.normalizedAmount,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      fxRate: fxRate ?? this.fxRate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      parentRecurringId: parentRecurringId ?? this.parentRecurringId,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      privacyRedacted: privacyRedacted ?? this.privacyRedacted,
    );
  }
}

/// Recurrence rule for recurring income (v1.5)
class RecurrenceRule {
  final String frequency; // 'daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom'
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
}

/// Attachment model for income documentation
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

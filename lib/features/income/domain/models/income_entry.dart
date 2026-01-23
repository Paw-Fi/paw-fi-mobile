/// Income entry model
/// Represents a single income transaction with privacy controls and household sharing

import 'dart:convert';

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
    // Support both the income endpoints' API shape (camelCase + major units)
    // and raw `expenses` table rows (snake_case + cents) returned by some
    // edge functions like `save-income`.

    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return null;
    }

    String? asNonEmptyString(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    DateTime? parseDateTime(dynamic value) {
      final raw = asNonEmptyString(value);
      if (raw == null) return null;
      return DateTime.parse(raw);
    }

    List<dynamic> parseJsonList(dynamic value) {
      if (value is List) return value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return const [];
        try {
          final decoded = jsonDecode(trimmed);
          return decoded is List ? decoded : const [];
        } catch (_) {
          return const [];
        }
      }
      return const [];
    }

    final dateStr = asNonEmptyString(json['date']) ??
        asNonEmptyString(json['created_at']) ??
        DateTime.now().toIso8601String();
    final parsedDate = DateTime.parse(dateStr);

    final createdAt =
        parseDateTime(json['createdAt'] ?? json['created_at']) ?? parsedDate;

    final amountMajor = asDouble(json['amountMajor']) ??
        asDouble(json['amount']) ??
        (() {
          final cents = asDouble(json['amountCents'] ?? json['amount_cents']);
          return cents == null ? null : (cents / 100.0);
        })() ??
        0.0;

    final normalizedAmountMajor = asDouble(json['normalizedAmountMajor']) ??
        asDouble(json['normalizedAmount']) ??
        (() {
          final cents = asDouble(
              json['normalizedAmountCents'] ?? json['normalized_amount_cents']);
          return cents == null ? null : (cents / 100.0);
        })();

    final recurrenceRaw = json['recurrenceRule'] ?? json['recurrence_rule'];
    final recurrenceRule = recurrenceRaw is Map
        ? RecurrenceRule.fromJson(Map<String, dynamic>.from(recurrenceRaw))
        : null;

    final attachmentsRaw = parseJsonList(json['attachments']);
    final attachments = attachmentsRaw
        .whereType<Map>()
        .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('IncomeEntry.fromJson: missing id');
    }

    return IncomeEntry(
      id: id,
      date: parsedDate,
      category: (json['category'] as String?) ?? 'income',
      description: asNonEmptyString(json['description']) ??
          asNonEmptyString(json['raw_text']),
      source: asNonEmptyString(json['source']),
      amount: amountMajor,
      currency: (json['currency'] as String?) ?? 'USD',
      ownerType: asNonEmptyString(json['ownerType']) ??
          asNonEmptyString(json['owner_type']) ??
          'me',
      privacyScope: asNonEmptyString(json['privacyScope']) ??
          asNonEmptyString(json['privacy_scope']) ??
          'full',
      householdId: asNonEmptyString(json['householdId']) ??
          asNonEmptyString(json['household_id']),
      isAcknowledged: (json['isAcknowledged'] as bool?) ??
          (json['is_acknowledged'] as bool?) ??
          false,
      acknowledgedCount: (json['acknowledgedCount'] as int?) ??
          (json['acknowledged_count'] as int?) ??
          0,
      normalizedAmount: normalizedAmountMajor,
      baseCurrency: asNonEmptyString(json['baseCurrency']) ??
          asNonEmptyString(json['base_currency']),
      fxRate: asDouble(json['fxRate']) ?? asDouble(json['fx_rate']),
      isRecurring: (json['isRecurring'] as bool?) ??
          (json['is_recurring'] as bool?) ??
          false,
      recurrenceRule: recurrenceRule,
      parentRecurringId: asNonEmptyString(json['parentRecurringId']) ??
          asNonEmptyString(json['parent_recurring_id']),
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: parseDateTime(json['updatedAt'] ?? json['updated_at']),
      privacyRedacted: (json['privacyRedacted'] as bool?) ??
          (json['privacy_redacted'] as bool?) ??
          false,
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
    DateTime? parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return null;
    }

    return RecurrenceRule(
      frequency: (json['frequency'] as String?) ?? 'monthly',
      anchorDate: parseDate(json['anchor_date'] ?? json['anchorDate']) ??
          DateTime.now(),
      endDate: parseDate(json['end_date'] ?? json['endDate']),
      interval: parseInt(json['interval']),
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

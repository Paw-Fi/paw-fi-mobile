/// Recurring transaction model
/// Represents a recurring income or expense transaction

import 'dart:convert';
import 'package:flutter/foundation.dart';

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
  final RecurrenceRule? recurrenceRule; // Nullable - for parsing safety
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
    this.recurrenceRule, // Not required anymore
    required this.type,
    required this.attachments,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    debugPrint('🔍 Parsing RecurringTransaction from JSON: ${json.keys.toList()}');
    debugPrint('🔍 Raw JSON: ${jsonEncode(json)}');
    
    // Infer type from source field (income) or default to expense
    // Backend doesn't always return 'type' field, so we need to infer it
    String inferredType;
    if (json['type'] != null) {
      inferredType = json['type'] as String;
    } else if (json['source'] != null) {
      // If source field exists, it's income
      inferredType = 'income';
    } else {
      // Default to expense
      inferredType = 'expense';
    }
    
    debugPrint('🔍 Inferred type: $inferredType');
    debugPrint('🔍 Attachments type: ${json['attachments'].runtimeType}');
    debugPrint('🔍 Attachments value: ${json['attachments']}');
    
    // Normalize amount from various possible fields
    final amountMajor = (json['amountMajor'] as num?)?.toDouble();
    final amountCentsNum = (json['amount_cents'] as num?);
    final amountFromCents = amountCentsNum != null ? amountCentsNum.toDouble() / 100 : null;
    final amountLegacy = (json['amount'] as num?)?.toDouble();

    return RecurringTransaction(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      description:
          json['description'] as String? ?? json['raw_text'] as String?,
      source: json['source'] as String?,
      amount: amountMajor ?? amountFromCents ?? amountLegacy ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      ownerType:
          json['ownerType'] as String? ?? json['owner_type'] as String? ?? 'me',
      privacyScope: json['privacyScope'] as String? ??
          json['privacy_scope'] as String? ??
          'full',
      householdId:
          json['householdId'] as String? ?? json['household_id'] as String?,
      recurrenceRule: (json['recurrenceRule'] != null || json['recurrence_rule'] != null)
          ? RecurrenceRule.fromJson(
              json['recurrenceRule'] as Map<String, dynamic>? ??
                  json['recurrence_rule'] as Map<String, dynamic>,
            )
          : null,
      type: inferredType,
      attachments: _parseAttachments(json['attachments']),
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null),
    );
  }
  
  /// Parse attachments from various formats (List, String, null)
  static List<Attachment> _parseAttachments(dynamic value) {
    debugPrint('🔍 _parseAttachments called with type: ${value.runtimeType}, value: $value');
    
    if (value == null) {
      debugPrint('🔍 Attachments is null, returning empty list');
      return [];
    }
    
    if (value is String) {
      debugPrint('🔍 Attachments is String: "$value"');
      // Backend might return JSON string, parse it
      if (value.isEmpty || value == '[]') {
        debugPrint('🔍 Empty string or "[]", returning empty list');
        return [];
      }
      try {
        final parsed = jsonDecode(value);
        debugPrint('🔍 Parsed string to: ${parsed.runtimeType}');
        if (parsed is List) {
          return parsed
              .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('❌ Error parsing attachments string: $e');
        return [];
      }
      return [];
    }
    
    if (value is List) {
      debugPrint('🔍 Attachments is List with ${value.length} items');
      try {
        return value
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('❌ Error parsing attachments list: $e');
        return [];
      }
    }
    
    debugPrint('⚠️ Attachments is unexpected type: ${value.runtimeType}');
    return [];
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
      if (recurrenceRule != null) 'recurrenceRule': recurrenceRule?.toJson(), // Safe null access
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
    // If no recurrence rule, return the transaction date
    if (recurrenceRule == null) {
      return date;
    }
    
    final rule = recurrenceRule!; // Safe after null check
    final reference = from ?? DateTime.now();
    final anchor = rule.anchorDate;

    // If reference is before anchor, return anchor
    if (reference.isBefore(anchor)) {
      return anchor;
    }

    // If there's an end date and we're past it, return the anchor (no more occurrences)
    if (rule.endDate != null && reference.isAfter(rule.endDate!)) {
      return anchor;
    }

    // Calculate next occurrence based on frequency
    switch (rule.frequency) {
      case 'daily':
        final interval = rule.interval ?? 1;
        final daysDiff = reference.difference(anchor).inDays;
        final nextDays = ((daysDiff / interval).ceil() * interval).toInt();
        return anchor.add(Duration(days: nextDays));

      case 'weekly':
        final interval = rule.interval ?? 1;
        final weeksDiff = reference.difference(anchor).inDays ~/ 7;
        final nextWeeks = ((weeksDiff / interval).ceil() * interval).toInt();
        return anchor.add(Duration(days: nextWeeks * 7));

      case 'biweekly':
        final weeksDiff = reference.difference(anchor).inDays ~/ 7;
        final nextWeeks = ((weeksDiff / 2).ceil() * 2).toInt();
        return anchor.add(Duration(days: nextWeeks * 7));

      case 'monthly':
        final interval = rule.interval ?? 1;
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
        final interval = rule.interval ?? 1;
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
    if (recurrenceRule == null) return true;
    final rule = recurrenceRule!; // Safe after null check
    if (rule.endDate == null) return true;
    return DateTime.now().isBefore(rule.endDate!);
  }

  /// Get human-readable frequency text
  String get frequencyText {
    if (recurrenceRule == null) return 'One-time';
    
    final rule = recurrenceRule!; // Safe after null check
    switch (rule.frequency) {
      case 'daily':
        return rule.interval != null && rule.interval! > 1
            ? 'Every ${rule.interval} days'
            : 'Daily';
      case 'weekly':
        return rule.interval != null && rule.interval! > 1
            ? 'Every ${rule.interval} weeks'
            : 'Weekly';
      case 'biweekly':
        return 'Every 2 weeks';
      case 'monthly':
        return rule.interval != null && rule.interval! > 1
            ? 'Every ${rule.interval} months'
            : 'Monthly';
      case 'yearly':
        return rule.interval != null && rule.interval! > 1
            ? 'Every ${rule.interval} years'
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
  final bool? reminderEnabled;
  final int? reminderValue;
  final String? reminderUnit;

  RecurrenceRule({
    required this.frequency,
    required this.anchorDate,
    this.endDate,
    this.interval,
    this.reminderEnabled,
    this.reminderValue,
    this.reminderUnit,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final reminder = json['reminder'] as Map<String, dynamic>?;
    return RecurrenceRule(
      frequency: json['frequency'] as String,
      anchorDate: DateTime.parse(json['anchor_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      interval: json['interval'] as int?,
      reminderEnabled: reminder?['enabled'] as bool?,
      reminderValue: reminder?['value'] as int?,
      reminderUnit: reminder?['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'anchor_date': anchorDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'interval': interval,
      if (reminderEnabled != null ||
          reminderValue != null ||
          reminderUnit != null)
        'reminder': {
          if (reminderEnabled != null) 'enabled': reminderEnabled,
          if (reminderValue != null) 'value': reminderValue,
          if (reminderUnit != null) 'unit': reminderUnit,
        },
    };
  }

  RecurrenceRule copyWith({
    String? frequency,
    DateTime? anchorDate,
    DateTime? endDate,
    int? interval,
    bool? reminderEnabled,
    int? reminderValue,
    String? reminderUnit,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      anchorDate: anchorDate ?? this.anchorDate,
      endDate: endDate ?? this.endDate,
      interval: interval ?? this.interval,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderValue: reminderValue ?? this.reminderValue,
      reminderUnit: reminderUnit ?? this.reminderUnit,
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

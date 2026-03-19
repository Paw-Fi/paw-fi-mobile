/// Recurring transaction model
/// Represents a recurring income or expense transaction

import 'dart:convert';
import 'package:flutter/foundation.dart' as foundation;
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/utils/user_timezone.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugLog(String message) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message);
  }
}

DateTime? _parseRecurrenceCalendarDate(dynamic value) {
  return parseCalendarDateFromFlexibleInput(value?.toString());
}

String _sanitizeRequired(String value, {String fallback = ''}) {
  if (value.isEmpty) return fallback;
  return sanitizeUtf16(value);
}

String? _sanitizeOptional(String? value) {
  if (value == null || value.isEmpty) return value;
  return sanitizeUtf16(value);
}

class RecurringTransaction {
  final String id;
  final String? userId;
  final DateTime date;
  final String category;
  final String? description;
  final String? source; // For income
  final double amount; // In major units
  final String currency;
  final String ownerType; // 'me', 'partner', 'household'
  final String privacyScope; // 'private', 'balances_only', 'full'
  final String? householdId;
  final String? payerUserId; // Who paid (household sharing)
  final String? splitGroupId;
  final RecurrenceRule? recurrenceRule; // Nullable - for parsing safety
  final String type; // 'income' or 'expense'
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RecurringTransaction({
    required this.id,
    this.userId,
    required this.date,
    required this.category,
    this.description,
    this.source,
    required this.amount,
    required this.currency,
    required this.ownerType,
    required this.privacyScope,
    this.householdId,
    this.payerUserId,
    this.splitGroupId,
    this.recurrenceRule, // Not required anymore
    required this.type,
    required this.attachments,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
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

    // Parse recurrence_rule - handle both string and Map formats
    dynamic recurrenceRuleData =
        json['recurrenceRule'] ?? json['recurrence_rule'];

    RecurrenceRule? parsedRecurrenceRule;
    if (recurrenceRuleData != null) {
      if (recurrenceRuleData is String) {
        // Backend returned JSONB as string - parse it first
        try {
          final parsed = jsonDecode(recurrenceRuleData);
          if (parsed is Map<String, dynamic>) {
            parsedRecurrenceRule = RecurrenceRule.fromJson(parsed);
          }
        } catch (e) {
          _debugLog('Failed to parse recurrence rule string');
        }
      } else if (recurrenceRuleData is Map<String, dynamic>) {
        // Already a map, parse directly
        parsedRecurrenceRule = RecurrenceRule.fromJson(recurrenceRuleData);
      }
    }

    // Normalize amount from various possible fields
    final amountMajor = (json['amountMajor'] as num?)?.toDouble();
    final amountCentsNum = (json['amount_cents'] as num?);
    final amountFromCents =
        amountCentsNum != null ? amountCentsNum.toDouble() / 100 : null;
    final amountLegacy = (json['amount'] as num?)?.toDouble();

    DateTime parseDateOnly(dynamic value) {
      final parsed = parseCalendarDateFromFlexibleInput(value?.toString());
      return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    final rawCategory = json['category'] as String? ?? 'Uncategorized';
    final sanitizedDescription = _sanitizeOptional(
          json['description'] as String?,
        ) ??
        _sanitizeOptional(json['raw_text'] as String?);

    return RecurringTransaction(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      date: parseDateOnly(json['date']),
      category: _sanitizeRequired(rawCategory, fallback: 'Uncategorized'),
      description: sanitizedDescription,
      source: _sanitizeOptional(json['source'] as String?),
      amount: amountMajor ?? amountFromCents ?? amountLegacy ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      ownerType:
          json['ownerType'] as String? ?? json['owner_type'] as String? ?? 'me',
      privacyScope: json['privacyScope'] as String? ??
          json['privacy_scope'] as String? ??
          'full',
      householdId:
          json['householdId'] as String? ?? json['household_id'] as String?,
      payerUserId:
          json['payerUserId'] as String? ?? json['payer_user_id'] as String?,
      splitGroupId:
          json['splitGroupId'] as String? ?? json['split_group_id'] as String?,
      recurrenceRule: parsedRecurrenceRule,
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
    if (value == null) {
      return [];
    }

    if (value is String) {
      // Backend might return JSON string, parse it
      if (value.isEmpty || value == '[]') {
        return [];
      }
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) {
          return parsed
              .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        _debugLog('Error parsing attachments string');
        return [];
      }
      return [];
    }

    if (value is List) {
      try {
        return value
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _debugLog('Error parsing attachments list');
        return [];
      }
    }

    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': formatDateOnlyYmd(date),
      'category': category,
      'description': description,
      'source': source,
      'amountMajor': amount,
      'currency': currency,
      'ownerType': ownerType,
      'privacyScope': privacyScope,
      'householdId': householdId,
      'payerUserId': payerUserId,
      'splitGroupId': splitGroupId,
      if (recurrenceRule != null)
        'recurrenceRule': recurrenceRule?.toJson(), // Safe null access
      'type': type,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  RecurringTransaction copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? category,
    String? description,
    String? source,
    double? amount,
    String? currency,
    String? ownerType,
    String? privacyScope,
    String? householdId,
    String? payerUserId,
    String? splitGroupId,
    RecurrenceRule? recurrenceRule,
    String? type,
    List<Attachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      ownerType: ownerType ?? this.ownerType,
      privacyScope: privacyScope ?? this.privacyScope,
      householdId: householdId ?? this.householdId,
      payerUserId: payerUserId ?? this.payerUserId,
      splitGroupId: splitGroupId ?? this.splitGroupId,
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

    // Recurring schedules are calendar-based. In practice we've seen cases where
    // `recurrence_rule.anchor_date` drifts from the intended calendar date due to
    // timezone serialization/parsing differences (e.g. an ISO string with `Z`).
    // The `expenses.date` field is a date-only value and often reflects the
    // intended day more reliably.
    //
    // To prevent showing the next occurrence a day (or more) early, we pick the
    // later of:
    // - the date-only value from `recurrence_rule.anchor_date`
    // - the date-only value from the row's `date` column
    // while preserving the time-of-day from the recurrence anchor.
    final ruleAnchor = rule.anchorDate;

    DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    int clampDayOfMonth(
        {required int year, required int month, required int day}) {
      final lastDay = DateTime(year, month + 1, 0).day;
      return day <= lastDay ? day : lastDay;
    }

    DateTime buildDatePreservingTime({
      required int year,
      required int month,
      required int day,
    }) {
      return DateTime(
        year,
        month,
        day,
        ruleAnchor.hour,
        ruleAnchor.minute,
        ruleAnchor.second,
        ruleAnchor.millisecond,
        ruleAnchor.microsecond,
      );
    }

    final anchorDayFromRule = dateOnly(ruleAnchor);
    final anchorDayFromRowDate = dateOnly(date);
    final pickedAnchorDay = anchorDayFromRowDate.isAfter(anchorDayFromRule)
        ? anchorDayFromRowDate
        : anchorDayFromRule;
    final anchor = buildDatePreservingTime(
      year: pickedAnchorDay.year,
      month: pickedAnchorDay.month,
      day: pickedAnchorDay.day,
    );

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
        final intervalDays = rule.interval ?? 1;
        final anchorDay = dateOnly(anchor);
        final referenceDay = dateOnly(reference);

        final daysBetween = referenceDay.difference(anchorDay).inDays;
        final alignedDays = (daysBetween ~/ intervalDays) * intervalDays;
        var candidate = anchor.add(Duration(days: alignedDays));
        if (!candidate.isAfter(reference)) {
          candidate = candidate.add(Duration(days: intervalDays));
        }
        return candidate;

      case 'weekly':
        final intervalWeeks = rule.interval ?? 1;
        final intervalDays = intervalWeeks * 7;
        final anchorDay = dateOnly(anchor);
        final referenceDay = dateOnly(reference);

        final daysBetween = referenceDay.difference(anchorDay).inDays;
        final alignedDays = (daysBetween ~/ intervalDays) * intervalDays;
        var candidate = anchor.add(Duration(days: alignedDays));
        if (!candidate.isAfter(reference)) {
          candidate = candidate.add(Duration(days: intervalDays));
        }
        return candidate;

      case 'biweekly':
        const intervalDays = 14;
        final anchorDay = dateOnly(anchor);
        final referenceDay = dateOnly(reference);

        final daysBetween = referenceDay.difference(anchorDay).inDays;
        final alignedDays = (daysBetween ~/ intervalDays) * intervalDays;
        var candidate = anchor.add(Duration(days: alignedDays));
        if (!candidate.isAfter(reference)) {
          candidate = candidate.add(const Duration(days: intervalDays));
        }
        return candidate;

      case 'monthly':
        final interval = rule.interval ?? 1;
        var nextDate = buildDatePreservingTime(
          year: anchor.year,
          month: anchor.month,
          day: clampDayOfMonth(
            year: anchor.year,
            month: anchor.month,
            day: anchor.day,
          ),
        );
        while (nextDate.isBefore(reference) ||
            nextDate.isAtSameMomentAs(reference)) {
          final newMonth = nextDate.month + interval;
          final newYear = nextDate.year + (newMonth - 1) ~/ 12;
          final adjustedMonth = ((newMonth - 1) % 12) + 1;
          nextDate = buildDatePreservingTime(
            year: newYear,
            month: adjustedMonth,
            day: clampDayOfMonth(
              year: newYear,
              month: adjustedMonth,
              day: anchor.day,
            ),
          );
        }
        return nextDate;

      case 'yearly':
        final interval = rule.interval ?? 1;
        var nextDate = buildDatePreservingTime(
          year: anchor.year,
          month: anchor.month,
          day: clampDayOfMonth(
            year: anchor.year,
            month: anchor.month,
            day: anchor.day,
          ),
        );
        while (nextDate.isBefore(reference) ||
            nextDate.isAtSameMomentAs(reference)) {
          final nextYear = nextDate.year + interval;
          nextDate = buildDatePreservingTime(
            year: nextYear,
            month: anchor.month,
            day: clampDayOfMonth(
              year: nextYear,
              month: anchor.month,
              day: anchor.day,
            ),
          );
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

  DateTime? getNextSkippableOccurrence([DateTime? from]) {
    if (recurrenceRule == null) {
      return date;
    }

    final rule = recurrenceRule!;
    final endDate = rule.endDate == null
        ? null
        : DateTime(rule.endDate!.year, rule.endDate!.month, rule.endDate!.day);
    final excludedDateKeys =
        rule.excludedDates.map((date) => formatDateOnlyYmd(date)).toSet();

    var searchFrom = from ?? DateTime.now();
    DateTime? previousCandidate;

    for (var attempt = 0; attempt < 1000; attempt++) {
      final candidate = getNextOccurrence(searchFrom);
      final candidateDay =
          DateTime(candidate.year, candidate.month, candidate.day);

      if (endDate != null && candidateDay.isAfter(endDate)) {
        return null;
      }

      if (previousCandidate != null && !candidate.isAfter(previousCandidate)) {
        return null;
      }

      if (!excludedDateKeys.contains(formatDateOnlyYmd(candidate))) {
        return candidate;
      }

      previousCandidate = candidate;
      searchFrom = candidate.add(const Duration(microseconds: 1));
    }

    return null;
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
  final List<DateTime>
      excludedDates; // Dates to skip (for "delete this occurrence")

  RecurrenceRule({
    required this.frequency,
    required this.anchorDate,
    this.endDate,
    this.interval,
    this.reminderEnabled,
    this.reminderValue,
    this.reminderUnit,
    this.excludedDates = const [],
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final reminder = json['reminder'] as Map<String, dynamic>?;
    final excludedRaw = json['excluded_dates'] as List<dynamic>?;
    return RecurrenceRule(
      frequency: json['frequency'] as String,
      anchorDate: DateTime.parse(json['anchor_date'] as String),
      endDate: _parseRecurrenceCalendarDate(json['end_date']),
      interval: json['interval'] as int?,
      reminderEnabled: reminder?['enabled'] as bool?,
      reminderValue: reminder?['value'] as int?,
      reminderUnit: reminder?['unit'] as String?,
      excludedDates:
          excludedRaw?.map((e) => DateTime.parse(e as String)).toList() ??
              const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'anchor_date': formatDateOnlyYmd(anchorDate),
      'end_date': endDate == null ? null : formatDateOnlyYmd(endDate!),
      'interval': interval,
      if (reminderEnabled != null ||
          reminderValue != null ||
          reminderUnit != null)
        'reminder': {
          if (reminderEnabled != null) 'enabled': reminderEnabled,
          if (reminderValue != null) 'value': reminderValue,
          if (reminderUnit != null) 'unit': reminderUnit,
        },
      if (excludedDates.isNotEmpty)
        'excluded_dates': excludedDates.map(formatDateOnlyYmd).toList(),
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
    List<DateTime>? excludedDates,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      anchorDate: anchorDate ?? this.anchorDate,
      endDate: endDate ?? this.endDate,
      interval: interval ?? this.interval,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderValue: reminderValue ?? this.reminderValue,
      reminderUnit: reminderUnit ?? this.reminderUnit,
      excludedDates: excludedDates ?? this.excludedDates,
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

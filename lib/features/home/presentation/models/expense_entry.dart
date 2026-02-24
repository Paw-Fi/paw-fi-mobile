import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/utils/user_timezone.dart';

String? _sanitizeNullable(String? value) =>
    value == null ? null : sanitizeUtf16(value);

/// Represents a single transaction from expenses table (type = 'expense' or 'income')
class ExpenseEntry {
  final String id;
  final String? contactId;
  final String? userId;
  final String? userName; // From users.full_name
  final String? userAvatarUrl; // From users.avatar_url
  final String? householdId;
  final DateTime date;
  final int amountCents;
  final String? currency;
  final String? category;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? rawText;
  final List<String>? breakdown;
  final String? receiptImageUrl;
  final List<String>? sharedMemberIds;
  final String? splitGroupId;
  final String? bankAccountId;
  final String? type; // 'expense' | 'income'
  final bool isRecurring;

  ExpenseEntry({
    required this.id,
    this.contactId,
    this.userId,
    this.userName,
    this.userAvatarUrl,
    this.householdId,
    required this.date,
    required this.amountCents,
    this.currency,
    this.category,
    required this.createdAt,
    this.updatedAt,
    this.rawText,
    this.breakdown,
    this.receiptImageUrl,
    this.sharedMemberIds,
    this.splitGroupId,
    this.bankAccountId,
    this.type,
    this.isRecurring = false,
  });

  double get amount => amountCents / 100.0;

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    // Extract user data from nested users object if available
    final userData = json['users'] as Map<String, dynamic>?;

    String stringOrEmpty(dynamic value) =>
        value == null ? '' : value.toString();

    DateTime parseDateOnly(dynamic value) {
      final parsed = parseCalendarDateFromFlexibleInput(value?.toString());
      return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime parseInstant(dynamic value) {
      final s = value?.toString();
      if (s == null || s.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    int parseAmountCents(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed.round();
      }
      return 0;
    }

    return ExpenseEntry(
      id: stringOrEmpty(json['id']),
      contactId: json['contact_id'] as String?,
      userId: json['user_id'] as String?,
      userName: _sanitizeNullable(userData?['full_name'] as String?),
      userAvatarUrl: userData?['avatar_url'] as String?,
      householdId: json['household_id'] as String?,
      date: parseDateOnly(json['date']),
      amountCents: parseAmountCents(json['amount_cents']),
      currency: canonicalizeCurrencyCode(json['currency'] as String?),
      category: _sanitizeNullable(json['category'] as String?),
      createdAt: parseInstant(json['created_at']),
      updatedAt:
          json['updated_at'] != null ? parseInstant(json['updated_at']) : null,
      rawText: _sanitizeNullable(json['raw_text'] as String?),
      breakdown: json['breakdown'] != null
          ? (json['breakdown'] as List)
              .map((e) => sanitizeUtf16(e.toString()))
              .toList()
          : null,
      receiptImageUrl: json['receipt_image_url'] as String?,
      sharedMemberIds: json['shared_member_ids'] != null
          ? List<String>.from(json['shared_member_ids'] as List)
          : null,
      splitGroupId: json['split_group_id'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      type: json['type'] as String?,
      isRecurring: json['is_recurring'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'household_id': householdId,
      'date': formatDateOnlyYmd(date),
      'amount_cents': amountCents,
      'currency': currency,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'raw_text': rawText,
      'breakdown': breakdown,
      'receipt_image_url': receiptImageUrl,
      'shared_member_ids': sharedMemberIds,
      'split_group_id': splitGroupId,
      'bank_account_id': bankAccountId,
      'type': type,
      'is_recurring': isRecurring,
    };
  }

  /// Create a copy of this ExpenseEntry with some fields replaced
  ExpenseEntry copyWith({
    String? id,
    String? contactId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? householdId,
    DateTime? date,
    int? amountCents,
    String? currency,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawText,
    List<String>? breakdown,
    String? receiptImageUrl,
    List<String>? sharedMemberIds,
    String? splitGroupId,
    String? bankAccountId,
    String? type,
    bool? isRecurring,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      householdId: householdId ?? this.householdId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawText: rawText ?? this.rawText,
      breakdown: breakdown ?? this.breakdown,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      sharedMemberIds: sharedMemberIds ?? this.sharedMemberIds,
      splitGroupId: splitGroupId ?? this.splitGroupId,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }
}

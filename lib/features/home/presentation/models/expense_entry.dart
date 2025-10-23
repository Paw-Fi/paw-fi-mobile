import '../../../households/domain/entities/shared_budget.dart' show ShareScope;

/// Represents a single spending entry from expenses table
class ExpenseEntry {
  final String id;
  final String? contactId;
  final String? userId;
  final String? userName;  // From users.full_name
  final String? userAvatarUrl;  // From users.avatar_url
  final String? householdId;
  final DateTime date;
  final int amountCents;
  final String? currency;
  final String? category;
  final DateTime createdAt;
  final String? rawText;
  final String? receiptImageUrl;
  final ShareScope shareScope;
  final List<String>? sharedMemberIds;
  final String? splitGroupId;

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
    this.rawText,
    this.receiptImageUrl,
    this.shareScope = ShareScope.private,
    this.sharedMemberIds,
    this.splitGroupId,
  });

  double get amount => amountCents / 100.0;

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    // Extract user data from nested users object if available
    final userData = json['users'] as Map<String, dynamic>?;
    
    return ExpenseEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String?,
      userId: json['user_id'] as String?,
      userName: userData?['full_name'] as String?,
      userAvatarUrl: userData?['avatar_url'] as String?,
      householdId: json['household_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rawText: json['raw_text'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      shareScope: json['share_scope'] != null
          ? ShareScope.fromJson(json['share_scope'] as String)
          : ShareScope.private,
      sharedMemberIds: json['shared_member_ids'] != null
          ? List<String>.from(json['shared_member_ids'] as List)
          : null,
      splitGroupId: json['split_group_id'] as String?,
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
      'date': date.toIso8601String(),
      'amount_cents': amountCents,
      'currency': currency,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'raw_text': rawText,
      'receipt_image_url': receiptImageUrl,
      'share_scope': shareScope.toJson(),
      'shared_member_ids': sharedMemberIds,
      'split_group_id': splitGroupId,
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
    String? rawText,
    String? receiptImageUrl,
    ShareScope? shareScope,
    List<String>? sharedMemberIds,
    String? splitGroupId,
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
      rawText: rawText ?? this.rawText,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      shareScope: shareScope ?? this.shareScope,
      sharedMemberIds: sharedMemberIds ?? this.sharedMemberIds,
      splitGroupId: splitGroupId ?? this.splitGroupId,
    );
  }
}

/// Represents user contact info from user_contacts table
class UserContact {
  final String id;
  final String? userId;
  final String phoneE164;
  final bool verified;
  final String? preferredCurrency;

  UserContact({
    required this.id,
    this.userId,
    required this.phoneE164,
    required this.verified,
    this.preferredCurrency,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    return UserContact(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      phoneE164: json['phone_e164'] as String,
      verified: json['verified'] as bool,
      preferredCurrency: json['preferred_currency'] as String?,
    );
  }

  UserContact copyWith({
    String? preferredCurrency,
  }) {
    return UserContact(
      id: id,
      userId: userId,
      phoneE164: phoneE164,
      verified: verified,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    );
  }
}

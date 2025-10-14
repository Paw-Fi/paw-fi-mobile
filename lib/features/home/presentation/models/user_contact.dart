/// Represents user contact info from user_contacts table
class UserContact {
  final String id;
  final String? userId;
  final String? phoneE164;  // Nullable for mobile-only users without WhatsApp
  final bool verified;
  final String? preferredCurrency;

  UserContact({
    required this.id,
    this.userId,
    this.phoneE164,  // Optional
    required this.verified,
    this.preferredCurrency,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    return UserContact(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      phoneE164: json['phone_e164'] as String?,  // Nullable cast
      verified: json['verified'] as bool? ?? false,  // Default to false if null
      preferredCurrency: json['preferred_currency'] as String?,
    );
  }

  UserContact copyWith({
    String? preferredCurrency,
  }) {
    return UserContact(
      id: id,
      userId: userId,
      phoneE164: phoneE164,  // Already nullable, no issue
      verified: verified,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    );
  }
}

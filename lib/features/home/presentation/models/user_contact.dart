/// Represents user contact info from user_contacts table
class UserContact {
  final String id;
  final String? userId;
  final String? phoneE164; // Nullable for mobile-only users without WhatsApp
  final bool verified;
  final String? preferredCurrency;
  final String? preferredTimezone;

  UserContact({
    required this.id,
    this.userId,
    this.phoneE164, // Optional
    required this.verified,
    this.preferredCurrency,
    this.preferredTimezone,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    return UserContact(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      phoneE164: json['phone_e164'] as String?, // Nullable cast
      verified: json['verified'] as bool? ?? false, // Default to false if null
      preferredCurrency: json['preferred_currency'] as String?,
      preferredTimezone: json['preferred_timezone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'phone_e164': phoneE164,
      'verified': verified,
      'preferred_currency': preferredCurrency,
      'preferred_timezone': preferredTimezone,
    };
  }

  UserContact copyWith({
    String? preferredCurrency,
    String? preferredTimezone,
  }) {
    return UserContact(
      id: id,
      userId: userId,
      phoneE164: phoneE164, // Already nullable, no issue
      verified: verified,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      preferredTimezone: preferredTimezone ?? this.preferredTimezone,
    );
  }
}

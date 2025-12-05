/// WhatsApp binding entity representing WhatsApp integration status
/// Simplified version based on user_contacts table existence
class WhatsAppBinding {
  final String userId;
  final bool isBound;
  final String? phoneE164;
  final bool? verified;

  const WhatsAppBinding({
    required this.userId,
    required this.isBound,
    this.phoneE164,
    this.verified,
  });

  factory WhatsAppBinding.fromJson(Map<String, dynamic> json) {
    return WhatsAppBinding(
      userId: json['user_id'] as String? ?? '',
      isBound: json['is_bound'] as bool? ?? false,
      phoneE164: json['phone_e164'] as String?,
      verified: json['verified'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_bound': isBound,
      'phone_e164': phoneE164,
      'verified': verified,
    };
  }

  WhatsAppBinding copyWith({
    String? userId,
    bool? isBound,
    String? phoneE164,
    bool? verified,
  }) {
    return WhatsAppBinding(
      userId: userId ?? this.userId,
      isBound: isBound ?? this.isBound,
      phoneE164: phoneE164 ?? this.phoneE164,
      verified: verified ?? this.verified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppBinding &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isBound == other.isBound &&
          phoneE164 == other.phoneE164;

  @override
  int get hashCode => userId.hashCode ^ isBound.hashCode ^ phoneE164.hashCode;
}

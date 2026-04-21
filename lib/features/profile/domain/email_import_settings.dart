const emailImportInboundAddress = 'files@inbound.moneko.io';

class EmailImportWhitelistEntry {
  const EmailImportWhitelistEntry({
    required this.id,
    required this.email,
    required this.normalizedEmail,
  });

  final String id;
  final String email;
  final String normalizedEmail;

  factory EmailImportWhitelistEntry.fromJson(Map<String, dynamic> json) {
    return EmailImportWhitelistEntry(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      normalizedEmail: (json['normalizedEmail'] as String?) ??
          (json['email'] as String?) ??
          '',
    );
  }
}

class EmailImportSettings {
  const EmailImportSettings({
    required this.enabled,
    required this.scopeId,
    required this.scopeName,
    required this.isPortfolio,
    required this.defaultEmail,
    required this.whitelistEmails,
    this.accountId,
    this.accountName,
  });

  final bool enabled;
  final String scopeId;
  final String scopeName;
  final bool isPortfolio;
  final String? accountId;
  final String? accountName;
  final String defaultEmail;
  final List<EmailImportWhitelistEntry> whitelistEmails;

  factory EmailImportSettings.fromJson(Map<String, dynamic> json) {
    final whitelist = json['whitelistEmails'];
    return EmailImportSettings(
      enabled: json['enabled'] as bool? ?? false,
      scopeId: (json['scopeId'] as String?) ?? 'personal',
      scopeName: (json['scopeName'] as String?) ?? 'Personal',
      isPortfolio: json['isPortfolio'] as bool? ?? false,
      accountId: _optionalString(json['accountId']),
      accountName: _optionalString(json['accountName']),
      defaultEmail: (json['defaultEmail'] as String?) ?? '',
      whitelistEmails: whitelist is List
          ? whitelist
              .whereType<Map>()
              .map(
                (item) => EmailImportWhitelistEntry.fromJson(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
          : const <EmailImportWhitelistEntry>[],
    );
  }

  factory EmailImportSettings.disabled({required String defaultEmail}) {
    return EmailImportSettings(
      enabled: false,
      scopeId: 'personal',
      scopeName: 'Personal',
      isPortfolio: false,
      accountId: null,
      accountName: null,
      defaultEmail: defaultEmail,
      whitelistEmails: const <EmailImportWhitelistEntry>[],
    );
  }

  EmailImportSettings copyWith({
    bool? enabled,
    String? scopeId,
    String? scopeName,
    bool? isPortfolio,
    String? accountId,
    String? accountName,
    String? defaultEmail,
    List<EmailImportWhitelistEntry>? whitelistEmails,
    bool clearAccountSelection = false,
  }) {
    return EmailImportSettings(
      enabled: enabled ?? this.enabled,
      scopeId: scopeId ?? this.scopeId,
      scopeName: scopeName ?? this.scopeName,
      isPortfolio: isPortfolio ?? this.isPortfolio,
      accountId: clearAccountSelection ? null : accountId ?? this.accountId,
      accountName:
          clearAccountSelection ? null : accountName ?? this.accountName,
      defaultEmail: defaultEmail ?? this.defaultEmail,
      whitelistEmails: whitelistEmails ?? this.whitelistEmails,
    );
  }

  static String? _optionalString(Object? value) {
    final raw = value as String?;
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

String? normalizeWhitelistEmail(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty) return null;

  const pattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
  if (!RegExp(pattern).hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

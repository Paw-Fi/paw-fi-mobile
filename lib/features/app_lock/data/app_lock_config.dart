enum AppLockTimeout {
  immediately(Duration.zero),
  afterThirtySeconds(Duration(seconds: 30)),
  afterOneMinute(Duration(minutes: 1)),
  afterFiveMinutes(Duration(minutes: 5));

  const AppLockTimeout(this.duration);

  final Duration duration;

  static AppLockTimeout fromName(String? name) {
    return AppLockTimeout.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AppLockTimeout.immediately,
    );
  }
}

class AppLockConfig {
  const AppLockConfig({
    required this.userId,
    required this.passcodeHashBase64,
    required this.saltBase64,
    required this.hashVersion,
    required this.biometricEnabled,
    required this.lockTimeout,
    this.failedAttempts = 0,
    this.lockoutUntil,
  });

  factory AppLockConfig.fromJson(Map<String, dynamic> json) {
    final lockoutRaw = json['lockoutUntil'] as String?;
    return AppLockConfig(
      userId: json['userId'] as String? ?? '',
      passcodeHashBase64: json['passcodeHashBase64'] as String? ?? '',
      saltBase64: json['saltBase64'] as String? ?? '',
      hashVersion: (json['hashVersion'] as num?)?.toInt() ?? 0,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      lockTimeout: AppLockTimeout.fromName(json['lockTimeout'] as String?),
      failedAttempts: (json['failedAttempts'] as num?)?.toInt() ?? 0,
      lockoutUntil: lockoutRaw == null ? null : DateTime.tryParse(lockoutRaw),
    );
  }

  final String userId;
  final String passcodeHashBase64;
  final String saltBase64;
  final int hashVersion;
  final bool biometricEnabled;
  final AppLockTimeout lockTimeout;
  final int failedAttempts;
  final DateTime? lockoutUntil;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'passcodeHashBase64': passcodeHashBase64,
      'saltBase64': saltBase64,
      'hashVersion': hashVersion,
      'biometricEnabled': biometricEnabled,
      'lockTimeout': lockTimeout.name,
      'failedAttempts': failedAttempts,
      'lockoutUntil': lockoutUntil?.toIso8601String(),
    };
  }

  bool isLockedOut(DateTime now) {
    final until = lockoutUntil;
    return until != null && now.isBefore(until);
  }

  AppLockConfig copyWith({
    String? passcodeHashBase64,
    String? saltBase64,
    int? hashVersion,
    bool? biometricEnabled,
    AppLockTimeout? lockTimeout,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockoutUntil = false,
  }) {
    return AppLockConfig(
      userId: userId,
      passcodeHashBase64: passcodeHashBase64 ?? this.passcodeHashBase64,
      saltBase64: saltBase64 ?? this.saltBase64,
      hashVersion: hashVersion ?? this.hashVersion,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockTimeout: lockTimeout ?? this.lockTimeout,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil:
          clearLockoutUntil ? null : lockoutUntil ?? this.lockoutUntil,
    );
  }
}

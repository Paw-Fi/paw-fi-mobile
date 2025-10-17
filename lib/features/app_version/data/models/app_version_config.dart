class AppVersionConfig {
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String? updateMessage;
  final String? iosAppStoreUrl;
  final String? androidPlayStoreUrl;

  AppVersionConfig({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    this.updateMessage,
    this.iosAppStoreUrl,
    this.androidPlayStoreUrl,
  });

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) {
    return AppVersionConfig(
      minVersion: json['min_version'] as String,
      latestVersion: json['latest_version'] as String,
      forceUpdate: json['force_update'] as bool,
      updateMessage: json['update_message'] as String?,
      iosAppStoreUrl: json['ios_app_store_url'] as String?,
      androidPlayStoreUrl: json['android_play_store_url'] as String?,
    );
  }
}

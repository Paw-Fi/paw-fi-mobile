import 'dart:developer' as developer;
import 'dart:io';
import 'package:moneko/core/core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_version_config.dart';

class VersionService {
  /// Get current app version from package info
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Get current build number
  Future<String> getCurrentBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.buildNumber;
  }

  /// Fetch version config from Supabase
  Future<AppVersionConfig?> getVersionConfig() async {
    try {
      // Dynamically detect platform
      final platform = Platform.isIOS ? 'ios' : 'android';
      developer.log('Fetching version config for platform: $platform', name: 'VersionService');
      
      final List<dynamic> response = await supabase
          .from('app_version_config')
          .select()
          .eq('platform', platform)
          .limit(1);

      // Safely parse list payload
      if (response.isEmpty) {
        developer.log('No version config found in database', name: 'VersionService');
        return null;
      }

      final first = response.first as Map<String, dynamic>;
      final config = AppVersionConfig.fromJson(first);
      developer.log(
        'Config loaded: minVersion=${config.minVersion}, forceUpdate=${config.forceUpdate}',
        name: 'VersionService',
      );
      
      return config;
    } catch (e) {
      developer.log('Error fetching version config: $e', name: 'VersionService', error: e);
      return null;
    }
  }

  /// Compare two version strings (e.g., "1.0.0" vs "1.0.1")
  /// Returns:
  ///   -1 if v1 < v2
  ///    0 if v1 == v2
  ///    1 if v1 > v2
  int compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final part1 = i < v1Parts.length ? v1Parts[i] : 0;
      final part2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (part1 < part2) return -1;
      if (part1 > part2) return 1;
    }

    return 0;
  }

  /// Check if update is required
  /// Returns true if current version is less than minimum required version
  Future<bool> isUpdateRequired() async {
    final config = await getVersionConfig();
    if (config == null) return false;
    if (!config.forceUpdate) return false;

    final currentVersion = await getCurrentVersion();
    final comparison = compareVersions(currentVersion, config.minVersion);

    developer.log(
      'Current: $currentVersion, Min Required: ${config.minVersion}, Update Required: ${comparison < 0}',
      name: 'VersionService',
    );

    return comparison < 0; // Current version is older than minimum
  }

  /// Check if newer version is available (optional update)
  Future<bool> isNewerVersionAvailable() async {
    final config = await getVersionConfig();
    if (config == null) return false;

    final currentVersion = await getCurrentVersion();
    final comparison = compareVersions(currentVersion, config.latestVersion);

    return comparison < 0; // Current version is older than latest
  }
}

import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/models/app_version_config.dart';
import '../../data/services/version_service.dart';

// Provider for version service
final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService();
});

// Provider for version config
final versionConfigProvider = FutureProvider<AppVersionConfig?>((ref) async {
  final service = ref.watch(versionServiceProvider);
  return service.getVersionConfig();
});

// Provider to check if update is required
final isUpdateRequiredProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(versionServiceProvider);
  return service.isUpdateRequired();
});

// Provider for current app version
final currentAppVersionProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(versionServiceProvider);
  return service.getCurrentVersion();
});

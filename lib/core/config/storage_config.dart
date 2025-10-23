/// Storage configuration for Supabase
class StorageConfig {
  /// Public storage bucket name for household images
  static const String publicBucket = 'public';

  /// Maximum file size in bytes (5MB)
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Allowed image formats
  static const List<String> allowedImageFormats = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ];

  /// Storage paths
  static const String householdCoversPath = 'household-covers';
  static const String userAvatarsPath = 'user-avatars';

  /// Validates if file extension is allowed
  static bool isAllowedFormat(String filename) {
    final extension = filename.toLowerCase();
    return allowedImageFormats.any((format) => extension.endsWith(format));
  }

  /// Validates if file size is within limits
  static bool isValidFileSize(int fileSizeBytes) {
    return fileSizeBytes <= maxFileSizeBytes;
  }

  /// Gets formatted file size string
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

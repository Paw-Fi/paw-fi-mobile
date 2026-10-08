import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/core/utils/image_compressor.dart';
import '../../core/household_constants.dart';
import 'package:moneko/core/utils/error_handler.dart';

class HouseholdCreationUtils {
  static Future<String> uploadImageWithRetry(
      File imageFile, String userId) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < HouseholdConstants.maxRetryAttempts) {
      try {
        return await _uploadImage(imageFile, userId);
      } catch (e) {
        lastError = e;
        if (!ErrorHandler.isRetryable(e)) rethrow;
        attempts++;
        if (attempts < HouseholdConstants.maxRetryAttempts) {
          await Future.delayed(
            Duration(milliseconds: HouseholdConstants.retryDelayMs * attempts),
          );
        }
      }
    }

    throw lastError ??
        Exception(
            'Upload failed after ${HouseholdConstants.maxRetryAttempts} attempts');
  }

  static Future<String> _uploadImage(File imageFile, String userId) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('File not found at path: ${imageFile.path}');
      }

      // Compress before upload to reduce egress
      final bytes = await ImageCompressor.compressFile(
        imageFile,
        config: ImageCompressConfig.householdCover,
      );

      if (!StorageConfig.isValidFileSize(bytes.length)) {
        throw Exception(
          'File too large (${StorageConfig.getFileSizeString(bytes.length)}). Max is ${StorageConfig.getFileSizeString(StorageConfig.maxFileSizeBytes)}.',
        );
      }

      final originalExtension = imageFile.path.contains('.')
          ? '.${imageFile.path.split('.').last.toLowerCase()}'
          : '';
      if (!StorageConfig.isAllowedFormat(originalExtension)) {
        throw Exception('Unsupported file format: $originalExtension');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      final filePath = '${StorageConfig.householdCoversPath}/$fileName';

      try {
        await Supabase.instance.client.storage
            .from(StorageConfig.publicBucket)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
                cacheControl: '31536000',
              ),
            );

        final publicUrl = Supabase.instance.client.storage
            .from(StorageConfig.publicBucket)
            .getPublicUrl(filePath);

        return publicUrl;
      } catch (storageError) {
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}

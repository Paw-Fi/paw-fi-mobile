import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error handling utility for user-friendly error messages
class ErrorHandler {
  /// Maps technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return 'An unexpected error occurred. Please try again.'; 
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Supabase specific errors
    if (error is AuthException) {
      return _handleAuthException(error);
    }

    if (error is PostgrestException) {
      return _handlePostgrestException(error);
    }

    if (error is StorageException) {
      return _handleStorageException(error);
    }

    // Supabase Edge Function errors
    if (error is FunctionException) {
      // Prefer the structured `{ error: "..." }` payload returned by our Edge
      // Functions, instead of the full `FunctionException(...)` string.
      final details = error.details;
      if (details is Map && details['error'] is String) {
        final message = (details['error'] as String).trim();
        if (message.isNotEmpty) return message;
      }
      if (details is String) {
        final message = details.trim();
        if (message.isNotEmpty) return message;
      }
      // Fall back to a generic permission message for common statuses.
      if (error.status == 401 || error.status == 403) {
        return 'You don\'t have permission to perform this action.';
      }
      return 'Something went wrong. Please try again.';
    }

    // Invitation-specific errors
    if (errorString.contains('expired')) {
      return 'This invitation has expired. Please request a new one.';
    }

    if (errorString.contains('revoked')) {
      return 'This invitation has been revoked.';
    }

    if (errorString.contains('already') && errorString.contains('member')) {
      return 'You are already a member of this household.';
    }

    if (errorString.contains('invalid') && errorString.contains('token')) {
      return 'Invalid invitation link. Please check the link and try again.';
    }

    // HTTP status codes
    if (errorString.contains('400')) {
      return 'Invalid request. Please check your input and try again.';
    }

    if (errorString.contains('401') || errorString.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorString.contains('404')) {
      return 'The requested resource was not found.';
    }

    if (errorString.contains('409')) {
      return 'This action conflicts with existing data.';
    }

    if (errorString.contains('429')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    if (errorString.contains('500') || errorString.contains('503')) {
      return 'Server error. Please try again later.';
    }

    // File upload errors
    if (errorString.contains('file') && errorString.contains('large')) {
      return 'File is too large. Please choose a smaller image (max 5MB).';
    }

    if (errorString.contains('format') || errorString.contains('type')) {
      return 'Unsupported file format. Please use JPG, PNG, or WebP.';
    }

    // Default fallback
    return 'Something went wrong. Please try again.';
  }

  static String _handleAuthException(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return 'Invalid credentials. Please check your information.';
      case '401':
        return 'Authentication failed. Please sign in again.';
      case '422':
        return 'Invalid email or password format.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Authentication error. Please try again.';
    }
  }

  static String _handlePostgrestException(PostgrestException error) {
    if (error.code == '23505') {
      return 'This record already exists.';
    }
    if (error.code == '23503') {
      return 'Cannot perform this action due to related data.';
    }
    if (error.code == 'PGRST116') {
      return 'No data found.';
    }
    return error.message.isNotEmpty
        ? 'Database error: ${error.message}'
        : 'A database error occurred.';
  }

  static String _handleStorageException(StorageException error) {
    if (error.statusCode == '404') {
      return 'File not found.';
    }
    if (error.statusCode == '413') {
      return 'File is too large (max 5MB).';
    }
    return error.message.isNotEmpty
        ? error.message
        : 'Storage error occurred.';
  }

  /// Extracts error code from error object if available
  static String? getErrorCode(dynamic error) {
    if (error is PostgrestException) {
      return error.code;
    }
    if (error is StorageException) {
      return error.statusCode;
    }
    if (error is AuthException) {
      return error.statusCode;
    }
    return null;
  }

  /// Checks if error is retryable
  static bool isRetryable(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('503') ||
        errorString.contains('500');
  }
}

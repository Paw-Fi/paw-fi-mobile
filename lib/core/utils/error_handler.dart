import 'package:supabase_flutter/supabase_flutter.dart';

enum BackendErrorContext {
  generic,
  analyzeExpense,
  updateExpense,
  deleteExpense,
  saveRecurring,
  recording,
}

class _NormalizedBackendError {
  final String? code;
  final int? status;
  final String? message;

  const _NormalizedBackendError({
    this.code,
    this.status,
    this.message,
  });
}

/// Centralized error handling utility for user-friendly error messages
class ErrorHandler {
  /// Maps technical errors to user-friendly messages
  static String getUserFriendlyMessage(
    dynamic error, {
    BackendErrorContext context = BackendErrorContext.generic,
  }) {
    if (error == null) {
      return 'An unexpected error occurred. Please try again.';
    }

    final normalized = _normalizeBackendError(error);
    final mappedBackend = _mapBackendError(normalized, context);
    if (mappedBackend != null) {
      return mappedBackend;
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

  static _NormalizedBackendError _normalizeBackendError(dynamic error) {
    String? code;
    int? status;
    String? message;

    if (error is FunctionException) {
      status = error.status;
      final details = error.details;
      if (details is Map) {
        code = (details['errorCode'] ?? details['code'])?.toString();
        final statusValue = details['status'];
        if (statusValue is int) {
          status = statusValue;
        }
        final rawMessage = details['error'] ?? details['message'];
        if (rawMessage is String && rawMessage.trim().isNotEmpty) {
          message = rawMessage.trim();
        }
      } else if (details is String && details.trim().isNotEmpty) {
        message = details.trim();
      }
    }

    if (error is Map) {
      code ??= (error['errorCode'] ?? error['code'])?.toString();
      final statusValue = error['status'];
      if (statusValue is int) {
        status ??= statusValue;
      }
      final rawMessage = error['error'] ?? error['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        message ??= rawMessage.trim();
      }
    }

    final raw = error.toString();
    if (error is String && error.trim().isNotEmpty) {
      message ??= error.trim();
    }

    if ((message == null || message.isEmpty) &&
        raw.contains('details:') &&
        raw.contains('{')) {
      final detailsMatch = RegExp(r'details:\s*\{([^}]+)\}').firstMatch(raw);
      final detailsText = detailsMatch?.group(1);
      if (detailsText != null) {
        final codeMatch = RegExp(r'code:\s*([^,}]+)').firstMatch(detailsText);
        final messageMatch =
            RegExp(r'error:\s*([^,}]+)').firstMatch(detailsText);
        if (codeMatch != null && code == null) {
          code = codeMatch.group(1)?.trim();
        }
        if (messageMatch != null && (message == null || message.isEmpty)) {
          final extracted = messageMatch.group(1)?.replaceAll("'", '').trim();
          if (extracted != null && extracted.isNotEmpty) {
            message = extracted;
          }
        }
      }
    }

    if (status == null) {
      final statusMatch = RegExp(r'status:\s*(\d{3})').firstMatch(raw);
      final statusText = statusMatch?.group(1);
      if (statusText != null) {
        status = int.tryParse(statusText);
      }
    }

    return _NormalizedBackendError(
      code: code?.toUpperCase(),
      status: status,
      message: message,
    );
  }

  static String? _mapBackendError(
    _NormalizedBackendError error,
    BackendErrorContext context,
  ) {
    final message = error.message?.toLowerCase() ?? '';
    final code = error.code ?? '';

    if (message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('bad gateway') ||
        message.contains('gateway timeout')) {
      if (context == BackendErrorContext.analyzeExpense) {
        return 'This took too long. Try a smaller file.';
      }
      return 'Request timed out. Please try again.';
    }

    if (context == BackendErrorContext.recording) {
      return 'Could not process recording. Please try again.';
    }

    if (code == 'UNAUTHORIZED' || error.status == 401 || error.status == 403) {
      return 'You don\'t have permission to do that.';
    }

    if (code == 'PLAID_ITEM_CONTROL_FAILED' ||
        message.contains('failed to execute plaid item action')) {
      return 'Could not update this bank connection right now. Please try again in a moment.';
    }

    if (code == 'PGRST202' ||
        message.contains('schema cache') ||
        message.contains('could not find the function')) {
      return 'This feature is temporarily unavailable. Please try again later.';
    }

    if (code == 'NOT_FOUND' || error.status == 404) {
      if (context == BackendErrorContext.deleteExpense ||
          context == BackendErrorContext.updateExpense) {
        return 'This transaction is no longer available.';
      }
      return 'That item was not found.';
    }

    if (code == 'VALIDATION_ERROR' || error.status == 400) {
      if (message.contains('amount_cents must be less than') ||
          message.contains('amount must be less than')) {
        return 'Amount is too large. Please enter a smaller value.';
      }
      if (context == BackendErrorContext.generic &&
          message.isNotEmpty &&
          _isSafeUserMessage(message)) {
        return _capitalizeFirst(message);
      }
      if (context == BackendErrorContext.saveRecurring) {
        return 'Please check the recurring details and try again.';
      }
      if (context == BackendErrorContext.updateExpense) {
        return 'Please check your changes and try again.';
      }
      if (context == BackendErrorContext.analyzeExpense) {
        return 'Could not analyze this input. Please try again.';
      }
      return 'Please check your input and try again.';
    }

    if (error.status == 409 || code == 'CONFLICT') {
      return 'This item changed recently. Please refresh and try again.';
    }

    if (error.status == 429 || code == 'RATE_LIMIT') {
      return 'Too many requests. Please try again in a moment.';
    }

    if (error.status != null && error.status! >= 500 ||
        code == 'SERVER_ERROR') {
      if (message.isNotEmpty && _isSafeUserMessage(message)) {
        return _capitalizeFirst(message);
      }
      return 'Something went wrong on our side. Please try again.';
    }

    if (message.isNotEmpty && _isSafeUserMessage(message)) {
      return _capitalizeFirst(message);
    }

    return null;
  }

  static bool _isSafeUserMessage(String message) {
    final lowered = message.toLowerCase();
    if (lowered.contains('functionexception') ||
        lowered.contains('stack') ||
        lowered.contains('status:') ||
        lowered.contains('details:') ||
        lowered.contains('failed to execute')) {
      return false;
    }
    return !lowered.contains('{') && !lowered.contains('}');
  }

  static String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
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
    return error.message.isNotEmpty ? error.message : 'Storage error occurred.';
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

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';

part 'impersonation_service.g.dart';

/// Service for admin impersonation functionality
/// Allows admins (is_creator = true) to view data from another user's perspective
/// without actually logging in as that user
class ImpersonationService {
  String? _impersonatedUserEmail;
  bool _isCreator = false;

  /// Whether the current user is in impersonation mode
  bool get isImpersonating => _impersonatedUserEmail != null;

  /// The email of the user being impersonated
  String? get impersonatedEmail => _impersonatedUserEmail;

  /// Whether the current user is a creator (admin)
  bool get isCreator => _isCreator;

  /// Initialize the service by checking if the current user is a creator
  Future<void> initialize(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('is_creator')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _isCreator = response['is_creator'] as bool? ?? false;
      }
    } catch (error, stackTrace) {
      appLog(
        'Failed to check creator status',
        name: 'ImpersonationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Start impersonating a user by their email
  /// Only allowed for creators (admins)
  Future<bool> startImpersonation(String email) async {
    if (!_isCreator) {
      appLog(
        'Impersonation denied: user is not a creator',
        name: 'ImpersonationService',
      );
      return false;
    }

    try {
      // Verify the target user exists
      final response = await supabase
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        appLog(
          'Impersonation failed: user with email $email not found',
          name: 'ImpersonationService',
        );
        return false;
      }

      _impersonatedUserEmail = email;
      appLog(
        'Started impersonating user: $email',
        name: 'ImpersonationService',
      );
      return true;
    } catch (error, stackTrace) {
      appLog(
        'Failed to start impersonation',
        name: 'ImpersonationService',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Stop impersonating and return to normal view
  void stopImpersonation() {
    if (_impersonatedUserEmail != null) {
      appLog(
        'Stopped impersonating user: $_impersonatedUserEmail',
        name: 'ImpersonationService',
      );
      _impersonatedUserEmail = null;
    }
  }

  /// Get the effective user email for data queries
  /// Returns impersonated email if in impersonation mode, otherwise the current user's email
  String getEffectiveUserEmail(String currentUserEmail) {
    return _impersonatedUserEmail ?? currentUserEmail;
  }

  /// Get the effective user ID for data queries
  /// Returns impersonated user's ID if in impersonation mode, otherwise the current user's ID
  Future<String?> getEffectiveUserId(String currentUserId) async {
    if (_impersonatedUserEmail == null) {
      return currentUserId;
    }

    try {
      final response = await supabase
          .from('users')
          .select('id')
          .eq('email', _impersonatedUserEmail!)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (error, stackTrace) {
      appLog(
        'Failed to get impersonated user ID',
        name: 'ImpersonationService',
        error: error,
        stackTrace: stackTrace,
      );
      return currentUserId;
    }
  }
}

/// Riverpod provider for impersonation service
@Riverpod(keepAlive: true)
class Impersonation extends _$Impersonation {
  final _service = ImpersonationService();

  @override
  ImpersonationService build() {
    return _service;
  }

  /// Initialize the service with the current user
  Future<void> initialize(String userId) async {
    await _service.initialize(userId);
    ref.notifyListeners();
  }

  /// Start impersonating a user
  Future<bool> startImpersonation(String email) async {
    final result = await _service.startImpersonation(email);
    if (result) {
      ref.notifyListeners();
    }
    return result;
  }

  /// Stop impersonating
  void stopImpersonation() {
    _service.stopImpersonation();
    ref.notifyListeners();
  }

  /// Check if currently impersonating
  bool get isImpersonating => _service.isImpersonating;

  /// Get impersonated email
  String? get impersonatedEmail => _service.impersonatedEmail;

  /// Check if current user is a creator
  bool get isCreator => _service.isCreator;

  /// Get effective user email for queries
  String getEffectiveUserEmail(String currentUserEmail) {
    return _service.getEffectiveUserEmail(currentUserEmail);
  }

  /// Get effective user ID for queries
  Future<String?> getEffectiveUserId(String currentUserId) {
    return _service.getEffectiveUserId(currentUserId);
  }
}

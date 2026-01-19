import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

part 'whatsapp_binding_provider.g.dart';

/// Provider to check if user has bound their WhatsApp account
/// Keep alive to cache the binding status across navigation
@Riverpod(keepAlive: true)
class WhatsAppBinding extends _$WhatsAppBinding {
  @override
  Future<bool> build() async {
    return await checkBinding();
  }

  /// Check if user has bound WhatsApp by querying user_contacts table
  Future<bool> checkBinding() async {
    try {
      final user = ref.read(authProvider);
      if (user.isEmpty) return false;

      final List<dynamic> response = await supabase
          .from('user_contacts')
          .select('id')
          .eq('user_id', user.uid)
          .order('id', ascending: false)
          .limit(1);

      return response.isNotEmpty;
    } catch (error) {
      debugPrint('Error checking WhatsApp binding: $error');
      return false;
    }
  }

  /// Refresh binding status
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => checkBinding());
  }

  /// Mark as verified without fetching from database
  /// Use this after successful verification to update UI immediately
  void setVerified() {
    state = const AsyncValue.data(true);
  }

  /// Get WhatsApp contact details if bound
  Future<Map<String, dynamic>?> getContactDetails() async {
    try {
      final user = ref.read(authProvider);
      if (user.isEmpty) return null;

      final List<dynamic> response = await supabase
          .from('user_contacts')
          .select()
          .eq('user_id', user.uid)
          .order('id', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(
            response.first as Map<String, dynamic>);
      }
      return null;
    } catch (error) {
      debugPrint('Error fetching WhatsApp contact: $error');
      return null;
    }
  }

  /// Clear cached state (useful on logout)
  void clear() {
    state = const AsyncValue.data(false);
  }
}

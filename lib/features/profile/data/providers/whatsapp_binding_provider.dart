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

      final response = await supabase
          .from('user_contacts')
          .select('id')
          .eq('user_id', user.uid)
          .maybeSingle();

      return response != null;
    } catch (error) {
      print('Error checking WhatsApp binding: $error');
      return false;
    }
  }

  /// Refresh binding status
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => checkBinding());
  }

  /// Get WhatsApp contact details if bound
  Future<Map<String, dynamic>?> getContactDetails() async {
    try {
      final user = ref.read(authProvider);
      if (user.isEmpty) return null;

      final response = await supabase
          .from('user_contacts')
          .select()
          .eq('user_id', user.uid)
          .maybeSingle();

      return response;
    } catch (error) {
      print('Error fetching WhatsApp contact: $error');
      return null;
    }
  }
  
  /// Clear cached state (useful on logout)
  void clear() {
    state = const AsyncValue.data(false);
  }
}

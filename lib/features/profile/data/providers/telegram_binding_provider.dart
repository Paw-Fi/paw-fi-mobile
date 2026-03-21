import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

/// Provider to check if user has bound their Telegram account
/// Keep alive to cache the binding status across navigation
final telegramBindingProvider =
    AsyncNotifierProvider<TelegramBinding, bool>(TelegramBinding.new);

class TelegramBinding extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => checkBinding();

  /// Check if user has bound Telegram by querying user_contacts table
  Future<bool> checkBinding() async {
    try {
      final user = ref.read(authProvider);
      if (user.isEmpty) return false;

      final List<dynamic> response = await supabase
          .from('user_contacts')
          .select('telegram_chat_id')
          .eq('user_id', user.uid)
          .order('id', ascending: false)
          .limit(1);

      if (response.isEmpty) return false;
      final row = response.first as Map<String, dynamic>;
      final chatId = row['telegram_chat_id'] as String?;
      return chatId != null && chatId.isNotEmpty;
    } catch (error) {
      debugPrint('Error checking Telegram binding: $error');
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

  /// Clear cached state (useful on logout)
  void clear() {
    state = const AsyncValue.data(false);
  }
}

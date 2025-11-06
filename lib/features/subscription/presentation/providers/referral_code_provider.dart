import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';

part 'referral_code_provider.g.dart';

@riverpod
class ReferralCodeChecker extends _$ReferralCodeChecker {
  @override
  Future<bool> build() async {
    final user = ref.watch(authProvider);
    if (user.isEmpty) return false;

    return _checkReferralCode(user.uid);
  }

  Future<bool> _checkReferralCode(String userId) async {
    try {
      appLog('Checking if user has referral code: $userId', name: 'ReferralCodeProvider');

      final response = await supabase
          .from('referral_codes')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      final responseList = response as List;
      final hasReferralCode = responseList.isNotEmpty;

      appLog('User has referral code: $hasReferralCode', name: 'ReferralCodeProvider');
      return hasReferralCode;
    } catch (e, stack) {
      appLog('Error checking referral code', name: 'ReferralCodeProvider', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authProvider);
      if (user.isEmpty) return false;
      return _checkReferralCode(user.uid);
    });
  }
}

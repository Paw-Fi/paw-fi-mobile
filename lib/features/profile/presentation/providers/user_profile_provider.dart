import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'user_profile_provider.g.dart';

class UserProfile {
  final String? fullName;
  final String? avatarUrl;

  UserProfile({
    this.fullName,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

@riverpod
Future<UserProfile?> userProfile(UserProfileRef ref, String userId) async {
  final client = Supabase.instance.client;
  
  final data = await client
      .from('users')
      .select('full_name, avatar_url')
      .eq('id', userId)
      .maybeSingle();

  if (data == null) return null;
  
  return UserProfile.fromJson(data);
}

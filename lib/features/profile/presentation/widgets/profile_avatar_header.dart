import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildProfileAvatarHeader(BuildContext context, WidgetRef ref, user) {
  final colorScheme = Theme.of(context).colorScheme;
  final profileAsync = ref.watch(userProfileProvider(user.uid));

  return profileAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stack) => Center(child: Text(context.l10n.errorLoadingProfile)),
    data: (profile) {
      final dbName = profile?.fullName;
      final dbAvatarUrl = profile?.avatarUrl;

      final displayName = (dbName?.trim().isNotEmpty == true)
          ? dbName!.trim()
          : (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : context.l10n.user);

      final initials = displayName.isNotEmpty
          ? displayName.substring(0, 1).toUpperCase()
          : (user.email.isNotEmpty ? user.email.substring(0, 1).toUpperCase() : 'U');

      final avatarUrl = (dbAvatarUrl != null && dbAvatarUrl.isNotEmpty)
          ? dbAvatarUrl
          : (user.photoUrl != null && user.photoUrl!.isNotEmpty ? user.photoUrl : null);

      return Column(
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarUrl != null
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.card,
              ),
              clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () => context.push('/avatar'),
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _InitialsFallback(initials),
                  )
                : _InitialsFallback(initials),
          ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.mutedForeground,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.monekoPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.proBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _InitialsFallback extends StatelessWidget {
  final String initials;
  const _InitialsFallback(this.initials);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7458FF), Color(0xFF836DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

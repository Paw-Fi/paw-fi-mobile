import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/navigation/custom_drawer.dart';
import 'package:moneko/core/navigation/zoom_drawer_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

/// Leading widget for app bar that includes:
/// - Profile/Household avatar
/// - Personal/Household name
class HomeHeaderLeading extends ConsumerWidget {
  const HomeHeaderLeading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final AppDrawerController zoomController =
        ref.read(zoomDrawerControllerProvider);

    return GestureDetector(
      onTap: () => zoomController.toggle?.call(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderAvatarButton(
            user: user,
            viewMode: viewMode,
            householdsAsync: householdsAsync,
            selectedHouseholdState: selectedHouseholdState,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 12),
          Text(
            viewMode.mode == ViewMode.personal
                ? (user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : user.email)
                : householdsAsync.when(
                    loading: () => context.l10n.forUs,
                    error: (_, __) => context.l10n.forUs,
                    data: (households) {
                      if (households.isEmpty) return context.l10n.forUs;

                      // Use selected household if available, otherwise first household
                      final household =
                          selectedHouseholdState.household ?? households.first;
                      return household.name;
                    },
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: colorScheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing widget for app bar that includes:
/// - Personal/Household mode switch
class HomeHeaderTrailing extends ConsumerWidget {
  const HomeHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);

    return _AccountTypeSwitch(
      viewMode: viewMode,
      colorScheme: colorScheme,
      onPersonalSelected: () => _setPersonalMode(ref),
      onHouseholdSelected: () => _switchToHouseholdMode(context, ref),
    );
  }

  static void _setPersonalMode(WidgetRef ref) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    ref.read(viewModeProvider.notifier).setPersonalMode();
  }

  static void _switchToHouseholdMode(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    // Switch to household mode and invalidate households so data is refreshed.
    final user = ref.read(authProvider);
    debugPrint(
        '🔄 Switching to household mode - invalidating userHouseholdsProvider');
    ref.invalidate(userHouseholdsProvider(user.uid));
    ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
  }
}

/// Header for pages that includes:
/// - Profile/Household cover photo
/// - Personal/Household switch
///
class HomeHeaderSliver extends ConsumerWidget {
  const HomeHeaderSliver({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final AppDrawerController zoomController =
        ref.read(zoomDrawerControllerProvider);

    return SizedBox(
      height: 65,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 5, 16, 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ListTile(
                onTap: () => zoomController.toggle?.call(),
                leading: _HeaderAvatarButton(
                  user: user,
                  viewMode: viewMode,
                  householdsAsync: householdsAsync,
                  selectedHouseholdState: selectedHouseholdState,
                  colorScheme: colorScheme,
                ),
                title: Text(
                  viewMode.mode == ViewMode.personal
                      ? (user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : user.email)
                      : householdsAsync.when(
                          loading: () => context.l10n.forUs,
                          error: (_, __) => context.l10n.forUs,
                          data: (households) {
                            if (households.isEmpty) return context.l10n.forUs;

                            // Use selected household if available, otherwise first household
                            final household =
                                selectedHouseholdState.household ??
                                    households.first;
                            return household.name;
                          },
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ),
            const HomeHeaderTrailing(),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatarButton extends StatelessWidget {
  const _HeaderAvatarButton({
    required this.user,
    required this.viewMode,
    required this.householdsAsync,
    required this.selectedHouseholdState,
    required this.colorScheme,
  });

  final AppUser user;
  final ViewModeState viewMode;
  final AsyncValue<List<Household>> householdsAsync;
  final SelectedHouseholdState selectedHouseholdState;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 44,
      child: ClipOval(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (viewMode.mode == ViewMode.personal) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('users')
            .select('avatar_url')
            .eq('id', user.uid)
            .maybeSingle(),
        builder: (context, snapshot) {
          final dbAvatarUrl = snapshot.data != null
              ? snapshot.data!['avatar_url'] as String?
              : null;

          String? validatedAvatarUrl;
          if (dbAvatarUrl != null &&
              dbAvatarUrl.isNotEmpty &&
              dbAvatarUrl != 'SKIPPED' &&
              (dbAvatarUrl.startsWith('http://') ||
                  dbAvatarUrl.startsWith('https://'))) {
            validatedAvatarUrl = dbAvatarUrl;
          }

          final avatarUrl = validatedAvatarUrl ??
              (user.photoUrl != null && user.photoUrl!.isNotEmpty
                  ? user.photoUrl
                  : null);

          if (avatarUrl != null) {
            return Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _fallbackPersonalAvatar(),
            );
          }

          return _fallbackPersonalAvatar();
        },
      );
    }

    return householdsAsync.when(
      loading: () => _placeholder(),
      error: (_, __) => _placeholder(),
      data: (households) {
        if (households.isEmpty) {
          return _placeholder();
        }

        final household = selectedHouseholdState.household ?? households.first;
        if (household.coverImageUrl != null) {
          return Image.network(
            household.coverImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _fallbackHouseholdAvatar(),
          );
        }
        return _fallbackHouseholdAvatar();
      },
    );
  }

  Widget _fallbackPersonalAvatar() {
    return Container(
      color: colorScheme.muted.withValues(alpha: 0.5),
      child: Icon(
        Icons.person_rounded,
        color: colorScheme.mutedForeground.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _fallbackHouseholdAvatar() {
    return Container(
      color: colorScheme.muted.withValues(alpha: 0.5),
      child: Icon(
        Icons.home_rounded,
        color: colorScheme.mutedForeground.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: colorScheme.muted.withValues(alpha: 0.3),
    );
  }
}

class _AccountTypeSwitch extends StatelessWidget {
  const _AccountTypeSwitch({
    required this.viewMode,
    required this.colorScheme,
    required this.onPersonalSelected,
    required this.onHouseholdSelected,
  });

  final ViewModeState viewMode;
  final ColorScheme colorScheme;
  final VoidCallback onPersonalSelected;
  final VoidCallback onHouseholdSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Personal
          GestureDetector(
            onTap:
                viewMode.mode == ViewMode.personal ? null : onPersonalSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: viewMode.mode == ViewMode.personal
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.l10n.forMe,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: viewMode.mode == ViewMode.personal
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: viewMode.mode == ViewMode.personal
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
          // Household
          GestureDetector(
            onTap: viewMode.mode == ViewMode.household
                ? null
                : onHouseholdSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: viewMode.mode == ViewMode.household
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.l10n.forUs,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: viewMode.mode == ViewMode.household
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: viewMode.mode == ViewMode.household
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

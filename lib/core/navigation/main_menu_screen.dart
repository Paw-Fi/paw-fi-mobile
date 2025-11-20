import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/currency_dropdown_button.dart';
import 'package:moneko/features/home/presentation/widgets/date_range_filter_modal.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Zoom drawer content focused on budgeting context:
/// - Currency selector
/// - Household selection (when in household mode)
/// - User profile row with settings gear
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.card,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _CurrencySection(colorScheme: colorScheme),
            const SizedBox(height: 16),
            _DateRangeSection(colorScheme: colorScheme),
            const SizedBox(height: 24),
            if (viewMode.mode == ViewMode.household)
              _HouseholdSection(colorScheme: colorScheme),
            const Spacer(),
            _ProfileRow(user: user, colorScheme: colorScheme),
            if (PlatformInfo.isIOS26OrHigher()) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _DateRangeSection extends ConsumerWidget {
  const _DateRangeSection({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(homeFilterProvider);
    final DateRangeFilter currentFilter = filterState.dateRangeFilter;
    final String label = currentFilter.getLabel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.selectDateRange,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            showDateRangeFilter(context, colorScheme);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencySection extends ConsumerWidget {
  const _CurrencySection({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.currency,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 18,
                color: colorScheme.mutedForeground,
              ),
              const SizedBox(width: 10),
              const CurrencyDropdownButton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HouseholdSection extends ConsumerWidget {
  const _HouseholdSection({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final selectedState = ref.watch(selectedHouseholdProvider);

    return householdsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (households) {
        if (households.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.household,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: households.length,
                itemBuilder: (context, index) {
                  final household = households[index];
                  final bool isSelected = selectedState.householdId != null &&
                      selectedState.householdId == household.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        // Preserve selection behavior by delegating to the same notifier
                        final user = ref.read(authProvider);
                        await ref
                            .read(selectedHouseholdProvider.notifier)
                            .selectHousehold(household.id, user.uid);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer.withOpacity(0.4)
                              : colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: household.coverImageUrl != null
                                    ? Image.network(
                                        household.coverImageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: colorScheme.muted
                                            .withValues(alpha: 0.5),
                                        child: Icon(
                                          Icons.home_rounded,
                                          size: 22,
                                          color: colorScheme.mutedForeground
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                household.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                              ),
                            ),
                            if (isSelected)
                              IconButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => HouseholdSettingsPage(
                                        householdId: household.id,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.user,
    required this.colorScheme,
  });

  final AppUser user;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return AdaptiveListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: FutureBuilder<Map<String, dynamic>?>(
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

            return Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.muted.withValues(alpha: 0.5),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_rounded,
                            color: colorScheme.mutedForeground
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.muted.withValues(alpha: 0.5),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.person_rounded,
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.8),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
      title: Text(
        user.displayName?.isNotEmpty == true ? user.displayName! : user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.foreground,
        ),
      ),
      subtitle: Text(
        user.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.mutedForeground,
        ),
      ),
      trailing: IconButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SettingsPage(),
            ),
          );
        },
        icon: Icon(
          Icons.settings_outlined,
          size: 20,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

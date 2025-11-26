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
import 'package:moneko/features/households/presentation/pages/household_create_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/plaid/plaid_link_service.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';

import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Zoom drawer content focused on budgeting context:
/// - Currency selector
/// - Household selection (when in household mode)
/// - User profile row with settings gear
final plaidCountryCodeProvider = StateProvider<String>((ref) => 'US');

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(user: user, colorScheme: colorScheme),
              const SizedBox(height: 40),
              _SettingsList(colorScheme: colorScheme),
              if (viewMode.mode == ViewMode.household) ...[
                const SizedBox(height: 40),
                Expanded(child: _HouseholdSection(colorScheme: colorScheme)),
              ] else
                const Spacer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(homeFilterProvider);
    final DateRangeFilter currentFilter = filterState.dateRangeFilter;
    final String dateLabel = currentFilter.getLabel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: context.l10n.currency, colorScheme: colorScheme),
        const SizedBox(height: 12),
        CurrencyDropdownButton(
          onAfterSelect: () {
            final user = ref.read(authProvider);
            if (user.uid.isEmpty) return;
            ref.read(analyticsProvider.notifier).refresh(user.uid);

            final viewMode = ref.read(viewModeProvider);
            final selectedHousehold = ref.read(selectedHouseholdProvider);
            final householdId = viewMode.mode == ViewMode.household
                ? selectedHousehold.householdId
                : null;

            ref
                .read(recurringTransactionsProvider(householdId).notifier)
                .refresh(user.uid);
            ref.invalidate(pocketsProvider);
          },
        ),
        const SizedBox(height: 32),
        _SectionLabel(
            label: context.l10n.selectDateRange, colorScheme: colorScheme),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => showDateRangeFilter(context, colorScheme),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colorScheme.mutedForeground,
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _SectionLabel(
          label: context.l10n.autoSync,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),
        _PlaidCountrySelector(colorScheme: colorScheme),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlaidSyncWalkthroughPage(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.foreground,
              side: BorderSide(
                  color: colorScheme.mutedForeground.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: Icon(
              Icons.sync,
              size: 18,
              color: colorScheme.mutedForeground,
            ),
            label: Text(
              context.l10n.autoSync,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.colorScheme,
  });

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.mutedForeground,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _HouseholdSection extends ConsumerWidget {
  const _HouseholdSection({required this.colorScheme});

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
        if (households.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.household,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                    letterSpacing: 0.5,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HouseholdCreatePage(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.add,
                      size: 26,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: households.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final household = households[index];
                  final isSelected = selectedState.householdId == household.id;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.selectedStateBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final user = ref.read(authProvider);
                        await ref
                            .read(selectedHouseholdProvider.notifier)
                            .selectHousehold(household.id, user.uid);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: colorScheme.surfaceContainerHighest,
                                image: household.coverImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            household.coverImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: household.coverImageUrl == null
                                  ? Icon(
                                      Icons.home_rounded,
                                      size: 24,
                                      color: colorScheme.mutedForeground,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    household.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: colorScheme.foreground,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.colorScheme,
  });

  final AppUser user;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('users')
                .select('avatar_url')
                .eq('id', user.uid)
                .maybeSingle(),
            builder: (context, snapshot) {
              final dbAvatarUrl = snapshot.data?['avatar_url'] as String?;
              final avatarUrl = dbAvatarUrl ?? user.photoUrl;

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest,
                  image: avatarUrl != null &&
                          avatarUrl.isNotEmpty &&
                          avatarUrl != 'SKIPPED'
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null ||
                        avatarUrl.isEmpty ||
                        avatarUrl == 'SKIPPED'
                    ? Icon(
                        Icons.person_rounded,
                        size: 28,
                        color: colorScheme.mutedForeground,
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : 'User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsPage(),
              ),
            );
          },
          icon: Icon(
            Icons.settings_outlined,
            size: 24,
            color: colorScheme.foreground,
          ),
        ),
      ],
    );
  }
}

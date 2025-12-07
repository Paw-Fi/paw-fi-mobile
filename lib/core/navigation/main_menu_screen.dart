import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/currency_dropdown_button.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/households/presentation/pages/household_create_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Zoom drawer content focused on budgeting context:
/// - Currency selector
/// - Household selection (when in household mode)
/// - User profile row with settings gear
final plaidCountryCodeProvider = StateProvider<String>((ref) => 'US');

/// Latest Plaid sync time for the current user (null = never synced).
final plaidLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final user = ref.watch(authProvider);
  if (user.uid.isEmpty) return null;

  final client = Supabase.instance.client;
  final response = await client
      .from('bank_connections')
      .select('last_synced_at')
      .eq('user_id', user.uid)
      .order('last_synced_at', ascending: false)
      .limit(5);

  final rows = response as List<dynamic>?;
  if (rows == null || rows.isEmpty) return null;

  for (final row in rows) {
    final raw = (row as Map<String, dynamic>)['last_synced_at'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw)?.toLocal();
      if (parsed != null) return parsed;
    }
  }
  return null;
});

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
        //const SizedBox(height: 32),
        // _SectionLabel(
        //   label: context.l10n.autoSync,
        //   colorScheme: colorScheme,
        // ),
        // const SizedBox(height: 12),
        // _PlaidSyncCard(colorScheme: colorScheme),
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

class _PlaidSyncCard extends ConsumerWidget {
  const _PlaidSyncCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSyncAsync = ref.watch(plaidLastSyncProvider);

    return lastSyncAsync.when(
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => _SyncButton(colorScheme: colorScheme),
      data: (lastSync) {
        if (lastSync == null) {
          return _SyncBanner(colorScheme: colorScheme);
        }
        final formatted = DateFormat('MMM d, h:mm a').format(lastSync);
        return _SyncedCard(
          colorScheme: colorScheme,
          subtitle: 'Last sync: $formatted',
        );
      },
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automate your tracking',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connect your bank to automatically import transactions and keep your budget up to date.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _SyncButton(colorScheme: colorScheme),
          ),
        ],
      ),
    );
  }
}

class _SyncedCard extends StatelessWidget {
  const _SyncedCard({required this.colorScheme, required this.subtitle});

  final ColorScheme colorScheme;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Sync Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _SyncButton(colorScheme: colorScheme, compact: true),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.colorScheme, this.compact = false});

  final ColorScheme colorScheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaidSyncWalkthroughPage(),
            ),
          );
        },
        icon: Icon(Icons.sync_rounded, color: colorScheme.primary),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(8),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlaidSyncWalkthroughPage(),
          ),
        );
      },
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(Icons.link_rounded, size: 20),
      label: const Text(
        'Connect Bank',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
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

        if (!selectedState.isLoading && selectedState.householdId == null) {
          if (user.uid.isNotEmpty) {
            ref
                .read(selectedHouseholdProvider.notifier)
                .initialize(user.uid);
          }
        }

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

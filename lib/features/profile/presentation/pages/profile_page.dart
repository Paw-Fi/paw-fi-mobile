import 'package:flutter/material.dart' hide IconButton, Card, Divider, Switch, Chip;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:rsupa/features/auth/presentation/states/auth.dart';
import 'package:rsupa/core/theme/app_theme.dart';

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final selectedTab = useState(0);
    final theme = shadcnui.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: shadcnui.SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _buildHeader(context, ref),
                const shadcnui.Gap(40),
                _buildProfileHeader(context, user),
                const shadcnui.Gap(32),
                _buildNavigationTabs(context, selectedTab),
                const shadcnui.Gap(32),
                _buildTabContent(context, selectedTab.value, user, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Header with settings action
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Profile',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
          ),
        ),
        shadcnui.IconButton(
          variance: shadcnui.ButtonVariance.ghost,
          icon: Icon(Icons.settings_outlined, color: colorScheme.mutedForeground),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  // Profile header with avatar and bio
  Widget _buildProfileHeader(BuildContext context, user) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Column(
      children: [
        shadcnui.Avatar(
          initials: user.displayName?.substring(0, 2).toUpperCase() ??
                    user.email.substring(0, 2).toUpperCase(),
          size: 96,
          backgroundColor: colorScheme.primary,
        ),
        const shadcnui.Gap(20),
        Text(
          user.displayName ?? 'User',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
            letterSpacing: -0.3,
          ),
        ),
        const shadcnui.Gap(8),
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
            const shadcnui.Gap(8),
            const shadcnui.PrimaryBadge(
              child: Text(
                'PRO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }


  // Navigation tabs
  Widget _buildNavigationTabs(BuildContext context, ValueNotifier<int> selectedTab) {
    return Row(
      children: [
        Expanded(child: _buildTab(context, 'Overview', 0, selectedTab)),
        const shadcnui.Gap(12),
        Expanded(child: _buildTab(context, 'Activity', 1, selectedTab)),
      ],
    );
  }

  Widget _buildTab(BuildContext context, String label, int index, ValueNotifier<int> selectedTab) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isSelected = selectedTab.value == index;
    return GestureDetector(
      onTap: () => selectedTab.value = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colorScheme.border : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.foreground : colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }

  // Tab content switcher
  Widget _buildTabContent(BuildContext context, int selectedTab, user, WidgetRef ref) {
    switch (selectedTab) {
      case 0:
        return _buildOverviewTab(context, user, ref);
      case 1:
        return _buildActivityTab(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // Overview tab
  Widget _buildOverviewTab(BuildContext context, user, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Account Information'),
        const shadcnui.Gap(16),
        _buildInfoCard(context, user),
        const shadcnui.Gap(32),
        _buildActionButtons(ref),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.foreground,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, user) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow(context, 'User ID', user.uid.substring(0, 16) + '...'),
          const shadcnui.Gap(20),
          _buildInfoRow(context, 'Email', user.email),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Widget? trailing}) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing ?? Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  // Activity tab - removed mock data, will be populated with real activity later
  Widget _buildActivityTab(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Recent Activity'),
        const shadcnui.Gap(16),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No activity yet',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildActionButtons(WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: shadcnui.DestructiveButton(
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            child: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }
}

// Settings Page
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDarkMode = currentTheme == shadcnui.ThemeMode.dark;
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: shadcnui.IconButton(
          variance: shadcnui.ButtonVariance.ghost,
          icon: Icon(Icons.arrow_back, color: colorScheme.foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const shadcnui.Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  shadcnui.Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).state =
                        value ? shadcnui.ThemeMode.dark : shadcnui.ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

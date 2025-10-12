import 'package:flutter/material.dart' hide IconButton, Card, Divider, Switch, Chip;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:rsupa/features/auth/presentation/states/auth.dart';
import 'package:rsupa/core/theme/app_theme.dart';
import 'package:rsupa/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:rsupa/features/profile/presentation/widgets/whatsapp_tutorial_modal.dart';

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
                _buildWhatsAppBindingCard(context, ref),
                const shadcnui.Gap(24),
                _buildActionButtons(ref)
                // _buildNavigationTabs(context, selectedTab),
                // const shadcnui.Gap(32),
                // _buildTabContent(context, selectedTab.value, user, ref),
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
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  (user.displayName?.substring(0, 2).toUpperCase() ?? user.email.substring(0, 2).toUpperCase()),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryForeground,
                  ),
                ),
              ),
              if (user.photoUrl != null)
                ClipOval(
                  child: Image.network(
                    user.photoUrl!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
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


  // WhatsApp binding card
  Widget _buildWhatsAppBindingCard(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final whatsappBinding = ref.watch(whatsAppBindingProvider);

    return whatsappBinding.when(
      data: (isBound) {
        if (isBound) {
          // Success state - show connected
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF25D366),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Connected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Log expenses via WhatsApp messages',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          );
        }

        // CTA state - not bound yet
        return GestureDetector(
          onTap: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => const WhatsAppTutorialModal(),
            );
            if (result == true) {
              ref.invalidate(whatsAppBindingProvider);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF25D366).withOpacity(0.1),
                  const Color(0xFF128C7E).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                   
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Connect WhatsApp',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log expenses instantly via chat',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: colorScheme.foreground,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBenefitIcon(
                      context,
                      Icons.flash_on,
                      'Fast',
                    ),
                    _buildBenefitIcon(
                      context,
                      Icons.mic,
                      'Voice',
                    ),
                    _buildBenefitIcon(
                      context,
                      Icons.sync,
                      'Auto-sync',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildBenefitIcon(BuildContext context, IconData icon, String label) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF25D366),
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
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

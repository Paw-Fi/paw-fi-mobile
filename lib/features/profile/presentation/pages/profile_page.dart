import 'package:flutter/material.dart' hide IconButton, Card, Divider, Switch, Chip;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:rsupa/features/auth/presentation/states/auth.dart';

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final showSettings = useState(false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          shadcnui.IconButton(
            variance: shadcnui.ButtonVariance.ghost,
            icon: const Icon(Icons.settings),
            onPressed: () => showSettings.value = !showSettings.value,
          ),
        ],
      ),
      body: shadcnui.SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserCard(user),
              const shadcnui.Gap(24),
              _buildStatsSection(),
              const shadcnui.Gap(24),
              _buildAccountInfoSection(user),
              const shadcnui.Gap(24),
              if (showSettings.value) _buildSettingsSection(),
              if (showSettings.value) const shadcnui.Gap(24),
              _buildActivitySection(),
              const shadcnui.Gap(24),
              _buildBadgesSection(),
              const shadcnui.Gap(24),
              _buildQuickActions(ref),
              const shadcnui.Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(user) {
    return shadcnui.Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            shadcnui.Avatar(
              initials: user.displayName?.substring(0, 2).toUpperCase() ?? user.email.substring(0, 2).toUpperCase(),
              size: 64,
              backgroundColor: const Color(0xFF6366F1),
            ),
            const shadcnui.Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Text(user.displayName ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const shadcnui.Gap(8), const shadcnui.PrimaryBadge(child: Text('PRO'))]),
                  const shadcnui.Gap(4),
                  Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const shadcnui.Gap(8),
                  const shadcnui.Progress(progress: 0.75),
                  const shadcnui.Gap(4),
                  Text('Profile Completeness: 75%', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const shadcnui.Gap(12),
        Row(children: [Expanded(child: shadcnui.Card(child: _buildStatCard(Icons.account_balance_wallet, '\$12,450', 'Total Saved'))), const shadcnui.Gap(12), Expanded(child: shadcnui.Card(child: _buildStatCard(Icons.trending_up, '+15.3%', 'This Month', color: const Color(0xFF10B981))))]),
        const shadcnui.Gap(12),
        Row(children: [Expanded(child: shadcnui.Card(child: _buildStatCard(Icons.flag, '5', 'Active Goals', color: const Color(0xFF6366F1)))), const shadcnui.Gap(12), Expanded(child: shadcnui.Card(child: _buildStatCard(Icons.check_circle, '12', 'Completed', color: const Color(0xFF10B981))))]),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [Icon(icon, size: 32, color: color), const shadcnui.Gap(8), Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
    );
  }

  Widget _buildAccountInfoSection(user) {
    return shadcnui.Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const shadcnui.Gap(16),
            _buildInfoRow('User ID', user.uid),
            const shadcnui.Divider(),
            _buildInfoRow('Email', user.email),
            const shadcnui.Divider(),
            _buildInfoRow('Member Since', 'January 2025'),
            const shadcnui.Divider(),
            _buildInfoRow('Account Type', 'Premium'),
            const shadcnui.Divider(),
            _buildInfoRow('Verification Status', 'Verified', trailing: const shadcnui.PrimaryBadge(child: Text('✓ Verified'))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)), trailing ?? Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))]));
  }

  Widget _buildSettingsSection() {
    return shadcnui.Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const shadcnui.Gap(16),
            shadcnui.Accordion(
              items: [
                shadcnui.AccordionItem(trigger: const Text('Notifications'), content: Column(children: [_buildSwitchRow('Email Notifications', true), _buildSwitchRow('Push Notifications', true), _buildSwitchRow('SMS Alerts', false)])),
                shadcnui.AccordionItem(trigger: const Text('Privacy & Security'), content: Column(children: [_buildSwitchRow('Two-Factor Authentication', true), _buildSwitchRow('Profile Visibility', false), _buildSwitchRow('Activity Tracking', true)])),
                shadcnui.AccordionItem(trigger: const Text('Preferences'), content: Column(children: [_buildSwitchRow('Dark Mode', false), _buildSwitchRow('Auto-Save Goals', true), _buildSwitchRow('Monthly Reports', true)])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), shadcnui.Switch(value: value, onChanged: (v) {})]));
  }

  Widget _buildActivitySection() {
    final activities = [
      {'icon': Icons.add_circle, 'title': 'Created new goal', 'time': '2h ago', 'color': const Color(0xFF6366F1)},
      {'icon': Icons.attach_money, 'title': 'Deposited \$500', 'time': '1d ago', 'color': const Color(0xFF10B981)},
      {'icon': Icons.check_circle, 'title': 'Completed goal', 'time': '3d ago', 'color': const Color(0xFFFBBF24)},
    ];
    return shadcnui.Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const shadcnui.Gap(16), ...activities.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20)), const shadcnui.Gap(12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), Text(a['time'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[500]))]))])))]),
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const shadcnui.Gap(12), const Wrap(spacing: 8, runSpacing: 8, children: [shadcnui.Chip(leading: Icon(Icons.emoji_events, size: 16), child: Text('First Goal')), shadcnui.Chip(leading: Icon(Icons.local_fire_department, size: 16), child: Text('7 Day Streak')), shadcnui.Chip(leading: Icon(Icons.savings, size: 16), child: Text('Saved \$10K')), shadcnui.Chip(leading: Icon(Icons.star, size: 16), child: Text('Power User')), shadcnui.Chip(leading: Icon(Icons.share, size: 16), child: Text('Referral Master'))])]);
  }

  Widget _buildQuickActions(WidgetRef ref) {
    return shadcnui.Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const shadcnui.Gap(16), shadcnui.PrimaryButton(onPressed: () {}, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, size: 18), shadcnui.Gap(8), Text('Edit Profile')])), const shadcnui.Gap(12), shadcnui.OutlineButton(onPressed: () {}, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.download, size: 18), shadcnui.Gap(8), Text('Export Data')])), const shadcnui.Gap(12), shadcnui.OutlineButton(onPressed: () {}, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share, size: 18), shadcnui.Gap(8), Text('Share Profile')])), const shadcnui.Gap(12), const shadcnui.Divider(), const shadcnui.Gap(12), shadcnui.DestructiveButton(onPressed: () => ref.read(authProvider.notifier).signOut(), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, size: 18), shadcnui.Gap(8), Text('Sign Out')]))]),
      ),
    );
  }
}

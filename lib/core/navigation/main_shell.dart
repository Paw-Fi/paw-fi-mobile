import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/pages/home_page.dart';
import 'package:moneko/features/insights/presentation/pages/insights_page.dart';
import 'package:moneko/features/profile/presentation/pages/profile_page.dart';
import 'package:moneko/features/goals/presentation/pages/goals_list_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';

/// Main navigation shell with bottom navigation bar
class MainShell extends HookConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState(0);
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    final pages = [
      const HomePage(),
      const GoalsListPage(),
      const AnalyticsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[currentIndex.value],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          border: Border(
            top: BorderSide(
              color: colorScheme.border,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: currentIndex.value == 0 ? Icons.home : Icons.home_outlined,
                label: context.l10n.home,
                isSelected: currentIndex.value == 0,
                onTap: () => currentIndex.value = 0,
              ),
              _NavButton(
                icon: currentIndex.value == 1 ? Icons.flag : Icons.flag_outlined,
                label: context.l10n.goals ?? 'Goals',
                isSelected: currentIndex.value == 1,
                onTap: () => currentIndex.value = 1,
              ),
              _NavButton(
                icon: currentIndex.value == 2 ? Icons.insights : Icons.insights_outlined,
                label: context.l10n.insights,
                isSelected: currentIndex.value == 2,
                onTap: () => currentIndex.value = 2,
              ),
              _NavButton(
                icon: currentIndex.value == 3 ? Icons.person : Icons.person_outline,
                label: context.l10n.profile,
                isSelected: currentIndex.value == 3,
                onTap: () => currentIndex.value = 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.mutedForeground,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

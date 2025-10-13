import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/profile/presentation/widgets/profile_tab_content.dart';

Widget buildNavigationTabs(BuildContext context, ValueNotifier<int> selectedTab) {
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

Widget buildTabContent(BuildContext context, int selectedTab, user, WidgetRef ref) {
  switch (selectedTab) {
    case 0:
      return buildOverviewTab(context, user, ref);
    case 1:
      return buildActivityTab(context);
    default:
      return const SizedBox.shrink();
  }
}

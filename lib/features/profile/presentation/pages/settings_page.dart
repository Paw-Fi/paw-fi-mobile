import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/theme/app_theme.dart';

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

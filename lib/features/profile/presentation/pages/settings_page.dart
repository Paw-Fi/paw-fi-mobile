import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDarkMode = currentTheme == shadcnui.ThemeMode.dark;
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final contact = analyticsState.contact;

    final selectedCurrency = useState<String?>(contact?.preferredCurrency?.toUpperCase());
    final isSaving = useState(false);

    useEffect(() {
      selectedCurrency.value = contact?.preferredCurrency?.toUpperCase();
      return null;
    }, [contact?.preferredCurrency]);

    final currencies = getAvailableCurrencyOptions();

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
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(value ? shadcnui.ThemeMode.dark : shadcnui.ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
            const shadcnui.Gap(24),
            Text(
              'Currency',
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
                    Icons.payments_outlined,
                    size: 20,
                    color: colorScheme.mutedForeground,
                  ),
                  const shadcnui.Gap(16),
                  Expanded(
                    child: Text(
                      'Currency',
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: _CurrencyDropdown(
                      colorScheme: colorScheme,
                      options: currencies,
                      selected: selectedCurrency.value,
                      isSaving: isSaving.value,
                      onChanged: (code) async {
                            if (code == null) return;
                            final normalized = code.toUpperCase();
                            if (normalized == selectedCurrency.value) return;

                            if (!isSupportedCurrencyCode(normalized)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unsupported currency code: $normalized'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                              return;
                            }

                            if (authState.uid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please sign in to update your currency.'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                              return;
                            }

                            isSaving.value = true;
                            try {
                              final response = await supabase.functions.invoke(
                                'update-preferred-currency',
                                body: {
                                  'userId': authState.uid,
                                  'currency': normalized,
                                },
                              );

                              final status = response.status;
                              if (status >= 400) {
                                throw Exception('Request failed ($status)');
                              }

                              final payload = response.data as Map<String, dynamic>?;
                              if (payload == null || payload['ok'] != true) {
                                final message = payload?['error'] as String? ?? 'Unable to update currency';
                                throw Exception(message);
                              }

                              selectedCurrency.value = normalized;
                              ref.read(analyticsProvider.notifier).updatePreferredCurrency(normalized);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Currency updated to $normalized'),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            } catch (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update currency: $error'),
                                  backgroundColor: colorScheme.destructive,
                                ),
                              );
                            } finally {
                              isSaving.value = false;
                            }
                          },
                        ),
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

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.colorScheme,
    required this.options,
    required this.selected,
    required this.isSaving,
    required this.onChanged,
  });

  final shadcnui.ColorScheme colorScheme;
  final Map<String, String> options;
  final String? selected;
  final bool isSaving;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = selected?.toUpperCase();
    final current = normalizedSelected != null && options.containsKey(normalizedSelected)
        ? normalizedSelected
        : options.keys.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.5), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          icon: isSaving
              ? SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                )
              : Icon(Icons.keyboard_arrow_down, size: 16, color: colorScheme.mutedForeground),
          isDense: true,
          isExpanded: true,
          dropdownColor: colorScheme.card,
          style: TextStyle(color: colorScheme.foreground, fontSize: 13, fontWeight: FontWeight.w500),
          items: options.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.value}  ${entry.key}'),
                ),
              )
              .toList(),
          onChanged: isSaving ? null : onChanged,
        ),
      ),
    );
  }
}

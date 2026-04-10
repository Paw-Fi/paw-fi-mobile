import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/plaid/plaid_country_flags.dart';
import 'package:moneko/core/plaid/plaid_country_selector_modal.dart';
import 'package:moneko/core/theme/app_theme.dart';

class PlaidSyncCountrySelectionStep extends ConsumerWidget {
  const PlaidSyncCountrySelectionStep({
    super.key,
    required this.isDisabled,
  });

  final bool isDisabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCode = ref.watch(plaidCountryCodeProvider);
    final selectedOption =
        plaidCountryOptions.firstWhere((option) => option.code == selectedCode);
    final flagPath = getPlaidCountryFlagPath(selectedCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.public_rounded,
              size: 46,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Select Region',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your banking region to see the institutions available for syncing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isDisabled ? 0.6 : 1,
            child: Material(
              color: colorScheme.surface.withValues(alpha: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: isDisabled
                    ? null
                    : () async {
                        final result =
                            await showPlaidCountrySelectorModal(context, ref);
                        if (result != null) {
                          ref.read(plaidCountryCodeProvider.notifier).state =
                              result;
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: colorScheme.sheetBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.sheetBorder),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
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
                          color: colorScheme.cardSurface,
                          border: Border.all(color: colorScheme.border),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            flagPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Region',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedOption.label,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CurrencyDropdownButton extends ConsumerWidget {
  final VoidCallback? onAfterSelect;
  const CurrencyDropdownButton({super.key, this.onAfterSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final code = ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';

    return GestureDetector(
      onTap: () async {
        await showCurrencySelectorModal(context, ref);
        if (onAfterSelect != null) onAfterSelect!();
      },
      child: Container
        (
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.muted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: colorScheme.foreground,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

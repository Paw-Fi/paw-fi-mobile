import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.unfold_more_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ],
      ),
    );
  }
}

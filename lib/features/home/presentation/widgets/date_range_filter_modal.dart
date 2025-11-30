import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Shows the **per-card** date range filter sheet.
///
/// The sheet is tall by default to avoid overflow with longer locales.
/// You can override the height by passing [height].
/// - If [height] is null: defaults to 70% of screen height.
/// - If 0 < [height] <= 1: treated as a fraction of screen height.
/// - If [height] > 1: treated as absolute pixels.
void showCardDateRangeFilter(
  BuildContext context,
  ColorScheme colorScheme,
  HomeCardFilterId cardId, {
  double? height,
}) {
  double resolveHeight(BuildContext c, double? h) {
    final screenH = MediaQuery.of(c).size.height;
    if (h == null) return screenH * 0.7;
    if (h > 0 && h <= 1) return screenH * h;
    return h;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.appBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final sheetHeight = resolveHeight(ctx, height);
      return SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.l10n.selectDateRange,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.foreground),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ...DateRangeFilter.values
                          .where((f) => f != DateRangeFilter.custom)
                          .map((filter) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
                          title: Text(
                            filter.getLabel(ctx),
                            style: TextStyle(color: colorScheme.foreground),
                          ),
                          onTap: () async {
                            final container = ProviderScope.containerOf(ctx);
                            container
                                .read(cardDateFilterProvider(cardId).notifier)
                                .setFilter(filter);

                            // Close after updating the per-card filter.
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

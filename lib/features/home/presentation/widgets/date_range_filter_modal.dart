import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/l10n/l10n.dart';

void showDateRangeFilter(BuildContext context, shadcnui.ColorScheme colorScheme) {
  showModalBottomSheet(
    context: context,
    backgroundColor: colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.selectDateRange,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.foreground),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...DateRangeFilter.values.where((f) => f != DateRangeFilter.custom).map((filter) {
              return ListTile(
                title: Text(
                  filter.getLabel(context),
                  style: TextStyle(color: colorScheme.foreground),
                ),
                onTap: () async {
                  // Use local home filter instead of modifying the analytics provider
                  final container = ProviderScope.containerOf(context);
                  container.read(homeFilterProvider.notifier).setFilter(filter);
                  // Persist selection in local storage for next app launch
                  try {
                    final service = container.read(dateRangePreferenceServiceProvider);
                    await service.setSelectedDateRange(filter.name);
                  } catch (e) {
                    debugPrint('Error saving date range preference: $e');
                  }
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

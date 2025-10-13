import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

void showDateRangeFilter(BuildContext context, shadcnui.ColorScheme colorScheme, String userId) {
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
                  'Select Date Range',
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
                  filter.label,
                  style: TextStyle(color: colorScheme.foreground),
                ),
                onTap: () {
                  ProviderScope.containerOf(context).read(analyticsProvider.notifier).setDateRangeFilter(filter, userId);
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

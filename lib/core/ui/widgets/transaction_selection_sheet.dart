import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Generic selection sheet for picking from a list of items
/// Shows platform-specific UI (Cupertino for iOS, Material for Android)
/// 
/// This is a low-level widget that only handles displaying options
/// and returning the selected value. It has no knowledge of what
/// type of data it's displaying.
/// 
/// [T] - Type of items to select from
/// [items] - List of items to display
/// [getLabel] - Function to convert item to display string
/// [initial] - Initially selected item
/// 
/// Returns the selected item or null if cancelled
Future<T?> showTransactionSelectionSheet<T>({
  required BuildContext context,
  required List<T> items,
  required String Function(T) getLabel,
  required T initial,
}) async {
  if (Platform.isIOS) {
    int selectedIndex = items.indexOf(initial);
    if (selectedIndex < 0) selectedIndex = 0;
    
    return await showCupertinoModalPopup<T>(
      context: context,
      builder: (context) {
        T tempValue = items[selectedIndex];
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop<T>(context),
                      child: Text(context.l10n.cancel),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop<T>(context, tempValue),
                      child: Text(context.l10n.done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                  itemExtent: 40,
                  onSelectedItemChanged: (i) {
                    tempValue = items[i];
                  },
                  children: items.map((e) => Center(child: Text(getLabel(e)))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  } else {
    return await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.border.withValues(alpha: 0.4)),
                    itemBuilder: (context, i) {
                      final value = items[i];
                      final label = getLabel(value);
                      final selected = value == initial;
                      return ListTile(
                        title: Text(label, style: TextStyle(color: scheme.foreground)),
                        trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
                        onTap: () => Navigator.pop<T>(context, value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

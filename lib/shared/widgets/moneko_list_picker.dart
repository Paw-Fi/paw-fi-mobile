import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';


/// Platform-adaptive list picker that shows a Cupertino picker on iOS
/// and a Material bottom sheet list elsewhere.
class MonekoListPicker {
  const MonekoListPicker._();

  /// Presents a platform-appropriate picker and returns the selected item.
  static Future<T?> show<T>({
    required BuildContext context,
    required List<T> items,
    required String Function(T) labelBuilder,
    required T initial,
    String? title,
  }) async {
    if (items.isEmpty) return null;

    if (PlatformInfo.isIOS) {
      int selectedIndex = items.indexOf(initial);
      if (selectedIndex < 0) selectedIndex = 0;

      return showCupertinoModalPopup<T>(
        context: context,
        builder: (ctx) {
          T tempValue = items[selectedIndex];
          return Container(
            height: 340,
            color: CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(ctx),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop<T>(ctx),
                        child: Text(CupertinoLocalizations.of(ctx).cancelButtonLabel),
                      ),
                      if (title != null)
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop<T>(ctx, tempValue),
                        child: Text(context.l10n.done),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: selectedIndex),
                    itemExtent: 44,
                    onSelectedItemChanged: (index) {
                      tempValue = items[index];
                    },
                    children: items
                        .map((item) => Center(child: Text(labelBuilder(item))))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(
            alpha: 0.0,
          ),
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
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
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: scheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.border.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final label = labelBuilder(item);
                      final selected = item == initial;
                      return ListTile(
                        title: Text(
                          label,
                          style: TextStyle(color: scheme.foreground),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.pop<T>(context, item),
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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class MonekoActionSheetAction<T> {
  MonekoActionSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
}

class MonekoActionSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    required List<MonekoActionSheetAction<T>> actions,
    MonekoActionSheetAction<T>? cancelAction,
  }) {
    if (PlatformInfo.isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (popupContext) {
          return CupertinoActionSheet(
            title: Text(title),
            message: message != null ? Text(message) : null,
            actions: actions
                .map(
                  (action) => CupertinoActionSheetAction(
                    isDestructiveAction: action.isDestructive,
                    onPressed: () {
                      Navigator.of(popupContext).pop(action.value);
                    },
                    child: _buildActionRow(action.label, action.icon),
                  ),
                )
                .toList(),
            cancelButton: cancelAction != null
                ? CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () {
                      Navigator.of(popupContext).pop(cancelAction.value);
                    },
                    child:
                        _buildActionRow(cancelAction.label, cancelAction.icon),
                  )
                : null,
          );
        },
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewPadding.bottom;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (message != null && message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...actions.map(
                      (action) => ListTile(
                        leading: action.icon != null
                            ? Icon(
                                action.icon,
                                color: action.isDestructive
                                    ? colorScheme.error
                                    : colorScheme.onSurface,
                              )
                            : null,
                        title: Text(
                          action.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: action.isDestructive
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop(action.value);
                        },
                      ),
                    ),
                    if (cancelAction != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: cancelAction.icon != null
                            ? Icon(
                                cancelAction.icon,
                                color: colorScheme.onSurface,
                              )
                            : null,
                        title: Text(
                          cancelAction.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop(cancelAction.value);
                        },
                      ),
                    ],
                    SizedBox(height: bottomInset + 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildActionRow(String label, IconData? icon) {
    if (icon == null) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

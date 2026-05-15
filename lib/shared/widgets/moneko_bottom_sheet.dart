import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';

class MonekoBottomSheet {
  const MonekoBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool useRootNavigator = false,
    bool useSafeArea = true,
    String? title,
    VoidCallback? onClose,
    VoidCallback? onConfirm,
    bool isConfirmLoading = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
      clipBehavior: clipBehavior,
      constraints: constraints,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
      builder: (context) {
        return _MonekoSheetContent(
          builder: builder,
          title: title,
          onClose: onClose,
          onConfirm: onConfirm,
          isConfirmLoading: isConfirmLoading,
          colorScheme: colorScheme,
          backgroundColor: backgroundColor ?? colorScheme.sheetBackground,
        );
      },
    );
  }
}

class _MonekoSheetContent extends StatelessWidget {
  const _MonekoSheetContent({
    required this.builder,
    required this.colorScheme,
    required this.backgroundColor,
    this.title,
    this.onClose,
    this.onConfirm,
    this.isConfirmLoading = false,
  });

  final WidgetBuilder builder;
  final ColorScheme colorScheme;
  final Color backgroundColor;
  final String? title;
  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal Sheet Drag Handle
          const ModalSheetHandle(),

          // Header with Circle Icons
          if (title != null || onClose != null || onConfirm != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon:
                          Icon(Icons.close, color: colorScheme.mutedForeground),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.muted.withValues(alpha: 0.2),
                      ),
                    )
                  else
                    const SizedBox(width: 48),

                  // Title
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),

                  // Check Button
                  if (onConfirm != null)
                    IconButton(
                      onPressed: isConfirmLoading ? null : onConfirm,
                      icon: isConfirmLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(Icons.check, color: colorScheme.primary),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

          // Content
          Flexible(child: builder(context)),
        ],
      ),
    );
  }
}

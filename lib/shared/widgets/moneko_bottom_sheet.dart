import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';

class MonekoSheetConfirmController extends ChangeNotifier {
  VoidCallback? _onConfirm;
  bool _isLoading = false;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;

  void attach(VoidCallback onConfirm) => _onConfirm = onConfirm;

  void detach() => _onConfirm = null;

  void confirm() => _onConfirm?.call();

  void setLoading(bool value) {
    if (_isDisposed || _isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _onConfirm = null;
    super.dispose();
  }
}

class MonekoSheetConfirmButton extends StatelessWidget {
  const MonekoSheetConfirmButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: isLoading ? null : onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('confirm-loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onSurface,
                  ),
                ),
              )
            : Icon(
                Icons.check,
                key: const ValueKey('confirm-ready'),
                color: colorScheme.onSurface,
              ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
      ),
    );
  }
}

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
    MonekoSheetConfirmController? confirmController,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          confirmController: confirmController,
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
    this.confirmController,
  });

  final WidgetBuilder builder;
  final ColorScheme colorScheme;
  final Color backgroundColor;
  final String? title;
  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;
  final MonekoSheetConfirmController? confirmController;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal Sheet Drag Handle
          const ModalSheetHandle(),

          // Header with Circle Icons
          if (title != null ||
              onClose != null ||
              onConfirm != null ||
              confirmController != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    )
                  else
                    const SizedBox(width: 48),

                  // Title
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),

                  // Check Button
                  if (confirmController != null)
                    AnimatedBuilder(
                      animation: confirmController!,
                      builder: (context, _) => MonekoSheetConfirmButton(
                        onPressed: confirmController!.confirm,
                        isLoading: confirmController!.isLoading,
                      ),
                    )
                  else if (onConfirm != null)
                    MonekoSheetConfirmButton(
                      onPressed: onConfirm,
                      isLoading: isConfirmLoading,
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

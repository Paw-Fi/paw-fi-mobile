import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
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

class MonekoSheetCloseButton extends StatelessWidget {
  const MonekoSheetCloseButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.close_rounded,
    this.iconSize = 24.0,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: iconSize, color: colorScheme.onSurface),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          fixedSize: const Size.square(40),
          backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class MonekoSheetLeadingCloseButton extends StatelessWidget {
  const MonekoSheetLeadingCloseButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.close_rounded,
    this.iconSize = 24.0,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MonekoBottomSheet.leadingPadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: MonekoSheetCloseButton(
          onPressed: onPressed,
          icon: icon,
          iconSize: iconSize,
          tooltip: tooltip,
        ),
      ),
    );
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
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        onPressed: isLoading ? null : onPressed,
        padding: EdgeInsets.zero,
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
                  Icons.check_rounded,
                  key: const ValueKey('confirm-ready'),
                  size: 24,
                  color: colorScheme.onSurface,
                ),
        ),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          fixedSize: const Size.square(40),
          backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class MonekoBottomSheet {
  const MonekoBottomSheet._();

  static const double horizontalPadding = 20.0;
  static const double toolbarHeight = 64.0;
  static const double leadingWidth = 68.0;
  static const EdgeInsets leadingPadding = EdgeInsets.only(
    left: 20.0,
    top: 8.0,
    bottom: 8.0,
  );
  static const EdgeInsets actionsPadding = EdgeInsets.only(
    right: 20.0,
    top: 8.0,
    bottom: 8.0,
  );
  static const EdgeInsets headerRowPadding = EdgeInsets.fromLTRB(
    20.0,
    4.0,
    20.0,
    12.0,
  );

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
    ValueChanged<BuildContext>? onCloseWithContext,
    VoidCallback? onConfirm,
    bool isConfirmLoading = false,
    MonekoSheetConfirmController? confirmController,
  }) {
    assert(
      onClose == null || onCloseWithContext == null,
      'Provide only one close callback.',
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
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
          onCloseWithContext: onCloseWithContext,
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
    this.onCloseWithContext,
    this.onConfirm,
    this.isConfirmLoading = false,
    this.confirmController,
  });

  final WidgetBuilder builder;
  final ColorScheme colorScheme;
  final Color backgroundColor;
  final String? title;
  final VoidCallback? onClose;
  final ValueChanged<BuildContext>? onCloseWithContext;
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal Sheet Drag Handle
          const ModalSheetHandle(),

          // Header with Circle Icons
          MonekoSheetHeader(
            title: title,
            onClose: onClose,
            onCloseWithContext: onCloseWithContext,
            onConfirm: onConfirm,
            isConfirmLoading: isConfirmLoading,
            confirmController: confirmController,
          ),

          // Content
          Flexible(child: builder(context)),
        ],
      ),
    );
  }
}

/// Standard reusable header for bottom sheets using Row layout.
class MonekoSheetHeader extends StatelessWidget {
  const MonekoSheetHeader({
    super.key,
    this.title,
    this.onClose,
    this.onCloseWithContext,
    this.onConfirm,
    this.isConfirmLoading = false,
    this.confirmController,
    this.closeButton,
    this.confirmButton,
    this.padding,
  });

  final String? title;
  final VoidCallback? onClose;
  final ValueChanged<BuildContext>? onCloseWithContext;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;
  final MonekoSheetConfirmController? confirmController;
  final Widget? closeButton;
  final Widget? confirmButton;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasClose =
        closeButton != null || onCloseWithContext != null || onClose != null;
    final hasConfirm =
        confirmButton != null || confirmController != null || onConfirm != null;

    if (title == null && !hasClose && !hasConfirm) {
      return const SizedBox.shrink();
    }

    return MonekoTextScale(
      mode: MonekoTextScaling.compact,
      child: Padding(
        padding: padding ?? MonekoBottomSheet.headerRowPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (closeButton != null)
              closeButton!
            else if (onCloseWithContext != null || onClose != null)
              MonekoSheetCloseButton(
                onPressed: () {
                  if (onCloseWithContext != null) {
                    onCloseWithContext!(context);
                  } else {
                    onClose?.call();
                  }
                },
              )
            else
              const SizedBox(width: 40),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  maxLines: MonekoTextScale.isAtLeast(context, 1.5) ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            if (confirmButton != null)
              confirmButton!
            else if (confirmController != null)
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
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// Standard reusable SliverAppBar for bottom sheets with consistent insets,
/// toolbar height, leading close button, and actions confirm button.
class MonekoSheetSliverAppBar extends StatelessWidget {
  const MonekoSheetSliverAppBar({
    super.key,
    this.onClose,
    this.onConfirm,
    this.isConfirmLoading = false,
    this.confirmController,
    this.expandedHeight,
    this.flexibleSpace,
    this.title,
    this.forceMaterialTransparency = false,
    this.backgroundColor,
    this.leading,
    this.actions,
    this.pinned = true,
    this.stretch = true,
  });

  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;
  final MonekoSheetConfirmController? confirmController;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final Widget? title;
  final bool forceMaterialTransparency;
  final Color? backgroundColor;
  final Widget? leading;
  final List<Widget>? actions;
  final bool pinned;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHeight = expandedHeight ?? MonekoBottomSheet.toolbarHeight;

    return SliverAppBar(
      toolbarHeight: MonekoBottomSheet.toolbarHeight,
      expandedHeight: effectiveHeight,
      leadingWidth: MonekoBottomSheet.leadingWidth,
      pinned: pinned,
      stretch: stretch,
      backgroundColor:
          backgroundColor ?? colorScheme.surface.withValues(alpha: 0.0),
      forceMaterialTransparency: forceMaterialTransparency,
      elevation: 0,
      title: title,
      leading: leading ??
          (onClose != null
              ? MonekoSheetLeadingCloseButton(onPressed: onClose)
              : null),
      actionsPadding: MonekoBottomSheet.actionsPadding,
      actions: actions ??
          [
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
              ),
          ],
      flexibleSpace: flexibleSpace ?? const SizedBox.shrink(),
    );
  }
}

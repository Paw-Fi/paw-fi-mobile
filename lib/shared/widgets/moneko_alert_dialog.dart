import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Configuration for an optional text input inside the dialog.
class MonekoAlertDialogInputConfig {
  const MonekoAlertDialogInputConfig({
    this.initialValue,
    this.placeholder,
    this.isRequired = false,
    this.validationPattern,
    this.validationMessage,
    this.keyboardType = TextInputType.text,
  });

  final String? initialValue;
  final String? placeholder;
  final bool isRequired;
  final RegExp? validationPattern;
  final String? validationMessage;
  final TextInputType keyboardType;
}

/// Structured result of the dialog.
class MonekoAlertDialogResult {
  const MonekoAlertDialogResult({
    required this.confirmed,
    required this.action,
    this.text,
    this.secondaryText,
  });

  final bool confirmed;
  final MonekoAlertDialogAction action;
  final String? text;
  final String? secondaryText;
}

enum MonekoAlertDialogAction {
  confirm,
  secondary,
  cancel,
}

/// Custom, modern alert dialog with optional text input.
///
/// - No platform alert widgets are used; layout is fully custom.
/// - Uses PrimaryAdaptiveButton and OutlinedAdaptiveButton for actions.
/// - When [inputConfig] is provided, an AdaptiveTextField is shown with
///   optional required/regex validation.
class MonekoAlertDialog {
  const MonekoAlertDialog._();

  static Future<MonekoAlertDialogResult?> show({
    required BuildContext context,
    required String title,
    String? description,
    String? confirmLabel,
    String? cancelLabel,
    String? secondaryLabel,
    bool barrierDismissible = true,
    MonekoAlertDialogInputConfig? inputConfig,
    MonekoAlertDialogInputConfig? secondaryInputConfig,
    Widget? content,
    bool isDestructive = false,
  }) {
    return showGeneralDialog<MonekoAlertDialogResult>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dialog',
      barrierColor: Theme.of(context).colorScheme.shadow.withValues(
            alpha: 0.35,
          ),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: _MonekoAlertDialogWidget(
              title: title,
              description: description,
              confirmLabel: confirmLabel ?? context.l10n.confirm,
              cancelLabel: cancelLabel ?? context.l10n.cancel,
              secondaryLabel: secondaryLabel,
              inputConfig: inputConfig,
              secondaryInputConfig: secondaryInputConfig,
              content: content,
              isDestructive: isDestructive,
            ),
          ),
        );
      },
    );
  }
}

class _MonekoAlertDialogWidget extends StatefulWidget {
  const _MonekoAlertDialogWidget({
    required this.title,
    this.description,
    required this.confirmLabel,
    this.cancelLabel,
    this.secondaryLabel,
    this.inputConfig,
    this.secondaryInputConfig,
    this.content,
    this.isDestructive = false,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final String? cancelLabel;
  final String? secondaryLabel;
  final MonekoAlertDialogInputConfig? inputConfig;
  final MonekoAlertDialogInputConfig? secondaryInputConfig;
  final Widget? content;
  final bool isDestructive;

  @override
  State<_MonekoAlertDialogWidget> createState() =>
      _MonekoAlertDialogWidgetState();
}

class _MonekoAlertDialogWidgetState extends State<_MonekoAlertDialogWidget> {
  late final TextEditingController? _controller;
  late final TextEditingController? _secondaryController;
  String? _errorText;
  String? _secondaryErrorText;
  bool _touched = false;
  bool _secondaryTouched = false;

  bool get _hasInput => widget.inputConfig != null;
  bool get _hasSecondaryInput => widget.secondaryInputConfig != null;

  @override
  void initState() {
    super.initState();
    if (_hasInput) {
      final initial = widget.inputConfig!.initialValue ?? '';
      _controller = TextEditingController(text: initial);
      // Select all for quick overwrite.
      _controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller!.text.length,
      );
    } else {
      _controller = null;
    }

    if (_hasSecondaryInput) {
      final initial = widget.secondaryInputConfig!.initialValue ?? '';
      _secondaryController = TextEditingController(text: initial);
    } else {
      _secondaryController = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _secondaryController?.dispose();
    super.dispose();
  }

  String? _validate(String value, MonekoAlertDialogInputConfig? cfg) {
    if (cfg == null) return null;

    final trimmed = value.trim();
    if (cfg.isRequired && trimmed.isEmpty) {
      return cfg.validationMessage ?? context.l10n.thisFieldIsRequired;
    }
    if (cfg.validationPattern != null && trimmed.isNotEmpty) {
      if (!cfg.validationPattern!.hasMatch(trimmed)) {
        return cfg.validationMessage ?? context.l10n.pleaseEnterAValidValue;
      }
    }
    return null;
  }

  void _onChanged(String value) {
    setState(() {
      _touched = true;
      _errorText = _validate(value, widget.inputConfig);
    });
  }

  void _onSecondaryChanged(String value) {
    setState(() {
      _secondaryTouched = true;
      _secondaryErrorText = _validate(value, widget.secondaryInputConfig);
    });
  }

  bool get _canConfirm {
    if (_hasInput) {
      final value = _controller!.text;
      if (_validate(value, widget.inputConfig) != null) return false;
    }
    if (_hasSecondaryInput) {
      final value = _secondaryController!.text;
      if (_validate(value, widget.secondaryInputConfig) != null) return false;
    }
    return true;
  }

  void _handleCancel() {
    Navigator.of(context).pop(
      const MonekoAlertDialogResult(
        confirmed: false,
        action: MonekoAlertDialogAction.cancel,
        text: null,
      ),
    );
  }

  void _handleSecondary() {
    Navigator.of(context).pop(
      MonekoAlertDialogResult(
        confirmed: false,
        action: MonekoAlertDialogAction.secondary,
        text: _controller?.text.trim(),
        secondaryText: _secondaryController?.text.trim(),
      ),
    );
  }

  void _handleConfirm() {
    if (!_canConfirm) {
      setState(() {
        _touched = true;
        _errorText = _validate(_controller?.text ?? '', widget.inputConfig);
        _secondaryTouched = true;
        _secondaryErrorText = _validate(
            _secondaryController?.text ?? '', widget.secondaryInputConfig);
      });
      return;
    }

    Navigator.of(context).pop(
      MonekoAlertDialogResult(
        confirmed: true,
        action: MonekoAlertDialogAction.confirm,
        text: _controller?.text.trim(),
        secondaryText: _secondaryController?.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine platform style
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          // Android M3 tends to be wider, iOS alerts are traditionally narrower (270px) but modern customized ones are wider.
          // We'll keep it responsive but maybe cap it differently.
          final double dialogWidth = maxWidth > 480
              ? 400.0
              : maxWidth -
                  (isIOS
                      ? 48.0
                      : 32.0); // More margin on iOS for that "floating" look

          if (isIOS) {
            return _buildIOSDialog(context, dialogWidth);
          } else {
            return _buildAndroidDialog(context, dialogWidth);
          }
        },
      ),
    );
  }

  Widget _buildAndroidDialog(BuildContext context, double width) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh, // Material 3 surface container
          borderRadius: BorderRadius.circular(28), // M3 conversational radii
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start, // Left align for Android
          children: [
            // Icon could go here in future, but standard is Title first
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.description != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (_hasInput) ...[
              const SizedBox(height: 16),
              _buildInput(context),
            ],
            if (_hasSecondaryInput) ...[
              const SizedBox(height: 12),
              _buildSecondaryInput(context),
            ],
            const SizedBox(height: 24),
            // Actions
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.cancelLabel != null)
                  TextButton(
                    onPressed: _handleCancel,
                    child: Text(
                      widget.cancelLabel!,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (widget.secondaryLabel != null)
                  TextButton(
                    onPressed: _canConfirm ? _handleSecondary : null,
                    child: Text(
                      widget.secondaryLabel!,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        widget.isDestructive ? scheme.error : scheme.primary,
                    foregroundColor: widget.isDestructive
                        ? scheme.onError
                        : scheme.onPrimary,
                  ),
                  onPressed: _canConfirm ? _handleConfirm : null,
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSDialog(BuildContext context, double width) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Glassmorphism background for iOS
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20), // Apple-like rounded corners
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF252525).withValues(alpha: 0.85)
                  : const Color(0xFFF2F2F2).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 24,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.description!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: scheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (_hasInput) ...[
                        const SizedBox(height: 16),
                        _buildInput(context),
                      ],
                      if (_hasSecondaryInput) ...[
                        const SizedBox(height: 12),
                        _buildSecondaryInput(context),
                      ],
                      if (widget.content != null) ...[
                        const SizedBox(height: 16),
                        widget.content!,
                      ],
                    ],
                  ),
                ),
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                // Actions (Full width, split if 2)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.cancelLabel != null) ...[
                        Expanded(
                          child: InkWell(
                            onTap: _handleCancel,
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  widget.cancelLabel!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurface.withValues(
                                        alpha: 0.65), // Neutral Cancel
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ],
                      if (widget.secondaryLabel != null) ...[
                        Expanded(
                          child: InkWell(
                            onTap: _canConfirm ? _handleSecondary : null,
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  widget.secondaryLabel!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.65),
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ],
                      Expanded(
                        child: InkWell(
                          onTap: _canConfirm ? _handleConfirm : null,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                widget.confirmLabel,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: widget.isDestructive
                                      ? scheme.error
                                      : scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 17,
                                  // Opacity if disabled
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveTextField(
          controller: _controller!,
          placeholder: widget.inputConfig!.placeholder ?? '',
          keyboardType: widget.inputConfig!.keyboardType,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: (_) => _handleConfirm(),
          // Passing some decoration styles could be good here if AdaptiveTextField supports it,
          // assuming it adapts nicely.
        ),
        if (_touched && _errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: Theme.of(context).platform == TargetPlatform.iOS
                ? TextAlign.center
                : TextAlign.start,
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryInput(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveTextField(
          controller: _secondaryController!,
          placeholder: widget.secondaryInputConfig!.placeholder ?? '',
          keyboardType: widget.secondaryInputConfig!.keyboardType,
          autofocus: !_hasInput,
          onChanged: _onSecondaryChanged,
          onSubmitted: (_) => _handleConfirm(),
        ),
        if (_secondaryTouched && _secondaryErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _secondaryErrorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: Theme.of(context).platform == TargetPlatform.iOS
                ? TextAlign.center
                : TextAlign.start,
          ),
        ],
      ],
    );
  }
}

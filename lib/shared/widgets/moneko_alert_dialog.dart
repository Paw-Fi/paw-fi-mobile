import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

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
    this.text,
  });

  final bool confirmed;
  final String? text;
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
    bool barrierDismissible = true,
    MonekoAlertDialogInputConfig? inputConfig,
  }) {
    return showGeneralDialog<MonekoAlertDialogResult>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dialog',
      barrierColor: Colors.black.withValues(alpha: 0.35),
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
              inputConfig: inputConfig,
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
    this.inputConfig,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final String? cancelLabel;
  final MonekoAlertDialogInputConfig? inputConfig;

  @override
  State<_MonekoAlertDialogWidget> createState() => _MonekoAlertDialogWidgetState();
}

class _MonekoAlertDialogWidgetState
    extends State<_MonekoAlertDialogWidget> {
  late final TextEditingController? _controller;
  String? _errorText;
  bool _touched = false;

  bool get _hasInput => widget.inputConfig != null;

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
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final cfg = widget.inputConfig;
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
      _errorText = _validate(value);
    });
  }

  bool get _canConfirm {
    if (!_hasInput) return true;
    final value = _controller!.text;
    return _validate(value) == null;
  }

  void _handleCancel() {
    Navigator.of(context).pop(
      const MonekoAlertDialogResult(confirmed: false, text: null),
    );
  }

  void _handleConfirm() {
    if (!_canConfirm) {
      setState(() {
        _touched = true;
        _errorText = _validate(_controller?.text ?? '');
      });
      return;
    }

    Navigator.of(context).pop(
      MonekoAlertDialogResult(
        confirmed: true,
        text: _controller?.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final dialogWidth = maxWidth > 480 ? 420.0 : maxWidth - 32.0;

          return Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_hasInput) ...[
                      const SizedBox(height: 18),
                      AdaptiveTextField(
                        controller: _controller!,
                        placeholder: widget.inputConfig!.placeholder ?? '',
                        keyboardType: widget.inputConfig!.keyboardType,
                        autofocus: true,
                        onChanged: _onChanged,
                        onSubmitted: (_) => _handleConfirm(),
                      ),
                      if (_touched && _errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _errorText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (widget.cancelLabel != null) ...[
                          Expanded(
                            child: OutlinedAdaptiveButton(
                              onPressed: _handleCancel,
                              child: Text(widget.cancelLabel!),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: PrimaryAdaptiveButton(
                            onPressed: _canConfirm ? _handleConfirm : null,
                            child: Text(widget.confirmLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

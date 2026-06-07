import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';

class AppLockPasscodePrompt extends StatefulWidget {
  const AppLockPasscodePrompt({
    required this.title,
    required this.subtitle,
    required this.onComplete,
    this.errorText,
    this.enabled = true,
    this.isSubmitting = false,
    this.showBiometricButton = false,
    this.onBiometricPressed,
    this.footer,
    this.biometricTooltip,
    super.key,
  });

  final String title;
  final String subtitle;
  final ValueChanged<String> onComplete;
  final String? errorText;
  final bool enabled;
  final bool isSubmitting;
  final bool showBiometricButton;
  final VoidCallback? onBiometricPressed;
  final Widget? footer;
  final String? biometricTooltip;

  @override
  State<AppLockPasscodePrompt> createState() => _AppLockPasscodePromptState();
}

class _AppLockPasscodePromptState extends State<AppLockPasscodePrompt> {
  String _passcode = '';
  bool _completed = false;

  bool get _canEdit => widget.enabled && !widget.isSubmitting && !_completed;

  void _appendDigit(String digit) {
    if (!_canEdit ||
        _passcode.length >= AppLockPasscodeHasher.requiredPasscodeLength) {
      return;
    }

    final nextPasscode = '$_passcode$digit';
    setState(() {
      _passcode = nextPasscode;
      _completed =
          nextPasscode.length == AppLockPasscodeHasher.requiredPasscodeLength;
    });

    if (nextPasscode.length == AppLockPasscodeHasher.requiredPasscodeLength) {
      widget.onComplete(nextPasscode);
    }
  }

  void _deleteDigit() {
    if (!_canEdit || _passcode.isEmpty) {
      return;
    }

    setState(() {
      _passcode = _passcode.substring(0, _passcode.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final keypadMaxWidth = fillsHeight
            ? math.min(
                244.0,
                math.max(
                  168.0,
                  (constraints.maxHeight -
                          _PasscodeHeader.estimatedHeight -
                          _PasscodeDots.estimatedFlexibleBandHeight -
                          (widget.footer == null ? 0 : 76) +
                          12) *
                      0.75,
                ),
              )
            : 244.0;

        return SizedBox(
          height: fillsHeight ? constraints.maxHeight : null,
          child: Column(
            mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _PasscodeHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                errorText: widget.errorText,
              ),
              fillsHeight
                  ? Expanded(
                      child: Center(
                        child: _PasscodeDots(length: _passcode.length),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: _PasscodeDots(length: _passcode.length),
                    ),
              Align(
                key: const ValueKey('app-lock-keypad'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: keypadMaxWidth),
                  child: _NumericKeypad(
                    enabled: _canEdit,
                    onDigit: _appendDigit,
                    onDelete: _deleteDigit,
                    showBiometricButton: widget.showBiometricButton,
                    onBiometricPressed: widget.onBiometricPressed,
                    biometricTooltip:
                        widget.biometricTooltip ?? context.l10n.useBiometrics,
                    passcodeLength: _passcode.length,
                  ),
                ),
              ),
              if (widget.footer != null) ...[
                const SizedBox(height: 24),
                widget.footer!,
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PasscodeHeader extends StatelessWidget {
  const _PasscodeHeader({
    required this.title,
    required this.subtitle,
    this.errorText,
  });

  final String title;
  final String subtitle;
  final String? errorText;

  static const double estimatedHeight = 112;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 42,
          color: colorScheme.onSurface,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            errorText ?? subtitle,
            key: ValueKey(errorText ?? subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: errorText == null
                  ? colorScheme.onSurface.withValues(alpha: 0.6)
                  : colorScheme.destructive,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasscodeDots extends StatelessWidget {
  const _PasscodeDots({required this.length});

  final int length;
  static const double estimatedFlexibleBandHeight = 32;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children:
          List.generate(AppLockPasscodeHasher.requiredPasscodeLength, (index) {
        final filled = index < length;
        return AnimatedContainer(
          key: ValueKey('app-lock-passcode-dot-$index'),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: filled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
    required this.showBiometricButton,
    required this.onBiometricPressed,
    required this.biometricTooltip,
    required this.passcodeLength,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool showBiometricButton;
  final VoidCallback? onBiometricPressed;
  final String biometricTooltip;
  final int passcodeLength;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'del'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int j = 0; j < rows[i].length; j++) ...[
                if (j > 0) const SizedBox(width: 18),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Builder(builder: (context) {
                      final keyData = rows[i][j];

                      if (keyData == 'bio') {
                        if (!showBiometricButton) {
                          return const SizedBox.shrink();
                        }
                        return Tooltip(
                          message: biometricTooltip,
                          child: _GlassKeypadButton(
                            isAction: true,
                            icon: Icons.face_rounded,
                            onTap: enabled ? onBiometricPressed : null,
                          ),
                        );
                      }

                      if (keyData == 'del') {
                        if (passcodeLength == 0) return const SizedBox.shrink();
                        return _GlassKeypadButton(
                          isAction: true,
                          icon: Icons.backspace_rounded,
                          onTap: enabled ? onDelete : null,
                          isTransparent:
                              true, // Make delete button transparent background
                        );
                      }

                      return _GlassKeypadButton(
                        digit: keyData,
                        onTap: enabled ? () => onDigit(keyData) : null,
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _GlassKeypadButton extends StatefulWidget {
  const _GlassKeypadButton({
    this.digit = '',
    this.onTap,
    this.isAction = false,
    this.icon,
    this.isTransparent = false,
  });

  final String digit;
  final VoidCallback? onTap;
  final bool isAction;
  final IconData? icon;
  final bool isTransparent;

  @override
  State<_GlassKeypadButton> createState() => _GlassKeypadButtonState();
}

class _GlassKeypadButtonState extends State<_GlassKeypadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.90).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
        ),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: _buildButton(colorScheme),
        ),
      ),
    );
  }

  Widget _buildButton(ColorScheme colorScheme) {
    if (widget.isTransparent) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isPressed = _controller.value > 0;
          return Container(
            decoration: BoxDecoration(
              color: isPressed
                  ? colorScheme.onSurface.withValues(alpha: 0.1)
                  : colorScheme.surface.withValues(alpha: 0.0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: _buildContent(colorScheme),
          );
        },
      );
    }

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final isPressed = _controller.value > 0;
            return Container(
              decoration: BoxDecoration(
                color: isPressed
                    ? colorScheme.onSurface.withValues(alpha: 0.15)
                    : colorScheme.onSurface.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: _buildContent(colorScheme),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (widget.isAction) {
      return Icon(
        widget.icon,
        size: 26,
        color: colorScheme.onSurface,
      );
    }

    return Text(
      widget.digit,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
        height: 1.0,
      ),
    );
  }
}

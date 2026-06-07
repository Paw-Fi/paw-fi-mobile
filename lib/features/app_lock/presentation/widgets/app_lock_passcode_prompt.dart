import 'package:flutter/material.dart';
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
    this.biometricTooltip = 'Use biometrics',
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
  final String biometricTooltip;

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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_rounded,
          size: 52,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            widget.errorText ?? widget.subtitle,
            key: ValueKey(widget.errorText ?? widget.subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.errorText == null
                  ? colorScheme.mutedForeground
                  : colorScheme.destructive,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _PasscodeDots(length: _passcode.length),
        const SizedBox(height: 28),
        Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _NumericKeypad(
              enabled: _canEdit,
              onDigit: _appendDigit,
              onDelete: _deleteDigit,
            ),
          ),
        ),
        if (widget.showBiometricButton || widget.footer != null) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.showBiometricButton)
                IconButton(
                  tooltip: widget.biometricTooltip,
                  onPressed: widget.enabled && !widget.isSubmitting
                      ? widget.onBiometricPressed
                      : null,
                  icon: const Icon(Icons.fingerprint_rounded),
                ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ],
      ],
    );
  }
}

class _PasscodeDots extends StatelessWidget {
  const _PasscodeDots({required this.length});

  final int length;

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
          width: filled ? 14 : 12,
          height: filled ? 14 : 12,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: filled ? colorScheme.primary : colorScheme.surface,
            border: Border.all(color: colorScheme.border),
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
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final value = keys[index];
        if (value.isEmpty) {
          return const SizedBox.shrink();
        }
        return OutlinedButton(
          onPressed: !enabled
              ? null
              : value == 'del'
                  ? onDelete
                  : () => onDigit(value),
          child: value == 'del'
              ? const Icon(Icons.backspace_outlined)
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }
}

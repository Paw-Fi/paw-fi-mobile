import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/data/services/impersonation_service.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Dialog for admins to start impersonating a user
class ImpersonationDialog extends ConsumerStatefulWidget {
  const ImpersonationDialog({super.key});

  // Convenient static helper to show this dialog
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ImpersonationDialog(),
    );
  }

  @override
  ConsumerState<ImpersonationDialog> createState() =>
      _ImpersonationDialogState();
}

class _ImpersonationDialogState extends ConsumerState<ImpersonationDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _startImpersonation() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = context.l10n.pleaseEnterAnEmailAddress;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(impersonationProvider.notifier)
        .startImpersonation(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage =
            context.l10n.failedToImpersonateUserPleaseCheckTheEmailAndTryAgain;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final infoBase = colorScheme.info;
    final infoBackground = colorScheme.infoSurface;
    final infoBorder = colorScheme.infoBorder;

    return AlertDialog(
      title: Text(context.l10n.impersonateUser),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.enterTheEmailAddressOfTheUserYouWantToImpersonate,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: context.l10n.userEmail,
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
              enabled: !_isLoading,
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _startImpersonation(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: infoBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: infoBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: infoBase,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n
                        .youWillSeeDataFromThisUsersPerspectiveWithoutLoggingInAsThem,
                    style: TextStyle(
                      fontSize: 12,
                      color: infoBase.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _startImpersonation,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.start),
        ),
      ],
    );
  }
}

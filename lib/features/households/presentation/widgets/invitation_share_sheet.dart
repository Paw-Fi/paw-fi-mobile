import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/household_constants.dart';

/// Invitation share sheet for sharing household invitation URLs
///
/// Features:
/// - Clean modern UI with 0.08-0.12 border opacity
/// - Full accessibility support
/// - Copy and share functionality
/// - Theme-aware colors
class InvitationShareSheet extends StatelessWidget {
  final String inviteUrl;
  final String householdName;
  final VoidCallback? onClose;

  const InvitationShareSheet({
    super.key,
    required this.inviteUrl,
    required this.householdName,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Semantics(
      label: AppLocalizations.of(context)!.shareInvitationForHousehold(householdName),
      container: true,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Semantics(
              header: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.shareInvitation,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Semantics(
                    label: HouseholdConstants.closeButtonLabel,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose ?? () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Success message
            Semantics(
              label: AppLocalizations.of(context)!.householdCreatedSuccessfully(householdName),
              readOnly: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.householdCreatedSuccessfullyWithQuotes(householdName),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Invite URL display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.invitationLink,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),

                Semantics(
                  label: AppLocalizations.of(context)!.invitationLinkWithUrl(inviteUrl),
                  textField: true,
                  readOnly: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.border.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            inviteUrl,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.foreground.withOpacity(0.8),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Semantics(
                          label: AppLocalizations.of(context)!.copyInvitationLink,
                          button: true,
                          child: InkWell(
                            onTap: () => _copyToClipboard(context, inviteUrl),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.copy,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: AppLocalizations.of(context)!.copyInvitationLinkToClipboard,
                    button: true,
                    child: shadcnui.OutlineButton(
                      onPressed: () => _copyToClipboard(context, inviteUrl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.copy, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.copyLink,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: AppLocalizations.of(context)!.shareInvitationLink,
                    button: true,
                    child: shadcnui.PrimaryButton(
                      onPressed: () => _shareInvite(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.share,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Done button
            Semantics(
              label: AppLocalizations.of(context)!.closeShareSheet,
              button: true,
              child: SizedBox(
                width: double.infinity,
                child: shadcnui.TextButton(
                  onPressed: onClose ?? () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)!.done,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.invitationLinkCopiedToClipboard),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareInvite(BuildContext context) {
    Share.share(
      AppLocalizations.of(context)!.joinMyHouseholdMessage(householdName, inviteUrl),
      subject: AppLocalizations.of(context)!.joinMyHouseholdSubject,
    );
  }

  /// Show the share sheet as a bottom modal
  static void show({
    required BuildContext context,
    required String inviteUrl,
    required String householdName,
    VoidCallback? onClose,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvitationShareSheet(
        inviteUrl: inviteUrl,
        householdName: householdName,
        onClose: onClose,
      ),
    );
  }
}

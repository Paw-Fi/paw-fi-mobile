import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:share_plus/share_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class InviteMembersPage extends ConsumerStatefulWidget {
  const InviteMembersPage({
    super.key,
    required this.householdId,
    required this.householdName,
    required this.onDone,
  });

  final String householdId;
  final String householdName;
  final VoidCallback onDone;

  @override
  ConsumerState<InviteMembersPage> createState() => _InviteMembersPageState();
}

class _InviteMembersPageState extends ConsumerState<InviteMembersPage> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  int _selectedExpirationDays = 7;
  bool _isLoading = false;

  // Result state
  String? _generatedInviteUrl;
  bool _emailSent = false;

  final List<int> _expirationOptions = [1, 7, 30];

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    final email = _emailController.text.trim();
    final personalMessage = _messageController.text.trim();
    final user = ref.read(authProvider);
    final inviterName =
        (user.displayName?.trim().isNotEmpty == true ? user.displayName : user.email)
            ?.trim();
    /*
      Validation: 
      - If email is provided, validate format? 
        The backend likely validates, but simple regex is good UX.
    */
    if (email.isNotEmpty && !email.contains('@')) {
      AppToast.error(context, context.l10n.pleaseEnterValidEmailAddress);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(householdRepositoryProvider);

      final inviteUrl = await repository.createInvite(
        householdId: widget.householdId,
        invitedEmail: email.isEmpty ? null : email,
        personalMessage: personalMessage.isEmpty ? null : personalMessage,
        inviterName: inviterName?.isNotEmpty == true ? inviterName : null,
        householdName: widget.householdName.trim().isNotEmpty
            ? widget.householdName.trim()
            : null,
        expiresInDays: _selectedExpirationDays,
      );

      if (!mounted) return;
      setState(() {
        _generatedInviteUrl = inviteUrl;
        _emailSent = email.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ INVITATION ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void _copyLink() {
    if (_generatedInviteUrl == null) return;
    Clipboard.setData(ClipboardData(text: _generatedInviteUrl!));
    HapticFeedback.selectionClick();
    AppToast.success(context, context.l10n.linkCopiedToClipboard);
  }

  void _shareLink() {
    if (_generatedInviteUrl == null) return;
    Share.share(
      'Join my space "${widget.householdName}" on Moneko: $_generatedInviteUrl',
      subject: 'Join "${widget.householdName}" on Moneko',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title:
            _generatedInviteUrl == null ? context.l10n.inviteMembers : context.l10n.invitationReady,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
          child: Material(
            color: colorScheme.appBackground,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _generatedInviteUrl != null
                  ? _buildResultContent(colorScheme)
                  : _buildConfigContent(colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.whoDoYouWantToInvite,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.emailInviteDescription,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: colorScheme.border.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.emailAddressOptional,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                AdaptiveTextField(
                  controller: _emailController,
                  placeholder: context.l10n.emailPlaceholder,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _createInvite(),
                ),

                const SizedBox(height: 24),

                Text(
                  context.l10n.personalMessageOptional,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                AdaptiveTextField(
                  controller: _messageController,
                  placeholder: context.l10n.personalMessageOptional,
                  keyboardType: TextInputType.text,
                ),

                const SizedBox(height: 24),

                Text(
                  context.l10n.linkExpiration,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),

                // Expiry Selector Chips
                Row(
                  children: _expirationOptions.map((days) {
                    final isSelected = days == _selectedExpirationDays;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedExpirationDays = days),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.muted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.border.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            "$days ${context.l10n.days}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.foreground,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          PrimaryAdaptiveButton(
            onPressed: _isLoading ? null : _createInvite,
            child: _isLoading
                ? const CircularProgressIndicator.adaptive(
                    backgroundColor: Colors.white)
                : Text(
                    context.l10n.createInviteLink,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (!_isLoading)
            Center(
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(
                  context.l10n.skipForNow,
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            _emailSent ? context.l10n.inviteSent : context.l10n.linkReady,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailSent
                ? context.l10n.invitationEmailSent
                : context.l10n.shareLinkDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Link Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: colorScheme.border.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _generatedInviteUrl ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.foreground,
                            fontFamily: 'Monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButtons(
                        label: context.l10n.copyLink,
                        icon: Icons.copy_rounded,
                        onPressed: _copyLink,
                        colorScheme: colorScheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButtons(
                        label: context.l10n.share,
                        icon: Icons.ios_share_rounded,
                        onPressed: _shareLink,
                        colorScheme: colorScheme,
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          TextButton(
            onPressed: widget.onDone,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: colorScheme.foreground,
            ),
            child: Text(
              context.l10n.done,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isPrimary ? colorScheme.primary : colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: colorScheme.border.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : colorScheme.foreground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

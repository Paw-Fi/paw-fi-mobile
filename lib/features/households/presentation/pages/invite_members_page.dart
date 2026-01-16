import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:share_plus/share_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
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
  int _selectedExpirationDays = 7;
  bool _isLoading = false;

  // Result state
  String? _generatedInviteUrl;
  bool _emailSent = false;

  final List<int> _expirationOptions = [1, 7, 30];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    final email = _emailController.text.trim();
    /*
      Validation: 
      - If email is provided, validate format? 
        The backend likely validates, but simple regex is good UX.
    */
    if (email.isNotEmpty && !email.contains('@')) {
      AppToast.error(context, "Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(householdRepositoryProvider);

      final inviteUrl = await repository.createInvite(
        householdId: widget.householdId,
        invitedEmail: email.isEmpty ? null : email,
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
    AppToast.success(context, "Link copied to clipboard");
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
            _generatedInviteUrl == null ? "Invite Members" : "Invitation Ready",
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
            "Who do you want to invite?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter an email to send a personal invitation, or just generate a link to share directly.",
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
                  "Email Address (Optional)",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                AdaptiveTextField(
                  controller: _emailController,
                  placeholder: "name@example.com",
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _createInvite(),
                ),

                const SizedBox(height: 24),

                Text(
                  "Link Expiration",
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
                            "$days Days",
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
                : const Text(
                    "Create Invite Link",
                    style: TextStyle(
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
                  "Skip for now",
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
            _emailSent ? "Invite Sent!" : "Link Ready!",
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
                ? "We've sent an invitation email. You can also share the link below manually."
                : "Share this link with the people you want to join your space.",
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
                        label: "Copy Link",
                        icon: Icons.copy_rounded,
                        onPressed: _copyLink,
                        colorScheme: colorScheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButtons(
                        label: "Share",
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
            child: const Text(
              "Done",
              style: TextStyle(
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/error_handler.dart';
import '../../core/household_constants.dart';
import '../providers/household_providers.dart';

/// Modern page for joining a household via invitation URL
///
/// Features:
/// - Token validation with debouncing (500ms)
/// - Retry logic for network failures
/// - User-friendly error messages
/// - Accessibility labels
/// - Clean modern UI (2025 standards)
class HouseholdJoinPage extends ConsumerStatefulWidget {
  final String? initialToken;

  const HouseholdJoinPage({super.key, this.initialToken});

  @override
  ConsumerState<HouseholdJoinPage> createState() => _HouseholdJoinPageState();
}

enum JoinPageState {
  input,
  validating,
  preview,
  joining,
  success,
  error,
}

class _HouseholdJoinPageState extends ConsumerState<HouseholdJoinPage>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  JoinPageState _state = JoinPageState.input;
  String? _errorMessage;
  Map<String, dynamic>? _invitePreview;
  String? _extractedToken;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Debouncing for validation
  Timer? _validationDebounce;
  bool _isPasting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();

    _urlController.addListener(() {
      if (!mounted) return;
      setState(() {}); // Rebuild to update suffix icon

      // Debounce validation trigger
      _validationDebounce?.cancel();
      _validationDebounce = Timer(
        const Duration(milliseconds: HouseholdConstants.validationDebounceMs),
        () {
          if (!mounted) return;
          _formKey.currentState?.validate();
        },
      );
    });

    // If initialToken provided (from deep link), pre-fill and auto-validate
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _urlController.text = 'https://moneko.app/invites/${widget.initialToken}';
      // Auto-validate after a short delay to allow UI to settle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _validateInvite();
        }
      });
    }
  }

  @override
  void dispose() {
    _validationDebounce?.cancel();
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final canGoBack = _state != JoinPageState.joining;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Modern header
            _buildHeader(colorScheme, canGoBack),

            // Content area
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildContent(colorScheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(shadcnui.ColorScheme colorScheme, bool canGoBack) {
    return Semantics(
      label: HouseholdConstants.joinPageHeaderLabel,
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Semantics(
              label: HouseholdConstants.backButtonLabel,
              button: true,
              enabled: canGoBack,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: colorScheme.foreground,
                onPressed: canGoBack ? () => Navigator.pop(context) : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Join Household',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 44), // Balance
          ],
        ),
      ),
    );
  }

  Widget _buildContent(shadcnui.ColorScheme colorScheme) {
    switch (_state) {
      case JoinPageState.input:
      case JoinPageState.validating:
        return _buildInputForm(colorScheme);
      case JoinPageState.preview:
        return _buildPreview(colorScheme);
      case JoinPageState.joining:
        return _buildJoining(colorScheme);
      case JoinPageState.success:
        return _buildSuccess(colorScheme);
      case JoinPageState.error:
        return _buildError(colorScheme);
    }
  }

  Widget _buildInputForm(shadcnui.ColorScheme colorScheme) {
    final isValidating = _state == JoinPageState.validating;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // Hero illustration
            _buildHeroSection(colorScheme),

            const SizedBox(height: 40),

            // Instructions card
            _buildInstructionsCard(colorScheme),

            const SizedBox(height: 32),

            // URL Input
            _buildUrlInput(colorScheme, isValidating),

            const SizedBox(height: 32),

            // Continue button
            _buildContinueButton(colorScheme, isValidating),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(shadcnui.ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.joinHeroLabel,
      readOnly: true,
      child: Center(
        child: Column(
          children: [
            // Icon container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Icon(
                  Icons.group_add_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Join a Household',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your invitation link to join\na shared financial space',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground.withOpacity(0.6),
                height: 1.5,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard(shadcnui.ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.joinInstructionsLabel,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Icon(
              Icons.info_outline_rounded,
              color: colorScheme.mutedForeground.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Paste the invitation link you received from a household member',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.foreground.withOpacity(0.65),
                  height: 1.4,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput(shadcnui.ColorScheme colorScheme, bool isValidating) {
    return Semantics(
      label: HouseholdConstants.inviteLinkInputLabel,
      textField: true,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.border.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Left icon
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.link_rounded,
                color: colorScheme.mutedForeground.withOpacity(0.6),
                size: 20,
              ),
            ),

            // Input field
            Expanded(
              child: TextFormField(
                controller: _urlController,
                enabled: !isValidating,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onFieldSubmitted: (_) => isValidating ? null : _validateInvite(),
                decoration: InputDecoration(
                  hintText: 'Paste invitation link',
                  hintStyle: TextStyle(
                    color: colorScheme.mutedForeground.withOpacity(0.4),
                    fontWeight: FontWeight.normal,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: TextStyle(
                    fontSize: 13,
                    color: colorScheme.destructive,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 16,
                  ),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an invitation link';
                  }
                  if (_extractTokenFromUrl(value.trim()) == null) {
                    return 'Please enter a valid invitation link';
                  }
                  return null;
                },
              ),
            ),

            // Action button (paste or clear)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _urlController.text.isNotEmpty
                  ? Semantics(
                      label: HouseholdConstants.clearInputButtonLabel,
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.mutedForeground.withOpacity(0.6),
                          size: 20,
                        ),
                        onPressed: isValidating
                            ? null
                            : () {
                                if (!mounted) return;
                                _urlController.clear();
                              },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.muted.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  : Semantics(
                      label: HouseholdConstants.pasteButtonLabel,
                      button: true,
                      child: Material(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: (isValidating || _isPasting) ? null : _pasteFromClipboard,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: _isPasting
                                ? SizedBox(
                                    width: 50,
                                    height: 16,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.content_paste_rounded,
                                        color: colorScheme.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Paste',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(shadcnui.ColorScheme colorScheme, bool isValidating) {
    return Semantics(
      label: isValidating
          ? HouseholdConstants.validatingButtonLabel
          : HouseholdConstants.continueButtonLabel,
      button: true,
      enabled: !isValidating,
      child: SizedBox(
        height: 56,
        child: isValidating
            ? shadcnui.PrimaryButton(
                onPressed: null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primaryForeground.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Validating...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              )
            : shadcnui.PrimaryButton(
                onPressed: _validateInvite,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPreview(shadcnui.ColorScheme colorScheme) {
    final householdName = _invitePreview?['household_name'] ?? 'Household';
    final inviterEmail = _invitePreview?['inviter_email'] ?? 'Unknown';
    final expiresAt = _invitePreview?['expires_at'];
    final coverImageUrl = _invitePreview?['household']?['cover_image_url'] as String?;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Household preview card
          _buildHouseholdPreviewCard(
            colorScheme,
            householdName,
            inviterEmail,
            coverImageUrl,
          ),

          const SizedBox(height: 24),

          // Expiration info
          if (expiresAt != null) ...[
            _buildExpirationCard(colorScheme, expiresAt),
            const SizedBox(height: 16),
          ],

          // Benefits card
          _buildBenefitsCard(colorScheme),

          const SizedBox(height: 32),

          // Join button
          Semantics(
            label: 'Join $householdName household',
            button: true,
            child: SizedBox(
              height: 56,
              child: shadcnui.PrimaryButton(
                onPressed: _acceptInvite,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Join "$householdName"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel button
          Semantics(
            label: HouseholdConstants.cancelButtonLabel,
            button: true,
            child: SizedBox(
              height: 48,
              child: shadcnui.OutlineButton(
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _state = JoinPageState.input;
                    _invitePreview = null;
                    _extractedToken = null;
                  });
                  _animationController.reset();
                  _animationController.forward();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdPreviewCard(
    shadcnui.ColorScheme colorScheme,
    String householdName,
    String inviterEmail,
    String? coverImageUrl,
  ) {
    return Semantics(
      label: 'Household preview: $householdName, invited by $inviterEmail',
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.08),
              colorScheme.primary.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.12),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Household icon/image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: coverImageUrl != null && coverImageUrl.isNotEmpty
                    ? Image.network(
                        coverImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: colorScheme.primary.withOpacity(0.2),
                            child: Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) {
                          return Container(
                            color: colorScheme.primary.withOpacity(0.2),
                            child: Icon(
                              Icons.home_rounded,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: colorScheme.primary.withOpacity(0.2),
                        child: Center(
                          child: Icon(
                            Icons.home_rounded,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              householdName,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.muted.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: colorScheme.foreground.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Invited by $inviterEmail',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.foreground.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationCard(shadcnui.ColorScheme colorScheme, String expiresAt) {
    final expirationDate = DateTime.tryParse(expiresAt);
    final daysUntilExpiry = expirationDate != null
        ? expirationDate.difference(DateTime.now()).inDays
        : null;
    final isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry <= 2;

    return Semantics(
      label: isExpiringSoon
          ? 'Invitation expires soon on ${_formatDate(expiresAt)}'
          : 'Invitation valid until ${_formatDate(expiresAt)}',
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpiringSoon
              ? Colors.orange.withOpacity(0.1)
              : colorScheme.muted.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpiringSoon
                ? Colors.orange.withOpacity(0.3)
                : colorScheme.border.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpiringSoon ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              color: isExpiringSoon ? Colors.orange : colorScheme.foreground.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpiringSoon ? 'Expires soon' : 'Invitation valid until',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(expiresAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.foreground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsCard(shadcnui.ColorScheme colorScheme) {
    final benefits = [
      {'icon': Icons.account_balance_wallet_rounded, 'text': 'View shared budgets and expenses'},
      {'icon': Icons.insights_rounded, 'text': 'Track household financial health'},
      {'icon': Icons.people_rounded, 'text': 'Collaborate on financial decisions'},
    ];

    return Semantics(
      label: HouseholdConstants.benefitsCardLabel,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blue.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'What you\'ll get',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...benefits.map((benefit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      benefit['icon'] as IconData,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        benefit['text'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.foreground.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildJoining(shadcnui.ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.joiningHouseholdLabel,
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Joining household...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will only take a moment',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.foreground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(shadcnui.ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.joinSuccessLabel,
      liveRegion: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Success animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 70,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome Aboard!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re now part of the household.\nStart collaborating on your finances!',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Semantics(
              label: HouseholdConstants.goToHouseholdButtonLabel,
              button: true,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: shadcnui.PrimaryButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Go to Household',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(shadcnui.ColorScheme colorScheme) {
    return Semantics(
      label: 'Error: ${_errorMessage ?? "An unexpected error occurred"}',
      liveRegion: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // Error illustration
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.destructive.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.destructive.withOpacity(0.12),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.destructive.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: colorScheme.destructive,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unable to Join',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'An unexpected error occurred',
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground.withOpacity(0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Try again button
            Semantics(
              label: HouseholdConstants.tryAgainButtonLabel,
              button: true,
              child: SizedBox(
                height: 56,
                child: shadcnui.PrimaryButton(
                  onPressed: () {
                    if (!mounted) return;
                    setState(() {
                      _state = JoinPageState.input;
                      _errorMessage = null;
                      _extractedToken = null;
                    });
                    _animationController.reset();
                    _animationController.forward();
                  },
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel button
            Semantics(
              label: HouseholdConstants.cancelButtonLabel,
              button: true,
              child: SizedBox(
                height: 48,
                child: shadcnui.OutlineButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    if (!mounted) return;

    setState(() => _isPasting = true);

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;

      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        _urlController.text = clipboardData.text!;
      }
    } catch (e) {
      // Clipboard access failed, silently ignore
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isPasting = false);
      }
    }
  }

  Future<void> _validateInvite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final url = _urlController.text.trim();
    final token = _extractTokenFromUrl(url);

    if (token == null) {
      _showError(ErrorHandler.getUserFriendlyMessage('Invalid invitation link format'));
      return;
    }

    if (!mounted) return;
    setState(() {
      _state = JoinPageState.validating;
      _extractedToken = token;
    });

    await _validateInviteWithRetry(token);
  }

  Future<void> _validateInviteWithRetry(String token) async {
    int attempts = 0;

    while (attempts < HouseholdConstants.maxRetryAttempts) {
      try {
        final service = ref.read(householdServiceProvider);
        final result = await service.validateInvite(token);

        if (!mounted) return;

        if (result['valid'] == true) {
          setState(() {
            _invitePreview = result;
            _state = JoinPageState.preview;
          });
          _animationController.reset();
          _animationController.forward();
          return;
        } else {
          final errorMsg = result['error'] ?? 'Invalid or expired invitation';
          _showError(ErrorHandler.getUserFriendlyMessage(errorMsg));
          return;
        }
      } catch (e) {
        attempts++;

        if (!ErrorHandler.isRetryable(e) || attempts >= HouseholdConstants.maxRetryAttempts) {
          if (mounted) {
            _showError(ErrorHandler.getUserFriendlyMessage(e));
          }
          return;
        }

        // Wait before retry with exponential backoff
        await Future.delayed(
          Duration(milliseconds: HouseholdConstants.retryDelayMs * attempts),
        );
      }
    }
  }

  Future<void> _acceptInvite() async {
    if (_extractedToken == null) return;

    if (!mounted) return;
    setState(() {
      _state = JoinPageState.joining;
    });
    _animationController.reset();
    _animationController.forward();

    await _acceptInviteWithRetry(_extractedToken!);
  }

  Future<void> _acceptInviteWithRetry(String token) async {
    int attempts = 0;

    while (attempts < HouseholdConstants.maxRetryAttempts) {
      try {
        final service = ref.read(householdServiceProvider);
        await service.acceptInvite(token);

        if (!mounted) return;

        // Refresh households list
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ref.read(userHouseholdsProvider(userId).notifier).load();
        }

        if (!mounted) return;

        setState(() {
          _state = JoinPageState.success;
        });
        _animationController.reset();
        _animationController.forward();
        return;
      } catch (e) {
        attempts++;

        if (!ErrorHandler.isRetryable(e) || attempts >= HouseholdConstants.maxRetryAttempts) {
          if (mounted) {
            _showError(ErrorHandler.getUserFriendlyMessage(e));
          }
          return;
        }

        // Wait before retry with exponential backoff
        await Future.delayed(
          Duration(milliseconds: HouseholdConstants.retryDelayMs * attempts),
        );
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _state = JoinPageState.error;
      _errorMessage = message;
    });
    _animationController.reset();
    _animationController.forward();
  }

  String? _extractTokenFromUrl(String url) {
    // Try to extract token from various URL formats:
    // - https://moneko.app/invites/TOKEN
    // - moneko.app/invites/TOKEN
    // - /invites/TOKEN
    // - TOKEN (raw token)

    // Use improved token pattern from HouseholdConstants
    final invitePattern = RegExp(r'invites/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|[A-Za-z0-9_-]{32,})');
    final match = invitePattern.firstMatch(url);
    if (match != null) {
      final token = match.group(1);
      if (token != null && HouseholdConstants.tokenPattern.hasMatch(token)) {
        return token;
      }
    }

    // Try as raw token
    if (HouseholdConstants.tokenPattern.hasMatch(url)) {
      return url;
    }

    return null;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = date.difference(now);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Tomorrow';
      } else if (difference.inDays < 7) {
        return 'in ${difference.inDays} days';
      }

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

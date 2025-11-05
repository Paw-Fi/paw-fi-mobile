import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/error_handler.dart';
import '../../core/household_constants.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../../../../core/l10n/l10n.dart';

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
      _urlController.text = 'https://moneko.io/invites/${widget.initialToken}';
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
                context.l10n.joinHousehold,
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
                color: colorScheme.primary.withValues(alpha: 0.1),
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
              context.l10n.joinAHousehold,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.enterYourInvitationLinkToJoin,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground.withValues(alpha: 0.6),
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
          color: colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colorScheme.mutedForeground.withValues(alpha: 0.7),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.pasteTheInvitationLinkYouReceived,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.foreground.withValues(alpha: 0.65),
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
            color: colorScheme.border.withValues(alpha: 0.12),
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
                color: colorScheme.mutedForeground.withValues(alpha: 0.6),
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
                  hintText: context.l10n.pasteInvitationLink,
                  hintStyle: TextStyle(
                    color: colorScheme.mutedForeground.withValues(alpha: 0.4),
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
                    return context.l10n.pleaseEnterAnInvitationLink;
                  }
                  if (_extractTokenFromUrl(value.trim()) == null) {
                    return context.l10n.pleaseEnterAValidInvitationLink;
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
                          color: colorScheme.mutedForeground.withValues(alpha: 0.6),
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
                          backgroundColor: colorScheme.muted.withValues(alpha: 0.4),
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
                        color: colorScheme.primary.withValues(alpha: 0.1),
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
                                        context.l10n.pasteInvitationLink,
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
                          colorScheme.primaryForeground.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.validating,
                      style: const TextStyle(
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
                child: Text(
                  context.l10n.continueAction,
                  style: const TextStyle(
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
    final householdName = _invitePreview?['household']?['name'] ?? context.l10n.household;
    final inviterEmail = _invitePreview?['inviter']?['email'] ??
        _invitePreview?['inviter']?['full_name'] ?? context.l10n.unknown;
    final expiresAt = _invitePreview?['expires_at'];
    final coverImageUrl = _invitePreview?['household']?['cover_image_url'] as String?;
    final personalMessage = _invitePreview?['invite']?['personal_message'] as String?;

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

          // Personal message from inviter (if any)
          if (personalMessage != null && personalMessage.trim().isNotEmpty) ...[
            _buildPersonalMessageCard(colorScheme, personalMessage.trim()),
            const SizedBox(height: 16),
          ],

          // Benefits card
          _buildBenefitsCard(colorScheme),

          const SizedBox(height: 32),

          // Join button
          Semantics(
            label: context.l10n.joinHouseholdName(householdName),
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
                        context.l10n.joinHouseholdName(householdName),
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
                child: Text(
                  context.l10n.cancel,
                  style: const TextStyle(
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
      label: context.l10n.householdPreview(householdName, inviterEmail),
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.primary.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.12),
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
                    color: Colors.black.withValues(alpha: 0.08),
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
                            color: colorScheme.primary.withValues(alpha: 0.2),
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
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            child: Icon(
                              Icons.home_rounded,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: colorScheme.primary.withValues(alpha: 0.2),
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
                color: colorScheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: colorScheme.foreground.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.invitedBy(inviterEmail),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.foreground.withValues(alpha: 0.7),
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
    final daysUntilExpiry = expirationDate?.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry != null && daysUntilExpiry <= 2;

    return Semantics(
      label: isExpiringSoon
          ? context.l10n.invitationExpiresSoon(_formatDate(expiresAt))
          : context.l10n.invitationValidUntil(_formatDate(expiresAt)),
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpiringSoon
              ? Colors.orange.withValues(alpha: 0.1)
              : colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpiringSoon
                ? Colors.orange.withValues(alpha: 0.3)
                : colorScheme.border.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpiringSoon ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              color: isExpiringSoon ? Colors.orange : colorScheme.foreground.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpiringSoon ? context.l10n.expiresSoon : context.l10n.invitationValidUntilLabel,
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
                      color: colorScheme.foreground.withValues(alpha: 0.7),
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
      {'icon': Icons.account_balance_wallet_rounded, 'text': context.l10n.viewSharedBudgetsAndExpenses},
      {'icon': Icons.insights_rounded, 'text': context.l10n.trackHouseholdFinancialHealth},
      {'icon': Icons.people_rounded, 'text': context.l10n.collaborateOnFinancialDecisions},
    ];

    return Semantics(
      label: HouseholdConstants.benefitsCardLabel,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.12),
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
                  context.l10n.whatYoullGet,
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
                          color: colorScheme.foreground.withValues(alpha: 0.8),
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

  Widget _buildPersonalMessageCard(shadcnui.ColorScheme colorScheme, String message) {
    return Semantics(
      label: context.l10n.personalMessageFromInviter,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: colorScheme.mutedForeground, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.messageFromInviter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"$message"',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.foreground.withValues(alpha: 0.8),
                      height: 1.4,
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
              context.l10n.joiningHousehold,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.thisWillOnlyTakeAMoment,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.foreground.withValues(alpha: 0.6),
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
                color: Colors.green.withValues(alpha: 0.1),
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
              context.l10n.welcomeAboard,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.youreNowPartOfTheHousehold,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground.withValues(alpha: 0.6),
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
                  child: Text(
                    context.l10n.goToHousehold,
                    style: const TextStyle(
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
      label: context.l10n.errorWithMessage(_errorMessage ?? context.l10n.anUnexpectedErrorOccurred),
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
                color: colorScheme.destructive.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.destructive.withValues(alpha: 0.12),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.destructive.withValues(alpha: 0.1),
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
                    context.l10n.unableToJoin,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? context.l10n.anUnexpectedErrorOccurred,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.foreground.withValues(alpha: 0.7),
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
                  child: Text(
                    context.l10n.tryAgain,
                    style: const TextStyle(
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
                  child: Text(
                    context.l10n.cancel,
                    style: const TextStyle(
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
      _showError(ErrorHandler.getUserFriendlyMessage(context.l10n.invalidInvitationLinkFormat));
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
          final errorCode = (result['error_code'] ?? '').toString();
          final errorMsg = result['error'] ?? context.l10n.invalidOrExpiredInvitation;

          // If already a member, treat as success to avoid dead-end UX
          if (errorCode.toUpperCase() == 'ALREADY_MEMBER') {
            final userId = Supabase.instance.client.auth.currentUser?.id;
            final householdId = result['household']?['id'] as String?;
            if (userId != null && householdId != null) {
              // refresh list and set selection
              await ref.read(userHouseholdsProvider(userId).notifier).load();
              await ref.read(selectedHouseholdProvider.notifier).selectHousehold(householdId, userId);
            }
            if (!mounted) return;
            setState(() {
              _invitePreview = result;
              _state = JoinPageState.success;
            });
            _animationController.reset();
            _animationController.forward();
            return;
          }

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
        final result = await service.acceptInvite(token);

        if (!mounted) return;

        // Refresh households list
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final acceptedHouseholdId = (result['household_id'] as String?) ?? _invitePreview?['household']?['id'] as String?;
        if (userId != null) {
          await ref.read(userHouseholdsProvider(userId).notifier).load();
          if (acceptedHouseholdId != null) {
            await ref.read(selectedHouseholdProvider.notifier).selectHousehold(acceptedHouseholdId, userId);
          }
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
        final errStr = e.toString().toLowerCase();

        // Treat already-member conflicts as success
        if (errStr.contains('already') || errStr.contains('409')) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final householdId = _invitePreview?['household']?['id'] as String?;
          if (userId != null && householdId != null) {
            await ref.read(userHouseholdsProvider(userId).notifier).load();
            await ref.read(selectedHouseholdProvider.notifier).selectHousehold(householdId, userId);
          }
          if (!mounted) return;
          setState(() {
            _state = JoinPageState.success;
          });
          _animationController.reset();
          _animationController.forward();
          return;
        }

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

    // Capture full path segment after /invites/ until a delimiter (end, slash, ?, or #)
    final invitePattern = RegExp(r'invites/([^/?#]+)');
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
        return context.l10n.today;
      } else if (difference.inDays == 1) {
        return context.l10n.tomorrow;
      } else if (difference.inDays < 7) {
        return context.l10n.inDays(difference.inDays);
      }

      final months = [
        context.l10n.january,
        context.l10n.february,
        context.l10n.march,
        context.l10n.april,
        context.l10n.may,
        context.l10n.june,
        context.l10n.july,
        context.l10n.august,
        context.l10n.september,
        context.l10n.october,
        context.l10n.november,
        context.l10n.december
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

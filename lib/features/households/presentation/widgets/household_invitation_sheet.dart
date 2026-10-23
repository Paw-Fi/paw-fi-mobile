import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/households/presentation/widgets/household_invite_preview.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import '../providers/household_providers.dart';
import '../../../../../core/l10n/l10n.dart';
import '../providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class HouseholdInvitationSheet extends ConsumerStatefulWidget {
  final String token;

  const HouseholdInvitationSheet({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<HouseholdInvitationSheet> createState() =>
      _HouseholdInvitationSheetState();
}

enum _InvitationPhase { loading, preview, joining, success, error }

class _HouseholdInvitationSheetState
    extends ConsumerState<HouseholdInvitationSheet> {
  _InvitationPhase _phase = _InvitationPhase.loading;
  String? _error;
  String? _householdId;
  String? _householdName;
  HouseholdInvitePreviewData? _preview;
  bool _isSelecting = false;
  String? _actorUserId;
  bool _actorChanged = false;

  @override
  void initState() {
    super.initState();
    _actorUserId = ref.read(currentUserIdProvider);
    ref.listenManual(currentUserIdProvider, (_, userId) {
      if (userId == _actorUserId) return;
      _actorChanged = true;
      if (!mounted) return;
      setState(() {
        _phase = _InvitationPhase.error;
        _error = context.l10n.invitationError;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInvite();
    });
  }

  bool get _isActorActive =>
      mounted &&
      !_actorChanged &&
      _actorUserId != null &&
      _actorUserId!.isNotEmpty &&
      ref.read(currentUserIdProvider) == _actorUserId;

  void _fail(Object error) {
    if (!_isActorActive) return;
    setState(() {
      _phase = _InvitationPhase.error;
      _error = error.toString();
    });
  }

  Future<void> _refreshHouseholdList(String householdId) async {
    if (!_isActorActive) return;
    try {
      final households = userHouseholdsProvider(_actorUserId!);
      final notifier = ref.read(households.notifier);
      // load() retains the previously confirmed list while reconciling.
      await notifier.load();
      if (!_isActorActive) return;
      if (!(ref.read(households).valueOrNull ?? const [])
          .any((household) => household.id == householdId)) {
        // A coalesced read may have started before membership was committed.
        await notifier.load();
      }
    } catch (_) {
      // The backend already confirmed membership; retain the cached list.
    }
  }

  /// Validates only. Joining waits for the user's explicit confirmation so
  /// they can recognise the Space first.
  Future<void> _loadInvite() async {
    if (!mounted) return;
    if (!_isActorActive) {
      setState(() {
        _error = context.l10n.invitationError;
        _phase = _InvitationPhase.error;
      });
      return;
    }

    final repo = ref.read(householdRepositoryProvider);
    try {
      final validateResponse = await repo.validateInvite(widget.token);
      if (!mounted || !_isActorActive) return;

      final householdId = validateResponse['household']?['id'] as String?;
      final errorCode =
          (validateResponse['error_code'] ?? '').toString().toUpperCase();

      if (householdId == null || householdId.trim().isEmpty) {
        throw Exception(validateResponse['error'] ??
            context.l10n.invalidInvitationMissingInfo);
      }
      _householdName = validateResponse['household']?['name'] as String?;

      // Already a member: nothing to decide, so reconcile straight to success.
      if (errorCode == 'ALREADY_MEMBER') {
        await _completeMembership(householdId);
        return;
      }
      if (validateResponse['valid'] != true) {
        throw Exception(validateResponse['error'] ?? 'Invalid invitation');
      }

      setState(() {
        _householdId = householdId;
        _preview = HouseholdInvitePreviewData.fromValidation(
          validateResponse,
          fallbackHouseholdName: context.l10n.household,
          fallbackInviterLabel: context.l10n.unknown,
        );
        _phase = _InvitationPhase.preview;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _join() async {
    if (_phase != _InvitationPhase.preview || !_isActorActive) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _InvitationPhase.joining);

    final repo = ref.read(householdRepositoryProvider);
    try {
      final data = await repo.acceptInvite(widget.token);
      if (!_isActorActive) return;
      final acceptedId = data['household_id'] as String?;
      if (data['success'] != true ||
          acceptedId == null ||
          acceptedId.trim().isEmpty) {
        throw Exception(data['error'] ?? 'Invalid invitation');
      }
      await _completeMembership(acceptedId);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _completeMembership(String householdId) async {
    ref.invalidate(householdMembersProvider(householdId));
    ref.invalidate(householdProvider(householdId));
    ref.invalidate(subscriptionNotifierProvider);
    ref.invalidate(subscriptionManagementProvider);
    await _refreshHouseholdList(householdId);
    if (!_isActorActive) return;
    HapticFeedback.lightImpact();
    setState(() {
      _householdId = householdId;
      _phase = _InvitationPhase.success;
    });
  }

  Future<void> _viewHousehold() async {
    final householdId = _householdId;
    if (!_isActorActive || householdId == null || _isSelecting) {
      return;
    }
    _isSelecting = true;
    try {
      await _refreshHouseholdList(householdId);
      if (!_isActorActive) return;
      await ref
          .read(selectedHouseholdProvider.notifier)
          .selectHousehold(householdId);
      if (!mounted || !_isActorActive) return;
      final selected = ref.read(selectedHouseholdProvider);
      if (!selected.hasSelection ||
          selected.householdId != householdId ||
          selected.error != null) {
        throw Exception(
            selected.error ?? context.l10n.invalidInvitationMissingInfo);
      }
      ref.read(viewModeProvider.notifier).setMode(ViewMode.household);

      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        Navigator.of(navCtx).pop();
        navCtx.go('/dashboard');
      }
    } catch (e) {
      _fail(e);
    } finally {
      _isSelecting = false;
    }
  }

  String _title(BuildContext context) => switch (_phase) {
        _InvitationPhase.loading ||
        _InvitationPhase.preview =>
          context.l10n.invitationReviewTitle,
        _InvitationPhase.joining => context.l10n.joiningHousehold,
        _InvitationPhase.success => context.l10n.youreIn,
        _InvitationPhase.error => context.l10n.invitationError,
      };

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserIdProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isJoining = _phase == _InvitationPhase.joining;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final transition =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 250);

    return PopScope(
      // Keep the sheet up while the join request is in flight. PopScope covers
      // back and barrier taps; the modal sheet's drag-to-dismiss pops directly,
      // so a child drag recognizer claims vertical drags while joining.
      canPop: !isJoining,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: isJoining ? (_) {} : null,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: transition,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [...previous, if (current != null) current],
                      ),
                      child: Text(
                        _title(context),
                        key: ValueKey(_phase == _InvitationPhase.loading
                            ? _InvitationPhase.preview
                            : _phase),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: transition,
                    opacity: isJoining ? 0 : 1,
                    child: IconButton(
                      icon:
                          Icon(Icons.close, color: colorScheme.mutedForeground),
                      onPressed:
                          isJoining ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: transition,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: transition,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(_phase == _InvitationPhase.joining
                        ? _InvitationPhase.preview
                        : _phase),
                    child: _buildBody(context, colorScheme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    return switch (_phase) {
      _InvitationPhase.loading => const _InvitationPreviewSkeleton(),
      _InvitationPhase.preview ||
      _InvitationPhase.joining =>
        _buildPreview(context, colorScheme),
      _InvitationPhase.success => _buildSuccess(context, colorScheme),
      _InvitationPhase.error => _buildError(context, colorScheme),
    };
  }

  Widget _buildPreview(BuildContext context, ColorScheme colorScheme) {
    final preview = _preview!;
    final isJoining = _phase == _InvitationPhase.joining;
    final message = preview.personalMessage;
    final expiresAt = preview.expiresAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HouseholdInvitePreviewCard(preview: preview),
        if (message != null) ...[
          const SizedBox(height: 12),
          HouseholdInviteMessageCard(message: message),
        ],
        if (expiresAt != null) ...[
          const SizedBox(height: 12),
          HouseholdInviteExpiryCard(expiresAt: expiresAt),
        ],
        const SizedBox(height: 24),
        Semantics(
          label: context.l10n.joinHouseholdName(preview.householdName),
          button: true,
          child: SizedBox(
            height: 52,
            child: PrimaryAdaptiveButton(
              onPressed: isJoining ? null : _join,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isJoining
                    ? SizedBox(
                        key: const ValueKey('joining'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary),
                        ),
                      )
                    : Text(
                        context.l10n.joinHouseholdName(preview.householdName),
                        key: const ValueKey('join'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isJoining ? 0.4 : 1,
          child: PlainAdaptiveButton(
            onPressed: isJoining ? null : () => Navigator.of(context).pop(),
            child: Text(context.l10n.notNow),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline,
                  color: colorScheme.errorAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error ?? context.l10n.invitationError,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryAdaptiveButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, ColorScheme colorScheme) {
    final householdName = _householdName ?? _preview?.householdName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.successSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.success, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  householdName != null
                      ? context.l10n.joinedHouseholdWithName(householdName)
                      : context.l10n.joinedHousehold,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryAdaptiveButton(
          onPressed: _viewHousehold,
          child: Text(context.l10n.viewHousehold),
        ),
        const SizedBox(height: 12),
        AdaptiveButton.child(
          onPressed: () => Navigator.of(context).pop(),
          style: AdaptiveButtonStyle.bordered,
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

/// Reserves the preview geometry while the invitation is validated.
class _InvitationPreviewSkeleton extends StatelessWidget {
  const _InvitationPreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.processingInvitation,
      liveRegion: true,
      child: Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(
          baseColor: colorScheme.skeletonBase,
          highlightColor: colorScheme.skeletonHighlight,
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HouseholdInvitePreviewCard(
                preview: HouseholdInvitePreviewData(
                  householdName: 'Household name',
                  inviterLabel: 'Inviter name',
                ),
              ),
              const SizedBox(height: 24),
              Bone(
                height: 52,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(height: 16),
              const Center(child: Bone.text(words: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show household invitation sheet
Future<void> showHouseholdInvitationSheet(
  BuildContext context, {
  required String token,
}) {
  // The shared sheet supplies the drag handle and shell. Title and close stay
  // inside the sheet because they change per phase (and hide while joining).
  return MonekoBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.card,
    builder: (context) => HouseholdInvitationSheet(token: token),
  );
}

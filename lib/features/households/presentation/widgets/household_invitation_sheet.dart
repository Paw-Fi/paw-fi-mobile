import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

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

class _HouseholdInvitationSheetState
    extends ConsumerState<HouseholdInvitationSheet> {
  String? _error;
  bool _accepted = false;
  String? _householdId;
  String? _householdName;
  bool _isProcessing = true;
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
        _accepted = false;
        _isProcessing = false;
        _error = context.l10n.invitationError;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _acceptInvite();
    });
  }

  bool get _isActorActive =>
      mounted &&
      !_actorChanged &&
      _actorUserId != null &&
      _actorUserId!.isNotEmpty &&
      ref.read(currentUserIdProvider) == _actorUserId;

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

  Future<void> _acceptInvite() async {
    if (!mounted) return;
    if (!_isActorActive) {
      setState(() {
        _error = context.l10n.invitationError;
        _isProcessing = false;
      });
      return;
    }

    final repo = ref.read(householdRepositoryProvider);
    try {
      final validateResponse = await repo.validateInvite(widget.token);
      if (!mounted || !_isActorActive) return;

      var householdId = validateResponse['household']?['id'] as String?;
      final householdName = validateResponse['household']?['name'] as String?;
      final errorCode =
          (validateResponse['error_code'] ?? '').toString().toUpperCase();

      if (householdId == null || householdId.trim().isEmpty) {
        throw Exception(validateResponse['error'] ??
            context.l10n.invalidInvitationMissingInfo);
      }
      if (errorCode != 'ALREADY_MEMBER') {
        if (validateResponse['valid'] != true) {
          throw Exception(validateResponse['error'] ?? 'Invalid invitation');
        }
        final data = await repo.acceptInvite(widget.token);
        if (!_isActorActive) return;
        final acceptedId = data['household_id'] as String?;
        if (data['success'] != true ||
            acceptedId == null ||
            acceptedId.trim().isEmpty) {
          throw Exception(data['error'] ?? 'Invalid invitation');
        }
        householdId = acceptedId;
      }

      ref.invalidate(householdMembersProvider(householdId));
      ref.invalidate(householdProvider(householdId));
      ref.invalidate(subscriptionNotifierProvider);
      ref.invalidate(subscriptionManagementProvider);
      await _refreshHouseholdList(householdId);
      if (!_isActorActive) return;
      setState(() {
        _accepted = true;
        _householdId = householdId;
        _householdName = householdName;
        _isProcessing = false;
      });
    } catch (e) {
      if (!_isActorActive) return;
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserIdProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final errorBase = colorScheme.errorAccent;
    final successBase = colorScheme.success;
    final errorBackground = colorScheme.errorSurface;
    final successBackground = colorScheme.successSurface;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _accepted
                    ? context.l10n.youreIn
                    : _error != null
                        ? context.l10n.invitationError
                        : context.l10n.joiningHousehold,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              if (!_isProcessing)
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Processing state
          if (_isProcessing) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(
              child: Text(
                context.l10n.processingInvitation,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Error state
          if (_error != null && !_isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorBase, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
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

          // Success state
          if (_accepted && !_isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: successBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: successBase, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _householdName != null
                          ? context.l10n
                              .joinedHouseholdWithName(_householdName!)
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
              onPressed: () async {
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
                  if (!context.mounted || !_isActorActive) return;
                  final selected = ref.read(selectedHouseholdProvider);
                  if (!selected.hasSelection ||
                      selected.householdId != householdId ||
                      selected.error != null) {
                    throw Exception(selected.error ??
                        context.l10n.invalidInvitationMissingInfo);
                  }
                  ref
                      .read(viewModeProvider.notifier)
                      .setMode(ViewMode.household);

                  final navCtx = rootNavigatorKey.currentContext;
                  if (navCtx != null && navCtx.mounted) {
                    Navigator.of(navCtx).pop();
                    navCtx.go('/dashboard');
                  }
                } catch (e) {
                  if (!_isActorActive) return;
                  setState(() {
                    _accepted = false;
                    _error = e.toString();
                  });
                } finally {
                  _isSelecting = false;
                }
              },
              child: Text(context.l10n.viewHousehold),
            ),
            const SizedBox(height: 12),
            AdaptiveButton.child(
              onPressed: () => Navigator.of(context).pop(),
              style: AdaptiveButtonStyle.bordered,
              child: Text(context.l10n.close),
            ),
          ],
        ],
      ),
    );
  }
}

/// Show household invitation sheet
Future<void> showHouseholdInvitationSheet(
  BuildContext context, {
  required String token,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(
          alpha: 0.0,
        ),
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: HouseholdInvitationSheet(token: token),
      );
    },
  );
}

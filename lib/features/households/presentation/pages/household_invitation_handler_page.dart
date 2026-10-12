import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';

class HouseholdInvitationHandlerPage extends ConsumerStatefulWidget {
  final String token;

  const HouseholdInvitationHandlerPage({super.key, required this.token});

  @override
  ConsumerState<HouseholdInvitationHandlerPage> createState() =>
      _HouseholdInvitationHandlerPageState();
}

class _HouseholdInvitationHandlerPageState
    extends ConsumerState<HouseholdInvitationHandlerPage> {
  String? _error;
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
      setState(() => _error = context.l10n.invitationError);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptInvite());
  }

  bool get _isActorActive =>
      mounted &&
      !_actorChanged &&
      _actorUserId != null &&
      _actorUserId!.isNotEmpty &&
      ref.read(currentUserIdProvider) == _actorUserId;

  Future<void> _acceptInvite() async {
    if (!mounted) return;
    if (!_isActorActive) {
      setState(() => _error = context.l10n.invitationError);
      return;
    }
    final repo = ref.read(householdRepositoryProvider);
    try {
      final validateResponse = await repo.validateInvite(widget.token);
      if (!mounted || !_isActorActive) return;

      var householdId = validateResponse['household']?['id'] as String?;
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
      // Refresh in place so the confirmed cached list stays visible.
      final households = userHouseholdsProvider(_actorUserId!);
      final notifier = ref.read(households.notifier);
      await notifier.load();
      if (!_isActorActive) return;
      if (!(ref.read(households).valueOrNull ?? const [])
          .any((household) => household.id == householdId)) {
        // A coalesced read may have started before membership was committed.
        await notifier.load();
      }
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
      context.go('/dashboard');
    } catch (e) {
      if (!_isActorActive) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentUserIdProvider);
    final colors = Theme.of(context).colorScheme;

    if (_error != null) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.destructive),
                const SizedBox(height: 12),
                Text('Invitation error',
                    style: TextStyle(
                        color: colors.foreground, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(color: colors.mutedForeground),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.l10n.joiningHousehold,
                style: TextStyle(color: colors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

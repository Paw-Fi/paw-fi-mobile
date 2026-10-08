import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _accepted = false;
  String? _householdId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptInvite());
  }

  Future<void> _acceptInvite() async {
    final repo = ref.read(householdRepositoryProvider);
    try {
      // First, validate the invite to get household_id
      // This avoids trying to re-accept an already accepted invite

      final validateResponse = await repo.validateInvite(widget.token);

      final householdId = validateResponse['household']?['id'] as String?;
      final errorCode =
          (validateResponse['error_code'] ?? '').toString().toUpperCase();

      // Treat ALREADY_MEMBER as success even if valid=false
      if (errorCode == 'ALREADY_MEMBER' && householdId != null) {
        setState(() {
          _accepted = true;
          _householdId = householdId;
        });
        return;
      }

      if (validateResponse['valid'] == true) {
        if (householdId != null) {
          // Invite is valid and not already accepted, proceed to accept
          try {
            final data = await repo.acceptInvite(widget.token);

            setState(() {
              _accepted = true;
              _householdId = data['household_id'] as String? ?? householdId;
            });
          } catch (e) {
            // If accept fails with 409 (already member), still navigate
            if (e.toString().contains('409') ||
                e.toString().contains('already')) {
              setState(() {
                _accepted = true;
                _householdId = householdId;
              });
            } else {
              rethrow;
            }
          }
        } else {
          setState(() =>
              _error = 'Invalid invitation: missing household information');
        }
      } else {
        // Validation failed
        final errorMsg =
            validateResponse['error'] as String? ?? 'Invalid invitation';

        setState(() => _error = errorMsg);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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

    if (_accepted && _householdId != null) {
      // Navigate to home page with household mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
            ref
                .read(selectedHouseholdProvider.notifier)
                .selectHousehold(_householdId!);
            context.go('/dashboard');
          }
        }
      });
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

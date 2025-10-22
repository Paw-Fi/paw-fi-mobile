import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/repositories/household_repository.dart';
import '../providers/household_providers.dart';
import 'household_overview_page.dart';

class HouseholdInvitationHandlerPage extends ConsumerStatefulWidget {
  final String token;

  const HouseholdInvitationHandlerPage({super.key, required this.token});

  @override
  ConsumerState<HouseholdInvitationHandlerPage> createState() => _HouseholdInvitationHandlerPageState();
}

class _HouseholdInvitationHandlerPageState extends ConsumerState<HouseholdInvitationHandlerPage> {
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

      if (validateResponse != null && validateResponse['valid'] == true) {
        final householdId = validateResponse['household']?['id'] as String?;

        if (householdId != null) {
          // Check error code for already-member case
          final errorCode = validateResponse['error_code'] as String?;

          if (errorCode == 'ALREADY_MEMBER') {
            // User is already a member, just navigate to the household
            setState(() {
              _accepted = true;
              _householdId = householdId;
            });
            return;
          }

          // Invite is valid and not already accepted, proceed to accept
          try {
            final data = await repo.acceptInvite(widget.token);
            setState(() {
              _accepted = true;
              _householdId = data['household_id'] as String? ?? householdId;
            });
          } catch (e) {
            // If accept fails with 409 (already member), still navigate
            if (e.toString().contains('409') || e.toString().contains('already')) {
              setState(() {
                _accepted = true;
                _householdId = householdId;
              });
            } else {
              rethrow;
            }
          }
        } else {
          setState(() => _error = 'Invalid invitation: missing household information');
        }
      } else {
        // Validation failed
        final errorMsg = validateResponse?['error'] as String? ?? 'Invalid invitation';
        setState(() => _error = errorMsg);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = shadcnui.Theme.of(context).colorScheme;

    if (_error != null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.destructive),
                const SizedBox(height: 12),
                Text('Invitation error', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.mutedForeground), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    if (_accepted && _householdId != null) {
      // Navigate to overview
      return HouseholdOverviewPage(householdId: _householdId!);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Joining household...', style: TextStyle(color: colors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

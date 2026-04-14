import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🏠 [HouseholdInvitationSheet] Initializing with token: ${widget.token}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptInvite());
  }

  /// Helper method to refresh the household list for the current user
  /// This is called whenever a user joins or is already a member of a household
  /// to ensure the UI reflects the latest state
  Future<void> _refreshHouseholdList() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await ref.read(userHouseholdsProvider(userId).notifier).load();
      debugPrint(
          '✅ [HouseholdInvitationSheet] Household list refreshed successfully');
    } catch (e) {
      debugPrint(
          '⚠️ [HouseholdInvitationSheet] Failed to refresh household list: $e');
      // Continue anyway - this is not a critical failure
    }
  }

  Future<void> _acceptInvite() async {
    debugPrint(
        '🏠 [HouseholdInvitationSheet] Starting invitation acceptance flow');
    final repo = ref.read(householdRepositoryProvider);
    try {
      // First, validate the invite to get household_id
      debugPrint('🏠 [HouseholdInvitationSheet] Validating invitation...');
      final validateResponse = await repo.validateInvite(widget.token);
      debugPrint(
          '🏠 [HouseholdInvitationSheet] Validation response: $validateResponse');

      final householdId = validateResponse['household']?['id'] as String?;
      final householdName = validateResponse['household']?['name'] as String?;
      final errorCode =
          (validateResponse['error_code'] ?? '').toString().toUpperCase();

      // Treat ALREADY_MEMBER as success even if valid=false
      if (errorCode == 'ALREADY_MEMBER' && householdId != null) {
        debugPrint(
            '🏠 [HouseholdInvitationSheet] User already a member, showing success');

        // Ensure household list is refreshed even if already a member
        // This handles cases where the household might not be in the local cache
        await _refreshHouseholdList();

        setState(() {
          _accepted = true;
          _householdId = householdId;
          _householdName = householdName;
          _isProcessing = false;
        });
        return;
      }

      if (validateResponse['valid'] == true) {
        if (householdId != null) {
          // Invite is valid and not already accepted, proceed to accept
          try {
            debugPrint('🏠 [HouseholdInvitationSheet] Accepting invitation...');
            final data = await repo.acceptInvite(widget.token);
            debugPrint(
                '🏠 [HouseholdInvitationSheet] Successfully accepted! Household ID: ${data['household_id']}');
            setState(() {
              _accepted = true;
              _householdId = data['household_id'] as String? ?? householdId;
              _householdName = householdName;
              _isProcessing = false;
            });
          } catch (e) {
            // If accept fails with 409 (already member), still show success
            if (e.toString().contains('409') ||
                e.toString().contains('already')) {
              debugPrint(
                  '🏠 [HouseholdInvitationSheet] Already a member (from accept call), showing success anyway');

              // Refresh household list to ensure consistency
              await _refreshHouseholdList();

              setState(() {
                _accepted = true;
                _householdId = householdId;
                _householdName = householdName;
                _isProcessing = false;
              });
            } else {
              debugPrint(
                  '❌ [HouseholdInvitationSheet] Error accepting invite: $e');
              rethrow;
            }
          }
        } else {
          debugPrint(
              '❌ [HouseholdInvitationSheet] Missing household ID in validation response');
          setState(() {
            _error = context.l10n.invalidInvitationMissingInfo;
            _isProcessing = false;
          });
        }
      } else {
        // Validation failed
        final errorMsg =
            validateResponse['error'] as String? ?? 'Invalid invitation';
        debugPrint('❌ [HouseholdInvitationSheet] Validation failed: $errorMsg');
        setState(() {
          _error = errorMsg;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint(
          '❌ [HouseholdInvitationSheet] Exception during invitation flow: $e');
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                final userId = Supabase.instance.client.auth.currentUser?.id;
                final householdId = _householdId;

                if (householdId == null || userId == null) {
                  // If no household ID or user ID, just close the sheet
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  return;
                }

                // Refresh household list to include the newly joined household
                await ref.read(userHouseholdsProvider(userId).notifier).load();

                // Switch to household mode and set the selected household
                // This will show the "For Us" view with the household selected
                ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
                await ref
                    .read(selectedHouseholdProvider.notifier)
                    .selectHousehold(householdId);

                // Close the bottom sheet and navigate using the root navigator
                // Use root navigator directly to avoid context issues
                final navCtx = rootNavigatorKey.currentContext;
                if (navCtx != null && navCtx.mounted) {
                  Navigator.of(navCtx).pop();
                  navCtx.go('/dashboard');
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

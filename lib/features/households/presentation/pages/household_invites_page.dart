import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';

/// Household Invites Management Page
/// Create, view, copy, and revoke invitations
class HouseholdInvitesPage extends ConsumerStatefulWidget {
  final String householdId;

  const HouseholdInvitesPage({
    super.key,
    required this.householdId,
  });

  @override
  ConsumerState<HouseholdInvitesPage> createState() => _HouseholdInvitesPageState();
}

class _HouseholdInvitesPageState extends ConsumerState<HouseholdInvitesPage> {
  List<HouseholdInvite> _invites = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(householdRepositoryProvider);
      final invites = await repository.getHouseholdInvites(widget.householdId);
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invites: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Invitations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvites,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Create Invite Button
                  shadcnui.PrimaryButton(
                    onPressed: () => _showCreateInviteDialog(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Create Invitation'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Invites List
                  Text(
                    'Pending Invitations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_invites.where((i) => i.status == InviteStatus.pending).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No pending invitations',
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    )
                  else
                    ..._invites
                        .where((i) => i.status == InviteStatus.pending)
                        .map((invite) => _InviteCard(
                              invite: invite,
                              onCopy: () => _copyInviteLink(invite),
                              onRevoke: () => _revokeInvite(invite),
                            )),

                  const SizedBox(height: 24),
                  Text(
                    'Invitation History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_invites.where((i) => i.status != InviteStatus.pending).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No invitation history',
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    )
                  else
                    ..._invites
                        .where((i) => i.status != InviteStatus.pending)
                        .map((invite) => _InviteCard(
                              invite: invite,
                              onCopy: null,
                              onRevoke: null,
                            )),
                ],
              ),
            ),
    );
  }

  void _showCreateInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    int expiresInDays = 7;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Invitation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'friend@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Personal Message (optional)',
                  hintText: 'Join our household budget!',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: expiresInDays,
                decoration: const InputDecoration(labelText: 'Expires In'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                ],
                onChanged: (value) {
                  if (value != null) expiresInDays = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _createInvite(
                email: emailController.text.isNotEmpty ? emailController.text : null,
                message: messageController.text.isNotEmpty ? messageController.text : null,
                expiresInDays: expiresInDays,
              );
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvite({
    String? email,
    String? message,
    required int expiresInDays,
  }) async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final token = await repository.createInvite(
        householdId: widget.householdId,
        invitedEmail: email,
        personalMessage: message,
        expiresInDays: expiresInDays,
      );

      await _loadInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation created successfully!')),
        );

        // Automatically copy the invite link
        final inviteUrl = 'https://moneko.app/invites/$token';
        Clipboard.setData(ClipboardData(text: inviteUrl));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite link copied to clipboard!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating invite: $e')),
        );
      }
    }
  }

  void _copyInviteLink(HouseholdInvite invite) {
    final inviteUrl = 'https://moneko.app/invites/${invite.token}';
    Clipboard.setData(ClipboardData(text: inviteUrl));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _revokeInvite(HouseholdInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Invitation'),
        content: const Text('Are you sure you want to revoke this invitation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(householdRepositoryProvider);
        await repository.revokeInvite(inviteId: invite.id);
        await _loadInvites();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation revoked')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking invite: $e')),
          );
        }
      }
    }
  }
}

/// Invite Card Widget
class _InviteCard extends StatelessWidget {
  final HouseholdInvite invite;
  final VoidCallback? onCopy;
  final VoidCallback? onRevoke;

  const _InviteCard({
    required this.invite,
    this.onCopy,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final isExpired = invite.expiresAt.isBefore(DateTime.now());
    final isPending = invite.status == InviteStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    invite.invitedEmail ?? 'Anyone with link',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(status: invite.status, isExpired: isExpired),
              ],
            ),
            if (invite.personalMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                invite.personalMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: colorScheme.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  isExpired
                      ? 'Expired ${_formatDate(invite.expiresAt)}'
                      : 'Expires ${_formatDate(invite.expiresAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            if (isPending && !isExpired && (onCopy != null || onRevoke != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onCopy != null)
                    Expanded(
                      child: shadcnui.OutlineButton(
                        onPressed: onCopy,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 16),
                            SizedBox(width: 8),
                            Text('Copy Link'),
                          ],
                        ),
                      ),
                    ),
                  if (onCopy != null && onRevoke != null) const SizedBox(width: 8),
                  if (onRevoke != null)
                    Expanded(
                      child: shadcnui.DestructiveButton(
                        onPressed: onRevoke,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel, size: 16),
                            SizedBox(width: 8),
                            Text('Revoke'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 0) {
      return '${difference.inDays.abs()} day${difference.inDays.abs() > 1 ? 's' : ''} ago';
    }
    return 'soon';
  }
}

/// Status Badge Widget
class _StatusBadge extends StatelessWidget {
  final InviteStatus status;
  final bool isExpired;

  const _StatusBadge({
    required this.status,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final text = isExpired ? 'EXPIRED' : status.toJson().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (isExpired) return Colors.red;

    return switch (status) {
      InviteStatus.pending => Colors.orange,
      InviteStatus.accepted => Colors.green,
      InviteStatus.revoked => Colors.red,
      InviteStatus.expired => Colors.grey,
    };
  }
}

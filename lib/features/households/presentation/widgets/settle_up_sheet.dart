import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../providers/household_providers.dart';

/// Bottom sheet for settling up balances
class SettleUpSheet extends ConsumerStatefulWidget {
  final String householdId;
  final String? specificMemberId; // If settling with specific member
  final double? amount; // Specific amount to settle

  const SettleUpSheet({
    super.key,
    required this.householdId,
    this.specificMemberId,
    this.amount,
  });

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  String? _selectedMemberId;
  bool _isProcessing = false;
  int? _unsettledCents; // Computed pair-wise unsettled amount (current user -> member)

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
    // Initial load of unsettled amount if member preselected
    if (_selectedMemberId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnsettled());
    }
  }

  Future<void> _loadUnsettled() async {
    final memberId = _selectedMemberId;
    if (memberId == null) return;

    try {
      final service = ref.read(householdServiceProvider);
      final cents = await service.getUnsettledAmountToMember(
        householdId: widget.householdId,
        memberUserId: memberId,
      );
      if (mounted) setState(() => _unsettledCents = cents);
    } catch (_) {
      if (mounted) setState(() => _unsettledCents = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final membersAsync = ref.watch(householdMembersProvider(widget.householdId));
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            context.l10n.settleUp,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.markExpensesAsSettled,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),

          // Member selector (if not specified)
          if (widget.specificMemberId == null)
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                child: Text('Error loading members', style: TextStyle(color: colorScheme.destructive)),
              ),
              data: (members) {
                final items = members
                    .where((m) => m.userId != userId)
                    .map((m) => DropdownMenuItem<String>(
                          value: m.userId,
                          child: Text(m.userName ?? m.userEmail ?? 'Member'),
                        ))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.whoAreYouSettlingWith,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedMemberId,
                      decoration: InputDecoration(
                        labelText: context.l10n.selectMember,
                        border: const OutlineInputBorder(),
                      ),
                      items: items,
                      onChanged: (value) async {
                        setState(() {
                          _selectedMemberId = value;
                          _unsettledCents = null;
                        });
                        await _loadUnsettled();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

          // Amount display (prefer live computed unsettled -> fallback to provided amount)
          Builder(builder: (context) {
            final cents = _unsettledCents;
            final amountToShow = cents != null
                ? (cents / 100.0)
                : (widget.amount != null ? widget.amount! : null);
            if (amountToShow == null) return const SizedBox.shrink();
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.amountToSettle,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      Text(
                        '\$${amountToShow.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),

          // Settlement options
          Text(
            context.l10n.howDidYouSettle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          _SettlementOption(
            icon: Icons.payments,
            title: context.l10n.cash,
            subtitle: context.l10n.paidInCash,
            onTap: () => _handleSettle('cash'),
          ),
          const SizedBox(height: 8),
          _SettlementOption(
            icon: Icons.account_balance,
            title: context.l10n.bankTransfer,
            subtitle: context.l10n.transferredViaBank,
            onTap: () => _handleSettle('bank_transfer'),
          ),
          const SizedBox(height: 8),
          _SettlementOption(
            icon: Icons.phone_android,
            title: context.l10n.mobilePayment,
            subtitle: context.l10n.venmoPaypalEtc,
            onTap: () => _handleSettle('mobile_payment'),
          ),
          const SizedBox(height: 8),
          _SettlementOption(
            icon: Icons.handshake,
            title: 'Other',
            subtitle: 'Settled in another way',
            onTap: () => _handleSettle('other'),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: shadcnui.SecondaryButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSettle(String method) async {
    if (_selectedMemberId == null && widget.specificMemberId == null) {
      // Show error
      if (mounted) {
        AppToast.info('Please select a member');
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final memberId = _selectedMemberId ?? widget.specificMemberId!;
      final service = ref.read(householdServiceProvider);
      final count = await service.settleAllDebtsToMember(
        householdId: widget.householdId,
        memberUserId: memberId,
      );
      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(count > 0 ? 'Settled via $method' : 'Nothing to settle');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Refresh amount preview
        await _loadUnsettled();
      }
    }
  }
}

class _SettlementOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettlementOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.foreground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

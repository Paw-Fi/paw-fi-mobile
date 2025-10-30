import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../../../../core/l10n/l10n.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.specificMemberId;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

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
          if (widget.specificMemberId == null) ...[
            Text(
              context.l10n.whoAreYouSettlingWith,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 12),
            // In real app, fetch household members and show selector
            DropdownButtonFormField<String>(
              value: _selectedMemberId,
              decoration: InputDecoration(
                labelText: context.l10n.selectMember,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'user1', child: Text('John Doe')),
                DropdownMenuItem(value: 'user2', child: Text('Jane Smith')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMemberId = value;
                });
              },
            ),
            const SizedBox(height: 24),
          ],

          // Amount display
          if (widget.amount != null) ...[
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
                    '\$${widget.amount!.toStringAsFixed(2)}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a member')),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // In real app:
      // 1. Find all unsettled split lines between current user and selected member
      // 2. Mark them as settled
      // 3. Optionally record settlement method
      // await ref.read(householdProvider).settleSplits(...)

      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settled via $method'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
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
                color: colorScheme.primary.withOpacity(0.1),
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

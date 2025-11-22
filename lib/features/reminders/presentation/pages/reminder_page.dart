import 'dart:ui';
import 'package:flutter/material.dart' hide Card, Divider, Switch;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';

class ReminderPage extends HookConsumerWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final showUpcomingPaychecks = useState(true);
    final showUpcomingBills = useState(true);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh reminder data - placeholder for now
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Main Title
                Text(
                  context.l10n.youveGotPaychecksIncomingAndBillsToPay,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),


                // Notification Setting
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.muted,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 18,
                          color: colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.notifyMeDaysBefore,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Upcoming Paychecks Section
                _buildExpandableSection(
                  colorScheme: colorScheme,
                  title: context.l10n.upcomingPaychecks,
                  isExpanded: showUpcomingPaychecks,
                  color: const Color(0xFF10B981),
                  child: Column(
                    children: [
                      _buildPaycheckCard(
                        colorScheme: colorScheme,
                        date: 'Sep 30',
                        title: context.l10n.paycheckFromWork,
                        amount: '\$2200.00',
                        isPositive: true,
                      ),
                      const SizedBox(height: 12),
                      _buildPaycheckCard(
                        colorScheme: colorScheme,
                        date: 'Oct 2',
                        title: context.l10n.freelanceProject,
                        amount: '\$800.00',
                        isPositive: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Upcoming Bills Section
                _buildExpandableSection(
                  colorScheme: colorScheme,
                  title: context.l10n.upcomingBills,
                  isExpanded: showUpcomingBills,
                  color: const Color(0xFFEF4444),
                  child: Column(
                    children: [
                      _buildPaycheckCard(
                        colorScheme: colorScheme,
                        date: 'Sep 28',
                        title: context.l10n.rentPayment,
                        amount: '\$1500.00',
                        isPositive: false,
                      ),
                      const SizedBox(height: 12),
                      _buildPaycheckCard(
                        colorScheme: colorScheme,
                        date: 'Oct 1',
                        title: context.l10n.electricityBill,
                        amount: '\$120.00',
                        isPositive: false,
                      ),
                    ],
                  ),
                ),

                  const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Blur overlay with "Coming in next phase" message
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: colorScheme.appBackground.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.border,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.comingInNextPhase,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.thisFeatureIsUnderDevelopment,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.mutedForeground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required ColorScheme colorScheme,
    required String title,
    required ValueNotifier<bool> isExpanded,
    required Color color,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => isExpanded.value = !isExpanded.value,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Icon(
                isExpanded.value ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: colorScheme.foreground,
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isExpanded.value) child,
      ],
    );
  }

  Widget _buildPaycheckCard({
    required ColorScheme colorScheme,
    required String date,
    required String title,
    required String amount,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPositive
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

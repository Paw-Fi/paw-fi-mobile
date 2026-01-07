import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:go_router/go_router.dart';
import '../dashboard_config.dart';

/// Pocket Health Scorecard Widget
/// Answers: "Which categories am I overspending in?"
class PocketHealthScorecardWidget extends ConsumerWidget {
  final List<PocketEnvelope> pockets;
  final double totalBudget;
  final String currency;
  final DashboardWidgetConfig config;

  const PocketHealthScorecardWidget({
    super.key,
    required this.pockets,
    required this.totalBudget,
    required this.currency,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Calculate health for each pocket
    final pocketHealthList = pockets.map((pocket) {
      final allocated = pocket.getLimit(totalBudget);
      final spent = pocket.spent;
      final healthRatio = allocated > 0 ? spent / allocated : 0.0;
      
      String status;
      Color statusColor;
      if (healthRatio > 1.0) {
        status = context.l10n.overBudget;
        statusColor = colorScheme.destructive;
      } else if (healthRatio > 0.85) {
        status = context.l10n.nearLimit;
        statusColor = AppTheme.warning;
      } else {
        status = context.l10n.onTrack;
        statusColor = AppTheme.success;
      }
      
      return {
        'pocket': pocket,
        'allocated': allocated,
        'spent': spent,
        'healthRatio': healthRatio,
        'status': status,
        'statusColor': statusColor,
      };
    }).toList();
    
    // Sort by health ratio (worst first)
    pocketHealthList.sort((a, b) => (b['healthRatio'] as double).compareTo(a['healthRatio'] as double));
    
    // Count how many are over budget
    final overBudgetCount = pocketHealthList.where((p) => (p['healthRatio'] as double) > 1.0).length;

    return GestureDetector(
      onTap: () {
        context.push('/widget-details', extra: {
          'widgetType': 'pocketHealthScorecard',
          'config': config,
          'currency': currency,
        });
      },
      child: Card(
        color: colorScheme.cardSurface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.pocketHealth,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (overBudgetCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.destructive.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$overBudgetCount ${context.l10n.over}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.destructive,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Pocket mini cards (show top 3)
              if (pocketHealthList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      context.l10n.noPocketsYet,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                )
              else
                ...pocketHealthList.take(3).map((pocketData) {
                  final pocket = pocketData['pocket'] as PocketEnvelope;
                  final allocated = pocketData['allocated'] as double;
                  final spent = pocketData['spent'] as double;
                  final healthRatio = pocketData['healthRatio'] as double;
                  final status = pocketData['status'] as String;
                  final statusColor = pocketData['statusColor'] as Color;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pocket.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatCurrency(spent, currency),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              Text(
                                formatCurrency(allocated, currency),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: healthRatio.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

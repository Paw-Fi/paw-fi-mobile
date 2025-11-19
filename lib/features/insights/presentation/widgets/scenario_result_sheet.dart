import 'package:flutter/material.dart';

import 'package:markdown_widget/markdown_widget.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/theme/app_theme.dart';
/// Helper to safely convert dynamic value to double
double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

/// Shows scenario analysis result bottom sheet
void showScenarioResultSheet(
  BuildContext context,
  String advice,
  Map<String, dynamic> meta, {
  String? selectedCurrency,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  
  // Use correct currency symbol based on selection
  final String currencySymbol;
  if (selectedCurrency != null) {
    currencySymbol = resolveCurrencySymbol(selectedCurrency);
  } else {
    // Mixed mode - no single symbol
    currencySymbol = '';
  }
  
  // Safely extract stats map and values
  final Map<String, dynamic>? stats = (meta['stats'] as Map?)?.cast<String, dynamic>();
  final curr = _asDouble(stats?['currentRunningBalance']);
  final proj = _asDouble(stats?['projectedNoScenarioByTarget']);
  final avg = _asDouble(stats?['avgNetPerDay']);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.mutedForeground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.scenarioAnalysis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.foreground),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Date Badge
                    if (meta['targetDate'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${context.l10n.target}: ${meta['targetDate']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // AI Advice (parsed from markdown)
                    MarkdownBlock(
                      data: advice,
                      config: MarkdownConfig(
                        configs: [
                          PConfig(
                            textStyle: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: colorScheme.foreground,
                            ),
                          ),
                          H1Config(
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          H2Config(
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          H3Config(
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          CodeConfig(
                            style: TextStyle(
                              backgroundColor: colorScheme.muted,
                              fontFamily: 'monospace',
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats Section
                    if (meta['stats'] != null) ...[
                      Text(
                        context.l10n.quickStats,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(context, colorScheme, context.l10n.currentBalance, '$currencySymbol${curr.toStringAsFixed(2)}'),
                      _buildStatRow(context, colorScheme, context.l10n.projectedNoChange, '$currencySymbol${proj.toStringAsFixed(2)}'),
                      _buildStatRow(context, colorScheme, context.l10n.avgDailyNet, '$currencySymbol${avg.toStringAsFixed(2)}'),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildStatRow(BuildContext context, ColorScheme colorScheme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ],
    ),
  );
}

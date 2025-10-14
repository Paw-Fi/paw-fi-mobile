import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:markdown_widget/markdown_widget.dart';

/// Shows scenario analysis result bottom sheet
void showScenarioResultSheet(
  BuildContext context,
  String advice,
  Map<String, dynamic> meta,
) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;

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
          color: colorScheme.background,
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
                      'Scenario Analysis',
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
                          'Target: ${meta['targetDate']}',
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
                        'Quick Stats',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(colorScheme, 'Current Balance', '\$${meta['stats']['currentRunningBalance']?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildStatRow(colorScheme, 'Projected (No Change)', '\$${meta['stats']['projectedNoScenarioByTarget']?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildStatRow(colorScheme, 'Avg Daily Net', '\$${meta['stats']['avgNetPerDay']?.toStringAsFixed(2) ?? '0.00'}'),
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

Widget _buildStatRow(shadcnui.ColorScheme colorScheme, String label, String value) {
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

import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget buildLongTermProjectionTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.border, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Long-Term Projection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.help_outline, size: 16, color: colorScheme.mutedForeground),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Based on historical averages; updates automatically with your data.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildLongTermProjectionChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': '18-Month Projection', 'color': const Color(0xFF10B981)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget buildRunningBalanceTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
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
                    'Running & Daily Balances',
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
                'Budget vs Spent per day with cumulative running balance.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: buildRunningBalanceChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': 'Running Balance', 'color': const Color(0xFF8B5CF6)},
                  {'label': 'Budget', 'color': const Color(0xFF3B82F6)},
                  {'label': 'Spent', 'color': const Color(0xFFEF4444)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

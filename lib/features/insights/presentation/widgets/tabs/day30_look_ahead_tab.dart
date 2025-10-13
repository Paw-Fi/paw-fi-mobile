import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';
import 'package:moneko/features/insights/presentation/widgets/chart_legend.dart';

Widget build30DayLookAheadTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
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
                    '30-Day Look-Ahead',
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
                'Projected from trailing 30-day averages.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: build30DayProjectionChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
              ),
              const SizedBox(height: 16),
              buildChartLegend(
                colorScheme,
                [
                  {'label': 'Projected Spending', 'color': const Color(0xFF10B981)},
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

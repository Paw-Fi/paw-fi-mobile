import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildChartLegend(
    ColorScheme colorScheme, List<Map<String, dynamic>> items) {
  return Wrap(
    spacing: 16,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: items.map((item) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: item['color'] as Color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item['label'] as String,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }).toList(),
  );
}

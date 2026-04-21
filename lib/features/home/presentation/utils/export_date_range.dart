import 'package:flutter/material.dart';

DateTime exportDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool isDateInExportRange(DateTime date, DateTimeRange range) {
  final dateOnly = exportDateOnly(date);
  final start = exportDateOnly(range.start);
  final end = exportDateOnly(range.end);
  return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
}

String formatExportDateRange(DateTimeRange range) {
  return '${formatExportDate(range.start)}..${formatExportDate(range.end)}';
}

String formatExportDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

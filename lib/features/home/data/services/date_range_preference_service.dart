import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing date range filter preferences in local storage
class DateRangePreferenceService {
  static const String _selectedDateRangeKey = 'selected_date_range_filter';
  static const String _customStartKey = 'custom_range_start';
  static const String _customEndKey = 'custom_range_end';

  // In-memory cache to reduce SharedPreferences reads
  String? _cachedSelected;

  /// Returns the stored date range filter identifier (enum name), or null if none
  Future<String?> getSelectedDateRange() async {
    if (_cachedSelected != null) return _cachedSelected;
    final prefs = await SharedPreferences.getInstance();
    _cachedSelected = prefs.getString(_selectedDateRangeKey);
    return _cachedSelected;
  }

  /// Persists the selected date range filter identifier (use enum name)
  Future<void> setSelectedDateRange(String filterName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDateRangeKey, filterName);
    _cachedSelected = filterName;
  }

  /// Optionally store custom range dates (ISO8601, date-only)
  Future<void> setCustomRange(DateTime start, DateTime end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customStartKey, _formatDate(start));
    await prefs.setString(_customEndKey, _formatDate(end));
  }

  /// Returns a map with 'start' and 'end' if a custom range exists; otherwise null
  Future<Map<String, DateTime>?> getCustomRange() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getString(_customStartKey);
    final end = prefs.getString(_customEndKey);
    if (start == null || end == null) return null;
    return {
      'start': DateTime.parse(start),
      'end': DateTime.parse(end),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedDateRangeKey);
    await prefs.remove(_customStartKey);
    await prefs.remove(_customEndKey);
    _cachedSelected = null;
  }

  String _formatDate(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;
}

/// Income summary model
/// Aggregated income statistics with privacy-aware breakdown

class IncomeSummary {
  final double totalIncome;
  final double? mtdIncome; // Month-to-date
  final double? ytdIncome; // Year-to-date
  final String currency;
  final Map<String, double> categoryBreakdown;
  final Map<String, CurrencyBreakdown>? currencyBreakdown;
  final Map<String, double>?
      memberBreakdown; // For household income (privacy-aware)
  final int transactionCount;
  final Period period;

  IncomeSummary({
    required this.totalIncome,
    this.mtdIncome,
    this.ytdIncome,
    required this.currency,
    required this.categoryBreakdown,
    this.currencyBreakdown,
    this.memberBreakdown,
    required this.transactionCount,
    required this.period,
  });

  factory IncomeSummary.fromJson(Map<String, dynamic> json) {
    final categoryBreakdownRaw =
        json['categoryBreakdown'] as Map<String, dynamic>?;
    final categoryBreakdown = categoryBreakdownRaw?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ??
        {};

    final currencyBreakdownRaw =
        json['currencyBreakdown'] as Map<String, dynamic>?;
    final currencyBreakdown = currencyBreakdownRaw?.map(
      (key, value) => MapEntry(
        key,
        CurrencyBreakdown.fromJson(value as Map<String, dynamic>),
      ),
    );

    final memberBreakdownRaw = json['memberBreakdown'] as Map<String, dynamic>?;
    final memberBreakdown = memberBreakdownRaw?.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return IncomeSummary(
      totalIncome: (json['totalIncome'] as num).toDouble(),
      mtdIncome: json['mtdIncome'] != null
          ? (json['mtdIncome'] as num).toDouble()
          : null,
      ytdIncome: json['ytdIncome'] != null
          ? (json['ytdIncome'] as num).toDouble()
          : null,
      currency: json['currency'] as String? ?? 'USD',
      categoryBreakdown: categoryBreakdown,
      currencyBreakdown: currencyBreakdown,
      memberBreakdown: memberBreakdown,
      transactionCount: json['transactionCount'] as int? ?? 0,
      period: Period.fromJson(json['period'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalIncome': totalIncome,
      'mtdIncome': mtdIncome,
      'ytdIncome': ytdIncome,
      'currency': currency,
      'categoryBreakdown': categoryBreakdown,
      'currencyBreakdown': currencyBreakdown?.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'memberBreakdown': memberBreakdown,
      'transactionCount': transactionCount,
      'period': period.toJson(),
    };
  }
}

/// Currency breakdown for multi-currency income
class CurrencyBreakdown {
  final int count;
  final double total;

  CurrencyBreakdown({
    required this.count,
    required this.total,
  });

  factory CurrencyBreakdown.fromJson(Map<String, dynamic> json) {
    return CurrencyBreakdown(
      count: json['count'] as int,
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'total': total,
    };
  }
}

/// Time period for income summary
class Period {
  final DateTime startDate;
  final DateTime endDate;

  Period({
    required this.startDate,
    required this.endDate,
  });

  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
    };
  }
}

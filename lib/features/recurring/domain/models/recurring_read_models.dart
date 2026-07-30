import 'package:flutter/foundation.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

@immutable
class RecurringReadScope {
  const RecurringReadScope({
    required this.userId,
    required this.householdId,
    required this.currencies,
  });

  final String userId;
  final String? householdId;
  final List<String> currencies;

  List<String> get normalizedCurrencies {
    final normalized = currencies
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      other is RecurringReadScope &&
      userId == other.userId &&
      householdId == other.householdId &&
      listEquals(normalizedCurrencies, other.normalizedCurrencies);

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        Object.hashAll(normalizedCurrencies),
      );
}

@immutable
class RecurringSeriesCursor {
  const RecurringSeriesCursor({
    required this.nextOccurrenceDate,
    required this.id,
  });

  final DateTime nextOccurrenceDate;
  final String id;

  factory RecurringSeriesCursor.fromJson(Map<String, dynamic> json) {
    return RecurringSeriesCursor(
      nextOccurrenceDate:
          DateTime.parse(json['next_occurrence_date'].toString()),
      id: json['id'].toString(),
    );
  }
}

@immutable
class RecurringSeriesSummary {
  const RecurringSeriesSummary({
    required this.transaction,
    required this.nextOccurrenceDate,
    required this.latestActionableOccurrenceDate,
    this.actionableCount = 0,
  });

  final RecurringTransaction transaction;
  final DateTime? nextOccurrenceDate;
  final DateTime? latestActionableOccurrenceDate;
  final int actionableCount;

  bool get hasActionableOccurrence => latestActionableOccurrenceDate != null;

  factory RecurringSeriesSummary.fromJson(Map<String, dynamic> json) {
    return RecurringSeriesSummary(
      transaction: RecurringTransaction.fromJson(json),
      nextOccurrenceDate: _parseNullableDate(json['next_occurrence_date']),
      latestActionableOccurrenceDate:
          _parseNullableDate(json['latest_actionable_occurrence_date']),
      actionableCount:
          ((json['actionable_count'] as num?)?.round() ?? 0).clamp(0, 1000000),
    );
  }
}

@immutable
class RecurringSeriesPage {
  const RecurringSeriesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RecurringSeriesSummary> items;
  final bool hasMore;
  final RecurringSeriesCursor? nextCursor;

  factory RecurringSeriesPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawCursor = json['next_cursor'];
    return RecurringSeriesPage(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => RecurringSeriesSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
      hasMore: json['has_more'] == true,
      nextCursor: rawCursor is Map
          ? RecurringSeriesCursor.fromJson(
              Map<String, dynamic>.from(rawCursor),
            )
          : null,
    );
  }
}

@immutable
class RecurringOccurrenceSummary {
  const RecurringOccurrenceSummary({
    required this.id,
    required this.recurringId,
    required this.scheduledOccurrenceDate,
    required this.status,
    required this.confirmationSource,
    required this.actualTransactionId,
    required this.paidDate,
    required this.amountCents,
    required this.currency,
    required this.confirmedAt,
    required this.confirmedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.wasSkippedBeforeConfirmation = false,
  });

  final String id;
  final String recurringId;
  final DateTime scheduledOccurrenceDate;
  final String status;
  final String? confirmationSource;
  final String? actualTransactionId;
  final DateTime? paidDate;
  final int? amountCents;
  final String? currency;
  final DateTime? confirmedAt;
  final String? confirmedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool wasSkippedBeforeConfirmation;

  bool get isConfirmed => status == 'confirmed';
  bool get isSkipped => status == 'skipped';

  factory RecurringOccurrenceSummary.fromJson(Map<String, dynamic> json) {
    return RecurringOccurrenceSummary(
      id: json['id'].toString(),
      recurringId: json['recurring_id'].toString(),
      scheduledOccurrenceDate:
          DateTime.parse(json['scheduled_occurrence_date'].toString()),
      status: json['status']?.toString() ?? 'pending',
      confirmationSource: json['confirmation_source']?.toString(),
      actualTransactionId: json['actual_transaction_id']?.toString(),
      paidDate: _parseNullableDate(json['paid_date']),
      amountCents: (json['amount_cents'] as num?)?.round(),
      currency: json['currency']?.toString(),
      confirmedAt: _parseNullableDate(json['confirmed_at']),
      confirmedByUserId: json['confirmed_by_user_id']?.toString(),
      createdAt: _parseNullableDate(json['created_at']),
      updatedAt: _parseNullableDate(json['updated_at']),
      wasSkippedBeforeConfirmation:
          json['was_skipped_before_confirmation'] == true,
    );
  }
}

@immutable
class RecurringOccurrencePage {
  const RecurringOccurrencePage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RecurringOccurrenceSummary> items;
  final bool hasMore;
  final DateTime? nextCursor;

  factory RecurringOccurrencePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return RecurringOccurrencePage(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => RecurringOccurrenceSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
      hasMore: json['has_more'] == true,
      nextCursor: _parseNullableDate(json['next_cursor']),
    );
  }
}

@immutable
class RecurringOccurrenceDetail {
  const RecurringOccurrenceDetail({
    required this.occurrence,
    required this.transaction,
    required this.splitGroup,
    required this.isSettlementLocked,
  });

  final RecurringOccurrenceSummary occurrence;
  final Map<String, dynamic>? transaction;
  final Map<String, dynamic>? splitGroup;
  final bool isSettlementLocked;

  factory RecurringOccurrenceDetail.fromJson(Map<String, dynamic> json) {
    return RecurringOccurrenceDetail(
      occurrence: RecurringOccurrenceSummary.fromJson(
        Map<String, dynamic>.from(json['occurrence'] as Map),
      ),
      transaction: _mapOrNull(json['transaction']),
      splitGroup: _mapOrNull(json['split_group']),
      isSettlementLocked: json['settlement_locked'] == true,
    );
  }
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : DateTime.tryParse(text);
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

import 'dart:convert';

import 'package:moneko/core/utils/user_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

bool _aiTimezonesInitialized = false;

timezone.Location? _aiTimezoneLocation(String zone) {
  if (!_aiTimezonesInitialized) {
    timezone_data.initializeTimeZones();
    _aiTimezonesInitialized = true;
  }
  return timezone.timeZoneDatabase.locations[zone];
}

DateTime aiAnalysisWallNow({String? preferredTimezone, DateTime? at}) {
  final instant = at ?? DateTime.now();
  final zone = preferredTimezone?.trim() ?? '';
  final offset = tryParseTimezoneOffsetMinutes(zone);
  if (offset != null) {
    return instant.toUtc().add(Duration(minutes: offset));
  }
  final location = zone.isEmpty ? null : _aiTimezoneLocation(zone);
  return location == null
      ? instant.toLocal()
      : timezone.TZDateTime.from(instant, location);
}

class AiClockIssue extends FormatException {
  const AiClockIssue(this.reason, {this.itemIndex = 0})
      : super('The requested clock needs clarification');
  final String reason;
  final int itemIndex;
  Map<String, dynamic> toJson() =>
      {'itemIndex': itemIndex, 'field': 'transactionTime', 'reason': reason};
}

DateTime resolveVerifiedAiClock(
    {required String date, required String time, String? preferredTimezone}) {
  final wall = DateTime.parse('${date}T${time}Z');
  final zone = preferredTimezone?.trim() ?? '';
  final offset = tryParseTimezoneOffsetMinutes(zone);
  if (offset != null) {
    if (offset.abs() > 840 ||
        (zone.contains(':') && int.parse(zone.split(':').last) > 59)) {
      throw const FormatException('Invalid configured timezone');
    }
    return wall.subtract(Duration(minutes: offset));
  }
  final location = zone.isEmpty ? null : _aiTimezoneLocation(zone);
  if (location == null) {
    if (zone.isNotEmpty) {
      throw const FormatException('Unknown configured timezone');
    }
    final local = DateTime(
        wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second);
    if (local.year != wall.year ||
        local.month != wall.month ||
        local.day != wall.day ||
        local.hour != wall.hour ||
        local.minute != wall.minute) {
      throw const AiClockIssue('nonexistent_wall_time');
    }
    return local.toUtc();
  }
  final candidates = <DateTime>{};
  for (final offset in location.zones.map((zone) => zone.offset).toSet()) {
    final candidate = wall.subtract(Duration(milliseconds: offset));
    final local = timezone.TZDateTime.from(candidate, location);
    if (local.year == wall.year &&
        local.month == wall.month &&
        local.day == wall.day &&
        local.hour == wall.hour &&
        local.minute == wall.minute &&
        local.second == wall.second) {
      candidates.add(candidate);
    }
  }
  if (candidates.length != 1) {
    throw AiClockIssue(
        candidates.isEmpty ? 'nonexistent_wall_time' : 'ambiguous_wall_time');
  }
  return candidates.single;
}

Future<Map<String, dynamic>?> runInteractiveAiAnalysis({
  required Map<String, dynamic> body,
  required Future<Map<String, dynamic>> Function(Map<String, dynamic>) invoke,
  required Future<String?> Function(AiAnalysisQuestion) ask,
  required Future<bool> Function(Object) retry,
  required bool Function() isActive,
  String? preferredTimezone,
}) async {
  final answers = <Map<String, String>>[];
  AiClockIssue? pendingClockIssue;
  while (isActive()) {
    Map<String, dynamic> response;
    Map<String, dynamic> data;
    try {
      response = await invoke({
        ...body,
        'interactive': {
          'version': 1,
          'answers': List.of(answers),
          if (pendingClockIssue != null)
            'clientIssue': pendingClockIssue.toJson()
        },
      });
      if (!isActive()) return null;
      if (response['success'] != true || response['data'] is! Map) {
        throw const FormatException('Unable to verify transaction details');
      }
      data = Map<String, dynamic>.from(response['data'] as Map);
      if (data['interactiveVersion'] != 1 ||
          data['requireCorrection'] is! bool) {
        throw const FormatException(
            'Interactive analysis is not available yet');
      }
      if (data['requireCorrection'] == false) {
        if (pendingClockIssue != null) {
          throw const FormatException(
              'The server did not clarify the unresolved clock');
        }
        if (data['preferredTimezone'] != null &&
            data['preferredTimezone'] is! String) {
          throw const FormatException('Invalid verified timezone');
        }
        final items = data['items'];
        if (items is! List ||
            items.isEmpty ||
            items.length > 40 ||
            items.any((item) => item is! Map)) {
          throw const FormatException('Missing verified transactions');
        }
        groupInteractiveAiItems(
            items
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
            preferredTimezone:
                data['preferredTimezone'] as String? ?? preferredTimezone);
        return response;
      }
      if (answers.length >= 12) {
        await retry(const FormatException(
            'Too many clarification answers; please start a new input'));
        return null;
      }
      if (data['items'] is! List || (data['items'] as List).isNotEmpty) {
        throw const FormatException(
            'Unresolved analysis contains transactions');
      }
      final question = AiAnalysisQuestion.fromJson(data['correction']);
      final answer = await ask(question);
      if (!isActive() || answer == null) return null;
      final normalized = answer.trim();
      if (normalized.isEmpty || normalized.length > 4000) {
        throw const FormatException('Invalid clarification answer');
      }
      answers.add({'question': question.question, 'answer': normalized});
      pendingClockIssue = null;
    } on AiClockIssue catch (issue) {
      pendingClockIssue = issue;
    } catch (error) {
      if (!isActive() || !await retry(error) || !isActive()) return null;
    }
  }
  return null;
}

Map<AiAnalysisDestination, List<Map<String, dynamic>>> groupInteractiveAiItems(
    List<Map<String, dynamic>> items,
    {String? preferredTimezone}) {
  final groups = <AiAnalysisDestination, List<Map<String, dynamic>>>{};
  if (items.isEmpty || items.length > 40) {
    throw const FormatException('Invalid verified transaction count');
  }
  for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
    final item = items[itemIndex];
    final amount = item['amount'];
    final date = tryParseDateOnlyYmd(item['date']?.toString());
    final currency = item['currency'];
    if (amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        (amount * 100).abs() > 9007199254740991 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.000001 ||
        date == null ||
        currency is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        !['expense', 'income'].contains(item['type']) ||
        item['category'] is! String ||
        (item['category'] as String).trim().isEmpty ||
        (item['transactionTime'] != null &&
            (item['transactionTime'] is! String ||
                !RegExp(r'^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$')
                    .hasMatch(item['transactionTime'] as String))) ||
        (item['payerUserId'] != null &&
            (item['payerUserId'] is! String ||
                (item['payerUserId'] as String).trim().isEmpty)) ||
        (item['isRecurring'] != null && item['isRecurring'] is! bool) ||
        (item['recurrence_rule'] != null && item['isRecurring'] != true) ||
        (item['isRecurring'] == true && item['transactionTime'] != null)) {
      throw const FormatException('Invalid verified transaction');
    }
    final target =
        AiAnalysisDestination.fromJson(item['destination'], currency);
    if (item['transactionTime'] != null) {
      try {
        resolveVerifiedAiClock(
            date: item['date'] as String,
            time: item['transactionTime'] as String,
            preferredTimezone: preferredTimezone);
      } on AiClockIssue catch (issue) {
        throw AiClockIssue(issue.reason, itemIndex: itemIndex);
      }
    }
    for (final field in ['description', 'merchant']) {
      final value = item[field];
      if (value != null &&
          (value is! String ||
              value.trim().isEmpty ||
              value.length > (field == 'merchant' ? 255 : 4000))) {
        throw const FormatException('Invalid verified text');
      }
    }
    if ((item['customSplits'] != null || item['payerUserId'] != null) &&
        (target.householdId == null || target.isPortfolio)) {
      throw const FormatException('Invalid verified household instructions');
    }
    if (item['isRecurring'] == true) {
      final rule = item['recurrence_rule'];
      if (rule is! Map ||
          !['daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom']
              .contains(rule['frequency']) ||
          rule['interval'] is! int ||
          (rule['interval'] as int) < 1 ||
          (rule['interval'] as int) > 365 ||
          rule['anchor_date'] != item['date'] ||
          (rule['end_date'] != null &&
              (tryParseDateOnlyYmd(rule['end_date']?.toString()) == null ||
                  (rule['end_date'] as String)
                          .compareTo(item['date'] as String) <
                      0))) {
        throw const FormatException('Invalid verified recurrence');
      }
    }
    if (item['customSplits'] != null) {
      _validateVerifiedSplit(item['customSplits'], amount);
    }
    groups.putIfAbsent(target, () => []).add(item);
  }
  return groups;
}

void _validateVerifiedSplit(Object? value, num total) {
  if (value is! Map ||
      !['equal', 'amount', 'percentage', 'shares']
          .contains(value['splitType']) ||
      value['memberSplits'] is! List ||
      (value['memberSplits'] as List).isEmpty) {
    throw const FormatException('Invalid verified split');
  }
  final members = <String>{};
  num sum = 0;
  final type = value['splitType'];
  final key = type == 'percentage'
      ? 'percentage'
      : type == 'shares'
          ? 'shares'
          : 'amount';
  for (final line in value['memberSplits'] as List) {
    if (line is! Map ||
        line['userId'] is! String ||
        (line['userId'] as String).trim().isEmpty ||
        !members.add(line['userId'] as String)) {
      throw const FormatException('Invalid verified split member');
    }
    if (type == 'equal') continue;
    final amount = line[key];
    if (amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        amount.abs() > 9007199254740991 ||
        (type == 'amount' && (amount * 100).abs() > 9007199254740991) ||
        (type == 'shares' && amount != amount.round()) ||
        (type == 'amount' &&
            (amount * 100 - (amount * 100).round()).abs() > 0.000001)) {
      throw const FormatException('Invalid verified allocation');
    }
    sum += type == 'amount' ? (amount * 100).round() : amount;
  }
  if ((type == 'amount' && sum != (total * 100).round()) ||
      (type == 'percentage' && (sum - 100).abs() > 0.000001) ||
      (type == 'shares' && sum <= 0)) {
    throw const FormatException('Invalid verified allocation total');
  }
}

class AiAnalysisQuestion {
  const AiAnalysisQuestion({required this.question, required this.choices});

  final String question;
  final List<String> choices;

  factory AiAnalysisQuestion.fromJson(Object? value) {
    if (value is! Map ||
        value['question'] is! String ||
        value['choices'] is! List ||
        value['allowCustomResponse'] != true) {
      throw const FormatException('Invalid clarification question');
    }
    final question = (value['question'] as String).trim();
    final rawChoices = value['choices'] as List;
    if (question.isEmpty ||
        question.length > 1200 ||
        rawChoices.length < 2 ||
        rawChoices.length > 4 ||
        rawChoices.any((choice) =>
            choice is! String ||
            choice.trim().isEmpty ||
            choice.length > 400)) {
      throw const FormatException('Invalid clarification choices');
    }
    final choices =
        rawChoices.cast<String>().map((choice) => choice.trim()).toList();
    if (choices.toSet().length != choices.length) {
      throw const FormatException('Duplicate clarification choices');
    }
    return AiAnalysisQuestion(question: question, choices: choices);
  }
}

class AiAnalysisDestination {
  const AiAnalysisDestination(
      {required this.householdId,
      required this.isPortfolio,
      required this.accountId,
      required this.accountCurrency,
      required this.spaceLabel});

  final String? householdId;
  final bool isPortfolio;
  final String? accountId;
  final String? accountCurrency;
  final String spaceLabel;

  factory AiAnalysisDestination.fromJson(Object? value, String currency) {
    if (value is! Map ||
        !value.containsKey('householdId') ||
        !value.containsKey('accountId') ||
        value['isPortfolio'] is! bool ||
        value['spaceLabel'] is! String) {
      throw const FormatException('Missing verified destination');
    }
    final householdId = value['householdId'];
    final accountId = value['accountId'];
    final accountCurrency = value['accountCurrency'];
    if ((householdId != null &&
            (householdId is! String || householdId.trim().isEmpty)) ||
        (accountId != null &&
            (accountId is! String ||
                accountId.trim().isEmpty ||
                accountCurrency != currency)) ||
        (accountId == null && accountCurrency != null) ||
        (householdId == null && value['isPortfolio'] == true)) {
      throw const FormatException('Invalid verified destination');
    }
    return AiAnalysisDestination(
        householdId: householdId as String?,
        isPortfolio: value['isPortfolio'] as bool,
        accountId: accountId as String?,
        accountCurrency: accountCurrency as String?,
        spaceLabel: value['spaceLabel'] as String);
  }

  String get key =>
      jsonEncode([householdId, isPortfolio, accountId, accountCurrency]);

  @override
  bool operator ==(Object other) =>
      other is AiAnalysisDestination && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

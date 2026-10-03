import 'dart:convert';

import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/core/utils/user_timezone.dart';

Future<Map<String, dynamic>?> runInteractiveAiAnalysis({
  required Map<String, dynamic> body,
  required Future<Map<String, dynamic>> Function(Map<String, dynamic>) invoke,
  required Future<String?> Function(AiAnalysisQuestion) ask,
  required Future<bool> Function(Object) retry,
  required bool Function() isActive,
}) async {
  final answers = <Map<String, String>>[];
  while (isActive()) {
    Map<String, dynamic> response;
    Map<String, dynamic> data;
    try {
      response = await invoke({
        ...body,
        'interactive': {'version': 1, 'answers': List.of(answers)},
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
        final items = data['items'];
        if (items is! List ||
            items.isEmpty ||
            items.any((item) => item is! Map)) {
          throw const FormatException('Missing verified transactions');
        }
        groupInteractiveAiItems(items
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList());
        return response;
      }
      if (answers.length >= 12) {
        throw const FormatException(
            'Too many clarification answers; please start a new input');
      }
      final question = AiAnalysisQuestion.fromJson(data['correction']);
      final answer = await ask(question);
      if (!isActive() || answer == null) return null;
      final normalized = answer.trim();
      if (normalized.isEmpty || normalized.length > 4000) {
        throw const FormatException('Invalid clarification answer');
      }
      answers.add({'question': question.question, 'answer': normalized});
    } catch (error) {
      if (!isActive() || !await retry(error)) return null;
    }
  }
  return null;
}

Map<AiAnalysisDestination, List<Map<String, dynamic>>> groupInteractiveAiItems(
    List<Map<String, dynamic>> items) {
  final groups = <AiAnalysisDestination, List<Map<String, dynamic>>>{};
  for (final item in items) {
    final amount = item['amount'];
    final date = tryParseDateOnlyYmd(item['date']?.toString());
    final currency = item['currency'];
    if (amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        date == null ||
        currency is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        !['expense', 'income'].contains(item['type']) ||
        item['category'] is! String ||
        (item['category'] as String).trim().isEmpty ||
        (item['transactionTime'] != null &&
            normalizeExplicitTransactionTime(item['transactionTime']) ==
                null)) {
      throw const FormatException('Invalid verified transaction');
    }
    final target =
        AiAnalysisDestination.fromJson(item['destination'], currency);
    groups.putIfAbsent(target, () => []).add(item);
  }
  return groups;
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
    return AiAnalysisQuestion(
        question: question, choices: rawChoices.cast<String>());
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

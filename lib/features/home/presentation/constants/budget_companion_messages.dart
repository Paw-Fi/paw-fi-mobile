import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

/// Chat-bubble message keys per budget state, mapped from the gauge
/// percentage through [BudgetCompanionSummary.reaction]. Each state holds
/// eight variants; one is picked at random per header mount.
const Map<BudgetCompanionReaction, List<String>> budgetCompanionMessageKeys = {
  BudgetCompanionReaction.happy: [
    'budgetCompanionHappy1',
    'budgetCompanionHappy2',
    'budgetCompanionHappy3',
    'budgetCompanionHappy4',
    'budgetCompanionHappy5',
    'budgetCompanionHappy6',
    'budgetCompanionHappy7',
    'budgetCompanionHappy8',
  ],
  BudgetCompanionReaction.encouraging: [
    'budgetCompanionEncouraging1',
    'budgetCompanionEncouraging2',
    'budgetCompanionEncouraging3',
    'budgetCompanionEncouraging4',
    'budgetCompanionEncouraging5',
    'budgetCompanionEncouraging6',
    'budgetCompanionEncouraging7',
    'budgetCompanionEncouraging8',
  ],
  BudgetCompanionReaction.concerned: [
    'budgetCompanionConcerned1',
    'budgetCompanionConcerned2',
    'budgetCompanionConcerned3',
    'budgetCompanionConcerned4',
    'budgetCompanionConcerned5',
    'budgetCompanionConcerned6',
    'budgetCompanionConcerned7',
    'budgetCompanionConcerned8',
  ],
  BudgetCompanionReaction.overBudget: [
    'budgetCompanionOverBudget1',
    'budgetCompanionOverBudget2',
    'budgetCompanionOverBudget3',
    'budgetCompanionOverBudget4',
    'budgetCompanionOverBudget5',
    'budgetCompanionOverBudget6',
    'budgetCompanionOverBudget7',
    'budgetCompanionOverBudget8',
  ],
  BudgetCompanionReaction.planning: [
    'budgetCompanionPlanning1',
    'budgetCompanionPlanning2',
    'budgetCompanionPlanning3',
    'budgetCompanionPlanning4',
    'budgetCompanionPlanning5',
    'budgetCompanionPlanning6',
    'budgetCompanionPlanning7',
    'budgetCompanionPlanning8',
  ],
};

final math.Random _messageRandom = math.Random();

/// Picks a random message key for the given budget state.
String randomBudgetCompanionMessageKey(BudgetCompanionReaction reaction) {
  final keys = budgetCompanionMessageKeys[reaction]!;
  return keys[_messageRandom.nextInt(keys.length)];
}

/// Resolves a key from [budgetCompanionMessageKeys] through the generated
/// localizations.
String resolveBudgetCompanionMessage(AppLocalizations l10n, String key) {
  if (key == 'budgetCompanionHappy1') {
    final month = DateFormat.MMMM(l10n.localeName).format(DateTime.now());
    return l10n.budgetCompanionHappy1(month);
  }
  return _resolveMessage(l10n, key);
}

String _resolveMessage(AppLocalizations l10n, String key) => switch (key) {
      'budgetCompanionHappy2' => l10n.budgetCompanionHappy2,
      'budgetCompanionHappy3' => l10n.budgetCompanionHappy3,
      'budgetCompanionHappy4' => l10n.budgetCompanionHappy4,
      'budgetCompanionHappy5' => l10n.budgetCompanionHappy5,
      'budgetCompanionHappy6' => l10n.budgetCompanionHappy6,
      'budgetCompanionHappy7' => l10n.budgetCompanionHappy7,
      'budgetCompanionHappy8' => l10n.budgetCompanionHappy8,
      'budgetCompanionEncouraging1' => l10n.budgetCompanionEncouraging1,
      'budgetCompanionEncouraging2' => l10n.budgetCompanionEncouraging2,
      'budgetCompanionEncouraging3' => l10n.budgetCompanionEncouraging3,
      'budgetCompanionEncouraging4' => l10n.budgetCompanionEncouraging4,
      'budgetCompanionEncouraging5' => l10n.budgetCompanionEncouraging5,
      'budgetCompanionEncouraging6' => l10n.budgetCompanionEncouraging6,
      'budgetCompanionEncouraging7' => l10n.budgetCompanionEncouraging7,
      'budgetCompanionEncouraging8' => l10n.budgetCompanionEncouraging8,
      'budgetCompanionConcerned1' => l10n.budgetCompanionConcerned1,
      'budgetCompanionConcerned2' => l10n.budgetCompanionConcerned2,
      'budgetCompanionConcerned3' => l10n.budgetCompanionConcerned3,
      'budgetCompanionConcerned4' => l10n.budgetCompanionConcerned4,
      'budgetCompanionConcerned5' => l10n.budgetCompanionConcerned5,
      'budgetCompanionConcerned6' => l10n.budgetCompanionConcerned6,
      'budgetCompanionConcerned7' => l10n.budgetCompanionConcerned7,
      'budgetCompanionConcerned8' => l10n.budgetCompanionConcerned8,
      'budgetCompanionOverBudget1' => l10n.budgetCompanionOverBudget1,
      'budgetCompanionOverBudget2' => l10n.budgetCompanionOverBudget2,
      'budgetCompanionOverBudget3' => l10n.budgetCompanionOverBudget3,
      'budgetCompanionOverBudget4' => l10n.budgetCompanionOverBudget4,
      'budgetCompanionOverBudget5' => l10n.budgetCompanionOverBudget5,
      'budgetCompanionOverBudget6' => l10n.budgetCompanionOverBudget6,
      'budgetCompanionOverBudget7' => l10n.budgetCompanionOverBudget7,
      'budgetCompanionOverBudget8' => l10n.budgetCompanionOverBudget8,
      'budgetCompanionPlanning1' => l10n.budgetCompanionPlanning1,
      'budgetCompanionPlanning2' => l10n.budgetCompanionPlanning2,
      'budgetCompanionPlanning3' => l10n.budgetCompanionPlanning3,
      'budgetCompanionPlanning4' => l10n.budgetCompanionPlanning4,
      'budgetCompanionPlanning5' => l10n.budgetCompanionPlanning5,
      'budgetCompanionPlanning6' => l10n.budgetCompanionPlanning6,
      'budgetCompanionPlanning7' => l10n.budgetCompanionPlanning7,
      'budgetCompanionPlanning8' => l10n.budgetCompanionPlanning8,
      _ => key,
    };

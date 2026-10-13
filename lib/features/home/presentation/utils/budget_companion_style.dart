import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';

extension BudgetCompanionStyle on BudgetCompanionReaction {
  Color accent(ColorScheme colors) => switch (this) {
        BudgetCompanionReaction.happy => colors.budgetGaugeSuccess,
        BudgetCompanionReaction.encouraging => colors.budgetGaugeWarning,
        BudgetCompanionReaction.concerned => colors.budgetGaugeCaution,
        BudgetCompanionReaction.overBudget => colors.budgetGaugeDanger,
        BudgetCompanionReaction.planning => colors.budgetGaugeInfo,
      };

  Color foreground(ColorScheme colors) => switch (this) {
        BudgetCompanionReaction.happy => colors.budgetSuccessForeground,
        BudgetCompanionReaction.encouraging => colors.budgetWarningForeground,
        BudgetCompanionReaction.concerned => colors.budgetCautionForeground,
        BudgetCompanionReaction.overBudget => colors.budgetDangerForeground,
        BudgetCompanionReaction.planning => colors.budgetInfoForeground,
      };

  String get mascotAsset => switch (this) {
        BudgetCompanionReaction.happy ||
        BudgetCompanionReaction.planning =>
          'lib/assets/mascots/cat-pecentage-0-50.png',
        BudgetCompanionReaction.encouraging =>
          'lib/assets/mascots/cat-pecentage-50-75.png',
        BudgetCompanionReaction.concerned =>
          'lib/assets/mascots/cat-pecentage-75-99.png',
        BudgetCompanionReaction.overBudget =>
          'lib/assets/mascots/cat-pecentage-overlimit.png',
      };
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  const amount = '€1.234,56';
  const budget = '€9.876,54';
  const period = 'selected-period';

  for (final locale in AppLocalizations.supportedLocales) {
    test('complete budget messages preserve the amount in $locale', () {
      final l10n = lookupAppLocalizations(locale);
      for (final message in [
        l10n.dashboardBudgetSpentAmount(amount),
        l10n.budgetCompanionLeft(amount),
        l10n.budgetCompanionOver(amount),
      ]) {
        expect(message, contains(amount));
        expect(message.split(amount), hasLength(2));
        expect(message, isNot(contains('{amount}')));
      }
      final detail = l10n.dashboardBudgetSpentAndLimit(amount, budget);
      expect(detail.split(amount), hasLength(2));
      expect(detail.split(budget), hasLength(2));
      expect(detail, isNot(contains('{spent}')));
      expect(detail, isNot(contains('{budget}')));
      expect(detail.split(' / '), hasLength(2));
      for (final label in [
        l10n.dashboardBudgetRemainingPeriodLabel(period),
        l10n.dashboardBudgetOverPeriodLabel(period),
        l10n.dashboardBudgetSpentPeriodLabel(period),
      ]) {
        expect(label.split(period), hasLength(2));
        expect(label, isNot(contains('{period}')));
      }
      if (locale.languageCode != 'en') {
        expect(detail, isNot('Spent $amount / Budget $budget'));
        expect(l10n.dashboardBudgetRemainingPeriodLabel(period),
            isNot('$period · Remaining'));
        expect(l10n.dashboardBudgetSpentAmount(amount), isNot('$amount spent'));
      }
    });
  }

  test('Mandarin messages control amount order independently from English', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final chinese = lookupAppLocalizations(const Locale('zh'));
    final traditional = lookupAppLocalizations(const Locale('zh', 'TW'));
    expect(english.budgetCompanionLeft(amount), '$amount left');
    expect(chinese.budgetCompanionLeft(amount), '还剩 $amount');
    expect(traditional.budgetCompanionLeft(amount), '還剩 $amount');
    expect(chinese.dashboardBudgetSpentAndLimit(amount, budget),
        '已花 $amount / 预算 $budget');
    expect(traditional.dashboardBudgetSpentAndLimit(amount, budget),
        '已花 $amount / 預算 $budget');
    expect(chinese.dashboardBudgetRemainingPeriodLabel('10月'), '10月 · 剩余预算');
    expect(
        traditional.dashboardBudgetRemainingPeriodLabel('10月'), '10月 · 剩餘預算');
    expect(chinese.dashboardBudgetSpentAmount(amount), '已支出$amount');
  });

  test('over-budget label changes meaning without attaching it to the amount',
      () {
    final english = lookupAppLocalizations(const Locale('en'));
    expect(english.dashboardBudgetOverPeriodLabel('Oct'), 'Oct · Over budget');
    expect(
        english.dashboardBudgetRemainingPeriodLabel('Oct'), 'Oct · Remaining');
  });

  test('Urdu isolates a formatted amount without changing its content', () {
    final urdu = lookupAppLocalizations(const Locale('ur'));
    expect(urdu.dashboardBudgetSpentAndLimit(amount, budget),
        contains('\u2068$amount\u2069'));
    expect(urdu.dashboardBudgetSpentAndLimit(amount, budget),
        contains('\u2068$budget\u2069'));
    expect(urdu.dashboardBudgetSpentAmount(amount),
        contains('\u2068$amount\u2069'));
  });
}

import 'package:flutter/widgets.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

extension L10nX on BuildContext {
  /// Safe localization getter.
  /// Returns generated English localizations if the context is not yet
  /// wrapped with Localizations (early frames) or the locale is unsupported.
  AppLocalizations get l10n {
    final loc = AppLocalizations.of(this);
    if (loc != null) return loc;
    return AppLocalizationsEn('en');
  }
}

extension ExportL10n on AppLocalizations {
  String get displayCurrency => 'Display Currency';
  String get displayCurrencyTooltip =>
      'All amounts on this page are roughly converted to the selected currency.';
  String get activeAccounts => 'Active Accounts';
  String get financialOverview => 'Financial Overview';
  String get incomeThisMonth => 'Income this month';
  String get spent => 'Spent';
  String get totalSpent => 'Total Spent';
  String get expensesThisMonth => 'Expenses this month';
  String get netFlow => 'Net Flow';
  String get netFlowBreakdown => 'Net Flow Breakdown';
  String get totalIncome => 'Total Income';
  String get totalExpense => 'Total Expense';
  String get netResult => 'Net Result';
  String get dailyAverage => 'Daily Average';
  String get averageDailySpend => 'Average Daily Spend';
  String get daysTracked => 'days tracked';
  String get statistics => 'Statistics';
  String get trend => 'Trend';
  String get chart => 'Chart';
  String get spendingBreakdown => 'Spending Breakdown';
  String get spendingTrend => 'Spending Trend';
  String get topInsight => 'Top Insight';
  String get percentOfSpend => '% of spend';
  String get insight => 'Insight';
  String get accountsAnalysis => 'Accounts Analysis';
  String get spendByAccount => 'Spend by Account';
  String get accountSpend => 'Account Spend';
  String get noAccountActivity => 'No account activity yet';
  String get recentActivity => 'Recent Activity';
  String get viewAllTransactions => 'View All Transactions';
  String get transactions => 'Transactions';
  String get uncategorized => 'uncategorized';
  String get summary => 'Summary';
  String get topCategories => 'TOP CATEGORIES';
  String get transactionsUpper => 'TRANSACTIONS';
  String get charts => 'Charts';
  String get accountsList => 'ACCOUNTS LIST';
  String get transactionsInCategory => 'TRANSACTIONS IN';
  String get details => 'Details';
  String get totalAccounts => 'Total Accounts';
  String get currencies => 'Currencies';
  String get totalTransactions => 'Total Transactions';
  String get personal => 'Personal';
  String get left => 'left';
  String get spentLabel => 'spent';
  String get spentThisMonth => 'Spent this month';
  String get of => 'of';
  String get income => 'Income';
  String get expense => 'Expense';
  String get net => 'Net';
  String get accountSpent => 'Spent';
  String get accountIncome => 'Income';
  String get accountSpendLabel => 'Spend';
  String get noExpensesRecorded => 'No expenses recorded this month';
  String get transactionsCount => 'transactions';
  String get noTransactionsRecorded => 'No transactions recorded this month';
  String get other => 'Other';
  String get noExpensesDisplay => 'No expenses to display';
  String get exportExcel => 'Excel file';
  String get exportReceiptsZip => 'Receipts ZIP';
  String get noReceiptsFound => 'No receipts found';
  String get multipleCurrencies => 'Multiple currencies';
  String get importData => 'Import data';
  String get importStepSelect => 'Select';
  String get importStepMap => 'Map';
  String get importStepPreview => 'Preview';
  String get importSelectFileHint => 'Choose a CSV or TXT file to import';
  String get noFileSelected => 'No file selected';
  String get csvTxtSupported => 'CSV, PDF, XLSX, and XLS supported';
  String get importNoTable => 'No data loaded yet';
  String get selectColumn => 'Select column';
  String get importMapHint => 'Map your columns to fields';
  String get back => 'Back';
  String get next => 'Next';
  String get date => 'Date';
  String get amount => 'Amount';
  String get description => 'Description';
  String get currency => 'Currency';
  String get type => 'Type';
  String get importPreviewHint => 'Review rows before importing';
  String get skipDuplicates => 'Skip duplicates';
  String get importRowError => 'Needs fixes';
  String get importRowDuplicate => 'Duplicate';
  String get importRowReady => 'Ready';
  String get importRow => 'Imported row';
  String get importErrorInvalidDate => 'Enter a valid date';
  String get importErrorInvalidAmount => 'Enter a valid amount';
  String get importErrorUnknown => 'Fix missing fields';
  String get importEditRowTitle => 'Edit row';
  String get importEditDateHint => 'Select date';
  String get importEditAmountHint => 'e.g. 24.99';
  String get importEditCategoryHint => 'e.g. Groceries';
  String get importEditDescriptionHint => 'Optional note';
  String get importEditSave => 'Save';
  String get importEditInvalidTitle => 'Fix these fields';
  String get ok => 'OK';
  String get importing => 'Importing…';
  String get importConfirm => 'Import';
  String get imported => 'Imported';
  String get failed => 'Failed';
  String get rows => 'Rows';
  String get valid => 'Valid';
  String get errors => 'Errors';
  String get duplicates => 'Duplicates';
}

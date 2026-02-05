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

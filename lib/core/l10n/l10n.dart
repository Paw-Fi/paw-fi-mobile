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
}

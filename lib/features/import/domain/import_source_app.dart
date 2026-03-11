enum ImportSourceApp {
  ynab,
  monarch,
  copilot,
  pocketGuard,
  splitwise,
  everyDollar,
  cashew,
  mint,
  goodbudget,
  spendee,
  other,
}

class ImportSourceSpec {
  const ImportSourceSpec({
    required this.app,
    required this.allowedExtensions,
  });

  final ImportSourceApp app;
  final List<String> allowedExtensions;
}

const List<String> supportedImportExtensions = [
  'csv',
  'tsv',
  'txt',
  'pdf',
  'xlsx',
  'xls',
];

const List<ImportSourceSpec> importSourceSpecs = [
  ImportSourceSpec(
    app: ImportSourceApp.ynab,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.monarch,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.copilot,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.pocketGuard,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.splitwise,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.everyDollar,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.cashew,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.mint,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.goodbudget,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.spendee,
    allowedExtensions: supportedImportExtensions,
  ),
  ImportSourceSpec(
    app: ImportSourceApp.other,
    allowedExtensions: supportedImportExtensions,
  ),
];

ImportSourceSpec importSourceSpecFor(ImportSourceApp app) {
  for (final spec in importSourceSpecs) {
    if (spec.app == app) return spec;
  }
  return importSourceSpecs.last;
}

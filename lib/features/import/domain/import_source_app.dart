enum ImportSourceApp {
  ynab,
  monarch,
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

const List<ImportSourceSpec> importSourceSpecs = [
  ImportSourceSpec(
    app: ImportSourceApp.ynab,
    allowedExtensions: ['csv', 'tsv', 'txt'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.monarch,
    allowedExtensions: ['csv', 'txt'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.everyDollar,
    allowedExtensions: ['csv', 'txt'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.cashew,
    allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.mint,
    allowedExtensions: ['csv', 'txt'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.goodbudget,
    allowedExtensions: ['csv', 'txt'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.spendee,
    allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
  ),
  ImportSourceSpec(
    app: ImportSourceApp.other,
    allowedExtensions: ['csv', 'txt', 'pdf', 'xlsx', 'xls', 'tsv'],
  ),
];

ImportSourceSpec importSourceSpecFor(ImportSourceApp app) {
  for (final spec in importSourceSpecs) {
    if (spec.app == app) return spec;
  }
  return importSourceSpecs.last;
}

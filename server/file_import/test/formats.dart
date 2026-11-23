import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moneko/features/import/data/worker_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../backend.dart';
import '../worker.dart' as worker;

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

class FixtureBackend extends Backend {
  FixtureBackend(this.source) : super('', '', '');
  final Uint8List source;
  final objects = <String, Uint8List>{};
  var analyses = 0;
  var failFirstAnalysis = false;
  bool needsReview = false;
  @override
  Future<Uint8List> read(String path) async =>
      path.endsWith('/source') ? source : objects[path]!;
  @override
  Future<void> write(String path, Uint8List bytes) async {
    objects[path] = bytes;
  }

  @override
  Future<dynamic> json(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    if (method == 'PATCH') {
      return [
        {'id': 'job'}
      ];
    }
    if (path == 'rest/v1/expenses') return [];
    if (path.contains('/object/list/')) {
      return objects.keys.map((s) => {'name': s.split('/').last}).toList();
    }
    throw StateError(path);
  }

  @override
  Future<Json> invoke(String name, Json body) async {
    check(name == 'analyze-expense', 'unexpected function');
    analyses++;
    if (needsReview) throw RemoteFailure(422, 'PDF_REVIEW_REQUIRED');
    if (analyses == 1 && failFirstAnalysis) {
      throw RemoteFailure(400, 'PDF_PAGE_LIMIT');
    }
    return {
      'success': true,
      'data': {
        'items': [
          {
            'date': '2025-01-02',
            'amount': analyses,
            'currency': 'EUR',
            'category': 'groceries',
            'description': 'Corner store',
            'type': 'expense',
            'merchant_auto_resolution_blocked': true
          }
        ]
      }
    };
  }
}

Json job(String format, Uint8List bytes) => {
      'id': 'job',
      'lease': 'lease',
      'user_id': 'actor',
      'currency': 'EUR',
      'language': 'de',
      'local_date': '2025-01-02',
      'timezone': 'Europe/Berlin',
      'offset_minutes': 60,
      'format': format,
      'file_name': 'statement.$format',
      'skip_duplicates': true,
      'byte_count': bytes.length,
      'fingerprint': sha256.convert(bytes).toString(),
      'processed': 0,
      'imported': 0,
      'skipped': 0,
      'failures': 0
    };

Uint8List pdf(int pages) {
  final parts = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Count $pages /Kids [${List.generate(pages, (i) => "${i + 3} 0 R").join(" ")}] >>',
    for (var i = 0; i < pages; i++)
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>'
  ];
  var content = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < parts.length; i++) {
    offsets.add(content.length);
    content += '${i + 1} 0 obj\n${parts[i]}\nendobj\n';
  }
  final start = content.length;
  content += 'xref\n0 ${parts.length + 1}\n0000000000 65535 f \n';
  for (final offset in offsets) {
    content += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  return Uint8List.fromList(ascii.encode(
      '${content}trailer\n<< /Size ${parts.length + 1} /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n'));
}

Future<void> main() async {
  AppLocalizations.load(Directory('lib/l10n'));
  await initializeDateFormatting();
  tzdata.initializeTimeZones();
  const headers = [
    'Date',
    'Amount',
    'Description',
    'Category',
    'Currency',
    'Type'
  ];
  const line = [
    '2025-07-01',
    '12.34',
    'Café',
    'Lebensmittel',
    'EUR',
    'expense'
  ];
  final excel = Excel.createExcel();
  excel['Sheet1'].appendRow([TextCellValue('Title')]);
  final sheet = excel['Ledger'];
  for (final row in [headers, line, line]) {
    sheet.appendRow(row.map(TextCellValue.new).toList());
  }
  final textFiles = <String, Uint8List>{
    for (final format in ['csv', 'tsv', 'txt'])
      format: Uint8List.fromList(utf8.encode([headers, line, line]
          .map((r) => r.join(format == 'csv' ? ',' : '\t'))
          .join('\n'))),
    'xls': await File('server/file_import/test/fixtures/legacy_statement.xls')
        .readAsBytes(),
    'xlsx': Uint8List.fromList(excel.encode()!)
  };
  for (final entry in textFiles.entries) {
    final api = FixtureBackend(entry.value),
        settings = job(entry.key, entry.value);
    final rows = await worker.ImportWorker(api, settings).plan();
    check(rows.length == 1 && settings['skipped'] == 1,
        'duplicate or sheet selection: ${entry.key}');
    check(
        rows.single['amount'] == 12.34 &&
            rows.single['category'] == 'groceries',
        'amount/category: ${entry.key}');
    check(rows.single['clientCreatedAt'] == '2025-07-01T10:00:00.000Z',
        'historical DST');
    check(rows.single['accountId'] == null, 'unassigned wallet');
    api.close();
  }
  final document = pdf(7),
      api = FixtureBackend(document)..failFirstAnalysis = true;
  final settings = job('pdf', document);
  try {
    await worker.ImportWorker(api, settings).plan();
    throw StateError('expected page fallback');
  } on worker.YieldJob {
    check(settings['pdf_chunked'] == true, 'missing PDF checkpoint');
  }
  final rows = await worker.ImportWorker(api, settings).plan();
  check(api.analyses == 3 && rows.length == 2, 'all PDF pages covered');
  check(rows.every((r) => r['merchantAutoResolutionBlocked'] == true),
      'PDF merchant review flag');
  final cached = await worker.ImportWorker(api, settings).plan();
  check(cached.length == 2 && api.analyses == 3,
      'cached plan must not reanalyze PDFs');
  // Replay page checkpoints even when the final plan upload was not acknowledged.
  settings.remove('plan_path');
  await worker.ImportWorker(api, settings).plan();
  check(api.analyses == 3, 'cached page ranges should be reused');
  api.close();
  final flagged = FixtureBackend(document)..needsReview = true;
  try {
    await worker.ImportWorker(flagged, job('pdf', document)).plan();
    throw StateError('accepted a PDF marked for human review');
  } on worker.InvalidImport {
    check(flagged.objects.isEmpty, 'flagged PDF created a save plan');
  } finally {
    flagged.close();
  }
  final broken = Uint8List.fromList(
      utf8.encode('Column A,Column B\nnot a date,unreadable'));
  final invalid = FixtureBackend(broken);
  try {
    await worker.ImportWorker(invalid, job('csv', broken)).plan();
    throw StateError('ambiguous mapping accepted');
  } on worker.InvalidImport {
    check(invalid.objects.isEmpty, 'invalid file produced a save plan');
  }
  invalid.close();
  stdout.writeln(
      'File formats, locale, sheet selection, duplicates, DST, ambiguous mapping and PDF replay passed.');
}

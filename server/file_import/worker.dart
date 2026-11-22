import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/data/import_excel_parser.dart';
import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/data/import_preparation.dart';
import 'package:moneko/features/import/data/worker_localizations.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'backend.dart';

class InvalidImport implements Exception {
  const InvalidImport(this.message);
  final String message;
}

class LostLease implements Exception {}

class YieldJob implements Exception {}

class ImportWorker {
  ImportWorker(this.api, this.job);
  final Backend api;
  final Json job;
  final clock = Stopwatch()..start();
  String get prefix => "${job['user_id']}/${job['id']}";
  String get lease => job['lease'] as String;

  Future<void> checkpoint(Json changes) async {
    final rows = await api.json('PATCH', 'rest/v1/file_import_jobs',
        query: {
          'id': "eq.${job['id']}",
          'lease': 'eq.$lease',
          'status': 'eq.processing',
          'lease_until': 'gt.now',
          'select': 'id'
        },
        body: changes);
    if (rows is! List || rows.length != 1) throw LostLease();
    job.addAll(changes);
  }

  Future<void> active() async {
    if (clock.elapsed > const Duration(minutes: 3)) throw YieldJob();
    await checkpoint({
      'lease_until': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String()
    });
  }

  Future<List<ExpenseEntry>> existingExpenses() async {
    final household = job['household_id'];
    if (household != null) {
      final membership =
          await api.json('GET', 'rest/v1/household_members', query: {
        'select': 'id',
        'user_id': "eq.${job['user_id']}",
        'household_id': 'eq.$household',
        'limit': '1'
      });
      if ((membership as List).isEmpty) {
        throw const InvalidImport(
            'You no longer have access to this Space. Select another destination.');
      }
    }
    final entries = <ExpenseEntry>[];
    String? after;
    while (true) {
      final page = (await api.json('GET', 'rest/v1/expenses', query: {
        'select':
            'id,date,created_at,amount_cents,currency,type,raw_text,merchant,category,account_id,is_recurring',
        if (household == null) 'user_id': "eq.${job['user_id']}",
        'household_id': household == null ? 'is.null' : 'eq.$household',
        'deleted_at': 'is.null',
        'order': 'id',
        'limit': '1000',
        if (after != null) 'id': 'gt.$after'
      }) as List)
          .cast<Json>();
      if (page.isEmpty) break;
      entries.addAll(page.map(ExpenseEntry.fromJson));
      after = page.last['id'] as String;
    }
    return entries;
  }

  Future<List<dynamic>> extractPdfItems(Uint8List bytes) async {
    late Json result;
    try {
      result = await api.invoke('analyze-expense', {
        'userId': job['user_id'],
        'date': job['local_date'],
        'language': job['language'],
        'currency': job['currency'],
        'typeHint': 'mixed',
        'fileImportJobId': job['id'],
        'fileImportLease': lease,
        'attachments': [
          {
            'filename': job['file_name'],
            'contentType': 'application/pdf',
            'data': base64Encode(bytes)
          }
        ]
      });
    } on RemoteFailure catch (error) {
      if (error.code == 'PDF_REVIEW_REQUIRED' ||
          error.code == 'PDF_PARSE_FAILED' ||
          error.code == 'PDF_TEXT_EXTRACTION_EMPTY') {
        throw const InvalidImport(
            'The PDF could not be verified for automatic import. Choose Review before importing to check its extracted transactions.');
      }
      rethrow;
    }
    if (result['data']?['diagnostics']?['truncated'] == true) {
      throw const InvalidImport(
          'Only part of this PDF was extracted. Choose Review before importing.');
    }
    final rows = result['data']?['items'];
    if (result['success'] != true || rows is! List) throw RemoteFailure(503);
    return rows;
  }

  Future<List<dynamic>> analyzePdf(Uint8List source) async {
    final dir = await Directory.systemTemp.createTemp('statement-');
    try {
      final file = File('${dir.path}/statement.pdf');
      await file.writeAsBytes(source);
      final pages = await Process.run('qpdf', ['--show-npages', file.path]);
      final count = int.tryParse(pages.stdout.toString().trim());
      if (count == null || count < 1) {
        throw const InvalidImport(
            'The PDF could not be opened. Export an unlocked PDF and try again.');
      }
      // Preserve whole-document context whenever the established analyzer can finish.
      if (job['pdf_chunked'] != true) {
        try {
          return await extractPdfItems(source);
        } catch (error) {
          final transient = error is TimeoutException ||
              error is HttpException ||
              error is RemoteFailure &&
                  (error.status >= 500 ||
                      error.status == 413 ||
                      error.code == 'PDF_PAGE_LIMIT' ||
                      error.code == 'IMPORT_OUTPUT_LIMIT');
          if (count <= 5 || !transient) rethrow;
          await checkpoint({'pdf_chunked': true});
          throw YieldJob();
        }
      }
      // Resume at the first unacknowledged range so previously extracted
      // pages do not consume the time budget for the next range.
      for (var first = (job['pdf_next_page'] as int?) ?? 1;
          first <= count;
          first += 5) {
        await active();
        final last = min(first + 4, count);
        final path = '$prefix/pdf-$first-$last.json';
        // The result object is addressed by immutable source + page range. A
        // retry may read a previous lease's completely uploaded result.
        final found = await api.json(
            'POST', 'storage/v1/object/list/file-imports', body: {
          'prefix': prefix,
          'search': 'pdf-$first-$last.json',
          'limit': 1
        });
        if ((found as List).any((o) => o['name'] == 'pdf-$first-$last.json')) {
          await checkpoint({'pdf_next_page': last + 1});
          continue;
        }
        var bytes = source;
        if (count > 5) {
          final part = File('${dir.path}/part.pdf');
          final split = await Process.run('qpdf',
              [file.path, '--pages', '.', '$first-$last', '--', part.path]);
          if (split.exitCode != 0 && split.exitCode != 3) {
            throw const InvalidImport(
                'The PDF pages could not be read. Export a new copy and retry.');
          }
          bytes = await part.readAsBytes();
        }
        final rows = await extractPdfItems(bytes);
        await activeForWrite();
        await api.write(
            path, Uint8List.fromList(utf8.encode(jsonEncode(rows))));
        await checkpoint({'pdf_next_page': last + 1});
      }
      final items = <dynamic>[];
      for (var first = 1; first <= count; first += 5) {
        if ((first - 1) % 100 == 0) await activeForWrite();
        final path = '$prefix/pdf-$first-${min(first + 4, count)}.json';
        items.addAll(jsonDecode(utf8.decode(await api.read(path))) as List);
      }
      return items;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<void> activeForWrite() => checkpoint({
        'lease_until': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String()
      });

  Future<ImportTable> readLegacyWorkbook(Uint8List source) async {
    final dir = await Directory.systemTemp.createTemp('legacy-workbook-');
    try {
      final old = File('${dir.path}/input.xls'),
          converted = File('${dir.path}/cells.jsonl');
      await old.writeAsBytes(source);
      final process = await Process.run('python3',
          ['server/file_import/legacy_excel.py', old.path, converted.path]);
      if (process.exitCode != 0) {
        throw const InvalidImport(
            'The Excel file could not be opened. Export it as XLSX or CSV and retry.');
      }
      var best = const ImportTable(headers: [], rows: []);
      var cells = <List<String>>[];
      final lines = converted
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final row = jsonDecode(line);
        if (row == null) {
          final sheet = importExcelRowsToTable(cells);
          if (sheet.rows.length > best.rows.length) best = sheet;
          cells = [];
        } else {
          cells.add((row as List).cast<String>());
        }
      }
      return best;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<List<dynamic>> plan() async {
    final stored = job['plan_path'] as String?;
    if (stored != null) {
      return jsonDecode(utf8.decode(gzip.decode(await api.read(stored))))
          as List;
    }
    final source = await api.read('$prefix/source');
    if (source.length != job['byte_count'] ||
        sha256.convert(source).toString() != job['fingerprint']) {
      throw const InvalidImport(
          'The uploaded file did not match the selected file. Select a fresh copy and retry.');
    }
    final format = job['format'];
    List<dynamic> transactions;
    var skipped = 0;
    final isLegacyWorkbook = (format == 'xlsx' || format == 'xls') &&
        source.length >= 4 &&
        source[0] == 0xd0 &&
        source[1] == 0xcf &&
        source[2] == 0x11 &&
        source[3] == 0xe0;
    if (format == 'xlsx' || format == 'xls') {
      // Inspect the central directory before the Excel decoder expands it.
      if (source.length >= 2 && source[0] == 80 && source[1] == 75) {
        final directory = ZipDirectory.read(InputStream(source));
        final expanded = directory.fileHeaders
            .fold<int>(0, (sum, h) => sum + (h.uncompressedSize ?? 0));
        if (expanded > 256 * 1024 * 1024) {
          throw const InvalidImport(
              'This workbook is too large when unpacked. Export the data sheet as CSV and retry.');
        }
      }
    }
    final ImportTable table;
    try {
      table = format == 'pdf'
          ? analyzedItemsToImportTable(await analyzePdf(source))
          : (format == 'xlsx' || format == 'xls')
              ? (isLegacyWorkbook
                  ? await readLegacyWorkbook(source)
                  : parseImportExcelTable(source))
              : parseImportTable(decodeImportTextFromBytes(source));
    } on FormatException {
      throw const InvalidImport(
          'The file format could not be read. Check the file or choose Review before importing.');
    }
    final mapping = autoMapFieldsWithConfidence(table.headers,
        sampleRows: table.rows.take(10).toList());
    if (table.rows.isEmpty ||
        !mapping.mapping.hasRequiredFields ||
        mapping.confidence != MappingConfidence.high ||
        (mapping.sampleValidRate ?? 0) < 0.7) {
      throw const InvalidImport(
          'The columns need review. Choose Review before importing to confirm the sheet and mapping.');
    }
    final rows = parseImportRows(table, mapping.mapping,
        defaultCurrency: job['currency'],
        existing: await existingExpenses(),
        targetAccountId: job['account_id']);
    tz.Location? location;
    try {
      location = tz.getLocation(job['timezone']);
    } on tz.LocationNotFoundException {/* Fixed-offset device timezone. */}
    final prepared = prepareImportTransactions(rows,
        defaultCurrency: job['currency'],
        skipDuplicates: job['skip_duplicates'],
        selectedAccountId: job['account_id'],
        selectedAccountCurrency: job['account_currency'],
        timestampForDate: (d) => location == null
            ? DateTime.utc(d.year, d.month, d.day, 12)
                .subtract(Duration(minutes: job['offset_minutes']))
            : tz.TZDateTime(location, d.year, d.month, d.day, 12).toUtc());
    if (prepared.invalid > 0 || rows.isEmpty) {
      throw const InvalidImport(
          'Some rows need review. Choose Review before importing to check the highlighted rows. No transactions were saved.');
    }
    transactions = prepared.transactions;
    skipped = rows.length - transactions.length;
    final path = '$prefix/plan-$lease.gz';
    await activeForWrite();
    await api.write(path,
        Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(transactions)))));
    await checkpoint({
      'plan_path': path,
      'total': transactions.length,
      'skipped': skipped,
      'failures': 0
    });
    return transactions;
  }

  Future<void> run() async {
    try {
      final transactions = await plan();
      while (job['processed'] < transactions.length) {
        await active();
        final start = job['processed'] as int;
        final end = min(start + 50, transactions.length);
        final response = await api.invoke('save-transactions-batch', {
          'userId': job['user_id'],
          'householdId': job['household_id'],
          'isPortfolio': job['is_portfolio'],
          'manualImportMode': true,
          'fileImportLease': lease,
          'skipSemanticDuplicates': job['skip_duplicates'],
          'debugTraceId': "${job['id']}:$start",
          'transactions': [
            for (var i = start; i < end; i++)
              {
                ...transactions[i] as Json,
                'idempotencyKey': "file-import-v1:${job['id']}:$i"
              }
          ]
        });
        final results = response['results'];
        final acknowledged = <int>{};
        var saved = 0;
        if (results is! List) throw RemoteFailure(503);
        for (final row in results) {
          final index = row['index'];
          if (index is! int ||
              index < 0 ||
              index >= end - start ||
              !acknowledged.add(index)) {
            throw RemoteFailure(503);
          }
          if (row['success'] == true ||
              (row['duplicate'] == true && row['duplicateKind'] == 'request')) {
            saved++;
          } else if (row['duplicate'] != true) {
            throw RemoteFailure(503);
          }
        }
        if (acknowledged.length != end - start) throw RemoteFailure(503);
        await checkpoint({
          'processed': end,
          'imported': job['imported'] + saved,
          'skipped': job['skipped'] + end - start - saved,
          'failures': 0
        });
      }
      await checkpoint({
        'status': 'completed',
        'lease': null,
        'lease_until': null,
        'finished_at': DateTime.now().toUtc().toIso8601String()
      });
    } on LostLease {
      return;
    } on YieldJob {
      await checkpoint({
        'lease': null,
        'lease_until': null,
        'available_at': DateTime.now().toUtc().toIso8601String()
      });
    } catch (e, stack) {
      stderr.writeln(
          'Import ${job['id']} at row ${job['processed']}: ${e.runtimeType} ${e is RemoteFailure ? e.status : ''}\n${stack.toString().split('\n').take(4).join('\n')}');
      final permanent = e is InvalidImport;
      final failures = (job['failures'] as int) + 1;
      final now = DateTime.now().toUtc();
      final terminal = permanent || failures >= 5;
      await checkpoint({
        'lease': null,
        'lease_until': null,
        'failures': failures,
        if (terminal) ...{
          'status': 'failed',
          'finished_at': now.toIso8601String(),
          'retryable': !permanent,
          'error_message': permanent
              ? e.message
              : 'Processing stopped. Open Import Data and retry this job to resume safely. Previously saved transactions are protected.'
        } else
          'available_at':
              now.add(Duration(seconds: 15 * (1 << failures))).toIso8601String()
      });
    }
  }
}

Future<void> tick(Map<String, String> env) async {
  final api = Backend(env['SUPABASE_URL']!, env['SUPABASE_SERVICE_ROLE_KEY']!,
      env['INTERNAL_SERVICE_SECRET']!);
  try {
    final jobs = await api.rpc('claim_file_import') as List;
    if (jobs.isNotEmpty) {
      final job = jobs.single as Json;
      try {
        await api
            .request('POST', 'functions/v1/file-import-maintenance', body: {});
      } catch (_) {/* Independent delivery queue. */}
      AppLocalizations.load(Directory('lib/l10n'));
      await initializeDateFormatting();
      Intl.defaultLocale = job['language'].toString().replaceAll('-', '_');
      tzdata.initializeTimeZones();
      await ImportWorker(api, job).run();
    }
  } finally {
    try {
      await api
          .request('POST', 'functions/v1/file-import-maintenance', body: {});
    } finally {
      api.close();
    }
  }
}

Future<void> environmentTick() => tick(Platform.environment);

Future<void> main() async {
  final env = Platform.environment;
  for (final key in [
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'INTERNAL_SERVICE_SECRET',
    'FILE_IMPORT_WORKER_SECRET'
  ]) {
    if ((env[key] ?? '').isEmpty) throw StateError('Missing $key');
  }
  final server = await HttpServer.bind(
      InternetAddress.anyIPv4, int.parse(env['PORT'] ?? '8080'));
  var busy = false;
  await for (final req in server) {
    if (req.method != 'POST' ||
        req.uri.path != '/tick' ||
        req.headers.value('Authorization') !=
            'Bearer ${env['FILE_IMPORT_WORKER_SECRET']}') {
      req.response.statusCode = 403;
      await req.response.close();
      continue;
    }
    if (busy) {
      req.response.statusCode = 204;
      await req.response.close();
      continue;
    }
    busy = true;
    unawaited(Isolate.run(environmentTick).then((_) {
      req.response.statusCode = 204;
    }, onError: (Object e) {
      stderr.writeln('Import tick failed: ${e.runtimeType}');
      req.response.statusCode = 503;
    }).whenComplete(() async {
      busy = false;
      await req.response.close();
    }));
  }
}

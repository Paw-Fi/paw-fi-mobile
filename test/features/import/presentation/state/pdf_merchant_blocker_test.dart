import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'owner', email: 'owner@example.com');
}

class _Analytics extends AnalyticsNotifier {
  _Analytics(super.ref) {
    state = AnalyticsData(allExpenses: const []);
  }
}

class _PdfPicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult([
        PlatformFile(
            name: 'statement.pdf',
            size: 4,
            bytes: Uint8List.fromList([37, 80, 68, 70]))
      ]);
}

void main() {
  late Future<http.Response> Function(http.Request) handler;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '');
    FilePicker.platform = _PdfPicker();
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(), detectSessionInUri: false),
      httpClient: MockClient((request) => handler(request)),
    );
    handler = (request) async => http.Response(
        jsonEncode({
          'access_token': 'e30.${base64Url.encode(utf8.encode(jsonEncode({
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
              })))}.signature',
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'owner',
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z'
          }
        }),
        200,
        headers: {'content-type': 'application/json'});
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'owner@example.com', password: 'fixture-password');
  });

  for (final marker in [true, false, null, 'true']) {
    for (final type in ['expense', 'income']) {
      test(
          'PDF $type blocker=$marker survives mapping and serialized batch retry',
          () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final container = ProviderContainer(overrides: [
          authProvider.overrideWith(_Auth.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          analyticsProvider.overrideWith(_Analytics.new),
        ]);
        addTearDown(container.dispose);
        final keepAlive = container.listen(importWizardProvider, (_, __) {});
        addTearDown(keepAlive.close);
        final savedBodies = <Map<String, dynamic>>[];
        handler = (request) async {
          if (request.url.path.endsWith('analyze-expense')) {
            return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'amount': 99,
                        'description': 'total',
                        'merchant_auto_resolution_blocked': true
                      },
                      {
                        'type': type,
                        'amount': 12.34,
                        'date': '2026-10-03',
                        'category': 'groceries',
                        'currency': 'EUR',
                        'description': '記録',
                        'merchant': '原文の相手',
                        if (marker != null)
                          'merchant_auto_resolution_blocked': marker
                      },
                      {
                        'type': 'income',
                        'amount': 23.45,
                        'date': '2026-10-04',
                        'category': 'salary',
                        'currency': 'USD',
                        'description': 'الدخل',
                        'merchant': 'اسم خام'
                      }
                    ]
                  }
                }),
                200,
                headers: {'content-type': 'application/json'});
          }
          expect(request.url.path, '/functions/v1/save-transactions-batch');
          savedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (savedBodies.length == 1) {
            throw http.ClientException('network disconnected');
          }
          return http.Response(jsonEncode({'success': true}), 200,
              headers: {'content-type': 'application/json'});
        };
        final notifier = container.read(importWizardProvider.notifier);
        await notifier.pickFile(allowedExtensions: ['pdf']);
        expect(notifier.state.errorMessage, isNull);
        expect(notifier.state.table!.headers, [
          'date',
          'amount',
          'category',
          'description',
          'merchant',
          'currency',
          'type'
        ]);
        expect(notifier.state.parsedRows, hasLength(2));
        expect(notifier.state.parsedRows.first.merchantAutoResolutionBlocked,
            marker == true);
        expect(notifier.state.parsedRows.last.merchantAutoResolutionBlocked,
            isFalse);
        notifier.updateMapping(ImportField.category, 2);
        final row = notifier.state.parsedRows.first;
        notifier.updateParsedRow(row.copyWith(description: '記録の編集'));
        expect(notifier.state.parsedRows.first.merchantAutoResolutionBlocked,
            marker == true);
        await notifier.importRows();
        expect(savedBodies, hasLength(2));
        expect(savedBodies[1], savedBodies[0]);
        final transactions = savedBodies.last['transactions'] as List;
        expect(transactions, hasLength(2));
        final request = transactions.first as Map;
        expect(request.containsKey('merchantAutoResolutionBlocked'),
            marker == true);
        if (marker == true) {
          expect(request['merchantAutoResolutionBlocked'], true);
        }
        expect(
            (transactions.last as Map)
                .containsKey('merchantAutoResolutionBlocked'),
            isFalse);
        expect(request['merchant'], '原文の相手');
        expect(request['description'], '記録の編集');
        expect(request['amount'], 12.34);
        expect(request['currency'], 'EUR');
        expect(request['date'], '2026-10-03');
        expect(request['type'], type);
        expect(notifier.state.importedCount, 2);
        expect(notifier.state.failedCount, 0);
      });
    }
  }

  test(
      'manual PDF merchant correction clears only its inherited marker across reparse',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      analyticsProvider.overrideWith(_Analytics.new),
    ]);
    addTearDown(container.dispose);
    final keepAlive = container.listen(importWizardProvider, (_, __) {});
    addTearDown(keepAlive.close);
    final notifier = container.read(importWizardProvider.notifier);
    notifier.state = notifier.state.copyWith(
      table: const ImportTable(headers: [
        'date',
        'amount',
        'merchant',
        'currency',
        'type'
      ], rows: [
        ['2026-10-03', '12.34', '原文の相手', 'EUR', 'expense'],
        ['2026-10-04', '23.45', 'اسم خام', 'USD', 'income'],
      ], merchantAutoResolutionBlockedRowIndices: {
        0,
        1
      }),
      mapping: const ImportMapping(fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.merchant: 2,
        ImportField.currency: 3,
        ImportField.type: 4
      }),
    );
    notifier.updateMapping(ImportField.merchant, 2);
    notifier.updateParsedRow(
        notifier.state.parsedRows.first.copyWith(merchant: '訂正'));
    expect(
        notifier.state.parsedRows.first.merchantAutoResolutionBlocked, isFalse);
    expect(
        notifier.state.parsedRows.last.merchantAutoResolutionBlocked, isTrue);
    notifier.updateMapping(ImportField.amount, 1);
    expect(
        notifier.state.parsedRows.first.merchantAutoResolutionBlocked, isFalse);
    expect(
        notifier.state.parsedRows.last.merchantAutoResolutionBlocked, isTrue);
    notifier.updateMapping(ImportField.merchant, 1);
    expect(
        notifier.state.parsedRows
            .every((row) => !row.merchantAutoResolutionBlocked),
        isTrue);
    notifier.updateMapping(ImportField.merchant, 2);
    expect(
        notifier.state.parsedRows
            .every((row) => !row.merchantAutoResolutionBlocked),
        isTrue);
  });

  test('import marker defaults false and copyWith preserves unrelated edits',
      () {
    const legacy = ImportParsedRow(
        index: 0,
        date: null,
        amountCents: null,
        category: null,
        description: null,
        currency: null,
        type: null,
        errors: []);
    expect(legacy.merchantAutoResolutionBlocked, isFalse);
    final blocked = legacy.copyWith(merchantAutoResolutionBlocked: true);
    expect(
        blocked
            .copyWith(
                amountCents: 1234,
                date: DateTime(2026, 10, 3),
                description: '記録',
                isRecurring: true,
                isDuplicate: true)
            .merchantAutoResolutionBlocked,
        isTrue);
    expect(
        blocked
            .copyWith(merchantAutoResolutionBlocked: false)
            .merchantAutoResolutionBlocked,
        isFalse);
    expect(blocked.merchantAutoResolutionBlocked, isTrue);
    expect(
        const ImportTable(headers: [], rows: [])
            .merchantAutoResolutionBlockedRowIndices,
        isEmpty);
  });
}

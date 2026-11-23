import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/features/import/data/file_import_jobs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList(utf8.encode('Date,Amount\n2026-01-01,5'));
  late SupabaseClient client;
  var committed = false;
  var simulateLostAck = false;
  var uploads = 0;
  final rpcCalls = <String>[];
  setUp(() async {
    committed = false;
    simulateLostAck = false;
    uploads = 0;
    rpcCalls.clear();
    client = SupabaseClient('http://fixture.invalid', 'anon',
        httpClient: MockClient((req) async {
      http.Response ok(Object json) => http.Response(jsonEncode(json), 200,
          request: req, headers: {'content-type': 'application/json'});

      if (req.url.path.endsWith('/token')) {
        return ok({
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
        });
      }
      if (req.url.path.contains('/rpc/')) {
        final rpc = req.url.pathSegments.last;
        rpcCalls.add(rpc);
        if (rpc == 'begin_file_import') {
          expect(
              jsonDecode(req.body)['p_hash'], sha256.convert(bytes).toString());
          return ok([
            {'job_id': 'job', 'job_status': committed ? 'queued' : 'uploading'}
          ]);
        }
        if (rpc == 'accept_file_import') {
          return ok(committed ? 'queued' : 'uploading');
        }
      }
      expect(req.url.path, endsWith('/file-imports/owner/job/source'));
      uploads++;
      committed = true;
      if (simulateLostAck) {
        return http.Response('{"message":"lost acknowledgement"}', 500);
      }
      return ok({'Key': 'owner/job/source'});
    }));
    await client.auth
        .signInWithPassword(email: 'fixture@example.com', password: 'fixture');
  });
  tearDown(() => client.dispose());
  Future<String> upload({FileImportJob? interrupted}) =>
      FileImportJobs(client).upload(
          userId: 'owner',
          name: 'sample.csv',
          format: 'csv',
          bytes: bytes,
          householdId: null,
          portfolio: false,
          accountId: null,
          accountCurrency: null,
          currency: 'USD',
          language: 'en',
          interrupted: interrupted);

  test(
      'acknowledges a committed upload despite a lost response and deduplicates reselection',
      () async {
    simulateLostAck = true;
    expect(await upload(), 'queued');
    expect(await upload(), 'queued');
    expect(uploads, 1);
    expect(rpcCalls.where((s) => s == 'begin_file_import'), hasLength(2));
  });
  test('retry uses the original job and verifies the selected file', () async {
    await expectLater(
        upload(interrupted: {'id': 'job', 'fingerprint': 'wrong'}),
        throwsFormatException);
    expect(uploads, 0);
    expect(
        await upload(interrupted: {
          'id': 'job',
          'fingerprint': sha256.convert(bytes).toString()
        }),
        'queued');
    expect(rpcCalls, isNot(contains('begin_file_import')));
    expect(uploads, 1);
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/features/import/data/resumable_import_upload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('after restart only the missing bytes of a large upload are sent',
      () async {
    SharedPreferences.setMockInitialValues({});
    final bytes = Uint8List(importChunkBytes + 43)..last = 29;
    final prefs = await SharedPreferences.getInstance();
    var created = 0;
    var heads = 0;
    final sent = <int>[];
    final endpoint = Uri.parse('https://fixture.supabase.co/storage/v1');
    final client = MockClient((req) async {
      expect(req.url.host, 'fixture.storage.supabase.co');
      expect(req.headers['authorization'], 'Bearer fixture');
      switch (req.method) {
        case 'POST':
          created++;
          expect(req.headers['upload-length'], bytes.length.toString());
          return http.Response('', 201,
              headers: {'location': '/storage/v1/upload/resumable/session'});
        case 'HEAD':
          heads++;
          return http.Response('', 200, headers: {
            'upload-offset': '$importChunkBytes',
            'upload-length': '${bytes.length}'
          });
        case 'PATCH':
          sent.add(req.bodyBytes.length);
          if (sent.length == 1) {
            throw http.ClientException('Connection closed after commit');
          }
          expect(req.headers['upload-offset'], '$importChunkBytes');
          expect(req.bodyBytes.last, 29);
          return http.Response('', 204,
              headers: {'upload-offset': '${bytes.length}'});
        default:
          throw StateError(req.method);
      }
    });
    Future<void> upload() => uploadImportChunks(
        httpClient: client,
        storage: endpoint,
        object: 'owner/job/source',
        bytes: bytes,
        accessToken: () => 'fixture',
        preferences: prefs);
    await expectLater(upload(), throwsA(isA<http.ClientException>()));
    expect(prefs.getKeys(), hasLength(1));
    await upload();
    expect(sent, [importChunkBytes, 43]);
    expect([created, heads], [1, 1]);
    expect(prefs.getKeys(), isEmpty);
    client.close();
  });
  test('a session location on another origin cannot receive the owner token',
      () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.url.host, 'fixture.invalid');
      return http.Response('', 201, headers: {
        'location':
            'https://elsewhere.invalid/storage/v1/upload/resumable/session'
      });
    });
    await expectLater(
        uploadImportChunks(
            httpClient: client,
            storage: Uri.parse('https://fixture.invalid/storage/v1'),
            object: 'owner/job/source',
            bytes: Uint8List(43),
            accessToken: () => 'fixture',
            preferences: await SharedPreferences.getInstance()),
        throwsStateError);
    expect(calls, 1);
    client.close();
  });
}

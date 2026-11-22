import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const importChunkBytes = 6 * 1024 * 1024;

/// The job owns the object path. Store only the TUS session coordinate on the
/// device and obtain a fresh owner-checked access token for each request.
Future<void> uploadImportChunks({
  required http.Client httpClient,
  required Uri storage,
  required String object,
  required Uint8List bytes,
  required String Function() accessToken,
  required SharedPreferences preferences,
  String? apiKey,
  void Function(int sent, int total)? progress,
}) async {
  var endpoint = Uri.parse('${storage.toString()}/upload/resumable');
  final hosted =
      RegExp(r'^([a-z0-9]+)\.supabase\.co$').firstMatch(endpoint.host);
  if (hosted != null && endpoint.scheme == 'https') {
    endpoint = endpoint.replace(host: '${hosted[1]}.storage.supabase.co');
  }
  final cacheKey = 'file-import-tus:${endpoint.origin}:$object';
  Uri? sessionLocation(String? value) {
    if (value == null) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    final uri = endpoint.resolveUri(parsed);
    // Storage can return its canonical /v1 path when reached via /storage/v1.
    final allowedPath = uri.path.startsWith('${endpoint.path}/') ||
        (hosted != null && uri.path.startsWith('/v1/upload/resumable/'));
    if (uri.scheme != endpoint.scheme ||
        uri.host != endpoint.host ||
        uri.port != endpoint.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        !allowedPath) {
      return null;
    }
    return uri;
  }

  Future<http.Response> send(String method, Uri uri,
      {Map<String, String>? headers, Uint8List? body}) async {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers.addAll({
      'Authorization': 'Bearer ${accessToken()}',
      'Tus-Resumable': '1.0.0',
      if (apiKey != null) 'apikey': apiKey,
      ...?headers
    });
    if (body != null) request.bodyBytes = body;
    final response =
        await httpClient.send(request).timeout(const Duration(minutes: 3));
    return http.Response.fromStream(response)
        .timeout(const Duration(seconds: 30));
  }

  int offsetOf(http.Response response) {
    final offset = int.tryParse(response.headers['upload-offset'] ?? '');
    if (offset == null || offset < 0 || offset > bytes.length) {
      throw StateError('Invalid upload offset');
    }
    return offset;
  }

  var location = sessionLocation(preferences.getString(cacheKey));
  var offset = 0;
  if (location != null) {
    final response = await send('HEAD', location);
    if (response.statusCode == 404 || response.statusCode == 410) {
      await preferences.remove(cacheKey);
      location = null;
    } else if (response.statusCode == 200 || response.statusCode == 204) {
      if (int.tryParse(response.headers['upload-length'] ?? '') !=
          bytes.length) {
        throw StateError('The upload session belongs to a different file.');
      }
      offset = offsetOf(response);
    } else {
      throw StateError('Could not confirm the uploaded portion of the file.');
    }
  }
  if (location == null) {
    final metadata = {
      'bucketName': 'file-imports',
      'objectName': object,
      'contentType': 'application/octet-stream'
    };
    final response = await send('POST', endpoint, headers: {
      'Upload-Length': bytes.length.toString(),
      'Upload-Metadata': metadata.entries
          .map((e) => '${e.key} ${base64.encode(utf8.encode(e.value))}')
          .join(','),
    });
    location = sessionLocation(response.headers['location']);
    if (response.statusCode != 201 || location == null) {
      throw StateError('Could not start the upload.');
    }
    await preferences.setString(cacheKey, location.toString());
  }
  progress?.call(offset, bytes.length);
  while (offset < bytes.length) {
    final end = math.min(offset + importChunkBytes, bytes.length);
    final response = await send('PATCH', location,
        headers: {
          'Content-Type': 'application/offset+octet-stream',
          'Upload-Offset': offset.toString()
        },
        body: Uint8List.sublistView(bytes, offset, end));
    if (response.statusCode != 204 || offsetOf(response) != end) {
      throw StateError('The upload was interrupted.');
    }
    offset = end;
    progress?.call(offset, bytes.length);
  }
  await preferences.remove(cacheKey);
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef Json = Map<String, dynamic>;

class RemoteFailure implements Exception {
  RemoteFailure(this.status, [this.code]);
  final String? code;
  final int status;
}

class Backend {
  Backend(this.url, this.serviceKey, this.internalKey);
  final String url, serviceKey, internalKey;
  final _http = HttpClient()
    ..idleTimeout = const Duration(seconds: 2)
    ..connectionTimeout = const Duration(seconds: 12);

  Future<Uint8List> request(String method, String path,
      {Map<String, String>? query, Object? body, String? contentType}) async {
    try {
      return await _request(method, path,
          query: query, body: body, contentType: contentType);
    } on HttpException {
      // Long CPU-bound spreadsheet parsing can outlive a pooled connection.
      // Reads and absolute, lease-fenced checkpoints can safely be replayed.
      if (method != 'GET' && method != 'PATCH') rethrow;
      return _request(method, path,
          query: query, body: body, contentType: contentType);
    }
  }

  Future<Uint8List> _request(String method, String path,
      {Map<String, String>? query, Object? body, String? contentType}) async {
    final uri = Uri.parse('$url/$path').replace(queryParameters: query);
    final request = await _http.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set('apikey', serviceKey);
    request.headers.set('Authorization', 'Bearer $serviceKey');
    if (path.startsWith('functions/')) {
      request.headers.set('X-Moneko-Internal-Key', internalKey);
    }
    if (method == 'PATCH') {
      request.headers.set('Prefer', 'return=representation');
    }
    if (body != null) {
      request.headers.set('Content-Type', contentType ?? 'application/json');
      final payload = body is Uint8List ? body : utf8.encode(jsonEncode(body));
      request.contentLength = payload.length;
      request.add(payload);
    }
    final response = await request.close().timeout(const Duration(minutes: 4));
    final output = BytesBuilder(copy: false);
    await for (final block in response.timeout(const Duration(minutes: 1))) {
      output.add(block);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      if (path.startsWith('functions/') && output.length <= 16384) {
        try {
          final error = jsonDecode(utf8.decode(output.takeBytes()));
          if (error is Map && error['code'] is String) code = error['code'];
        } on FormatException {/* The gateway may return plain text. */}
      }
      throw RemoteFailure(response.statusCode, code);
    }
    return output.takeBytes();
  }

  Future<dynamic> json(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final bytes = await request(method, path, query: query, body: body);
    return bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
  }

  Future<dynamic> rpc(String name, [Json args = const {}]) =>
      json('POST', 'rest/v1/rpc/$name', body: args);
  Future<Json> invoke(String name, Json body) async =>
      (await json('POST', 'functions/v1/$name', body: body)) as Json;
  Future<Uint8List> read(String path) =>
      request('GET', 'storage/v1/object/authenticated/file-imports/$path');
  Future<void> write(String path, Uint8List bytes) =>
      request('POST', 'storage/v1/object/file-imports/$path',
          body: bytes, contentType: 'application/octet-stream');
  void close() => _http.close(force: true);
}

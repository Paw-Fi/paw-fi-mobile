import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'resumable_import_upload.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/utils/user_timezone.dart';

typedef FileImportJob = Map<String, dynamic>;
const _columns =
    'id,file_name,status,total,processed,imported,skipped,error_message,retryable,files_removed,fingerprint,format';

final fileImportHistoryProvider = StreamProvider.autoDispose
    .family<List<FileImportJob>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);
  final stream = StreamController<List<FileImportJob>>();
  Timer? nextPoll;
  var disposed = false;
  Future<void> refresh() async {
    var delay = const Duration(seconds: 5);
    try {
      final rows = await supabase
          .from('file_import_jobs')
          .select(_columns)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(40);
      if (disposed) return;
      stream.add(rows);
      final active = rows.any((row) =>
          ['uploading', 'queued', 'processing'].contains(row['status']));
      delay = Duration(seconds: active ? 4 : 30);
    } catch (error, stack) {
      if (!disposed) stream.addError(error, stack);
    } finally {
      if (!disposed) nextPoll = Timer(delay, refresh);
    }
  }

  stream.onListen = refresh;
  ref.onDispose(() {
    disposed = true;
    nextPoll?.cancel();
    unawaited(stream.close());
  });
  return stream.stream;
});

String _fingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

class FileImportJobs {
  FileImportJobs(this.client);
  final SupabaseClient client;

  Future<String> upload(
      {required String userId,
      required String name,
      required String format,
      required Uint8List bytes,
      required String? householdId,
      required bool portfolio,
      required String? accountId,
      required String? accountCurrency,
      required String currency,
      required String language,
      void Function(int sent, int total)? progress,
      FileImportJob? interrupted}) async {
    void checkOwner() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('Sign in to the original account and retry.');
      }
    }

    checkOwner();
    final hash = await compute(_fingerprint, bytes);
    late String id;
    if (interrupted != null) {
      if (interrupted['fingerprint'] != hash) {
        throw const FormatException(
            'Choose the same file to resume this upload.');
      }
      id = interrupted['id'] as String;
    } else {
      final now = DateTime.now();
      final timezone = await resolveDeviceTimezoneIdentifier();
      checkOwner();
      final result = await client.rpc('begin_file_import', params: {
        'p_hash': hash,
        'p_name': name,
        'p_format': format,
        'p_bytes': bytes.length,
        'p_household': householdId,
        'p_portfolio': portfolio,
        'p_account': accountId,
        'p_account_currency': accountCurrency,
        'p_currency': currency.toUpperCase(),
        'p_language': language,
        'p_date': formatDateOnlyYmd(now),
        'p_timezone': timezone,
        'p_offset': now.timeZoneOffset.inMinutes,
        'p_skip': true,
      });
      final row = (result as List).single;
      if (row['job_status'] != 'uploading') return row['job_status'] as String;
      id = row['job_id'] as String;
    }
    checkOwner();
    // An upload may have committed even when its HTTP acknowledgement was lost.
    if (await client.rpc('accept_file_import', params: {'p_id': id}) ==
        'uploading') {
      checkOwner();
      try {
        final object = '$userId/$id/source';
        if (bytes.length > importChunkBytes) {
          final httpClient = http.Client();
          try {
            await uploadImportChunks(
                httpClient: httpClient,
                storage: Uri.parse(client.storage.url),
                object: object,
                apiKey: client.auth.headers['apikey'],
                bytes: bytes,
                preferences: await SharedPreferences.getInstance(),
                progress: progress,
                accessToken: () {
                  checkOwner();
                  return client.auth.currentSession!.accessToken;
                });
          } finally {
            httpClient.close();
          }
        } else {
          await client.storage.from('file-imports').uploadBinary(object, bytes,
              fileOptions: const FileOptions(
                  contentType: 'application/octet-stream', upsert: false));
        }
      } catch (_) {
        checkOwner();
        final status =
            await client.rpc('accept_file_import', params: {'p_id': id});
        if (status == 'uploading') rethrow;
        return status as String;
      }
    }
    checkOwner();
    final accepted =
        await client.rpc('accept_file_import', params: {'p_id': id});
    if (accepted == 'uploading') {
      throw StateError(
          'The upload is incomplete. Select the same file to retry.');
    }
    return accepted as String;
  }

  Future<void> retry(String id) async {
    await client.rpc('retry_file_import', params: {'p_id': id});
  }
}

final fileImportJobsProvider =
    Provider<FileImportJobs>((ref) => FileImportJobs(supabase));

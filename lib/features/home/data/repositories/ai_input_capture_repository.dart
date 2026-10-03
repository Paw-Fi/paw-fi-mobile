import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:moneko/core/local_data/moneko_database.dart';

class AiInputCapture {
  AiInputCapture(this.mutation)
      : payload =
            Map<String, dynamic>.from(jsonDecode(mutation.payloadJson) as Map);

  final LocalMutationOutboxData mutation;
  final Map<String, dynamic> payload;
  String get id => mutation.entityId;
  String get userId => payload['userId'] as String;
  Map<String, dynamic> get body =>
      Map<String, dynamic>.from(payload['body'] as Map);
  Map<String, dynamic>? get readyResponse => payload['readyResponse'] is Map
      ? Map<String, dynamic>.from(payload['readyResponse'] as Map)
      : null;
  String transactionId(int index) =>
      payload['captureVersion'] == 1 ? 'optimistic_${id}_$index' : '$id-$index';
  List<String> get completedDestinations =>
      List<String>.from(payload['completedDestinations'] ?? []);
  DateTime get capturedAt =>
      DateTime.tryParse(payload['capturedAt']?.toString() ?? '') ??
      mutation.createdAt;
}

class AiInputCaptureRepository {
  AiInputCaptureRepository(this.database, {required this.directory});

  final MonekoDatabase database;
  final Future<Directory> Function() directory;

  Future<AiInputCapture> capture({
    required String userId,
    required Map<String, dynamic> body,
    required Map<String, dynamic> target,
    String? preferredTimezone,
    DateTime? capturedAt,
    bool isOnboarding = false,
  }) async {
    if (userId.isEmpty || body['userId'] != userId) {
      throw ArgumentError('AI capture requires its authenticated owner');
    }
    final random = Random.secure();
    final id =
        'ai_input_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final root = await directory();
    final folder = Directory('${root.path}/$id');
    await folder.create(recursive: true);
    var persisted = false;
    try {
      final storedBody = Map<String, dynamic>.from(body);
      final payload = <String, dynamic>{
        'captureVersion': 1,
        'userId': userId,
        'capturedAt': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'preferredTimezone': preferredTimezone,
        'isOnboarding': isOnboarding,
        'target': Map<String, dynamic>.from(target),
        'body': storedBody,
      };
      for (final kind in ['image', 'audio']) {
        if (storedBody[kind] is! Map) continue;
        final media = Map<String, dynamic>.from(storedBody.remove(kind) as Map);
        final path = await _writeMedia(folder, kind, media.remove('data'));
        payload[kind == 'image' ? 'localImagePath' : 'localAudioPath'] = path;
        payload['${kind}ContentType'] = media['contentType'];
      }
      if (storedBody['attachments'] is List) {
        final attachments = <Map<String, dynamic>>[];
        for (final item in storedBody.remove('attachments') as List) {
          if (item is! Map) throw const FormatException('Invalid attachment');
          final attachment = Map<String, dynamic>.from(item);
          attachment['localPath'] = await _writeMedia(folder,
              'attachment_${attachments.length}', attachment.remove('data'));
          attachments.add(attachment);
        }
        payload['localAttachments'] = attachments;
      }
      final mutation = await database.enqueueAiInput(
          clientMutationId: 'mobile:$id', entityId: id, payload: payload);
      persisted = true;
      return AiInputCapture(mutation);
    } catch (_) {
      if (!persisted && await folder.exists()) {
        await folder.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<String> _writeMedia(
      Directory folder, String name, dynamic data) async {
    if (data is! String || data.isEmpty) {
      throw const FormatException('Missing AI media bytes');
    }
    final bytes = base64Decode(data);
    if (bytes.isEmpty) throw const FormatException('Empty AI media');
    final temporary = File('${folder.path}/$name.part');
    await temporary.writeAsBytes(bytes, flush: true);
    return (await temporary.rename('${folder.path}/$name.bin')).path;
  }

  Future<List<AiInputCapture>> pending(String userId) async =>
      (await database.getPendingAiInputs(userId))
          .map(AiInputCapture.new)
          .toList(growable: false);

  Stream<List<AiInputCapture>> watchPending(String userId) =>
      Stream<List<AiInputCapture>>.multi((controller) {
        var disposed = false;
        var refreshing = false;
        var refreshAgain = false;
        Future<void> refresh() async {
          if (refreshing) {
            refreshAgain = true;
            return;
          }
          refreshing = true;
          do {
            refreshAgain = false;
            try {
              final captures = await pending(userId);
              if (!disposed) controller.add(captures);
            } catch (error, stack) {
              if (!disposed) controller.addError(error, stack);
            }
          } while (refreshAgain && !disposed);
          refreshing = false;
        }

        final subscription =
            database.aiInputChanges.listen((_) => unawaited(refresh()));
        controller.onCancel = () async {
          disposed = true;
          await subscription.cancel();
        };
        unawaited(refresh());
      });

  Future<AiInputCapture> hold(AiInputCapture capture) async {
    if (!await database.holdAiInputForForeground(capture.mutation)) {
      throw StateError('AI capture changed before processing');
    }
    return capture;
  }

  Future<AiInputCapture> checkpoint(
      AiInputCapture capture, Map<String, dynamic> changes) async {
    final next = {...capture.payload, ...changes};
    if (!await database.checkpointAiInput(
        clientMutationId: capture.mutation.clientMutationId,
        expectedPayloadJson: capture.mutation.payloadJson,
        payload: next)) {
      throw StateError('AI capture changed during processing');
    }
    return (await pending(capture.userId))
        .firstWhere((item) => item.id == capture.id);
  }

  Future<Map<String, dynamic>> requestBody(AiInputCapture capture) async {
    final body = capture.body;
    for (final kind in ['image', 'audio']) {
      final path = capture
          .payload[kind == 'image' ? 'localImagePath' : 'localAudioPath'];
      if (path is! String || path.isEmpty) continue;
      body[kind] = {
        'data': base64Encode(await File(path).readAsBytes()),
        'contentType': capture.payload['${kind}ContentType'] ??
            (kind == 'image' ? 'image/jpeg' : 'audio/mpeg'),
      };
    }
    if (capture.payload['localAttachments'] is List) {
      body['attachments'] = await Future.wait(
          (capture.payload['localAttachments'] as List).map((raw) async {
        final item = Map<String, dynamic>.from(raw as Map);
        final path = item.remove('localPath') as String;
        return {...item, 'data': base64Encode(await File(path).readAsBytes())};
      }));
    }
    return body;
  }

  Future<void> removeMaterializedMedia(AiInputCapture capture) async {
    if ((await pending(capture.userId)).any((item) => item.id == capture.id)) {
      return;
    }
    // Only this repository's own capture directory can be removed here.
    final root = await directory();
    if (!RegExp(r'^ai_input_[a-f0-9]{32}$').hasMatch(capture.id)) {
      return;
    }
    final folder = Directory('${root.path}/${capture.id}');
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

class AiInputResumeController {
  String? _activeId;
  final _attempted = <String>{};
  bool _disposed = false;
  bool get isDisposed => _disposed;
  bool get isActive => _activeId != null;

  bool tryStart(String id) {
    if (_disposed || _activeId != null || !_attempted.add(id)) return false;
    _activeId = id;
    return true;
  }

  void finish(String id) {
    if (_activeId == id) _activeId = null;
  }

  void wake() {
    _attempted.clear();
    if (_activeId != null) _attempted.add(_activeId!);
  }

  void dispose() {
    _disposed = true;
  }
}

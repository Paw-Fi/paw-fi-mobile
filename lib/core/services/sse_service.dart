import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';

/// Server-Sent Events (SSE) service for streaming responses
class SSEService {
  /// Stream SSE events from a URL with POST body and headers
  static Stream<SSEEvent> streamRequest({
    required Uri url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = const Duration(minutes: 3),
  }) async* {
    http.Client? client;
    http.StreamedResponse? response;

    try {
      client = http.Client();
      final request = http.Request('POST', url);

      // Set headers
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      if (headers != null) {
        request.headers.addAll(headers);
      }

      // Set body
      request.body = jsonEncode(body);

      debugPrint('[SSEService] Sending request to ${url.toString()}');

      // Send request and get streaming response
      response = await client.send(request).timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      debugPrint('[SSEService] Connected, streaming events...');

      // Parse SSE stream
      String buffer = '';
      String? currentEvent;
      String? currentData;

      await for (final chunk
          in response.stream.transform(utf8.decoder).timeout(timeout)) {
        buffer += chunk;

        // Process complete lines
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex);
          buffer = buffer.substring(newlineIndex + 1);

          if (line.isEmpty) {
            // Empty line signals end of event
            if (currentEvent != null && currentData != null) {
              yield SSEEvent(
                event: currentEvent,
                data: _parseEventData(currentData),
              );
            }
            currentEvent = null;
            currentData = null;
          } else if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final dataLine = line.substring(5).trim();
            currentData =
                currentData == null ? dataLine : '$currentData\n$dataLine';
          }
        }
      }

      debugPrint('[SSEService] Stream completed');
    } catch (e) {
      debugPrint('[SSEService] Error: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  /// Parse event data as JSON or return as-is
  static dynamic _parseEventData(String data) {
    try {
      return jsonDecode(data);
    } catch (e) {
      return data;
    }
  }
}

String formatStreamingProgressMessage(
  String message, {
  int? currentItem,
  int? totalItems,
}) {
  if (currentItem != null && totalItems != null) {
    return '$message ($currentItem/$totalItems)';
  }
  return message;
}

int? _parseProgressInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// SSE event model
class SSEEvent {
  final String event;
  final dynamic data;

  const SSEEvent({
    required this.event,
    required this.data,
  });

  @override
  String toString() => 'SSEEvent(event: $event, data: $data)';
}

class StreamingProgressEvent {
  final String stage;
  final String message;
  final int? currentItem;
  final int? totalItems;

  const StreamingProgressEvent({
    required this.stage,
    required this.message,
    this.currentItem,
    this.totalItems,
  });

  factory StreamingProgressEvent.fromJson(Map<String, dynamic> json) {
    return StreamingProgressEvent(
      stage: json['stage'] as String? ?? 'processing',
      message: sanitizeUtf16(json['message'] as String? ?? 'Processing...'),
      currentItem: _parseProgressInt(json['currentItem']),
      totalItems: _parseProgressInt(json['totalItems']),
    );
  }

  String get displayMessage => formatStreamingProgressMessage(
        message,
        currentItem: currentItem,
        totalItems: totalItems,
      );

  @override
  String toString() {
    return 'StreamingProgressEvent(stage: $stage, message: $message, currentItem: $currentItem, totalItems: $totalItems)';
  }
}

/// Analysis progress event model for AI expense processing
class AnalysisProgressEvent extends StreamingProgressEvent {
  const AnalysisProgressEvent({
    required super.stage,
    required super.message,
    super.currentItem,
    super.totalItems,
  });

  factory AnalysisProgressEvent.fromJson(Map<String, dynamic> json) {
    return AnalysisProgressEvent(
      stage: json['stage'] as String? ?? 'processing',
      message: sanitizeUtf16(json['message'] as String? ?? 'Processing...'),
      currentItem: _parseProgressInt(json['currentItem']),
      totalItems: _parseProgressInt(json['totalItems']),
    );
  }
}

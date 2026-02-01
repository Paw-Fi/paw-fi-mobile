import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents an SSE event from the server
class SSEEvent {
  final String event;
  final Map<String, dynamic> data;

  SSEEvent({required this.event, required this.data});

  @override
  String toString() => 'SSEEvent(event: $event, data: $data)';
}

/// Progress event from analyze-expense SSE stream
class AnalysisProgressEvent {
  final String type;
  final int? current;
  final int? total;
  final String? message;

  AnalysisProgressEvent({
    required this.type,
    this.current,
    this.total,
    this.message,
  });

  factory AnalysisProgressEvent.fromJson(Map<String, dynamic> json) {
    return AnalysisProgressEvent(
      type: json['type'] as String? ?? 'unknown',
      current: json['current'] as int?,
      total: json['total'] as int?,
      message: json['message'] as String?,
    );
  }

  String get displayMessage {
    if (message != null && message!.isNotEmpty) return message!;

    switch (type) {
      case 'started':
        return 'Starting analysis...';
      case 'extracting_text':
        return 'Extracting text from document...';
      case 'analyzing_chunk':
        if (current != null && total != null) {
          return 'Analyzing chunk $current of $total...';
        }
        return 'Analyzing document...';
      case 'processing_vision':
        return 'Processing with AI vision...';
      case 'complete':
        return 'Analysis complete';
      default:
        return 'Processing...';
    }
  }

  @override
  String toString() =>
      'AnalysisProgressEvent(type: $type, current: $current, total: $total, message: $message)';
}

/// Service for handling Server-Sent Events (SSE) streams
class SSEService {
  /// Parses SSE text stream into events
  ///
  /// SSE format:
  /// ```
  /// event: eventName
  /// data: {"key": "value"}
  ///
  /// event: anotherEvent
  /// data: {"key2": "value2"}
  /// ```
  static Stream<SSEEvent> parseSSEStream(Stream<String> textStream) async* {
    String buffer = '';

    await for (final chunk in textStream) {
      buffer += chunk;

      // Process complete events (separated by double newlines)
      final events = buffer.split('\n\n');

      // Keep the last potentially incomplete event in the buffer
      buffer = events.removeLast();

      for (final eventBlock in events) {
        if (eventBlock.trim().isEmpty) continue;

        final lines = eventBlock.split('\n');
        String? eventName;
        String? data;

        for (final line in lines) {
          if (line.startsWith('event: ')) {
            eventName = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            data = line.substring(6);
          }
        }

        if (data != null) {
          try {
            final jsonData = json.decode(data) as Map<String, dynamic>;
            yield SSEEvent(
              event: eventName ?? 'message',
              data: jsonData,
            );
          } catch (e) {
            debugPrint('[SSE] Failed to parse event data: $e');
          }
        }
      }
    }

    // Process any remaining data in buffer
    if (buffer.trim().isNotEmpty) {
      final lines = buffer.split('\n');
      String? eventName;
      String? data;

      for (final line in lines) {
        if (line.startsWith('event: ')) {
          eventName = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          data = line.substring(6);
        }
      }

      if (data != null) {
        try {
          final jsonData = json.decode(data) as Map<String, dynamic>;
          yield SSEEvent(
            event: eventName ?? 'message',
            data: jsonData,
          );
        } catch (e) {
          debugPrint('[SSE] Failed to parse final event data: $e');
        }
      }
    }
  }

  /// Makes an SSE request and returns a stream of events
  ///
  /// The request is made using HTTP POST with the given body.
  /// Returns a stream of [SSEEvent] objects.
  ///
  /// Throws if the request fails or the server returns an error status.
  static Stream<SSEEvent> streamRequest({
    required Uri url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = const Duration(minutes: 3),
  }) async* {
    final client = http.Client();

    try {
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        ...?headers,
      });
      request.body = json.encode(body);

      final response = await client.send(request).timeout(timeout);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw SSEException(
          statusCode: response.statusCode,
          message: 'SSE request failed: $errorBody',
        );
      }

      // Convert byte stream to string stream and parse as SSE
      final textStream = response.stream.transform(utf8.decoder);

      yield* parseSSEStream(textStream);
    } finally {
      client.close();
    }
  }
}

/// Exception thrown when SSE request fails
class SSEException implements Exception {
  final int? statusCode;
  final String message;

  SSEException({this.statusCode, required this.message});

  @override
  String toString() =>
      'SSEException(statusCode: $statusCode, message: $message)';
}

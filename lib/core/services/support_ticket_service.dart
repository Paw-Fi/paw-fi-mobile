import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supportTicketServiceProvider = Provider<SupportTicketService>((ref) {
  final client = Supabase.instance.client;
  return SupportTicketService(client);
});

class SupportTicketService {
  SupportTicketService(this._supabase);

  final SupabaseClient _supabase;

  Future<SupportTicketSubmissionResult> submitTicket({
    required SupportTicketType type,
    required String message,
    Map<String, dynamic>? diagnostics,
    Map<String, dynamic>? metadata,
    List<SupportTicketAttachment> attachments = const [],
    String? appVersion,
    String? platform,
    String source = 'mobile',
  }) async {
    final payload = <String, dynamic>{
      'type': type.value,
      'message': message.trim(),
      'diagnostics': diagnostics,
      'metadata': metadata ?? <String, dynamic>{},
      'appVersion': appVersion,
      'platform': platform,
      'source': source,
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map(
              (attachment) => <String, dynamic>{
                'base64': attachment.base64,
                if (attachment.fileName != null) 'fileName': attachment.fileName,
                if (attachment.contentType != null)
                  'contentType': attachment.contentType,
              },
            )
            .toList(),
    }..removeWhere((key, value) => value == null);

    final response = await _supabase.functions.invoke(
      'support-ticket-create',
      body: payload,
    );

    final data = response.data;
    if (response.status != 200 || data is! Map<String, dynamic>) {
      final message = data is Map<String, dynamic> && data['error'] is String
          ? data['error'] as String
          : 'Failed to submit support ticket';
      throw SupportTicketException(message);
    }

    return SupportTicketSubmissionResult(
      success: data['success'] == true,
      ticketId: data['ticketId'] as String?,
      status: data['status'] as String?,
    );
  }
}

class SupportTicketAttachment {
  const SupportTicketAttachment({
    required this.base64,
    this.fileName,
    this.contentType,
  });

  final String base64;
  final String? fileName;
  final String? contentType;
}

class SupportTicketSubmissionResult {
  const SupportTicketSubmissionResult({
    required this.success,
    this.ticketId,
    this.status,
  });

  final bool success;
  final String? ticketId;
  final String? status;
}

class SupportTicketException implements Exception {
  SupportTicketException(this.message);

  final String message;

  @override
  String toString() => 'SupportTicketException: $message';
}

enum SupportTicketType {
  bug('bug'),
  feedback('feedback'),
  featureRequest('feature_request'),
  other('other');

  const SupportTicketType(this.value);

  final String value;
}

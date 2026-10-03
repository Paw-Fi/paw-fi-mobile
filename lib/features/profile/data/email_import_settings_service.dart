import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/profile/domain/email_import_settings.dart';

class EmailImportSettingsService {
  EmailImportSettingsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<void> watchSenders(String userId) => _client
      .from('email_import_sender_whitelist')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((_) {});

  Future<Map<String, dynamic>> verifySender(String token) async {
    final response = await _client.functions.invoke(
      'email-import-sender-verify',
      body: {'token': token},
    );
    final body = response.data;
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! Map<String, dynamic>) {
      throw FunctionException(status: response.status, details: body);
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<EmailImportSettings> getSettings() async {
    final response = await _invoke(
      action: 'get',
    );
    return EmailImportSettings.fromJson(response);
  }

  Future<EmailImportSettings> updateSettings({
    required bool enabled,
    required String scopeId,
    required bool isPortfolio,
    String? accountId,
  }) async {
    final response = await _invoke(
      action: 'update_settings',
      body: {
        'enabled': enabled,
        'householdId': scopeId == 'personal' ? null : scopeId,
        'isPortfolio': isPortfolio,
        'accountId': accountId,
      },
    );
    return EmailImportSettings.fromJson(response);
  }

  Future<EmailImportSettings> addWhitelistEmail(String email) async {
    final response = await _invoke(
      action: 'add_whitelist',
      body: {'email': email, 'senderVerificationVersion': 1},
    );
    return EmailImportSettings.fromJson(response);
  }

  Future<EmailImportSettings> removeWhitelistEmail(String email) async {
    final response = await _invoke(
      action: 'remove_whitelist',
      body: {'email': email},
    );
    return EmailImportSettings.fromJson(response);
  }

  Future<Map<String, dynamic>> _invoke({
    required String action,
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final response = await _client.functions.invoke(
      'email-import-settings',
      body: {
        'action': action,
        ...body,
      },
    );

    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response payload');
    }
    final success = responseData['success'] == true;
    if (response.status >= 400 || !success) {
      throw FunctionException(status: response.status, details: responseData);
    }
    final data = responseData['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response payload');
    }
    return data;
  }
}

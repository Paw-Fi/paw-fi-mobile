import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/profile/domain/email_import_settings.dart';

class EmailImportSettingsService {
  EmailImportSettingsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      body: {'email': email},
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
    if (response.status >= 400) {
      final errorMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;
      throw Exception(errorMessage ?? 'Request failed with ${response.status}');
    }
    if (responseData is! Map<String, dynamic>) {
      throw Exception('Unexpected response payload');
    }
    final success = responseData['success'] == true;
    final data = responseData['data'];
    if (!success || data is! Map<String, dynamic>) {
      throw Exception(responseData['error']?.toString() ?? 'Request failed');
    }
    return data;
  }
}

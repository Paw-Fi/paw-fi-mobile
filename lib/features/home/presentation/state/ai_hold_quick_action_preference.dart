import 'package:shared_preferences/shared_preferences.dart';

const String aiHoldQuickActionPreferenceKey =
    'home_ai_hold_quick_action_preference';

enum AiHoldQuickAction {
  camera,
  photoLibrary,
  recordAudio,
  textInputDrawer,
}

extension AiHoldQuickActionStorage on AiHoldQuickAction {
  String get storageValue {
    return switch (this) {
      AiHoldQuickAction.camera => 'camera',
      AiHoldQuickAction.photoLibrary => 'photo_library',
      AiHoldQuickAction.recordAudio => 'record_audio',
      AiHoldQuickAction.textInputDrawer => 'text_input_drawer',
    };
  }

  static AiHoldQuickAction? fromStorageValue(String? value) {
    return switch (value) {
      'camera' => AiHoldQuickAction.camera,
      'photo_library' => AiHoldQuickAction.photoLibrary,
      'record_audio' => AiHoldQuickAction.recordAudio,
      'text_input_drawer' => AiHoldQuickAction.textInputDrawer,
      _ => null,
    };
  }
}

AiHoldQuickAction? readAiHoldQuickActionPreference(SharedPreferences prefs) {
  return AiHoldQuickActionStorage.fromStorageValue(
    prefs.getString(aiHoldQuickActionPreferenceKey),
  );
}

Future<void> writeAiHoldQuickActionPreference(
  SharedPreferences prefs,
  AiHoldQuickAction? action,
) async {
  if (action == null) {
    await prefs.remove(aiHoldQuickActionPreferenceKey);
    return;
  }

  await prefs.setString(aiHoldQuickActionPreferenceKey, action.storageValue);
}

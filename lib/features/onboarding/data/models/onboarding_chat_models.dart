import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_chat_models.freezed.dart';
part 'onboarding_chat_models.g.dart';

/// Request model for AI onboarding coach API
@freezed
class OnboardingCoachRequest with _$OnboardingCoachRequest {
  const factory OnboardingCoachRequest({
    required String message,
    @Default(false) bool isFirstMessage,
    @Default(false) bool withWelcomeAndResponse,
  }) = _OnboardingCoachRequest;

  factory OnboardingCoachRequest.fromJson(Map<String, dynamic> json) =>
      _$OnboardingCoachRequestFromJson(json);
}

/// Response model for AI onboarding coach API
@freezed
class OnboardingCoachResponse with _$OnboardingCoachResponse {
  const factory OnboardingCoachResponse({
    required String response,
    String? conversationId,
  }) = _OnboardingCoachResponse;

  factory OnboardingCoachResponse.fromJson(Map<String, dynamic> json) =>
      _$OnboardingCoachResponseFromJson(json);
}

/// Chat message model for UI
@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String content,
    required bool isUser,
    required DateTime timestamp,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

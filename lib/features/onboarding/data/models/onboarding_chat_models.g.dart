// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OnboardingCoachRequestImpl _$$OnboardingCoachRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$OnboardingCoachRequestImpl(
      message: json['message'] as String,
      isFirstMessage: json['isFirstMessage'] as bool? ?? false,
      withWelcomeAndResponse:
          json['withWelcomeAndResponse'] as bool? ?? false,
    );

Map<String, dynamic> _$$OnboardingCoachRequestImplToJson(
        _$OnboardingCoachRequestImpl instance) =>
    <String, dynamic>{
      'message': instance.message,
      'isFirstMessage': instance.isFirstMessage,
      'withWelcomeAndResponse': instance.withWelcomeAndResponse,
    };

_$OnboardingCoachResponseImpl _$$OnboardingCoachResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$OnboardingCoachResponseImpl(
      response: json['response'] as String,
      conversationId: json['conversationId'] as String?,
    );

Map<String, dynamic> _$$OnboardingCoachResponseImplToJson(
        _$OnboardingCoachResponseImpl instance) =>
    <String, dynamic>{
      'response': instance.response,
      'conversationId': instance.conversationId,
    };

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'content': instance.content,
      'isUser': instance.isUser,
      'timestamp': instance.timestamp.toIso8601String(),
    };

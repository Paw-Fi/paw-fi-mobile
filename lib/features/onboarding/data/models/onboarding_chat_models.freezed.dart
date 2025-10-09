// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_chat_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OnboardingCoachRequest _$OnboardingCoachRequestFromJson(
    Map<String, dynamic> json) {
  return _OnboardingCoachRequest.fromJson(json);
}

/// @nodoc
mixin _$OnboardingCoachRequest {
  String get message => throw _privateConstructorUsedError;
  bool get isFirstMessage => throw _privateConstructorUsedError;
  bool get withWelcomeAndResponse => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $OnboardingCoachRequestCopyWith<OnboardingCoachRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingCoachRequestCopyWith<$Res> {
  factory $OnboardingCoachRequestCopyWith(OnboardingCoachRequest value,
          $Res Function(OnboardingCoachRequest) then) =
      _$OnboardingCoachRequestCopyWithImpl<$Res, OnboardingCoachRequest>;
  @useResult
  $Res call({String message, bool isFirstMessage, bool withWelcomeAndResponse});
}

/// @nodoc
class _$OnboardingCoachRequestCopyWithImpl<$Res,
        $Val extends OnboardingCoachRequest>
    implements $OnboardingCoachRequestCopyWith<$Res> {
  _$OnboardingCoachRequestCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? isFirstMessage = null,
    Object? withWelcomeAndResponse = null,
  }) {
    return _then(_value.copyWith(
      message: null == message
          ? _value.message
          : message,
      isFirstMessage: null == isFirstMessage
          ? _value.isFirstMessage
          : isFirstMessage,
      withWelcomeAndResponse: null == withWelcomeAndResponse
          ? _value.withWelcomeAndResponse
          : withWelcomeAndResponse,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OnboardingCoachRequestImplCopyWith<$Res>
    implements $OnboardingCoachRequestCopyWith<$Res> {
  factory _$$OnboardingCoachRequestImplCopyWith(
          _$OnboardingCoachRequestImpl value,
          $Res Function(_$OnboardingCoachRequestImpl) then) =
      __$$OnboardingCoachRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message, bool isFirstMessage, bool withWelcomeAndResponse});
}

/// @nodoc
class __$$OnboardingCoachRequestImplCopyWithImpl<$Res>
    extends _$OnboardingCoachRequestCopyWithImpl<$Res,
        _$OnboardingCoachRequestImpl>
    implements _$$OnboardingCoachRequestImplCopyWith<$Res> {
  __$$OnboardingCoachRequestImplCopyWithImpl(
      _$OnboardingCoachRequestImpl _value,
      $Res Function(_$OnboardingCoachRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? isFirstMessage = null,
    Object? withWelcomeAndResponse = null,
  }) {
    return _then(_$OnboardingCoachRequestImpl(
      message: null == message
          ? _value.message
          : message,
      isFirstMessage: null == isFirstMessage
          ? _value.isFirstMessage
          : isFirstMessage,
      withWelcomeAndResponse: null == withWelcomeAndResponse
          ? _value.withWelcomeAndResponse
          : withWelcomeAndResponse,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OnboardingCoachRequestImpl implements _OnboardingCoachRequest {
  const _$OnboardingCoachRequestImpl(
      {required this.message,
      this.isFirstMessage = false,
      this.withWelcomeAndResponse = false});

  factory _$OnboardingCoachRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$OnboardingCoachRequestImplFromJson(json);

  @override
  final String message;
  @override
  @JsonKey()
  final bool isFirstMessage;
  @override
  @JsonKey()
  final bool withWelcomeAndResponse;

  @override
  String toString() {
    return 'OnboardingCoachRequest(message: $message, isFirstMessage: $isFirstMessage, withWelcomeAndResponse: $withWelcomeAndResponse)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingCoachRequestImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.isFirstMessage, isFirstMessage) ||
                other.isFirstMessage == isFirstMessage) &&
            (identical(other.withWelcomeAndResponse, withWelcomeAndResponse) ||
                other.withWelcomeAndResponse == withWelcomeAndResponse));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, message, isFirstMessage, withWelcomeAndResponse);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingCoachRequestImplCopyWith<_$OnboardingCoachRequestImpl>
      get copyWith => __$$OnboardingCoachRequestImplCopyWithImpl<
          _$OnboardingCoachRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OnboardingCoachRequestImplToJson(
      this,
    );
  }
}

abstract class _OnboardingCoachRequest implements OnboardingCoachRequest {
  const factory _OnboardingCoachRequest(
      {required final String message,
      final bool isFirstMessage,
      final bool withWelcomeAndResponse}) = _$OnboardingCoachRequestImpl;

  factory _OnboardingCoachRequest.fromJson(Map<String, dynamic> json) =
      _$OnboardingCoachRequestImpl.fromJson;

  @override
  String get message;
  @override
  bool get isFirstMessage;
  @override
  bool get withWelcomeAndResponse;
  @override
  @JsonKey(ignore: true)
  _$$OnboardingCoachRequestImplCopyWith<_$OnboardingCoachRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

OnboardingCoachResponse _$OnboardingCoachResponseFromJson(
    Map<String, dynamic> json) {
  return _OnboardingCoachResponse.fromJson(json);
}

/// @nodoc
mixin _$OnboardingCoachResponse {
  String get response => throw _privateConstructorUsedError;
  String? get conversationId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $OnboardingCoachResponseCopyWith<OnboardingCoachResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingCoachResponseCopyWith<$Res> {
  factory $OnboardingCoachResponseCopyWith(OnboardingCoachResponse value,
          $Res Function(OnboardingCoachResponse) then) =
      _$OnboardingCoachResponseCopyWithImpl<$Res, OnboardingCoachResponse>;
  @useResult
  $Res call({String response, String? conversationId});
}

/// @nodoc
class _$OnboardingCoachResponseCopyWithImpl<$Res,
        $Val extends OnboardingCoachResponse>
    implements $OnboardingCoachResponseCopyWith<$Res> {
  _$OnboardingCoachResponseCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? response = null,
    Object? conversationId = freezed,
  }) {
    return _then(_value.copyWith(
      response: null == response
          ? _value.response
          : response,
      conversationId: freezed == conversationId
          ? _value.conversationId
          : conversationId,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OnboardingCoachResponseImplCopyWith<$Res>
    implements $OnboardingCoachResponseCopyWith<$Res> {
  factory _$$OnboardingCoachResponseImplCopyWith(
          _$OnboardingCoachResponseImpl value,
          $Res Function(_$OnboardingCoachResponseImpl) then) =
      __$$OnboardingCoachResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String response, String? conversationId});
}

/// @nodoc
class __$$OnboardingCoachResponseImplCopyWithImpl<$Res>
    extends _$OnboardingCoachResponseCopyWithImpl<$Res,
        _$OnboardingCoachResponseImpl>
    implements _$$OnboardingCoachResponseImplCopyWith<$Res> {
  __$$OnboardingCoachResponseImplCopyWithImpl(
      _$OnboardingCoachResponseImpl _value,
      $Res Function(_$OnboardingCoachResponseImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? response = null,
    Object? conversationId = freezed,
  }) {
    return _then(_$OnboardingCoachResponseImpl(
      response: null == response
          ? _value.response
          : response,
      conversationId: freezed == conversationId
          ? _value.conversationId
          : conversationId,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OnboardingCoachResponseImpl implements _OnboardingCoachResponse {
  const _$OnboardingCoachResponseImpl(
      {required this.response, this.conversationId});

  factory _$OnboardingCoachResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$OnboardingCoachResponseImplFromJson(json);

  @override
  final String response;
  @override
  final String? conversationId;

  @override
  String toString() {
    return 'OnboardingCoachResponse(response: $response, conversationId: $conversationId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingCoachResponseImpl &&
            (identical(other.response, response) ||
                other.response == response) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, response, conversationId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingCoachResponseImplCopyWith<_$OnboardingCoachResponseImpl>
      get copyWith => __$$OnboardingCoachResponseImplCopyWithImpl<
          _$OnboardingCoachResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OnboardingCoachResponseImplToJson(
      this,
    );
  }
}

abstract class _OnboardingCoachResponse implements OnboardingCoachResponse {
  const factory _OnboardingCoachResponse(
      {required final String response,
      final String? conversationId}) = _$OnboardingCoachResponseImpl;

  factory _OnboardingCoachResponse.fromJson(Map<String, dynamic> json) =
      _$OnboardingCoachResponseImpl.fromJson;

  @override
  String get response;
  @override
  String? get conversationId;
  @override
  @JsonKey(ignore: true)
  _$$OnboardingCoachResponseImplCopyWith<_$OnboardingCoachResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  String get content => throw _privateConstructorUsedError;
  bool get isUser => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call({String content, bool isUser, DateTime timestamp});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? isUser = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      content: null == content
          ? _value.content
          : content,
      isUser: null == isUser
          ? _value.isUser
          : isUser,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String content, bool isUser, DateTime timestamp});
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? isUser = null,
    Object? timestamp = null,
  }) {
    return _then(_$ChatMessageImpl(
      content: null == content
          ? _value.content
          : content,
      isUser: null == isUser
          ? _value.isUser
          : isUser,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl implements _ChatMessage {
  const _$ChatMessageImpl(
      {required this.content, required this.isUser, required this.timestamp});

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  final String content;
  @override
  final bool isUser;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'ChatMessage(content: $content, isUser: $isUser, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.isUser, isUser) || other.isUser == isUser) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, content, isUser, timestamp);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
      {required final String content,
      required final bool isUser,
      required final DateTime timestamp}) = _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  String get content;
  @override
  bool get isUser;
  @override
  DateTime get timestamp;
  @override
  @JsonKey(ignore: true)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

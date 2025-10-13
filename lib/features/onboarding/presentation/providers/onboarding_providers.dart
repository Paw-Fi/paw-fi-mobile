import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/onboarding/data/api/onboarding_api.dart';
import 'package:moneko/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:moneko/features/onboarding/data/models/onboarding_chat_models.dart';
import 'package:moneko/features/onboarding/data/models/goal_creation_models.dart';

part 'onboarding_providers.g.dart';

/// Dio instance provider for onboarding API
@riverpod
Dio onboardingDio(OnboardingDioRef ref) {
  final dio = Dio();
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  dio.options = BaseOptions(
    baseUrl: '$supabaseUrl/functions/v1',
    headers: {
      'Authorization': 'Bearer $supabaseAnonKey',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  );

  return dio;
}

/// Onboarding API provider
@riverpod
OnboardingApi onboardingApi(OnboardingApiRef ref) {
  final dio = ref.watch(onboardingDioProvider);
  return OnboardingApi(dio);
}

/// Onboarding repository provider
@riverpod
OnboardingRepository onboardingRepository(OnboardingRepositoryRef ref) {
  final api = ref.watch(onboardingApiProvider);
  return OnboardingRepository(api);
}

/// Chat state provider
@riverpod
class OnboardingChat extends _$OnboardingChat {
  @override
  List<ChatMessage> build() {
    return [];
  }

  /// Add a user message
  void addUserMessage(String content) {
    state = [
      ...state,
      ChatMessage(
        content: content,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    ];
  }

  /// Add an AI response message
  void addAIMessage(String content) {
    state = [
      ...state,
      ChatMessage(
        content: content,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }

  /// Clear all messages
  void clearMessages() {
    state = [];
  }

  /// Send message to AI coach
  Future<void> sendMessage({
    required String message,
    bool isFirstMessage = false,
    bool withWelcomeAndResponse = false,
  }) async {
    final repository = ref.read(onboardingRepositoryProvider);

    // Add user message immediately
    addUserMessage(message);

    try {
      final response = await repository.sendMessage(
        message: message,
        isFirstMessage: isFirstMessage,
        withWelcomeAndResponse: withWelcomeAndResponse,
      );

      // Add AI response
      addAIMessage(response.response);
    } catch (e) {
      // Add error message
      addAIMessage('Sorry, I encountered an error. Please try again.');
      rethrow;
    }
  }

  /// Initialize chat with welcome message
  Future<void> initializeChat() async {
    final repository = ref.read(onboardingRepositoryProvider);

    try {
      final response = await repository.sendMessage(
        message: '',
        isFirstMessage: true,
        withWelcomeAndResponse: true,
      );

      // Add AI welcome message
      addAIMessage(response.response);
    } catch (e) {
      addAIMessage('Welcome! I\'m here to help you set up your financial goals.');
    }
  }
}

/// Loading state provider for chat
@riverpod
class ChatLoading extends _$ChatLoading {
  @override
  bool build() {
    return false;
  }

  void setLoading(bool value) {
    state = value;
  }
}

/// Current goal creation result provider
@riverpod
class CurrentGoal extends _$CurrentGoal {
  @override
  GoalCreationResult? build() {
    return null;
  }

  void setGoal(GoalCreationResult? goal) {
    state = goal;
  }

  void clearGoal() {
    state = null;
  }
}

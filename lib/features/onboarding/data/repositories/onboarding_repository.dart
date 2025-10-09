import 'package:dio/dio.dart';
import 'package:rsupa/core/core.dart';
import 'package:rsupa/features/onboarding/data/api/onboarding_api.dart';
import 'package:rsupa/features/onboarding/data/models/onboarding_chat_models.dart';
import 'package:rsupa/features/onboarding/data/models/goal_creation_models.dart';

class OnboardingRepository {
  final OnboardingApi _api;

  OnboardingRepository(this._api);

  /// Send a message to the AI onboarding coach
  Future<OnboardingCoachResponse> sendMessage({
    required String message,
    bool isFirstMessage = false,
    bool withWelcomeAndResponse = false,
  }) async {
    try {
      final request = OnboardingCoachRequest(
        message: message,
        isFirstMessage: isFirstMessage,
        withWelcomeAndResponse: withWelcomeAndResponse,
      );
      return await _api.sendMessage(request);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a financial goal using AI with questionnaire data
  Future<GoalCreationResult> createGoalWithAI({
    required Map<String, dynamic> questionnaireData,
    String? mode,
  }) async {
    try {
      final request = CreateGoalWithAIRequest(
        questionnaireData: questionnaireData,
        mode: mode,
      );
      return await _api.createGoalWithAI(request);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Save user's financial health profile
  Future<FinancialHealthProfileResponse> saveFinancialProfile({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double currentSavings,
    required double existingDebts,
    required String riskTolerance,
    required int savingHorizon,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final request = FinancialHealthProfileRequest(
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        currentSavings: currentSavings,
        existingDebts: existingDebts,
        riskTolerance: riskTolerance,
        savingHorizon: savingHorizon,
        additionalData: additionalData,
      );
      return await _api.saveFinancialProfile(request);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to user-friendly messages
  Exception _handleError(DioException error) {
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final message = error.response!.data?['message'] ?? error.message;

      switch (statusCode) {
        case 400:
          return Exception('Invalid request: $message');
        case 401:
          return Exception('Unauthorized. Please sign in again.');
        case 403:
          return Exception('Access denied.');
        case 404:
          return Exception('Service not found.');
        case 429:
          return Exception('Too many requests. Please try again later.');
        case 500:
          return Exception('Server error. Please try again later.');
        default:
          return Exception('An error occurred: $message');
      }
    } else {
      // Network error
      return Exception('Network error. Please check your connection.');
    }
  }
}

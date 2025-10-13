import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:moneko/features/onboarding/data/models/onboarding_chat_models.dart';
import 'package:moneko/features/onboarding/data/models/goal_creation_models.dart';

part 'onboarding_api.g.dart';

@RestApi()
abstract class OnboardingApi {
  factory OnboardingApi(Dio dio, {String baseUrl}) = _OnboardingApi;

  /// Chat with AI onboarding coach
  /// Endpoint: POST /ai-onboarding-coach
  @POST('/ai-onboarding-coach')
  Future<OnboardingCoachResponse> sendMessage(
    @Body() OnboardingCoachRequest request,
  );

  /// Create a financial goal with AI assistance
  /// Endpoint: POST /create-goal-with-ai
  @POST('/create-goal-with-ai')
  Future<GoalCreationResult> createGoalWithAI(
    @Body() CreateGoalWithAIRequest request,
  );

  /// Save financial health profile
  /// Endpoint: POST /financial-health-profile
  @POST('/financial-health-profile')
  Future<FinancialHealthProfileResponse> saveFinancialProfile(
    @Body() FinancialHealthProfileRequest request,
  );
}

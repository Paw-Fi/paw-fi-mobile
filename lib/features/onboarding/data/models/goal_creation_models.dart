import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_creation_models.freezed.dart';
part 'goal_creation_models.g.dart';

/// Request model for creating a goal with AI
@freezed
class CreateGoalWithAIRequest with _$CreateGoalWithAIRequest {
  const factory CreateGoalWithAIRequest({
    required Map<String, dynamic> questionnaireData,
    String? mode, // 'customized' or 'faster'
  }) = _CreateGoalWithAIRequest;

  factory CreateGoalWithAIRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateGoalWithAIRequestFromJson(json);
}

/// Response model for goal creation
@freezed
class GoalCreationResult with _$GoalCreationResult {
  const factory GoalCreationResult({
    required String goalId,
    required String goalType,
    required String goalName,
    required double targetAmount,
    required DateTime targetDate,
    String? description,
    @Default({}) Map<String, dynamic> insights,
    List<String>? keyInsights,
    List<String>? nextSteps,
  }) = _GoalCreationResult;

  factory GoalCreationResult.fromJson(Map<String, dynamic> json) =>
      _$GoalCreationResultFromJson(json);
}

/// Financial health profile request
@freezed
class FinancialHealthProfileRequest with _$FinancialHealthProfileRequest {
  const factory FinancialHealthProfileRequest({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double currentSavings,
    required double existingDebts,
    required String riskTolerance, // 'low', 'medium', 'high'
    required int savingHorizon, // in months
    Map<String, dynamic>? additionalData,
  }) = _FinancialHealthProfileRequest;

  factory FinancialHealthProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$FinancialHealthProfileRequestFromJson(json);
}

/// Financial health profile response
@freezed
class FinancialHealthProfileResponse with _$FinancialHealthProfileResponse {
  const factory FinancialHealthProfileResponse({
    required bool success,
    required String profileId,
    String? message,
  }) = _FinancialHealthProfileResponse;

  factory FinancialHealthProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$FinancialHealthProfileResponseFromJson(json);
}

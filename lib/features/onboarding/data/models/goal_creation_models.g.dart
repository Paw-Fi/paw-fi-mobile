// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_creation_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CreateGoalWithAIRequestImpl _$$CreateGoalWithAIRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateGoalWithAIRequestImpl(
      questionnaireData: json['questionnaireData'] as Map<String, dynamic>,
      mode: json['mode'] as String?,
    );

Map<String, dynamic> _$$CreateGoalWithAIRequestImplToJson(
        _$CreateGoalWithAIRequestImpl instance) =>
    <String, dynamic>{
      'questionnaireData': instance.questionnaireData,
      'mode': instance.mode,
    };

_$GoalCreationResultImpl _$$GoalCreationResultImplFromJson(
        Map<String, dynamic> json) =>
    _$GoalCreationResultImpl(
      goalId: json['goalId'] as String,
      goalType: json['goalType'] as String,
      goalName: json['goalName'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      targetDate: DateTime.parse(json['targetDate'] as String),
      description: json['description'] as String?,
      insights: (json['insights'] as Map<String, dynamic>?) ?? const {},
      keyInsights: (json['keyInsights'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      nextSteps: (json['nextSteps'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$GoalCreationResultImplToJson(
        _$GoalCreationResultImpl instance) =>
    <String, dynamic>{
      'goalId': instance.goalId,
      'goalType': instance.goalType,
      'goalName': instance.goalName,
      'targetAmount': instance.targetAmount,
      'targetDate': instance.targetDate.toIso8601String(),
      'description': instance.description,
      'insights': instance.insights,
      'keyInsights': instance.keyInsights,
      'nextSteps': instance.nextSteps,
    };

_$FinancialHealthProfileRequestImpl
    _$$FinancialHealthProfileRequestImplFromJson(Map<String, dynamic> json) =>
        _$FinancialHealthProfileRequestImpl(
          monthlyIncome: (json['monthlyIncome'] as num).toDouble(),
          monthlyExpenses: (json['monthlyExpenses'] as num).toDouble(),
          currentSavings: (json['currentSavings'] as num).toDouble(),
          existingDebts: (json['existingDebts'] as num).toDouble(),
          riskTolerance: json['riskTolerance'] as String,
          savingHorizon: (json['savingHorizon'] as num).toInt(),
          additionalData: json['additionalData'] as Map<String, dynamic>?,
        );

Map<String, dynamic> _$$FinancialHealthProfileRequestImplToJson(
        _$FinancialHealthProfileRequestImpl instance) =>
    <String, dynamic>{
      'monthlyIncome': instance.monthlyIncome,
      'monthlyExpenses': instance.monthlyExpenses,
      'currentSavings': instance.currentSavings,
      'existingDebts': instance.existingDebts,
      'riskTolerance': instance.riskTolerance,
      'savingHorizon': instance.savingHorizon,
      'additionalData': instance.additionalData,
    };

_$FinancialHealthProfileResponseImpl
    _$$FinancialHealthProfileResponseImplFromJson(Map<String, dynamic> json) =>
        _$FinancialHealthProfileResponseImpl(
          success: json['success'] as bool,
          profileId: json['profileId'] as String,
          message: json['message'] as String?,
        );

Map<String, dynamic> _$$FinancialHealthProfileResponseImplToJson(
        _$FinancialHealthProfileResponseImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'profileId': instance.profileId,
      'message': instance.message,
    };

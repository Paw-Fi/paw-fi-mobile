// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_creation_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CreateGoalWithAIRequest _$CreateGoalWithAIRequestFromJson(
    Map<String, dynamic> json) {
  return _CreateGoalWithAIRequest.fromJson(json);
}

/// @nodoc
mixin _$CreateGoalWithAIRequest {
  Map<String, dynamic> get questionnaireData =>
      throw _privateConstructorUsedError;
  String? get mode => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CreateGoalWithAIRequestCopyWith<CreateGoalWithAIRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateGoalWithAIRequestCopyWith<$Res> {
  factory $CreateGoalWithAIRequestCopyWith(CreateGoalWithAIRequest value,
          $Res Function(CreateGoalWithAIRequest) then) =
      _$CreateGoalWithAIRequestCopyWithImpl<$Res, CreateGoalWithAIRequest>;
  @useResult
  $Res call({Map<String, dynamic> questionnaireData, String? mode});
}

/// @nodoc
class _$CreateGoalWithAIRequestCopyWithImpl<$Res,
        $Val extends CreateGoalWithAIRequest>
    implements $CreateGoalWithAIRequestCopyWith<$Res> {
  _$CreateGoalWithAIRequestCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionnaireData = null,
    Object? mode = freezed,
  }) {
    return _then(_value.copyWith(
      questionnaireData: null == questionnaireData
          ? _value.questionnaireData
          : questionnaireData as Map<String, dynamic>,
      mode: freezed == mode
          ? _value.mode
          : mode as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateGoalWithAIRequestImplCopyWith<$Res>
    implements $CreateGoalWithAIRequestCopyWith<$Res> {
  factory _$$CreateGoalWithAIRequestImplCopyWith(
          _$CreateGoalWithAIRequestImpl value,
          $Res Function(_$CreateGoalWithAIRequestImpl) then) =
      __$$CreateGoalWithAIRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<String, dynamic> questionnaireData, String? mode});
}

/// @nodoc
class __$$CreateGoalWithAIRequestImplCopyWithImpl<$Res>
    extends _$CreateGoalWithAIRequestCopyWithImpl<$Res,
        _$CreateGoalWithAIRequestImpl>
    implements _$$CreateGoalWithAIRequestImplCopyWith<$Res> {
  __$$CreateGoalWithAIRequestImplCopyWithImpl(
      _$CreateGoalWithAIRequestImpl _value,
      $Res Function(_$CreateGoalWithAIRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionnaireData = null,
    Object? mode = freezed,
  }) {
    return _then(_$CreateGoalWithAIRequestImpl(
      questionnaireData: null == questionnaireData
          ? _value._questionnaireData
          : questionnaireData as Map<String, dynamic>,
      mode: freezed == mode
          ? _value.mode
          : mode as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateGoalWithAIRequestImpl implements _CreateGoalWithAIRequest {
  const _$CreateGoalWithAIRequestImpl(
      {required final Map<String, dynamic> questionnaireData, this.mode})
      : _questionnaireData = questionnaireData;

  factory _$CreateGoalWithAIRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateGoalWithAIRequestImplFromJson(json);

  final Map<String, dynamic> _questionnaireData;
  @override
  Map<String, dynamic> get questionnaireData {
    if (_questionnaireData is EqualUnmodifiableMapView)
      return _questionnaireData;
    return EqualUnmodifiableMapView(_questionnaireData);
  }

  @override
  final String? mode;

  @override
  String toString() {
    return 'CreateGoalWithAIRequest(questionnaireData: $questionnaireData, mode: $mode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateGoalWithAIRequestImpl &&
            const DeepCollectionEquality()
                .equals(other._questionnaireData, _questionnaireData) &&
            (identical(other.mode, mode) || other.mode == mode));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_questionnaireData), mode);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateGoalWithAIRequestImplCopyWith<_$CreateGoalWithAIRequestImpl>
      get copyWith => __$$CreateGoalWithAIRequestImplCopyWithImpl<
          _$CreateGoalWithAIRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateGoalWithAIRequestImplToJson(
      this,
    );
  }
}

abstract class _CreateGoalWithAIRequest implements CreateGoalWithAIRequest {
  const factory _CreateGoalWithAIRequest(
      {required final Map<String, dynamic> questionnaireData,
      final String? mode}) = _$CreateGoalWithAIRequestImpl;

  factory _CreateGoalWithAIRequest.fromJson(Map<String, dynamic> json) =
      _$CreateGoalWithAIRequestImpl.fromJson;

  @override
  Map<String, dynamic> get questionnaireData;
  @override
  String? get mode;
  @override
  @JsonKey(ignore: true)
  _$$CreateGoalWithAIRequestImplCopyWith<_$CreateGoalWithAIRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

GoalCreationResult _$GoalCreationResultFromJson(Map<String, dynamic> json) {
  return _GoalCreationResult.fromJson(json);
}

/// @nodoc
mixin _$GoalCreationResult {
  String get goalId => throw _privateConstructorUsedError;
  String get goalType => throw _privateConstructorUsedError;
  String get goalName => throw _privateConstructorUsedError;
  double get targetAmount => throw _privateConstructorUsedError;
  DateTime get targetDate => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  Map<String, dynamic> get insights => throw _privateConstructorUsedError;
  List<String>? get keyInsights => throw _privateConstructorUsedError;
  List<String>? get nextSteps => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GoalCreationResultCopyWith<GoalCreationResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GoalCreationResultCopyWith<$Res> {
  factory $GoalCreationResultCopyWith(
          GoalCreationResult value, $Res Function(GoalCreationResult) then) =
      _$GoalCreationResultCopyWithImpl<$Res, GoalCreationResult>;
  @useResult
  $Res call(
      {String goalId,
      String goalType,
      String goalName,
      double targetAmount,
      DateTime targetDate,
      String? description,
      Map<String, dynamic> insights,
      List<String>? keyInsights,
      List<String>? nextSteps});
}

/// @nodoc
class _$GoalCreationResultCopyWithImpl<$Res, $Val extends GoalCreationResult>
    implements $GoalCreationResultCopyWith<$Res> {
  _$GoalCreationResultCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? goalType = null,
    Object? goalName = null,
    Object? targetAmount = null,
    Object? targetDate = null,
    Object? description = freezed,
    Object? insights = null,
    Object? keyInsights = freezed,
    Object? nextSteps = freezed,
  }) {
    return _then(_value.copyWith(
      goalId: null == goalId
          ? _value.goalId
          : goalId as String,
      goalType: null == goalType
          ? _value.goalType
          : goalType as String,
      goalName: null == goalName
          ? _value.goalName
          : goalName as String,
      targetAmount: null == targetAmount
          ? _value.targetAmount
          : targetAmount as double,
      targetDate: null == targetDate
          ? _value.targetDate
          : targetDate as DateTime,
      description: freezed == description
          ? _value.description
          : description as String?,
      insights: null == insights
          ? _value.insights
          : insights as Map<String, dynamic>,
      keyInsights: freezed == keyInsights
          ? _value.keyInsights
          : keyInsights as List<String>?,
      nextSteps: freezed == nextSteps
          ? _value.nextSteps
          : nextSteps as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GoalCreationResultImplCopyWith<$Res>
    implements $GoalCreationResultCopyWith<$Res> {
  factory _$$GoalCreationResultImplCopyWith(_$GoalCreationResultImpl value,
          $Res Function(_$GoalCreationResultImpl) then) =
      __$$GoalCreationResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String goalId,
      String goalType,
      String goalName,
      double targetAmount,
      DateTime targetDate,
      String? description,
      Map<String, dynamic> insights,
      List<String>? keyInsights,
      List<String>? nextSteps});
}

/// @nodoc
class __$$GoalCreationResultImplCopyWithImpl<$Res>
    extends _$GoalCreationResultCopyWithImpl<$Res, _$GoalCreationResultImpl>
    implements _$$GoalCreationResultImplCopyWith<$Res> {
  __$$GoalCreationResultImplCopyWithImpl(_$GoalCreationResultImpl _value,
      $Res Function(_$GoalCreationResultImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? goalId = null,
    Object? goalType = null,
    Object? goalName = null,
    Object? targetAmount = null,
    Object? targetDate = null,
    Object? description = freezed,
    Object? insights = null,
    Object? keyInsights = freezed,
    Object? nextSteps = freezed,
  }) {
    return _then(_$GoalCreationResultImpl(
      goalId: null == goalId
          ? _value.goalId
          : goalId as String,
      goalType: null == goalType
          ? _value.goalType
          : goalType as String,
      goalName: null == goalName
          ? _value.goalName
          : goalName as String,
      targetAmount: null == targetAmount
          ? _value.targetAmount
          : targetAmount as double,
      targetDate: null == targetDate
          ? _value.targetDate
          : targetDate as DateTime,
      description: freezed == description
          ? _value.description
          : description as String?,
      insights: null == insights
          ? _value._insights
          : insights as Map<String, dynamic>,
      keyInsights: freezed == keyInsights
          ? _value._keyInsights
          : keyInsights as List<String>?,
      nextSteps: freezed == nextSteps
          ? _value._nextSteps
          : nextSteps as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GoalCreationResultImpl implements _GoalCreationResult {
  const _$GoalCreationResultImpl(
      {required this.goalId,
      required this.goalType,
      required this.goalName,
      required this.targetAmount,
      required this.targetDate,
      this.description,
      final Map<String, dynamic> insights = const {},
      final List<String>? keyInsights,
      final List<String>? nextSteps})
      : _insights = insights,
        _keyInsights = keyInsights,
        _nextSteps = nextSteps;

  factory _$GoalCreationResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$GoalCreationResultImplFromJson(json);

  @override
  final String goalId;
  @override
  final String goalType;
  @override
  final String goalName;
  @override
  final double targetAmount;
  @override
  final DateTime targetDate;
  @override
  final String? description;
  final Map<String, dynamic> _insights;
  @override
  Map<String, dynamic> get insights {
    if (_insights is EqualUnmodifiableMapView) return _insights;
    return EqualUnmodifiableMapView(_insights);
  }

  final List<String>? _keyInsights;
  @override
  List<String>? get keyInsights {
    final value = _keyInsights;
    if (value == null) return null;
    if (_keyInsights is EqualUnmodifiableListView) return _keyInsights;
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _nextSteps;
  @override
  List<String>? get nextSteps {
    final value = _nextSteps;
    if (value == null) return null;
    if (_nextSteps is EqualUnmodifiableListView) return _nextSteps;
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'GoalCreationResult(goalId: $goalId, goalType: $goalType, goalName: $goalName, targetAmount: $targetAmount, targetDate: $targetDate, description: $description, insights: $insights, keyInsights: $keyInsights, nextSteps: $nextSteps)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GoalCreationResultImpl &&
            (identical(other.goalId, goalId) || other.goalId == goalId) &&
            (identical(other.goalType, goalType) ||
                other.goalType == goalType) &&
            (identical(other.goalName, goalName) ||
                other.goalName == goalName) &&
            (identical(other.targetAmount, targetAmount) ||
                other.targetAmount == targetAmount) &&
            (identical(other.targetDate, targetDate) ||
                other.targetDate == targetDate) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._insights, _insights) &&
            const DeepCollectionEquality()
                .equals(other._keyInsights, _keyInsights) &&
            const DeepCollectionEquality()
                .equals(other._nextSteps, _nextSteps));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      goalId,
      goalType,
      goalName,
      targetAmount,
      targetDate,
      description,
      const DeepCollectionEquality().hash(_insights),
      const DeepCollectionEquality().hash(_keyInsights),
      const DeepCollectionEquality().hash(_nextSteps));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GoalCreationResultImplCopyWith<_$GoalCreationResultImpl> get copyWith =>
      __$$GoalCreationResultImplCopyWithImpl<_$GoalCreationResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GoalCreationResultImplToJson(
      this,
    );
  }
}

abstract class _GoalCreationResult implements GoalCreationResult {
  const factory _GoalCreationResult(
      {required final String goalId,
      required final String goalType,
      required final String goalName,
      required final double targetAmount,
      required final DateTime targetDate,
      final String? description,
      final Map<String, dynamic> insights,
      final List<String>? keyInsights,
      final List<String>? nextSteps}) = _$GoalCreationResultImpl;

  factory _GoalCreationResult.fromJson(Map<String, dynamic> json) =
      _$GoalCreationResultImpl.fromJson;

  @override
  String get goalId;
  @override
  String get goalType;
  @override
  String get goalName;
  @override
  double get targetAmount;
  @override
  DateTime get targetDate;
  @override
  String? get description;
  @override
  Map<String, dynamic> get insights;
  @override
  List<String>? get keyInsights;
  @override
  List<String>? get nextSteps;
  @override
  @JsonKey(ignore: true)
  _$$GoalCreationResultImplCopyWith<_$GoalCreationResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinancialHealthProfileRequest _$FinancialHealthProfileRequestFromJson(
    Map<String, dynamic> json) {
  return _FinancialHealthProfileRequest.fromJson(json);
}

/// @nodoc
mixin _$FinancialHealthProfileRequest {
  double get monthlyIncome => throw _privateConstructorUsedError;
  double get monthlyExpenses => throw _privateConstructorUsedError;
  double get currentSavings => throw _privateConstructorUsedError;
  double get existingDebts => throw _privateConstructorUsedError;
  String get riskTolerance => throw _privateConstructorUsedError;
  int get savingHorizon => throw _privateConstructorUsedError;
  Map<String, dynamic>? get additionalData =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FinancialHealthProfileRequestCopyWith<FinancialHealthProfileRequest>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinancialHealthProfileRequestCopyWith<$Res> {
  factory $FinancialHealthProfileRequestCopyWith(
          FinancialHealthProfileRequest value,
          $Res Function(FinancialHealthProfileRequest) then) =
      _$FinancialHealthProfileRequestCopyWithImpl<$Res,
          FinancialHealthProfileRequest>;
  @useResult
  $Res call(
      {double monthlyIncome,
      double monthlyExpenses,
      double currentSavings,
      double existingDebts,
      String riskTolerance,
      int savingHorizon,
      Map<String, dynamic>? additionalData});
}

/// @nodoc
class _$FinancialHealthProfileRequestCopyWithImpl<$Res,
        $Val extends FinancialHealthProfileRequest>
    implements $FinancialHealthProfileRequestCopyWith<$Res> {
  _$FinancialHealthProfileRequestCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? monthlyIncome = null,
    Object? monthlyExpenses = null,
    Object? currentSavings = null,
    Object? existingDebts = null,
    Object? riskTolerance = null,
    Object? savingHorizon = null,
    Object? additionalData = freezed,
  }) {
    return _then(_value.copyWith(
      monthlyIncome: null == monthlyIncome
          ? _value.monthlyIncome
          : monthlyIncome as double,
      monthlyExpenses: null == monthlyExpenses
          ? _value.monthlyExpenses
          : monthlyExpenses as double,
      currentSavings: null == currentSavings
          ? _value.currentSavings
          : currentSavings as double,
      existingDebts: null == existingDebts
          ? _value.existingDebts
          : existingDebts as double,
      riskTolerance: null == riskTolerance
          ? _value.riskTolerance
          : riskTolerance as String,
      savingHorizon: null == savingHorizon
          ? _value.savingHorizon
          : savingHorizon as int,
      additionalData: freezed == additionalData
          ? _value.additionalData
          : additionalData as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FinancialHealthProfileRequestImplCopyWith<$Res>
    implements $FinancialHealthProfileRequestCopyWith<$Res> {
  factory _$$FinancialHealthProfileRequestImplCopyWith(
          _$FinancialHealthProfileRequestImpl value,
          $Res Function(_$FinancialHealthProfileRequestImpl) then) =
      __$$FinancialHealthProfileRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double monthlyIncome,
      double monthlyExpenses,
      double currentSavings,
      double existingDebts,
      String riskTolerance,
      int savingHorizon,
      Map<String, dynamic>? additionalData});
}

/// @nodoc
class __$$FinancialHealthProfileRequestImplCopyWithImpl<$Res>
    extends _$FinancialHealthProfileRequestCopyWithImpl<$Res,
        _$FinancialHealthProfileRequestImpl>
    implements _$$FinancialHealthProfileRequestImplCopyWith<$Res> {
  __$$FinancialHealthProfileRequestImplCopyWithImpl(
      _$FinancialHealthProfileRequestImpl _value,
      $Res Function(_$FinancialHealthProfileRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? monthlyIncome = null,
    Object? monthlyExpenses = null,
    Object? currentSavings = null,
    Object? existingDebts = null,
    Object? riskTolerance = null,
    Object? savingHorizon = null,
    Object? additionalData = freezed,
  }) {
    return _then(_$FinancialHealthProfileRequestImpl(
      monthlyIncome: null == monthlyIncome
          ? _value.monthlyIncome
          : monthlyIncome as double,
      monthlyExpenses: null == monthlyExpenses
          ? _value.monthlyExpenses
          : monthlyExpenses as double,
      currentSavings: null == currentSavings
          ? _value.currentSavings
          : currentSavings as double,
      existingDebts: null == existingDebts
          ? _value.existingDebts
          : existingDebts as double,
      riskTolerance: null == riskTolerance
          ? _value.riskTolerance
          : riskTolerance as String,
      savingHorizon: null == savingHorizon
          ? _value.savingHorizon
          : savingHorizon as int,
      additionalData: freezed == additionalData
          ? _value._additionalData
          : additionalData as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FinancialHealthProfileRequestImpl
    implements _FinancialHealthProfileRequest {
  const _$FinancialHealthProfileRequestImpl(
      {required this.monthlyIncome,
      required this.monthlyExpenses,
      required this.currentSavings,
      required this.existingDebts,
      required this.riskTolerance,
      required this.savingHorizon,
      final Map<String, dynamic>? additionalData})
      : _additionalData = additionalData;

  factory _$FinancialHealthProfileRequestImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$FinancialHealthProfileRequestImplFromJson(json);

  @override
  final double monthlyIncome;
  @override
  final double monthlyExpenses;
  @override
  final double currentSavings;
  @override
  final double existingDebts;
  @override
  final String riskTolerance;
  @override
  final int savingHorizon;
  final Map<String, dynamic>? _additionalData;
  @override
  Map<String, dynamic>? get additionalData {
    final value = _additionalData;
    if (value == null) return null;
    if (_additionalData is EqualUnmodifiableMapView) return _additionalData;
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'FinancialHealthProfileRequest(monthlyIncome: $monthlyIncome, monthlyExpenses: $monthlyExpenses, currentSavings: $currentSavings, existingDebts: $existingDebts, riskTolerance: $riskTolerance, savingHorizon: $savingHorizon, additionalData: $additionalData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinancialHealthProfileRequestImpl &&
            (identical(other.monthlyIncome, monthlyIncome) ||
                other.monthlyIncome == monthlyIncome) &&
            (identical(other.monthlyExpenses, monthlyExpenses) ||
                other.monthlyExpenses == monthlyExpenses) &&
            (identical(other.currentSavings, currentSavings) ||
                other.currentSavings == currentSavings) &&
            (identical(other.existingDebts, existingDebts) ||
                other.existingDebts == existingDebts) &&
            (identical(other.riskTolerance, riskTolerance) ||
                other.riskTolerance == riskTolerance) &&
            (identical(other.savingHorizon, savingHorizon) ||
                other.savingHorizon == savingHorizon) &&
            const DeepCollectionEquality()
                .equals(other._additionalData, _additionalData));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      monthlyIncome,
      monthlyExpenses,
      currentSavings,
      existingDebts,
      riskTolerance,
      savingHorizon,
      const DeepCollectionEquality().hash(_additionalData));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FinancialHealthProfileRequestImplCopyWith<
          _$FinancialHealthProfileRequestImpl>
      get copyWith => __$$FinancialHealthProfileRequestImplCopyWithImpl<
          _$FinancialHealthProfileRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinancialHealthProfileRequestImplToJson(
      this,
    );
  }
}

abstract class _FinancialHealthProfileRequest
    implements FinancialHealthProfileRequest {
  const factory _FinancialHealthProfileRequest(
          {required final double monthlyIncome,
          required final double monthlyExpenses,
          required final double currentSavings,
          required final double existingDebts,
          required final String riskTolerance,
          required final int savingHorizon,
          final Map<String, dynamic>? additionalData}) =
      _$FinancialHealthProfileRequestImpl;

  factory _FinancialHealthProfileRequest.fromJson(Map<String, dynamic> json) =
      _$FinancialHealthProfileRequestImpl.fromJson;

  @override
  double get monthlyIncome;
  @override
  double get monthlyExpenses;
  @override
  double get currentSavings;
  @override
  double get existingDebts;
  @override
  String get riskTolerance;
  @override
  int get savingHorizon;
  @override
  Map<String, dynamic>? get additionalData;
  @override
  @JsonKey(ignore: true)
  _$$FinancialHealthProfileRequestImplCopyWith<
          _$FinancialHealthProfileRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

FinancialHealthProfileResponse _$FinancialHealthProfileResponseFromJson(
    Map<String, dynamic> json) {
  return _FinancialHealthProfileResponse.fromJson(json);
}

/// @nodoc
mixin _$FinancialHealthProfileResponse {
  bool get success => throw _privateConstructorUsedError;
  String get profileId => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FinancialHealthProfileResponseCopyWith<FinancialHealthProfileResponse>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinancialHealthProfileResponseCopyWith<$Res> {
  factory $FinancialHealthProfileResponseCopyWith(
          FinancialHealthProfileResponse value,
          $Res Function(FinancialHealthProfileResponse) then) =
      _$FinancialHealthProfileResponseCopyWithImpl<$Res,
          FinancialHealthProfileResponse>;
  @useResult
  $Res call({bool success, String profileId, String? message});
}

/// @nodoc
class _$FinancialHealthProfileResponseCopyWithImpl<$Res,
        $Val extends FinancialHealthProfileResponse>
    implements $FinancialHealthProfileResponseCopyWith<$Res> {
  _$FinancialHealthProfileResponseCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? profileId = null,
    Object? message = freezed,
  }) {
    return _then(_value.copyWith(
      success: null == success
          ? _value.success
          : success as bool,
      profileId: null == profileId
          ? _value.profileId
          : profileId as String,
      message: freezed == message
          ? _value.message
          : message as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FinancialHealthProfileResponseImplCopyWith<$Res>
    implements $FinancialHealthProfileResponseCopyWith<$Res> {
  factory _$$FinancialHealthProfileResponseImplCopyWith(
          _$FinancialHealthProfileResponseImpl value,
          $Res Function(_$FinancialHealthProfileResponseImpl) then) =
      __$$FinancialHealthProfileResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, String profileId, String? message});
}

/// @nodoc
class __$$FinancialHealthProfileResponseImplCopyWithImpl<$Res>
    extends _$FinancialHealthProfileResponseCopyWithImpl<$Res,
        _$FinancialHealthProfileResponseImpl>
    implements _$$FinancialHealthProfileResponseImplCopyWith<$Res> {
  __$$FinancialHealthProfileResponseImplCopyWithImpl(
      _$FinancialHealthProfileResponseImpl _value,
      $Res Function(_$FinancialHealthProfileResponseImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? profileId = null,
    Object? message = freezed,
  }) {
    return _then(_$FinancialHealthProfileResponseImpl(
      success: null == success
          ? _value.success
          : success as bool,
      profileId: null == profileId
          ? _value.profileId
          : profileId as String,
      message: freezed == message
          ? _value.message
          : message as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FinancialHealthProfileResponseImpl
    implements _FinancialHealthProfileResponse {
  const _$FinancialHealthProfileResponseImpl(
      {required this.success, required this.profileId, this.message});

  factory _$FinancialHealthProfileResponseImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$FinancialHealthProfileResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String profileId;
  @override
  final String? message;

  @override
  String toString() {
    return 'FinancialHealthProfileResponse(success: $success, profileId: $profileId, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinancialHealthProfileResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, success, profileId, message);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FinancialHealthProfileResponseImplCopyWith<
          _$FinancialHealthProfileResponseImpl>
      get copyWith => __$$FinancialHealthProfileResponseImplCopyWithImpl<
          _$FinancialHealthProfileResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinancialHealthProfileResponseImplToJson(
      this,
    );
  }
}

abstract class _FinancialHealthProfileResponse
    implements FinancialHealthProfileResponse {
  const factory _FinancialHealthProfileResponse(
      {required final bool success,
      required final String profileId,
      final String? message}) = _$FinancialHealthProfileResponseImpl;

  factory _FinancialHealthProfileResponse.fromJson(Map<String, dynamic> json) =
      _$FinancialHealthProfileResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String get profileId;
  @override
  String? get message;
  @override
  @JsonKey(ignore: true)
  _$$FinancialHealthProfileResponseImplCopyWith<
          _$FinancialHealthProfileResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}

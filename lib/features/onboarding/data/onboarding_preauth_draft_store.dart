import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

const kOnboardingPreauthFlowVersion = 5;

const _kPreauthDraftKey = 'onboarding_preauth_draft_v2';
const _kPreauthCompletedKey = 'onboarding_preauth_completed';
const _kPreauthBoundPrefix = 'onboarding_preauth_bound:';
const _kPreauthSyncedPrefix = 'onboarding_preauth_synced:';

class OnboardingPreauthDraft {
  const OnboardingPreauthDraft({
    required this.currentStep,
    required this.flowVersion,
    required this.selectedCurrency,
    required this.monthlyBudget,
    required this.wantsSharedSpace,
    required this.householdProfile,
    required this.primaryGoal,
    required this.lifestyleFocus,
    required this.recommendedTemplateId,
    required this.spaceName,
    required this.spaceImageUrl,
    required this.spaceImagePath,
    required this.inviteEmail,
    required this.inviteMessage,
    required this.inviteExpiresInDays,
    required this.wantsStarterPockets,
    required this.onboardingFocus,
    required this.billSplitFrequency,
    required this.livingSituation,
    required this.eatingOutFrequency,
    required this.subscriptionsLevel,
    required this.hasPets,
    required this.petSpendLevel,
    required this.transportMode,
    required this.hasDependents,
    required this.dependentsTopCost,
    required this.dependentsCostAmount,
    required this.housingType,
    required this.housingPayment,
    required this.utilitiesKnown,
    required this.utilitiesAmount,
    required this.debtMinimumPayments,
    required this.savingsMode,
    required this.savingsAmount,
    required this.savingsPercent,
    required this.planAheadSelections,
    required this.bufferPreference,
    required this.updatedAtIso,
  });

  final int currentStep;
  final int flowVersion;
  final String selectedCurrency;
  final double monthlyBudget;
  final bool wantsSharedSpace;
  final String householdProfile;
  final String primaryGoal;
  final String lifestyleFocus;
  final String recommendedTemplateId;
  final String spaceName;
  final String spaceImageUrl;
  final String spaceImagePath;
  final String inviteEmail;
  final String inviteMessage;
  final int inviteExpiresInDays;
  final bool wantsStarterPockets;
  final String onboardingFocus;
  final String billSplitFrequency;
  final String livingSituation;
  final String eatingOutFrequency;
  final String subscriptionsLevel;
  final bool hasPets;
  final String petSpendLevel;
  final String transportMode;
  final bool hasDependents;
  final String dependentsTopCost;
  final double dependentsCostAmount;
  final String housingType;
  final double housingPayment;
  final bool utilitiesKnown;
  final double utilitiesAmount;
  final double debtMinimumPayments;
  final String savingsMode;
  final double savingsAmount;
  final double savingsPercent;
  final List<String> planAheadSelections;
  final String bufferPreference;
  final String updatedAtIso;

  static OnboardingPreauthDraft initial() {
    return OnboardingPreauthDraft(
      currentStep: 0,
      flowVersion: kOnboardingPreauthFlowVersion,
      selectedCurrency: '',
      monthlyBudget: 0,
      wantsSharedSpace: false,
      householdProfile: 'personal',
      primaryGoal: 'balanced',
      lifestyleFocus: 'general',
      recommendedTemplateId: 'personal_freelancer',
      spaceName: '',
      spaceImageUrl: '',
      spaceImagePath: '',
      inviteEmail: '',
      inviteMessage: '',
      inviteExpiresInDays: 7,
      wantsStarterPockets: true,
      onboardingFocus: 'track_spending',
      billSplitFrequency: 'none',
      livingSituation: 'renting',
      eatingOutFrequency: 'sometimes',
      subscriptionsLevel: 'few',
      hasPets: false,
      petSpendLevel: 'medium',
      transportMode: 'mixed',
      hasDependents: false,
      dependentsTopCost: '',
      dependentsCostAmount: 0,
      housingType: 'not_sure',
      housingPayment: 0,
      utilitiesKnown: false,
      utilitiesAmount: 0,
      debtMinimumPayments: 0,
      savingsMode: 'not_sure',
      savingsAmount: 0,
      savingsPercent: 0.1,
      planAheadSelections: const [],
      bufferPreference: 'normal',
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  OnboardingPreauthDraft copyWith({
    int? currentStep,
    int? flowVersion,
    String? selectedCurrency,
    double? monthlyBudget,
    bool? wantsSharedSpace,
    String? householdProfile,
    String? primaryGoal,
    String? lifestyleFocus,
    String? recommendedTemplateId,
    String? spaceName,
    String? spaceImageUrl,
    String? spaceImagePath,
    String? inviteEmail,
    String? inviteMessage,
    int? inviteExpiresInDays,
    bool? wantsStarterPockets,
    String? onboardingFocus,
    String? billSplitFrequency,
    String? livingSituation,
    String? eatingOutFrequency,
    String? subscriptionsLevel,
    bool? hasPets,
    String? petSpendLevel,
    String? transportMode,
    bool? hasDependents,
    String? dependentsTopCost,
    double? dependentsCostAmount,
    String? housingType,
    double? housingPayment,
    bool? utilitiesKnown,
    double? utilitiesAmount,
    double? debtMinimumPayments,
    String? savingsMode,
    double? savingsAmount,
    double? savingsPercent,
    List<String>? planAheadSelections,
    String? bufferPreference,
    String? updatedAtIso,
  }) {
    return OnboardingPreauthDraft(
      currentStep: currentStep ?? this.currentStep,
      flowVersion: flowVersion ?? this.flowVersion,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      wantsSharedSpace: wantsSharedSpace ?? this.wantsSharedSpace,
      householdProfile: householdProfile ?? this.householdProfile,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      lifestyleFocus: lifestyleFocus ?? this.lifestyleFocus,
      recommendedTemplateId:
          recommendedTemplateId ?? this.recommendedTemplateId,
      spaceName: spaceName ?? this.spaceName,
      spaceImageUrl: spaceImageUrl ?? this.spaceImageUrl,
      spaceImagePath: spaceImagePath ?? this.spaceImagePath,
      inviteEmail: inviteEmail ?? this.inviteEmail,
      inviteMessage: inviteMessage ?? this.inviteMessage,
      inviteExpiresInDays: inviteExpiresInDays ?? this.inviteExpiresInDays,
      wantsStarterPockets: wantsStarterPockets ?? this.wantsStarterPockets,
      onboardingFocus: onboardingFocus ?? this.onboardingFocus,
      billSplitFrequency: billSplitFrequency ?? this.billSplitFrequency,
      livingSituation: livingSituation ?? this.livingSituation,
      eatingOutFrequency: eatingOutFrequency ?? this.eatingOutFrequency,
      subscriptionsLevel: subscriptionsLevel ?? this.subscriptionsLevel,
      hasPets: hasPets ?? this.hasPets,
      petSpendLevel: petSpendLevel ?? this.petSpendLevel,
      transportMode: transportMode ?? this.transportMode,
      hasDependents: hasDependents ?? this.hasDependents,
      dependentsTopCost: dependentsTopCost ?? this.dependentsTopCost,
      dependentsCostAmount: dependentsCostAmount ?? this.dependentsCostAmount,
      housingType: housingType ?? this.housingType,
      housingPayment: housingPayment ?? this.housingPayment,
      utilitiesKnown: utilitiesKnown ?? this.utilitiesKnown,
      utilitiesAmount: utilitiesAmount ?? this.utilitiesAmount,
      debtMinimumPayments: debtMinimumPayments ?? this.debtMinimumPayments,
      savingsMode: savingsMode ?? this.savingsMode,
      savingsAmount: savingsAmount ?? this.savingsAmount,
      savingsPercent: savingsPercent ?? this.savingsPercent,
      planAheadSelections: planAheadSelections ?? this.planAheadSelections,
      bufferPreference: bufferPreference ?? this.bufferPreference,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStep': currentStep,
      'flowVersion': flowVersion,
      'selectedCurrency': selectedCurrency,
      'monthlyBudget': monthlyBudget,
      'wantsSharedSpace': wantsSharedSpace,
      'householdProfile': householdProfile,
      'primaryGoal': primaryGoal,
      'lifestyleFocus': lifestyleFocus,
      'recommendedTemplateId': recommendedTemplateId,
      'spaceName': spaceName,
      'spaceImageUrl': spaceImageUrl,
      'spaceImagePath': spaceImagePath,
      'inviteEmail': inviteEmail,
      'inviteMessage': inviteMessage,
      'inviteExpiresInDays': inviteExpiresInDays,
      'wantsStarterPockets': wantsStarterPockets,
      'onboardingFocus': onboardingFocus,
      'billSplitFrequency': billSplitFrequency,
      'livingSituation': livingSituation,
      'eatingOutFrequency': eatingOutFrequency,
      'subscriptionsLevel': subscriptionsLevel,
      'hasPets': hasPets,
      'petSpendLevel': petSpendLevel,
      'transportMode': transportMode,
      'hasDependents': hasDependents,
      'dependentsTopCost': dependentsTopCost,
      'dependentsCostAmount': dependentsCostAmount,
      'housingType': housingType,
      'housingPayment': housingPayment,
      'utilitiesKnown': utilitiesKnown,
      'utilitiesAmount': utilitiesAmount,
      'debtMinimumPayments': debtMinimumPayments,
      'savingsMode': savingsMode,
      'savingsAmount': savingsAmount,
      'savingsPercent': savingsPercent,
      'planAheadSelections': planAheadSelections,
      'bufferPreference': bufferPreference,
      'updatedAtIso': updatedAtIso,
    };
  }

  static OnboardingPreauthDraft fromJson(Map<String, dynamic> json) {
    return OnboardingPreauthDraft(
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      flowVersion: (json['flowVersion'] as num?)?.toInt() ?? 1,
      selectedCurrency:
          (json['selectedCurrency'] as String? ?? '').toUpperCase(),
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble() ?? 0,
      wantsSharedSpace: json['wantsSharedSpace'] as bool? ?? false,
      householdProfile: json['householdProfile'] as String? ?? 'personal',
      primaryGoal: json['primaryGoal'] as String? ?? 'balanced',
      lifestyleFocus: json['lifestyleFocus'] as String? ?? 'general',
      recommendedTemplateId:
          json['recommendedTemplateId'] as String? ?? 'personal_freelancer',
      spaceName: json['spaceName'] as String? ?? '',
      spaceImageUrl: json['spaceImageUrl'] as String? ?? '',
      spaceImagePath: json['spaceImagePath'] as String? ?? '',
      inviteEmail: json['inviteEmail'] as String? ?? '',
      inviteMessage: json['inviteMessage'] as String? ?? '',
      inviteExpiresInDays: (json['inviteExpiresInDays'] as num?)?.toInt() ?? 7,
      wantsStarterPockets: json['wantsStarterPockets'] as bool? ?? true,
      onboardingFocus: json['onboardingFocus'] as String? ?? 'track_spending',
      billSplitFrequency: json['billSplitFrequency'] as String? ?? 'none',
      livingSituation: json['livingSituation'] as String? ?? 'renting',
      eatingOutFrequency: json['eatingOutFrequency'] as String? ?? 'sometimes',
      subscriptionsLevel: json['subscriptionsLevel'] as String? ?? 'few',
      hasPets: json['hasPets'] as bool? ?? false,
      petSpendLevel: json['petSpendLevel'] as String? ?? 'medium',
      transportMode: json['transportMode'] as String? ?? 'mixed',
      hasDependents: json['hasDependents'] as bool? ?? false,
      dependentsTopCost: json['dependentsTopCost'] as String? ?? '',
      dependentsCostAmount:
          (json['dependentsCostAmount'] as num?)?.toDouble() ?? 0,
      housingType: json['housingType'] as String? ?? 'not_sure',
      housingPayment: (json['housingPayment'] as num?)?.toDouble() ?? 0,
      utilitiesKnown: json['utilitiesKnown'] as bool? ?? false,
      utilitiesAmount: (json['utilitiesAmount'] as num?)?.toDouble() ?? 0,
      debtMinimumPayments:
          (json['debtMinimumPayments'] as num?)?.toDouble() ?? 0,
      savingsMode: json['savingsMode'] as String? ?? 'not_sure',
      savingsAmount: (json['savingsAmount'] as num?)?.toDouble() ?? 0,
      savingsPercent: (json['savingsPercent'] as num?)?.toDouble() ?? 0.1,
      planAheadSelections: (json['planAheadSelections'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const [],
      bufferPreference: json['bufferPreference'] as String? ?? 'normal',
      updatedAtIso:
          json['updatedAtIso'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class OnboardingPreauthDraftStore {
  const OnboardingPreauthDraftStore(this._prefs);

  final SharedPreferences _prefs;

  OnboardingPreauthDraft load() {
    final raw = _prefs.getString(_kPreauthDraftKey);
    if (raw == null || raw.isEmpty) return OnboardingPreauthDraft.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return OnboardingPreauthDraft.initial();
      }
      return OnboardingPreauthDraft.fromJson(decoded);
    } catch (_) {
      return OnboardingPreauthDraft.initial();
    }
  }

  Future<void> save(OnboardingPreauthDraft draft) async {
    final updated =
        draft.copyWith(updatedAtIso: DateTime.now().toIso8601String());
    await _prefs.setString(_kPreauthDraftKey, jsonEncode(updated.toJson()));
  }

  bool isPreauthCompleted() => _prefs.getBool(_kPreauthCompletedKey) ?? false;

  Future<void> markPreauthCompleted() async {
    await _prefs.setBool(_kPreauthCompletedKey, true);
  }

  bool isSyncedForUser(String uid) =>
      _prefs.getBool('$_kPreauthSyncedPrefix$uid') ?? false;

  Future<void> markSyncedForUser(
      String uid, OnboardingPreauthDraft draft) async {
    await _prefs.setString(
        '$_kPreauthBoundPrefix$uid', jsonEncode(draft.toJson()));
    await _prefs.setBool('$_kPreauthSyncedPrefix$uid', true);
  }
}

final onboardingPreauthDraftStoreProvider =
    Provider<OnboardingPreauthDraftStore>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return OnboardingPreauthDraftStore(prefs);
  },
);

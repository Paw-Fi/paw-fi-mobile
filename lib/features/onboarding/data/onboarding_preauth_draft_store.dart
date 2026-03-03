import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

const _kPreauthDraftKey = 'onboarding_preauth_draft_v1';
const _kPreauthCompletedKey = 'onboarding_preauth_completed';
const _kPreauthBoundPrefix = 'onboarding_preauth_bound:';
const _kPreauthSyncedPrefix = 'onboarding_preauth_synced:';

class OnboardingPreauthDraft {
  const OnboardingPreauthDraft({
    required this.currentStep,
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
    required this.updatedAtIso,
  });

  final int currentStep;
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
  final String updatedAtIso;

  static OnboardingPreauthDraft initial() {
    return OnboardingPreauthDraft(
      currentStep: 0,
      selectedCurrency: 'USD',
      monthlyBudget: 1200,
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
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  OnboardingPreauthDraft copyWith({
    int? currentStep,
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
    String? updatedAtIso,
  }) {
    return OnboardingPreauthDraft(
      currentStep: currentStep ?? this.currentStep,
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
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStep': currentStep,
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
      'updatedAtIso': updatedAtIso,
    };
  }

  static OnboardingPreauthDraft fromJson(Map<String, dynamic> json) {
    return OnboardingPreauthDraft(
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      selectedCurrency:
          (json['selectedCurrency'] as String? ?? 'USD').toUpperCase(),
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble() ?? 1200,
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

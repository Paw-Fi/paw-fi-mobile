// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$onboardingDioHash() => r'8a5e8f2c3d4b5a6e7f8g9h0i1j2k3l4m';

/// Dio instance provider for onboarding API
///
/// Copied from [onboardingDio].
@ProviderFor(onboardingDio)
final onboardingDioProvider = AutoDisposeProvider<Dio>.internal(
  onboardingDio,
  name: r'onboardingDioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingDioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OnboardingDioRef = AutoDisposeProviderRef<Dio>;
String _$onboardingApiHash() => r'5n6o7p8q9r0s1t2u3v4w5x6y7z8a9b0c';

/// Onboarding API provider
///
/// Copied from [onboardingApi].
@ProviderFor(onboardingApi)
final onboardingApiProvider = AutoDisposeProvider<OnboardingApi>.internal(
  onboardingApi,
  name: r'onboardingApiProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingApiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OnboardingApiRef = AutoDisposeProviderRef<OnboardingApi>;
String _$onboardingRepositoryHash() =>
    r'd1e2f3g4h5i6j7k8l9m0n1o2p3q4r5s6';

/// Onboarding repository provider
///
/// Copied from [onboardingRepository].
@ProviderFor(onboardingRepository)
final onboardingRepositoryProvider =
    AutoDisposeProvider<OnboardingRepository>.internal(
  onboardingRepository,
  name: r'onboardingRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OnboardingRepositoryRef
    = AutoDisposeProviderRef<OnboardingRepository>;
String _$onboardingChatHash() => r't6u7v8w9x0y1z2a3b4c5d6e7f8g9h0i1';

/// Chat state provider
///
/// Copied from [OnboardingChat].
@ProviderFor(OnboardingChat)
final onboardingChatProvider =
    AutoDisposeNotifierProvider<OnboardingChat, List<ChatMessage>>.internal(
  OnboardingChat.new,
  name: r'onboardingChatProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$onboardingChatHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$OnboardingChat = AutoDisposeNotifier<List<ChatMessage>>;
String _$chatLoadingHash() => r'j2k3l4m5n6o7p8q9r0s1t2u3v4w5x6y7';

/// Loading state provider for chat
///
/// Copied from [ChatLoading].
@ProviderFor(ChatLoading)
final chatLoadingProvider =
    AutoDisposeNotifierProvider<ChatLoading, bool>.internal(
  ChatLoading.new,
  name: r'chatLoadingProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatLoading = AutoDisposeNotifier<bool>;
String _$currentGoalHash() => r'z8a9b0c1d2e3f4g5h6i7j8k9l0m1n2o3';

/// Current goal creation result provider
///
/// Copied from [CurrentGoal].
@ProviderFor(CurrentGoal)
final currentGoalProvider =
    AutoDisposeNotifierProvider<CurrentGoal, GoalCreationResult?>.internal(
  CurrentGoal.new,
  name: r'currentGoalProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentGoalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentGoal = AutoDisposeNotifier<GoalCreationResult?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

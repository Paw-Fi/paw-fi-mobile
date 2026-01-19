// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subscriptionNotifierHash() => r'3f7e9d5c8b2a4e6f1d9c7a5b3e1f8d6c';

/// See also [SubscriptionNotifier].
@ProviderFor(SubscriptionNotifier)
final subscriptionNotifierProvider = AutoDisposeAsyncNotifierProvider<
    SubscriptionNotifier, Subscription?>.internal(
  SubscriptionNotifier.new,
  name: r'subscriptionNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subscriptionNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SubscriptionNotifier = AutoDisposeAsyncNotifier<Subscription?>;
String _$hasActiveSubscriptionHash() => r'8e2f7c4d6a9b1e5f3c8d7a4b2e6f9c1d';

/// See also [hasActiveSubscription].
@ProviderFor(hasActiveSubscription)
final hasActiveSubscriptionProvider = AutoDisposeProvider<bool>.internal(
  hasActiveSubscription,
  name: r'hasActiveSubscriptionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasActiveSubscriptionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasActiveSubscriptionRef = AutoDisposeProviderRef<bool>;
String _$isSubscriptionLoadedHash() => r'1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d';

/// See also [isSubscriptionLoaded].
@ProviderFor(isSubscriptionLoaded)
final isSubscriptionLoadedProvider = AutoDisposeProvider<bool>.internal(
  isSubscriptionLoaded,
  name: r'isSubscriptionLoadedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isSubscriptionLoadedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsSubscriptionLoadedRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_initialization_provider_v2.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appInitializationV2Hash() => r'b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7';

/// Improved app initialization provider with cache-first strategy
/// 
/// Architecture:
/// 1. Load from cache immediately (if available) → instant UI
/// 2. Fetch fresh data in background
/// 3. Update UI when fresh data arrives
/// 4. Handle errors gracefully
/// 
/// Features:
/// - Cache-first loading (instant startup)
/// - Single backend RPC call (fast & reliable)
/// - Progressive loading (no blocking splash)
/// - Proper error handling
/// - Full observability (timing metrics)
///
/// Copied from [AppInitializationV2].
@ProviderFor(AppInitializationV2)
final appInitializationV2Provider =
    NotifierProvider<AppInitializationV2, AppInitializationState>.internal(
  AppInitializationV2.new,
  name: r'appInitializationV2Provider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appInitializationV2Hash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppInitializationV2 = Notifier<AppInitializationState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

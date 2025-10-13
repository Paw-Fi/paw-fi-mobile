// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_initialization_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appInitializationHash() => r'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';

/// Provider that manages app initialization
/// Ensures auth, subscription, WhatsApp binding, and analytics are loaded before routing
///
/// Copied from [AppInitialization].
@ProviderFor(AppInitialization)
final appInitializationProvider =
    NotifierProvider<AppInitialization, AppInitState>.internal(
  AppInitialization.new,
  name: r'appInitializationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appInitializationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppInitialization = Notifier<AppInitState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

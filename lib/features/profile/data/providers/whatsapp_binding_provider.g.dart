// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whatsapp_binding_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$whatsAppBindingHash() => r'9d4e7f2c6a1b5e8f3c9d8a7b4e2f6c1d';

/// Provider to check if user has bound their WhatsApp account
/// Keep alive to cache the binding status across navigation
///
/// Copied from [WhatsAppBinding].
@ProviderFor(WhatsAppBinding)
final whatsAppBindingProvider =
    AsyncNotifierProvider<WhatsAppBinding, bool>.internal(
  WhatsAppBinding.new,
  name: r'whatsAppBindingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$whatsAppBindingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WhatsAppBinding = AsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

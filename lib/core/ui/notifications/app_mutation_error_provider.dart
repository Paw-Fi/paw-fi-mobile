import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

@immutable
class AppMutationErrorEvent {
  const AppMutationErrorEvent({
    required this.id,
    required this.feature,
  });

  final String id;
  final String feature;
}

final appMutationErrorProvider =
    StateProvider<AppMutationErrorEvent?>((ref) => null);

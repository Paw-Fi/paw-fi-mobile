import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';

enum WidgetLaunchActionType {
  none,
  textInput,
  cameraInput,
  configure,
  openPockets,
}

@immutable
class WidgetLaunchEvent {
  final WidgetLaunchActionType type;
  final Map<String, String>? params;

  const WidgetLaunchEvent({
    this.type = WidgetLaunchActionType.none,
    this.params,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetLaunchEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          mapEquals(params, other.params);

  @override
  int get hashCode => type.hashCode ^ params.hashCode;
}

final widgetLaunchProvider =
    StateProvider<WidgetLaunchEvent>((ref) => const WidgetLaunchEvent());

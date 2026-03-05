import 'package:hooks_riverpod/hooks_riverpod.dart';

const kPreviewModeActiveKey = 'preview_mode_active';
const kPreviewReturnToPreauthKey = 'preview_return_to_preauth';

class PreviewModeState {
  const PreviewModeState({
    required this.isActive,
    this.activatedAt,
  });

  final bool isActive;
  final DateTime? activatedAt;

  PreviewModeState copyWith({
    bool? isActive,
    DateTime? activatedAt,
  }) {
    return PreviewModeState(
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }

  static const inactive = PreviewModeState(isActive: false);
}

class PreviewModeNotifier extends StateNotifier<PreviewModeState> {
  PreviewModeNotifier() : super(PreviewModeState.inactive);

  void enable() {
    if (state.isActive) return;
    state = PreviewModeState(
      isActive: true,
      activatedAt: DateTime.now(),
    );
  }

  void disable() {
    if (!state.isActive) return;
    state = PreviewModeState.inactive;
  }
}

final previewModeProvider =
    StateNotifierProvider<PreviewModeNotifier, PreviewModeState>(
  (ref) => PreviewModeNotifier(),
);

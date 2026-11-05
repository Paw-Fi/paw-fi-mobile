import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

bool _isPickingImage = false;
DateTime? _imagePickerGraceUntil;

bool get isImagePickerActive {
  final graceUntil = _imagePickerGraceUntil;
  return _isPickingImage ||
      (graceUntil != null && DateTime.now().isBefore(graceUntil));
}

Future<T?> runWithImagePickerLock<T>(Future<T?> Function() action) async {
  if (_isPickingImage) return null;
  _isPickingImage = true;
  try {
    return await action();
  } finally {
    _isPickingImage = false;
    _imagePickerGraceUntil = DateTime.now().add(const Duration(seconds: 2));
  }
}

Future<XFile?> pickImageWithGuard({
  required ImagePicker picker,
  required ImageSource source,
  BuildContext? touchShieldContext,
  int? imageQuality,
  double? maxWidth,
  double? maxHeight,
}) {
  return runWithImagePickerLock(
    () async {
      final overlay = source == ImageSource.camera && touchShieldContext != null
          ? Overlay.maybeOf(touchShieldContext, rootOverlay: true)
          : null;
      final touchShield = overlay == null
          ? null
          : OverlayEntry(
              builder: (_) => const Positioned.fill(
                child: AbsorbPointer(child: SizedBox.expand()),
              ),
            );
      if (touchShield != null) overlay!.insert(touchShield);

      try {
        return await picker.pickImage(
          source: source,
          imageQuality: imageQuality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      } finally {
        if (touchShield != null) {
          // Older iOS pickers leak Use Photo/Retake taps into Flutter and return
          // before their native dismissal finishes (flutter/flutter#173453).
          // Cover the root overlay, including the transaction sheet's barrier,
          // through that transition without delaying the captured photo result.
          Timer(const Duration(milliseconds: 500), () {
            touchShield.remove();
            touchShield.dispose();
          });
        }
      }
    },
  );
}

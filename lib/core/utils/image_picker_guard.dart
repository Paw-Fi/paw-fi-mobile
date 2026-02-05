import 'package:image_picker/image_picker.dart';

bool _isPickingImage = false;

Future<T?> runWithImagePickerLock<T>(Future<T?> Function() action) async {
  if (_isPickingImage) return null;
  _isPickingImage = true;
  try {
    return await action();
  } finally {
    _isPickingImage = false;
  }
}

Future<XFile?> pickImageWithGuard({
  required ImagePicker picker,
  required ImageSource source,
  int? imageQuality,
  double? maxWidth,
  double? maxHeight,
}) {
  return runWithImagePickerLock(
    () => picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    ),
  );
}

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

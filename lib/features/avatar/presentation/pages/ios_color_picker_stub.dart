// Stub implementation for web platform
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class IOSColorPickerController {
  void showIOSCustomColorPicker({
    required Color startingColor,
    required Function(Color) onColorChanged,
    required BuildContext context,
  }) {
    // Fallback to flutter_colorpicker on web
    MonekoAlertDialog.show(
      context: context,
      title: context.l10n.selectColor,
      confirmLabel: context.l10n.done,
      showCancelButton: false,
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: startingColor,
          onColorChanged: onColorChanged,
        ),
      ),
    );
  }
}

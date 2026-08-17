import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';

void main() {
  test('reads a supported receipt from the allowed directory', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    addTearDown(() => directory.delete(recursive: true));
    final receipt = File('${directory.path}/receipt.png');
    await receipt.writeAsBytes(_pngHeader);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, _pngHeader);
  });

  test('rejects receipt paths outside the allowed directory', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    final outsideDirectory =
        await Directory.systemTemp.createTemp('moneko-export-outside-');
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(() => outsideDirectory.delete(recursive: true));
    final receipt = File('${outsideDirectory.path}/receipt.png');
    await receipt.writeAsBytes(_pngHeader);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, isNull);
  });

  test('rejects a non-image file with an image extension', () async {
    final directory = await Directory.systemTemp.createTemp('moneko-export-');
    addTearDown(() => directory.delete(recursive: true));
    final receipt = File('${directory.path}/receipt.png');
    await receipt.writeAsBytes([1, 2, 3]);

    final bytes = await readLocalReceiptBytesForExport(
      receipt.path,
      allowedDirectories: [directory],
    );

    expect(bytes, isNull);
  });
}

const _pngHeader = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

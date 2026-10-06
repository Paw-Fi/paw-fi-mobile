import 'dart:io';

import 'package:flutter/services.dart';

/// Uses the Flutter SDK's normal text metrics for viewport fit assertions.
/// Ahem makes every character square and cannot represent a phone layout.
Future<void> loadPaywallTestFonts() async {
  final executable = Platform.resolvedExecutable.replaceAll('\\', '/');
  final cacheIndex = executable.indexOf('/bin/cache/');
  if (cacheIndex < 0) {
    throw StateError('Flutter SDK cache path is unavailable.');
  }
  final sdkRoot = executable.substring(0, cacheIndex);
  final font = ByteData.sublistView(await File(
    '$sdkRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ).readAsBytes());
  for (final family in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay'
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(font));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(File(
      '$sdkRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytes().then(ByteData.sublistView));
  await icons.load();
}
